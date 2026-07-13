# oracle-daily

> what should you do with the rest of your day?

```
nix run github:oomlie/oracle-daily
```

a [pu.sh](https://pu.dev)-style oracle. fetches weather, reads your plans, asks an llm (via [openrouter](https://openrouter.ai)), delivers wisdom.

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

## env

| var | default | description |
|---|---|---|
| `OPENROUTER_API_KEY` | — | required. your openrouter key |
| `ORACLE_MODEL` | `google/gemini-2.5-flash` | any openrouter model |
| `ORACLE_PLANS` | `~/.config/oracle/plans.txt` | plans file path |
| `ORACLE_LOCATION` | `auto` | weather location |
| `ORACLE_MAX_TOKENS` | `2048` | max response length |

pass a custom plans file: `oracle ~/my-plans.txt`

## test

```
nix flake check
```

## license

mit
