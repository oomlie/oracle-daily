# oracle-daily

> what should you do with the rest of your day?

```
nix run github:oomlie/oracle-daily
```

a [pu.sh](https://pu.dev)-style oracle. fetches weather (condition, temp, feels-like, wind, humidity, UV, precipitation, pressure, sunrise, sunset, moon phase), reads your [khal](https://github.com/pimutils/khal) calendar (auto-syncs via vdirsyncer), checks [taskwarrior](https://taskwarrior.org) for pending tasks, asks an llm via [openrouter](https://openrouter.ai), delivers wisdom.

zero runtime deps except `sh`, `curl`, `awk`.

## quickstart

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
echo "- fix that bug
- eat something green" > ~/.config/oracle/plans.txt
nix run github:oomlie/oracle-daily
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

## test

```
nix flake check
```

## license

mit
