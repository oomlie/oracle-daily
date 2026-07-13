#!/usr/bin/env sh
# oracle.sh — daily advice from the shell.
# zero deps. just sh, curl, awk, and an openrouter key.
# usage: oracle [plans-file]

set -u

PLANS_FILE="${1:-${ORACLE_PLANS:-$HOME/.config/oracle/plans.txt}}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
MODEL="${ORACLE_MODEL:-google/gemini-2.5-flash}"
LOCATION="${ORACLE_LOCATION:-auto}"
MAX_TOKENS="${ORACLE_MAX_TOKENS:-2048}"

json_escape() {
  printf '%s' "$1" | LC_ALL=C tr -d '\000-\010\013\014\016-\037' | awk '{gsub(/\\/,"\\\\")} {gsub(/"/,"\\\"")} {gsub(/\t/,"\\t")} {gsub(/\r/,"\\r")} NR>1{printf "\\n"} {printf "%s",$0}'
}

die() { printf '\033[31m[oracle] %s\033[0m\n' "$1" >&2; exit 1; }
info() { printf '\033[36m[oracle]\033[0m %s\n' "$1" >&2; }

for _dep in curl awk; do
  command -v "$_dep" >/dev/null 2>&1 || die "$_dep not found"
done

[ -z "$OPENROUTER_API_KEY" ] && die "no OPENROUTER_API_KEY. get one at https://openrouter.ai/settings/keys"

# ─── weather data (wttr.in) ──────────────────────────────────────────────────

fetch_weather() {
  local loc="$1"
  # %l=location %c=condition(emoji) %C=condition(text) %t=temp %f=feels_like
  # %w=wind %h=humidity %p=precip %P=pressure
  # %S=sunrise %s=sunset %m=moon(emoji) %u=uv
  local fmt="%l|%c|%C|%t|%f|%w|%h|%p|%P|%S|%s|%m|%u"
  local w
  w=$(curl -sS -m15 "https://wttr.in/${loc}?format=${fmt}&lang=en" 2>&1) || {
    info "weather fetch failed, proceeding without it"
    return 1
  }
  printf '%s' "$w" | sed 's/\x1b\[[0-9;]*m//g'
}

# ─── taskwarrior integration ─────────────────────────────────────────────────

fetch_taskwarrior() {
  command -v task >/dev/null 2>&1 || return 1
  local pending overdue urgent
  pending=$(task +PENDING count 2>/dev/null) || return 1
  overdue=$(task +OVERDUE count 2>/dev/null)
  urgent=$(task urgency \> 10.0 count 2>/dev/null)
  printf 'pending:%s\noverdue:%s\nurgent(>10):%s' "$pending" "$overdue" "$urgent"
}

# ─── read plans file ─────────────────────────────────────────────────────────

read_plans() {
  local f="$1"
  if [ -f "$f" ]; then
    cat "$f"
  else
    info "no plans file at $f — the oracle will improvise"
    return 1
  fi
}

# ─── time context ────────────────────────────────────────────────────────────

time_context() {
  local now_h now_epoch sunrise_epoch sunset_epoch daylight_h
  now_h=$(date +%H | sed 's/^0//')
  now_epoch=$(date +%s)

  printf 'current date: %s\ncurrent time: %s\nday of week: %s\n' \
    "$(date +%Y-%m-%d)" \
    "$(date +%H:%M)" \
    "$(date +%A)"

  # try to compute daylight remaining if we have sunrise/sunset later
  printf 'timestamp_epoch:%s\n' "$now_epoch"
}

# ─── daylight remaining calculation ───────────────────────────────────────────

daylight_remaining() {
  local sunrise="$1" sunset="$2" now_epoch="$3"
  local sunrise_epoch sunset_epoch remaining_h
  sunrise_epoch=$(date -d "$sunrise" +%s 2>/dev/null) || return 1
  sunset_epoch=$(date -d "$sunset" +%s 2>/dev/null) || return 1
  remaining_h=$(( (sunset_epoch - now_epoch) / 3600 ))
  [ "$remaining_h" -lt 0 ] && remaining_h=0
  printf '%s' "$remaining_h"
}

# ─── openrouter api ──────────────────────────────────────────────────────────

ask_oracle() {
  local system="$1"
  local user="$2"
  local sys_esc user_esc
  sys_esc=$(json_escape "$system")
  user_esc=$(json_escape "$user")

  curl -sS -m60 \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
    -H "Content-Type: application/json" \
    -H "HTTP-Referer: https://github.com/oomlie/oracle-daily" \
    -H "X-Title: oracle-daily" \
    -d "{\"model\":\"${MODEL}\",\"max_tokens\":${MAX_TOKENS},\"system\":\"${sys_esc}\",\"messages\":[{\"role\":\"user\",\"content\":\"${user_esc}\"}]}" \
    "https://openrouter.ai/api/v1/chat/completions" 2>&1
}

# ─── response parsing ────────────────────────────────────────────────────────

parse_oracle() {
  printf '%s' "$1" | awk 'BEGIN{RS="\001"}{
    tgt="\"content\""
    n=index($0,tgt); if(n==0){print "";exit}
    s=substr($0,n+length(tgt)); sub(/^[[:space:]]*:/,"",s); sub(/^[[:space:]]*"/,"",s)
    o=""
    while(1){
      p=index(s,"\""); if(p==0){o=o s;break}
      pre=substr(s,1,p-1); bs=0
      for(i=length(pre);i>=1;i--){if(substr(pre,i,1)=="\\")bs++;else break}
      o=o pre
      if(bs%2==1){o=o "\"";s=substr(s,p+1);continue}; break
    }
    gsub(/\\\\/,"\001",o); gsub(/\\n/,"\n",o); gsub(/\\t/,"\t",o); gsub(/\\r/,"\r",o); gsub(/\\"/,"\"",o); gsub(/\001/,"\\",o)
    printf "%s",o
  }'
}

