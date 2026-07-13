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

fetch_weather() {
  local loc="$1"
  local fmt="%l:+%c+%t+%w+%h+%p+%P+%S+%s\n"
  local w
  w=$(curl -sS -m15 "https://wttr.in/${loc}?format=${fmt}&lang=en" 2>&1) || {
    info "weather fetch failed, proceeding without it"
    return 1
  }
  printf '%s' "$w" | sed 's/\x1b\[[0-9;]*m//g'
}

read_plans() {
  local f="$1"
  if [ -f "$f" ]; then
    cat "$f"
  else
    info "no plans file at $f — the oracle will improvise"
    return 1
  fi
}

time_context() {
  printf 'current date: %s\ncurrent time: %s\nday of week: %s' \
    "$(date +%Y-%m-%d)" \
    "$(date +%H:%M)" \
    "$(date +%A)"
}

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

# ─── main ────────────────────────────────────────────────────────────────────

info "consulting the digital oracle..."

WEATHER=$(fetch_weather "$LOCATION") || WEATHER="weather unavailable"
PLANS=$(read_plans "$PLANS_FILE") || PLANS="no plans on file"
TIME_CTX=$(time_context)

SYSTEM_PROMPT="You are a daily oracle. A wise, slightly mystical advisor who tells people what they should do with the rest of their day.

You are practical but poetic. You consider:
- The weather and how it affects the day's possibilities
- The person's existing plans and commitments
- The time of day (morning, afternoon, evening) and what makes sense energetically
- The day of the week (weekend vs weekday vibes)

Your output format:
1. A brief, evocative reading (2-3 sentences setting the mood)
2. The Weather & Vibe (1-2 sentences)
3. Primary Focus (the one most important thing to do)
4. Secondary Actions (2-3 other worthwhile things)
5. Energy Check (a note about pacing — when to push, when to rest)
6. A one-line closing blessing/proverb

Keep it concise but meaningful. Total output: 150-300 words. Use markdown formatting."

USER_PROMPT="${TIME_CTX}

WEATHER:
${WEATHER}

MY PLANS:
${PLANS}

What should I do with the rest of my day?"

RESPONSE=$(ask_oracle "$SYSTEM_PROMPT" "$USER_PROMPT")

ERR_MSG=$(check_error "$RESPONSE")
if [ -n "$ERR_MSG" ]; then
  die "openrouter error: $ERR_MSG"
fi

READING=$(parse_oracle "$RESPONSE")

if [ -z "$READING" ]; then
  die "empty response from oracle. raw: $(printf '%s' "$RESPONSE" | head -c 500)"
fi

printf '\n\033[1;35m═══════════════════════════════════════════════════════════════\033[0m\n'
printf '\033[1;35m  THE ORACLE SPEAKS\033[0m\n'
printf '\033[1;35m═══════════════════════════════════════════════════════════════\033[0m\n\n'
printf '%s\n\n' "$READING"
printf '\033[2m(model: %s)\033[0m\n' "$MODEL"
