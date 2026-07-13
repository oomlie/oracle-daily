# oracle-daily — high-value source integration plan

> sources that require more than a curl call, ranked by impact / effort.

## legend

- [ ] not started
- [~] planned
- [x] implemented

---

## tier 1 — highest impact, simplest integration

### [~] calendar remaining events
**what:** today's upcoming events from any caldav/google/ics source
**integration:** cron job exports `~/.config/oracle/calendar.txt` every 15min. oracle reads it like plans.
**effort:** low (if you already have calendar cli access)
**tooling:** `vdirsyncer`, `khal`, or a 10-line python script using google calendar API
**oracle impact:** "you have a meeting at 3pm — block deep work before then"

```bash
# ~/.config/oracle/calendar.txt (auto-generated)
14:00 — dentist appointment
16:30 — standup
19:00 — dinner with sam
```

### [~] open task count
**what:** number of pending tasks from taskwarrior, todo.txt, or simple file
**integration:** if `task` is installed, oracle already reads pending/overdue/urgent counts.
**effort:** done (taskwarrior integration is live)
**oracle impact:** "7 tasks pending, 2 overdue — tackle the oldest first"

### [~] sunset / daylight countdown
**what:** hours of daylight remaining
**integration:** computed from wttr.in sunrise/sunset. live in oracle.sh.
**effort:** done
**oracle impact:** "~2.5 hours of daylight left — outdoor tasks first"

---

## tier 2 — medium effort, high reward

### [ ] github assigned issues / prs
**what:** open PRs awaiting review, issues assigned to you
**integration:** `curl -H "Authorization: token $GH_TOKEN" https://api.github.com/issues`
**effort:** medium (needs auth token, rate limits, filtering)
**blockers:** need `$GITHUB_TOKEN` env var; nontrivial json parsing in awk
**oracle impact:** "3 PRs need your review — the longest has been waiting 2 days"

### [ ] unread messages / email count
**what:** unread count from fastmail/gmail/proton
**integration:** fastmail has JMAP (json over http, awk-parseable). gmail needs oauth2.
**effort:** medium (auth is the hard part)
**blockers:** oauth2 refresh tokens, session management
**oracle impact:** "12 unread — none are urgent, batch them for end of day"

### [ ] sleep last night
**what:** hours slept, sleep quality
**integration:** write `~/.config/oracle/sleep.txt` manually, or export from:
  - whoop / oura / apple health / garmin (all have APIs)
  - a simple "how did you sleep?" prompt on first run of the day
**effort:** low if manual, medium if automated
**oracle impact:** "you slept 5.5 hours — front-load easy wins, save hard tasks for tomorrow"

---

## tier 3 — high effort, niche value

### [ ] energy price / solar generation
**what:** real-time electricity price or home solar output
**integration:** curl to inverter API (shelly, enphase, solaredge) or electricity spot market API
**effort:** high (very personal setup, no universal API)
**oracle impact:** "solar generating 4kW — run dishwasher, do laundry, charge devices now"

### [ ] transit disruptions
**what:** local public transit delays / line closures
**integration:** most agencies have GTFS-realtime feeds or simple status endpoints
**effort:** medium (agency-specific, needs location-aware config)
**oracle impact:** "subway line 1 is down — plan 15 extra minutes or bike"

### [ ] screen time today
**what:** hours spent at computer/phone
**integration:** macOS: `osascript -e 'tell application "Screen Time"...'` (limited). linux: `w` command, activitywatch API, rescuetime API.
**effort:** medium (platform-specific)
**oracle impact:** "6 hours at the terminal — take a walk before your eyes give up"

### [ ] habit streaks
**what:** current streaks from a habit tracker
**integration:** read from a simple `~/.config/oracle/streaks.txt` file, auto-populated from:
  - git-journal (your existing system)
  - loop habit tracker (has export)
  - any plain text habit log
**effort:** low (file-based, no API needed)
**oracle impact:** "day 12 of your morning run streak — don't break it"

---

## implementation philosophy

keep the core oracle.sh **zero-dependency**. all high-value sources should be:

1. **file-based** — external scripts write to `~/.config/oracle/*.txt`, oracle reads them
2. **optional** — if the file doesn't exist, oracle proceeds gracefully
3. **external** — complex integrations live outside oracle.sh (python scripts, cron jobs, etc.)

this keeps oracle.sh minimal while making it infinitely extensible.

---

## example: calendar cron job

```bash
#!/bin/sh
# ~/.local/bin/oracle-calendar-sync
# runs every 15min via cron

export PATH="$HOME/.local/bin:$PATH"

# using khal (caldav cli)
khal list today today --format "{start-time} — {title}" > ~/.config/oracle/calendar.txt 2>/dev/null

# or using a simple python script with google calendar API
# python3 ~/.local/bin/gcal-export.py > ~/.config/oracle/calendar.txt
```

crontab entry:
```
*/15 * * * * ~/.local/bin/oracle-calendar-sync
```

oracle would read `~/.config/oracle/calendar.txt` if it exists and weave events into the reading.

---

## proposed file layout

```
~/.config/oracle/
├── plans.txt          # manual: your plans for the day
├── calendar.txt       # auto: upcoming events (cron job)
├── sleep.txt          # auto or manual: last night's sleep
├── streaks.txt        # auto: habit streaks (git-journal or tracker)
├── todos.txt          # auto: open task count (taskwarrior export)
└── github.txt         # auto: assigned issues/prs (cron job)
```

all optional. all file-based. all simple.