check_error() {
  printf '%s' "$1" | awk 'BEGIN{RS="\001"}{
    if(match($0,/"error"[[:space:]]*:[[:space:]]*\{/)){
      n=index($0,"\"message\""); if(n==0) exit 0
      s=substr($0,n+10); sub(/^[[:space:]]*"/,"",s)
      p=index(s,"\""); if(p>0) print substr(s,1,p-1)
      exit 1
    }
  }'
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

info "consulting the digital oracle..."

# ─── gather inputs ───────────────────────────────────────────────────────────

TIME_CTX=$(time_context)
NOW_EPOCH=$(date +%s)

WEATHER_RAW=$(fetch_weather "$LOCATION") || WEATHER_RAW="unavailable"
PLANS=$(read_plans "$PLANS_FILE") || PLANS="no plans on file"
TASKS=$(fetch_taskwarrior) || TASKS="taskwarrior not available"

# ─── parse weather fields ────────────────────────────────────────────────────

WEATHER_CTX=""
DAYLIGHT_CTX=""
if [ "$WEATHER_RAW" != "unavailable" ]; then
  # format: loc|cond_emoji|cond_text|temp|feels|wind|humidity|precip|pressure|sunrise|sunset|moon|uv
  local LOC COND_EMOJI COND_TEXT TEMP FEELS WIND HUM PRECIP PRESSURE SUNRISE SUNSET MOON UV
  LOC=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $1}')
  COND_EMOJI=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $2}')
  COND_TEXT=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $3}')
  TEMP=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $4}')
  FEELS=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $5}')
  WIND=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $6}')
  HUM=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $7}')
  PRECIP=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $8}')
  PRESSURE=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $9}')
  SUNRISE=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $10}')
  SUNSET=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $11}')
  MOON=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $12}')
  UV=$(printf '%s' "$WEATHER_RAW" | awk -F'|' '{print $13}')

  WEATHER_CTX="location: ${LOC}
condition: ${COND_EMOJI} ${COND_TEXT}
temperature: ${TEMP} (feels like ${FEELS})
wind: ${WIND}
humidity: ${HUM}
precipitation: ${PRECIP}
pressure: ${PRESSURE}
sunrise: ${SUNRISE}
sunset: ${SUNSET}
moon: ${MOON}
uv index: ${UV}"

  # compute daylight remaining
  if [ -n "$SUNRISE" ] && [ -n "$SUNSET" ]; then
    local dl_h
    dl_h=$(daylight_remaining "$SUNRISE" "$SUNSET" "$NOW_EPOCH" 2>/dev/null) || dl_h=""
    [ -n "$dl_h" ] && DAYLIGHT_CTX="daylight remaining: ~${dl_h} hours"
  fi
else
  WEATHER_CTX="weather: unavailable"
fi

# ─── build prompts ───────────────────────────────────────────────────────────

SYSTEM_PROMPT="You are a daily oracle. A wise, slightly mystical advisor who tells people what they should do with the rest of their day.

You are practical but poetic. You consider:
- The weather (temperature, wind, UV, precipitation) and how it affects outdoor vs indoor activities
- Daylight remaining — urgent if only 1-2 hours left
- Moon phase for subtle mystical flavor
- The person's existing plans and commitments
- Pending tasks — if many are urgent/overdue, that shapes priorities
- The time of day (morning, afternoon, evening) and what makes sense energetically
- The day of the week (weekend vs weekday vibes)

Your output format:
1. A brief, evocative reading (2-3 sentences setting the mood)
2. Conditions (weather + daylight + moon, woven into 2-3 sentences)
3. Primary Focus (the one most important thing to do)
4. Secondary Actions (2-3 other worthwhile things)
5. Task Check (reference pending/urgent/overdue tasks if available)
6. Energy Check (a note about pacing — when to push, when to rest)
7. A one-line closing blessing/proverb

Keep it concise but meaningful. Total output: 150-300 words. Use markdown formatting."

USER_PROMPT="${TIME_CTX}
${DAYLIGHT_CTX}

WEATHER:
${WEATHER_CTX}

TASKS:
${TASKS}

PLANS:
${PLANS}

What should I do with the rest of my day?"

# ─── call the oracle ─────────────────────────────────────────────────────────

RESPONSE=$(ask_oracle "$SYSTEM_PROMPT" "$USER_PROMPT")

ERR_MSG=$(check_error "$RESPONSE")
if [ -n "$ERR_MSG" ]; then
  die "openrouter error: $ERR_MSG"
fi

READING=$(parse_oracle "$RESPONSE")

if [ -z "$READING" ]; then
  die "empty response from oracle. raw: $(printf '%s' "$RESPONSE" | head -c 500)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# OUTPUT
# ══════════════════════════════════════════════════════════════════════════════

printf '\n\033[1;35m═══════════════════════════════════════════════════════════════\033[0m\n'
printf '\033[1;35m  THE ORACLE SPEAKS\033[0m\n'
printf '\033[1;35m═══════════════════════════════════════════════════════════════\033[0m\n\n'
printf '%s\n\n' "$READING"
printf '\033[2m(model: %s)\033[0m\n' "$MODEL"
