**English** | [한국어](commands.ko.md)

# Command reference

> The complete CLI reference for `cctg` — every command, flag, and behavior, verified against the source.

## Table of Contents

- [Synopsis](#synopsis)
- [Conventions](#conventions)
- [Bot lifecycle](#bot-lifecycle)
  - [`add`](#add)
  - [`rm`](#rm)
  - [`rename`](#rename)
- [Run control](#run-control)
  - [`up`](#up)
  - [`down`](#down)
  - [`restart`](#restart)
- [Observe](#observe)
  - [`status`](#status)
  - [`logs`](#logs)
  - [`attach`](#attach)
- [Configuration](#configuration)
  - [`config`](#config)
    - [config cwd](#config-cwd)
    - [config token](#config-token)
  - [`common`](#common)
  - [`lang`](#lang)
- [Maintenance](#maintenance)
  - [`doctor`](#doctor)
  - [`update`](#update)
  - [`version`](#version)
  - [`help`](#help)
- [See also](#see-also)

## Synopsis

```
cctg <command> [args]
  add <name> <cwd> [--channel telegram|discord] [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--group <id>[:nomention][:allow=m1,m2]]
  rm <name> [--purge]          rename <old> <new> [--keep-dir]
  config <name> [show|edit|mode <m|clear>|args <str>|snapshot <secs|off>|cwd <path>|token]
  common [...]
  up <name...|all|telegram|discord>    down <name...|all|telegram|discord>
  restart <name...|all|telegram|discord>
  status [--json]              logs <name|telegram|discord> [N]          attach <name>
  lang [show|en|ko|clear]
  doctor    update    version    help
```

A bot is one project's Claude Code channel session: a working directory, a channel (Telegram or Discord) with its token and access policy, and a detached `tmux` session named `cctg-<name>`. The global channel bots (whose state lives in `~/.claude/channels/<channel>/`) can now be started, stopped, and observed via the reserved names `telegram` and `discord`.

Every subcommand accepts `--help` (or `-h`) to print a one-line usage summary and exit.

## Conventions

- **Bot names** may contain only `[A-Za-z0-9_-]`. The names `telegram`, `discord`, `imessage`, and `fakechat` are **reserved**: `add`, `rm`, and `rename` refuse them. However, `telegram` and `discord` can now be used with `up`, `down`, `restart`, `status`, and `logs` to control the global channel bots (see [Run control](#run-control)).
- The CLI is **bilingual** (English / Korean). The examples below show English output; switch with [`lang`](#lang).
- Paths, numeric IDs, and tokens in examples are **placeholders** — substitute your own.
- `version`/`-v`/`--version` and `help`/`-h`/`--help`/no-args are aliases of `version` and `help`.
- Every subcommand accepts `--help` (`-h`) to print a usage line and exit with code `0`.

## Bot lifecycle

### `add`

```
cctg add <name> <cwd> [--channel telegram|discord] [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--group <id>[:nomention][:allow=m1,m2]]
```

Registers a new bot for the working directory `<cwd>` and scaffolds its state directory at `~/.claude/channels/<name>/`. The state directory holds the bot token (`.env`, mode `600`), the access policy (`access.json`), an `inbox/`, and per-bot options (`launch.env`).

`add` is **interactive by default** — it prompts for the token (masked), the channel ID, and the permission mode. Supplying either `--token-env` or `--token-stdin` switches it to **non-interactive mode**, where it never prompts: for Telegram you must then also pass `--id`, and the permission mode follows the shared policy unless `--mode` is given.

Channel behavior differs by `--channel` (default `telegram`):

- **Telegram** — an ID is required (non-interactively, via `--id`). The given ID seeds the allowlist (DM policy `allowlist`, `allowFrom: ["<id>"]`), so no pairing is needed.
- **Discord** — the ID is optional. Without an ID the bot starts with the `pairing` DM policy and an empty allowlist; pair from the channel afterward.

For full first-time setup walkthroughs see [telegram-setup.md](telegram-setup.md) and [discord-setup.md](discord-setup.md).

Flags:

| Flag | Meaning |
|---|---|
| `--channel telegram\|discord` | Channel type. Default `telegram`. |
| `--id <num>` | Numeric channel ID. Required for Telegram in non-interactive mode; optional for Discord. Must match `^[0-9]+$`. |
| `--token-env <VAR>` | Read the bot token from environment variable `VAR`. Switches to non-interactive mode. The token is never passed on `argv` (it would leak in the process list). |
| `--token-stdin` | Read the bot token from stdin. Switches to non-interactive mode. |
| `--mode <m>` | Permission mode: `acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, or `plan`. |
| `--group <id>[:nomention][:allow=csv]` | Discord server-channel access (repeatable). `id` must be numeric; `:nomention` clears the mention requirement; `:allow=csv` is a comma-separated list of numeric member IDs. Requires `jq`. |

```console
$ cctg add proj ~/code/proj --channel telegram --id 123456789 --token-env PROJ_BOT_TOKEN --mode acceptEdits
$ cctg add gamebot ~/code/game --channel discord --token-stdin --group 555000111:nomention:allow=42,43
```

### `rm`

```
cctg rm <name> [--purge]
```

Unregisters a bot. By default the **state directory is kept** so its token and allowlist can be reused later; only the registry entry is removed. Stop a running bot with [`down`](#down) first — `rm` refuses while the session is running.

`--purge` also deletes the state directory, but only when it is under `~/.claude/channels/` and is not a reserved global channel directory. Paths outside `CHANNELS_DIR` and the global channel directories are never deleted (a notice is printed instead).

```console
$ cctg rm proj
$ cctg rm proj --purge
```

### `rename`

```
cctg rename <old> <new> [--keep-dir]
```

Renames a bot. The new name must be valid and not already registered. Stop a running bot first — `rename` refuses while running, because the `tmux` session name (`cctg-<name>`) is derived from the bot name.

By default the state directory is also moved, **but only when it sits at the default path** `~/.claude/channels/<old>/`; the move target must not already exist. For a custom state-directory path, or with `--keep-dir`, only the registered name and the `tmux` session name change — the directory stays put.

```console
$ cctg rename proj proj-archived
$ cctg rename proj proj2 --keep-dir
```

## Run control

### `up`

```
cctg up <name...|all|telegram|discord>
```

Starts a bot in a detached `tmux` session named `cctg-<name>`. The session runs `caffeinate -is claude --channels <plugin> --settings <shared> [--permission-mode <mode>] [extra args]`, where the channel's state directory is injected via its environment variable (`TELEGRAM_STATE_DIR` / `DISCORD_STATE_DIR`). The shared permission policy is injected with `--settings`; a per-bot `CCTG_PERMISSION_MODE` (from `launch.env`) overrides the shared `defaultMode`, and `CLAUDE_EXTRA_ARGS` is appended.

The working directory and the bot's `.env` (token) must exist, or `up` reports an error. If `CCTG_LOG_SNAPSHOT_INTERVAL` is set for the bot, a periodic snapshot watcher is also started. `cctg up all` starts every registered bot.

**Multiple targets**: `up`, `down`, and `restart` accept several targets at once (names, reserved channel names, and/or `all`), processed sequentially left to right. Processing is **continue-on-error** — a failing target does not stop the rest. When two or more targets are processed, a summary line (succeeded / failed counts, with failed names) is printed, and the command exits non-zero if any target failed. A single target behaves exactly as before (no summary line).

**Global channel bots (`telegram` / `discord`)**: passing a reserved channel name bypasses the registry and uses `~/.claude/channels/<channel>/` as the state directory. The working directory (`cwd`) is whatever directory you run `cctg up` from at that moment. A **sole-owner guard** refuses startup if a `cctg-<channel>` tmux session already exists or if `bot.pid` in the state directory holds a live PID (the plugin's own runner is active). A missing `.env` is also refused.

```console
$ cctg up proj
$ cctg up proj1 proj2 telegram   # several targets, sequential
$ cctg up all
$ cctg up telegram
$ cctg up discord
```

### `down`

```
cctg down <name...|all|telegram|discord>
```

Stops a bot. Before killing the `tmux` session it saves a snapshot of the session pane to `<state>/last-session.log` (so [`logs`](#logs) keeps working after the bot is stopped) and stops any running snapshot watcher. `cctg down all` stops every registered bot. Stopping an already-stopped bot still cleans up any leftover snapshot-watcher PID file.

**Global channel bots (`telegram` / `discord`)**: only the `cctg-<channel>` tmux session is stopped. The channel plugin's own runner (`bot.pid` process) is not touched — this limit is shown in the output message when no session exists.

```console
$ cctg down proj
$ cctg down all
$ cctg down telegram
```

### `restart`

```
cctg restart <name...|all|telegram|discord>
```

`down` followed by `up`. Use it to apply configuration changes (permission mode, extra args, snapshot interval, shared policy) to a running bot. Accepts the reserved names `telegram` and `discord` to restart a global channel bot.

```console
$ cctg restart proj
$ cctg restart telegram
```

## Observe

### `status`

```
cctg status [--json]
```

Prints per-bot status. For each bot it shows the state — `RUNNING` (with uptime) / `DEAD` / `BROKEN` / `stopped` — plus the working and state directory paths, the permission mode (or `shared`), a **last-activity** line, and the channel. When `jq` is present and `access.json` exists, the channel line also shows the DM policy and the number of group entries (topology). Bots are listed `RUNNING → DEAD → BROKEN → stopped`.

The **last-activity** line (`last  <dur> ago`) shows how long ago the bot last produced output. For a live session it comes from the tmux `#{window_activity}` time; for a stopped bot it falls back to the `last-session.log` snapshot mtime; when no signal exists the line is omitted. It is an auxiliary indicator for spotting a bot that is up but idle/stalled — distinct from the `DEAD` health check.

A bot is `DEAD` when its `tmux` session is still alive but the `claude` process inside it has exited (a crash/exit leaves a bare `bash` in the pane via the launch's `exec bash` tail, which would otherwise look "running"). The state is detected by walking the session pane's process descendant tree for a `claude` process. A `restart` hint is printed; `up` does not auto-restart it.

A bot is `BROKEN` when it is registered but its working directory is missing or its `.env` (token) is absent; a per-reason recovery hint is printed.

A `--- global channel bots ---` section is appended for each reserved channel whose state directory (`~/.claude/channels/<channel>/`) exists. The displayed `cwd` for global bots is the directory from which `cctg status` was invoked (because global bots have no registered working directory).

`--json` emits a machine-readable array of objects with locale-independent tokens (requires `jq`). Each object has `name`, `state` (`running`/`dead`/`broken`/`stopped`), `running` (bool — `false` for `dead`), `cwd`, `stateDir`, `mode`, `channel`, `session`, `uptimeSeconds` (or `null`; `null` for `dead`), `lastActivitySeconds` (seconds since last activity, or `null` when unknown), and `issues` (e.g. `no-cwd`, `no-token`).

```console
$ cctg status
$ cctg status --json
```

```json
[
  {
    "name": "proj",
    "state": "running",
    "running": true,
    "cwd": "/Users/me/code/proj",
    "stateDir": "/Users/me/.claude/channels/proj",
    "mode": "acceptEdits",
    "channel": "telegram",
    "session": "cctg-proj",
    "uptimeSeconds": 3600,
    "lastActivitySeconds": 42,
    "issues": []
  }
]
```

### `logs`

```
cctg logs <name|telegram|discord> [N]
```

Prints the last `N` log lines (default `50`). While the bot is running it reads the live `tmux` pane (scrollback up to 2000 lines). While stopped it falls back to the `<state>/last-session.log` snapshot (written on [`down`](#down) or by the periodic snapshotter). If the bot is stopped and no snapshot exists, it reports an error.

Accepts the reserved names `telegram` and `discord` to read the global channel bot logs from `~/.claude/channels/<channel>/`.

```console
$ cctg logs proj
$ cctg logs proj 200
$ cctg logs telegram
```

### `attach`

```
cctg attach <name>
```

Attaches to the bot's live `tmux` session for an interactive view. Detach with `Ctrl-b d`. Requires a running session.

```console
$ cctg attach proj
```

## Configuration

### `config`

```
cctg config <name> [show | edit | mode <m|clear> | args <str> | snapshot <secs|off> | width <cols|clear> | cwd <path> | token [--token-env <VAR>|--token-stdin]]
```

Views or edits a bot's per-bot options, stored in `<state>/launch.env`. Changes take effect on the next [`up`](#up) / [`restart`](#restart); when the bot is running, `cctg` reminds you to restart.

| Action | Meaning |
|---|---|
| `show` (default) | Prints the channel, permission mode, snapshot interval, session width, and the `launch.env` contents. |
| `edit` | Opens `launch.env` in `$EDITOR` (default `vi`). |
| `mode <m>` | Sets `CCTG_PERMISSION_MODE` (one of `acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, `plan`). |
| `mode clear` | Empties the mode so the bot follows the shared `defaultMode`. |
| `args <str>` | Sets `CLAUDE_EXTRA_ARGS`, e.g. `"--model opus"`. Must be a single line — a value containing a newline is rejected (use `config <name> edit` for multi-line edits). |
| `snapshot <secs>` | Enables a periodic log snapshot every `<secs>` seconds (minimum `5`). |
| `snapshot off` | Disables periodic snapshots (also accepts `0`; off is the default). |
| `width <cols>` | Sets this bot's detached session width (`CCTG_SESS_WIDTH`, minimum `20`). |
| `width clear` | Empties the per-bot width so the bot follows the global default (also accepts `default`). |
| `cwd <path>` | <a name="config-cwd"></a>Changes the bot's working directory in the registry. The path must already exist. If the bot is running, a restart reminder is shown. |
| `token` | <a name="config-token"></a>Replaces the bot's token in `<state>/.env` (mode `600`). Accepts `--token-env <VAR>`, `--token-stdin`, or an interactive masked prompt. The token key (`TELEGRAM_BOT_TOKEN` / `DISCORD_BOT_TOKEN`) is determined by the bot's channel. If the bot is running, a restart reminder is shown. |

For the permission model itself, see [permissions.md](permissions.md).

```console
$ cctg config proj
$ cctg config proj mode bypassPermissions
$ cctg config proj args "--model opus"
$ cctg config proj snapshot 60
$ cctg config proj snapshot off
$ cctg config proj width 200
$ cctg config proj width clear
$ cctg config proj cwd ~/new/path/to/proj
$ cctg config proj token --token-stdin
$ cctg config proj token --token-env NEW_BOT_TOKEN
```

### `common`

```
cctg common [show | edit | mode <m> | width <cols|clear> | deny add|rm <rule> | allow add|rm <rule>]
```

Views or edits the shared permission policy that is injected into every bot via `--settings`, plus the global default session width. The settings file is auto-created on the first `add`/`up`. The `mode`, `deny`, and `allow` actions require `jq`.

| Action | Meaning |
|---|---|
| `show` (default) | Prints the global default session width (with its source) and the shared settings file. |
| `edit` | Opens the file in `$EDITOR`. |
| `mode <m>` | Sets `permissions.defaultMode`. |
| `width <cols>` | Sets the global default detached session width (minimum `20`), stored in `~/.config/cctg/config` (`sess_width`) — not in the permission settings file. |
| `width clear` | Removes the global default so it falls back to the built-in default (`100`; also accepts `default`). |
| `deny add <rule>` / `deny rm <rule>` | Adds/removes a deny rule, e.g. `Bash(sudo *)`. |
| `allow add <rule>` / `allow rm <rule>` | Adds/removes an allow rule. |

The effective width for a bot resolves as: per-bot `width` → env `CC_TG_SESS_WIDTH` → global `common width` → built-in default (`100`). For the full permission model, see [permissions.md](permissions.md).

```console
$ cctg common
$ cctg common mode default
$ cctg common width 160
$ cctg common width clear
$ cctg common deny add "Bash(sudo *)"
$ cctg common allow add "Read(~/notes/**)"
```

### `lang`

```
cctg lang [show | en | ko | clear]
```

Controls the CLI output language. `show` (default) reports the current language and where it came from (env, config, auto-detection, or default). `en`/`ko` set the preference permanently in `~/.config/cctg/config`. `clear` removes the preference, so the language falls back to auto-detection (from `LC_ALL`/`LANG`). See [configuration.md](configuration.md).

```console
$ cctg lang
$ cctg lang ko
$ cctg lang clear
```

## Maintenance

### `doctor`

```
cctg doctor
```

Diagnoses the environment: checks the dependencies (`tmux`, `claude`, `caffeinate`, `jq`), whether `~/.local/bin` is on `PATH`, the registry file and bot count, and the shared permission policy (`defaultMode`, deny/allow counts). It also reminds you to install the channel plugins globally. Finally it runs an **install integrity** pass: each registered bot's token `.env` must be `600`, the install manifest (`~/.config/cctg/install.conf`) paths are validated (repo/libexec exist), and the install `bindir` is checked for writability (so `update`/`uninstall` desync surfaces early). Channel-plugin presence and minimum tool versions are not asserted (no stable detection / non-arbitrary baseline).

```console
$ cctg doctor
```

### `update`

```
cctg update [--version X.Y.Z | --latest | --list] [--alias | --alias=NAME | --no-alias]
```

With no version option: when **not pinned**, runs `git pull --ff-only` then re-runs `install.sh` (idempotent, the original behavior); when **pinned**, it holds the pinned version and prints how to change it (no surprise upgrade). `--version X.Y.Z` switches to and pins a specific release; `--latest` returns to the tracking branch's latest and clears the pin; `--list` lists available versions (`*` = installed, `#` = pinned). Prints the old → new version. See [installation.md](installation.md).

Alias handling on update differs from a fresh install: **without an alias option the current alias is left exactly as-is** (update never force-adds `cg`). `--alias` adds `cg`, `--alias=NAME` sets a custom name, and `--no-alias` removes an existing alias.

```console
$ cctg update
```

### `version`

```
cctg version
cctg --version
cctg -v
```

Prints the version (from the `VERSION` file).

```console
$ cctg version
```

### `help`

```
cctg help
cctg --help
cctg -h
cctg
```

Prints the usage summary (also shown when run with no arguments).

```console
$ cctg help
```

## See also

- [permissions.md](permissions.md) — the shared permission policy and per-bot modes.
- [configuration.md](configuration.md) — `launch.env`, shared settings, language, and paths.
- [telegram-setup.md](telegram-setup.md) — first-time Telegram channel setup.
- [discord-setup.md](discord-setup.md) — first-time Discord channel setup.

[← Back to README](../README.md)
