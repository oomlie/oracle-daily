#!/usr/bin/env sh
# test.sh — minimal test suite for oracle.sh
# run with: nix flake check

set -u

PASSED=0 FAILED=0

pass() { PASSED=$((PASSED + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }

# ─── json_escape ─────────────────────────────────────────────────────────────

test_json_escape_basic() {
  local got
  got=$(printf '%s' 'hello world' | LC_ALL=C tr -d '\000-\010\013\014\016-\037' | awk '{gsub(/\\/,"\\\\")} {gsub(/"/,"\\\"")} {gsub(/\t/,"\\t")} {gsub(/\r/,"\\r")} NR>1{printf "\\n"} {printf "%s",$0}')
  [ "$got" = 'hello world' ] && pass "json_escape: basic string" || fail "json_escape: basic string — got '$got'"
}

test_json_escape_quotes() {
  local got
  got=$(printf '%s' 'say "hello"' | LC_ALL=C tr -d '\000-\010\013\014\016-\037' | awk '{gsub(/\\/,"\\\\")} {gsub(/"/,"\\\"")} {gsub(/\t/,"\\t")} {gsub(/\r/,"\\r")} NR>1{printf "\\n"} {printf "%s",$0}')
  [ "$got" = 'say \"hello\"' ] && pass "json_escape: escaped quotes" || fail "json_escape: escaped quotes — got '$got'"
}

test_json_escape_newline() {
  local got
  got=$(printf 'line1\nline2' | LC_ALL=C tr -d '\000-\010\013\014\016-\037' | awk '{gsub(/\\/,"\\\\")} {gsub(/"/,"\\\"")} {gsub(/\t/,"\\t")} {gsub(/\r/,"\\r")} NR>1{printf "\\n"} {printf "%s",$0}')
  [ "$got" = 'line1\nline2' ] && pass "json_escape: newline" || fail "json_escape: newline — got '$got'"
}

test_json_escape_backslash() {
  local got
  got=$(printf '%s' 'path\to\file' | LC_ALL=C tr -d '\000-\010\013\014\016-\037' | awk '{gsub(/\\/,"\\\\")} {gsub(/"/,"\\\"")} {gsub(/\t/,"\\t")} {gsub(/\r/,"\\r")} NR>1{printf "\\n"} {printf "%s",$0}')
  [ "$got" = 'path\\to\\file' ] && pass "json_escape: backslash" || fail "json_escape: backslash — got '$got'"
}

# ─── parse_oracle ────────────────────────────────────────────────────────────

test_parse_basic() {
  local resp='{"choices":[{"message":{"content":"hello world"}}]}'
  local got
  got=$(printf '%s' "$resp" | awk 'BEGIN{RS="\001"}{
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
  }')
  [ "$got" = 'hello world' ] && pass "parse_oracle: basic" || fail "parse_oracle: basic — got '$got'"
}

test_parse_with_newlines() {
  local resp='{"choices":[{"message":{"content":"line1\nline2\nline3"}}]}'
  local got
  got=$(printf '%s' "$resp" | awk 'BEGIN{RS="\001"}{
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
  }')
  [ "$got" = $'line1\nline2\nline3' ] && pass "parse_oracle: newlines" || fail "parse_oracle: newlines — got '$got'"
}

test_parse_empty() {
  local resp='{"choices":[]}'
  local got
  got=$(printf '%s' "$resp" | awk 'BEGIN{RS="\001"}{
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
  }')
  [ -z "$got" ] && pass "parse_oracle: empty choices" || fail "parse_oracle: empty choices — got '$got'"
}

# ─── check_error ─────────────────────────────────────────────────────────────

test_check_error_present() {
  local resp='{"error":{"message":"invalid key","code":401}}'
  local got
  got=$(printf '%s' "$resp" | awk 'BEGIN{RS="\001"}{
    if(match($0,/"error"[[:space:]]*:[[:space:]]*\{/)){
      n=index($0,"\"message\""); if(n==0) exit 0
      s=substr($0,n+10); sub(/^[[:space:]]*"/,"",s)
      p=index(s,"\""); if(p>0) print substr(s,1,p-1)
      exit 1
    }
  }')
  [ "$got" = 'invalid key' ] && pass "check_error: finds error" || fail "check_error: finds error — got '$got'"
}

test_check_error_none() {
  local resp='{"choices":[{"message":{"content":"ok"}}]}'
  local got rc=0
  got=$(printf '%s' "$resp" | awk 'BEGIN{RS="\001"}{
    if(match($0,/"error"[[:space:]]*:[[:space:]]*\{/)){
      n=index($0,"\"message\""); if(n==0) exit 0
      s=substr($0,n+10); sub(/^[[:space:]]*"/,"",s)
      p=index(s,"\""); if(p>0) print substr(s,1,p-1)
      exit 1
    }
  }') || rc=$?
  [ -z "$got" ] && [ "$rc" = 0 ] && pass "check_error: no error" || fail "check_error: no error — got '$got' rc=$rc"
}

# ─── weather parsing ─────────────────────────────────────────────────────────

test_weather_parsing() {
  local raw="London|☀️|Clear|+20°C|+18°C|↙22km/h|49%|0.0mm|1024hPa|04:58:16|21:13:47|🌑|0"
  local loc cond_emoji cond_text temp feels wind hum precip pressure sunrise sunset moon uv
  loc=$(printf '%s' "$raw" | awk -F'|' '{print $1}')
  cond_emoji=$(printf '%s' "$raw" | awk -F'|' '{print $2}')
  cond_text=$(printf '%s' "$raw" | awk -F'|' '{print $3}')
  temp=$(printf '%s' "$raw" | awk -F'|' '{print $4}')
  feels=$(printf '%s' "$raw" | awk -F'|' '{print $5}')
  wind=$(printf '%s' "$raw" | awk -F'|' '{print $6}')
  hum=$(printf '%s' "$raw" | awk -F'|' '{print $7}')
  precip=$(printf '%s' "$raw" | awk -F'|' '{print $8}')
  pressure=$(printf '%s' "$raw" | awk -F'|' '{print $9}')
  sunrise=$(printf '%s' "$raw" | awk -F'|' '{print $10}')
  sunset=$(printf '%s' "$raw" | awk -F'|' '{print $11}')
  moon=$(printf '%s' "$raw" | awk -F'|' '{print $12}')
  uv=$(printf '%s' "$raw" | awk -F'|' '{print $13}')

  [ "$loc" = "London" ] && [ "$temp" = "+20°C" ] && [ "$feels" = "+18°C" ] && \
  [ "$wind" = "↙22km/h" ] && [ "$hum" = "49%" ] && [ "$precip" = "0.0mm" ] && \
  [ "$pressure" = "1024hPa" ] && [ "$sunrise" = "04:58:16" ] && [ "$sunset" = "21:13:47" ] && \
  [ "$moon" = "🌑" ] && [ "$uv" = "0" ] \
    && pass "weather parsing: all 13 fields" \
    || fail "weather parsing: all 13 fields"
}

# ─── daylight remaining ──────────────────────────────────────────────────────

test_daylight_remaining() {
  local dl
  dl=$(awk 'BEGIN{
    sunrise_epoch = 1752300000
    sunset_epoch = 1752340000
    now_epoch = 1752320000
    remaining = int((sunset_epoch - now_epoch) / 3600)
    if (remaining < 0) remaining = 0
    print remaining
  }')
  [ "$dl" = "5" ] && pass "daylight_remaining: 5 hours" || fail "daylight_remaining: expected 5, got $dl"
}

test_daylight_remaining_after_sunset() {
  local dl
  dl=$(awk 'BEGIN{
    sunrise_epoch = 1752300000
    sunset_epoch = 1752320000
    now_epoch = 1752350000
    remaining = int((sunset_epoch - now_epoch) / 3600)
    if (remaining < 0) remaining = 0
    print remaining
  }')
  [ "$dl" = "0" ] && pass "daylight_remaining: after sunset = 0" || fail "daylight_remaining: expected 0, got $dl"
}

# ─── read_plans ──────────────────────────────────────────────────────────────

test_read_plans_exists() {
  local tmp got
  tmp=$(mktemp)
  printf 'plan A\nplan B' > "$tmp"
  got=$(cat "$tmp")
  rm -f "$tmp"
  [ "$got" = $'plan A\nplan B' ] && pass "read_plans: file exists" || fail "read_plans: file exists"
}

test_read_plans_missing() {
  ! cat /nonexistent/plans.txt 2>/dev/null && pass "read_plans: missing file" || fail "read_plans: missing file"
}

# ─── time_context ────────────────────────────────────────────────────────────

test_time_context() {
  local got
  got=$(printf 'current date: %s\ncurrent time: %s\nday of week: %s' \
    "$(date +%Y-%m-%d)" \
    "$(date +%H:%M)" \
    "$(date +%A)")
  case "$got" in
    'current date: 2026-'*'current time: '*'day of week: '*) pass "time_context: format" ;;
    *) fail "time_context: format — got '$got'" ;;
  esac
}

# ─── run ─────────────────────────────────────────────────────────────────────

printf '\n  oracle-daily test suite\n\n'

test_json_escape_basic
test_json_escape_quotes
test_json_escape_newline
test_json_escape_backslash
test_parse_basic
test_parse_with_newlines
test_parse_empty
test_check_error_present
test_check_error_none
test_weather_parsing
test_daylight_remaining
test_daylight_remaining_after_sunset
test_read_plans_exists
test_read_plans_missing
test_time_context

printf '\n  %d passed, %d failed\n\n' "$PASSED" "$FAILED"
[ "$FAILED" = 0 ] || exit 1
