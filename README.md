# oracle-daily

> what should you do with the rest of your day?

```
nix run github:oomlie/oracle-daily
```

a [pu.sh](https://pu.dev)-style oracle. fetches weather (condition, temp, feels-like, wind, humidity, UV, precipitation, pressure, sunrise, sunset, moon phase), reads your [khal](https://github.com/pimutils/khal) calendar (auto-syncs via vdirsyncer), checks [taskwarrior](https://taskwarrior.org) for pending tasks, asks an llm via [openrouter](https://openrouter.ai), delivers wisdom.

zero runtime deps except `sh`, `curl`, `awk`.

## quickstart

```bash
# 1. install nix (the package manager) if you don't have it yet.
#    this is the official installer — it won't mess with your system.
#    after the install, close and reopen your terminal.
curl -L https://nixos.org/nix/install | sh

# 2. get an openrouter key (free to sign up, pay-as-you-go)
#    https://openrouter.ai/settings/keys
export OPENROUTER_API_KEY="sk-or-v1-..."

# 3. write your plans for the day
mkdir -p ~/.config/oracle
echo "- fix that bug
- eat something green
- touch grass" > ~/.config/oracle/plans.txt

# 4. consult the oracle
nix run github:oomlie/oracle-daily

# everything — model, location, plans path, personality, sync frequency —
# is configurable via environment variables. see the 'env' section below.

# try a different personality:
# ORACLE_PERSONALITY=drill nix run github:oomlie/oracle-daily
```

## as a flake input

```nix
{
  inputs.oracle-daily.url = "github:oomlie/oracle-daily";

  outputs = { self, nixpkgs, oracle-daily, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [{
        environment.systemPackages = [ oracle-daily.packages.x86_64-linux.default ];
      }];
    };
  };
}
```

## what it knows

| source | data | how |
|--------|------|-----|
| **wttr.in** | condition, temp, feels-like, wind, humidity, UV, precipitation, pressure, sunrise, sunset, moon phase | curl, auto-located |
| **khal + vdirsyncer** | today's calendar events (auto-syncs if vdirsyncer present) | `khal` binary if installed |
| **taskwarrior** | pending count, overdue count, urgent task count | `task` binary if installed |
| **plans file** | your plans for the day | `~/.config/oracle/plans.txt` |
| **computed** | daylight hours remaining | from sunrise/sunset |
| **computed** | time of day, day of week | local date |

see [PLAN.md](https://github.com/oomlie/oracle-daily/blob/main/PLAN.md) for planned high-value integrations (github issues, sleep tracking, habit streaks, etc.).

## env

| var | default | description |
|---|---|---|
| `OPENROUTER_API_KEY` | — | **required.** your openrouter key |
| `ORACLE_MODEL` | `google/gemini-2.5-flash` | any openrouter model |
| `ORACLE_PLANS` | `~/.config/oracle/plans.txt` | plans file path |
| `ORACLE_LOCATION` | `auto` | weather location |
| `ORACLE_MAX_TOKENS` | `2048` | max response length |
| `ORACLE_SYNC_AGE` | `15` | minutes before re-syncing vdirsyncer |
| `ORACLE_CALENDAR` | `~/.config/oracle/calendar.txt` | fallback calendar file |
| `ORACLE_PERSONALITY` | `wise` | personality preset (see below) |
| `ORACLE_SYSTEM_PROMPT` | — | **full override.** set a custom system prompt |

pass a custom plans file: `oracle ~/my-plans.txt`

## calendar

if `khal` is on your `$PATH`, the oracle automatically:
1. runs `vdirsyncer sync` (if available) — but only if the last sync was > 15 minutes ago
2. lists today's events via `khal list today today`

no cron job needed. the oracle syncs on demand.

**setup:** `nix-env -iA nixpkgs.khal nixpkgs.vdirsyncer`, configure vdirsyncer with your caldav/google calendar, run `vdirsyncer sync` once. the oracle handles the rest.

**fallback:** if khal isn't installed, the oracle reads `~/.config/oracle/calendar.txt` (one event per line).

## taskwarrior

if `task` is on your `$PATH`, the oracle automatically includes:
- pending task count
- overdue task count
- urgent task count (urgency > 10)

this gives the oracle a sense of your workload and helps it prioritize.

## personality

the oracle has built-in personality presets. set `ORACLE_PERSONALITY` to change the voice:

| preset | vibe |
|--------|------|
| `wise` (default) | mystical, poetic, practical. a gentle advisor. |
| `stoic` | Marcus Aurelius. calm, direct, no sympathy — only clarity. |
| `drill` | drill sergeant. barks orders. calls you "maggot." |
| `chaos` | surreal trickster. absurd metaphors, weirdly insightful. |
| `zen` | Zen master. koans, paradox, speaks like water. |
| `goth` | brooding oracle. velvet darkness, death, the sublime. |
| `yoda` | 900-year-old master. inverted syntax, cryptic wisdom. |
| `pirate` | weathered captain. nautical slang, tasks as treasure. |

```bash
ORACLE_PERSONALITY=drill nix run github:oomlie/oracle-daily
ORACLE_PERSONALITY=goth nix run github:oomlie/oracle-daily
```

for a fully custom voice, set `ORACLE_SYSTEM_PROMPT` to whatever you want. this overrides all presets:

```bash
ORACLE_SYSTEM_PROMPT="You are a hype beast. Every sentence ends with 'lets goooo'." \
  nix run github:oomlie/oracle-daily
```

## test

```
nix flake check
```

## license

WTFPL — do what the fuck you want to.
