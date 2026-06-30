**English** | [한국어](configuration.ko.md)

# Configuration & internals

> How CCTG picks its CLI language, the environment variables and paths it reads, how a bot is launched, and how log snapshots are captured.

## Table of Contents

- [CLI language](#cli-language)
  - [Resolution order](#resolution-order)
  - [Managing the preference](#managing-the-preference)
  - [Language-neutral text](#language-neutral-text)
- [Environment variables & paths](#environment-variables--paths)
  - [Environment variables](#environment-variables)
  - [Per-bot channel state env](#per-bot-channel-state-env)
  - [Key files](#key-files)
- [How it works (architecture)](#how-it-works-architecture)
  - [Registry](#registry)
  - [State isolation](#state-isolation)
  - [Shared permission policy](#shared-permission-policy)
  - [Channel reply reminder](#channel-reply-reminder)
  - [tmux sessions](#tmux-sessions)
  - [The `up` launch line](#the-up-launch-line)
  - [Channels](#channels)
- [Log snapshots](#log-snapshots)
  - [Snapshot on graceful `down`](#snapshot-on-graceful-down)
  - [Periodic snapshots (opt-in)](#periodic-snapshots-opt-in)

## CLI language

The CLI prints messages in English or Korean.

### Resolution order

The language is resolved in this order — the first match wins:

1. `CCTG_LANG` environment variable — a one-off override, e.g. `CCTG_LANG=ko cctg status`.
2. The `lang` value in `~/.config/cctg/config` (set by `cctg lang`).
3. Locale auto-detection (`$LC_ALL` / `$LANG`; `ko*` or `*_KR*` → Korean, otherwise English).
4. Default: English.

### Managing the preference

```bash
cctg lang            # show current language and where it came from
cctg lang ko         # switch to Korean permanently (writes ~/.config/cctg/config)
cctg lang en         # switch to English permanently
cctg lang clear      # remove the preference (fall back to auto-detection)
```

Pick the initial language at install time with `./install.sh --lang en|ko`. The preference lives in `~/.config/cctg/config`, separate from the install manifest (`~/.config/cctg/install.conf`), so `cctg update` preserves it. Message catalogs ship as `messages/en.sh` and `messages/ko.sh` next to the launcher.

### Language-neutral text

Some text remains language-neutral regardless of the resolved language: the generated `launch.env` comments, missing-required-argument errors, and zsh completion descriptions.

## Environment variables & paths

### Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `CC_CHANNELS_DIR` | `~/.claude/channels` | Channel state root |
| `CC_TG_REGISTRY` | `$CC_CHANNELS_DIR/projects.conf` | Registry file |
| `CC_TG_SHARED_SETTINGS` | `$CC_CHANNELS_DIR/cctg-shared.settings.json` | Shared permission policy file |
| `CC_TG_REPLY_REMINDER_FILE` | `$CC_CHANNELS_DIR/cctg-reply-reminder.txt` | Channel reply-reminder text injected into every bot |
| `CC_TG_SESS_WIDTH` | (unset) | Detached session width override (columns); beats the `cctg common width` global default |
| `CC_TG_UP_READY_TIMEOUT` | `15` | Multi-target `up`/`restart`: max seconds to poll the previous bot's `claude` liveness before launching the next |
| `CC_TG_UP_SETTLE` | `3` | Multi-target `up`/`restart`: settle seconds after liveness, letting the channel register before the next launch. `0` effectively disables staggering |
| `CCTG_LANG` | (unset) | One-off CLI language override (`en`/`ko`) |
| `BINDIR` | `~/.local/bin` | Install location (`install.sh` / `uninstall.sh`) |
| `CCTG_LIBEXEC` | `~/.local/libexec/cctg` | Copy-install package dir (`install.sh`) |

### Per-bot channel state env

Each bot is launched with its channel's state-dir env set — `TELEGRAM_STATE_DIR` or `DISCORD_STATE_DIR` (resolved from the channel descriptor) — pointing at `~/.claude/channels/<name>/`, so it never mixes with the global channel bot or other project bots.

### Key files

Per install:

- launcher `~/.local/bin/cctg`
- copy-install package `~/.local/libexec/cctg/`
- manifest `~/.config/cctg/install.conf`
- user config `~/.config/cctg/config` (holds `lang` and the global default `sess_width`)

Per-bot state dir `~/.claude/channels/<name>/` contains:

- `.env` (token, `chmod 600`)
- `access.json` (allowlist / groups)
- `launch.env` (per-bot options)
- `inbox/`
- after a stop, `last-session.log` (`chmod 600`)

A running periodic snapshotter tracks its PID in `.snapshotter.pid`.

## How it works (architecture)

### Registry

The registry `~/.claude/channels/projects.conf` stores one line per bot:

```
name | working_dir | state_dir | channel
```

The 4th column is the channel type; legacy 3-column rows default to `telegram`.

### State isolation

Per-bot state is isolated under `~/.claude/channels/<name>/`. Each bot gets a separate channel `STATE_DIR` env so state never mixes.

### Shared permission policy

The shared permission policy (`cctg-shared.settings.json`) is injected into every bot via `claude --settings`.

### Channel reply reminder

Every bot is reminded — on each turn — to answer **through the channel reply tool** (and to quote-reply with `reply_to`), because a bot's terminal/transcript output never reaches the user. This keeps bots from "thinking out loud" without ever sending a reply.

- **Where**: a plain-text file at `~/.claude/channels/cctg-reply-reminder.txt`, seeded with a default message the first time you `add` or `up` a bot.
- **How it's applied**: on `up`, CCTG passes the file's contents to `claude --append-system-prompt` (see [the `up` launch line](#the-up-launch-line)). It is **on by default**.
- **Customize**: edit the file — your text is preserved across upgrades (CCTG only writes it when it is missing).
- **Disable (opt-out)**: empty the file (`: > ~/.claude/channels/cctg-reply-reminder.txt`). An empty file is kept as-is and skips injection. Deleting the file instead re-seeds the default on the next `up`, so empty it rather than delete it.
- **Scope**: this affects only CCTG bot sessions; your own `claude` usage is untouched.
- `cctg doctor` shows whether the reminder is ON or OFF.

> **Why not a settings hook?** An earlier design put a `UserPromptSubmit` hook in `cctg-shared.settings.json`. Claude Code does not document whether a `--settings` file's `hooks` key merges with or replaces your global `~/.claude/settings.json` hooks; if it replaces them, every bot session (which runs `bypassPermissions`) would lose your global hooks — including a `git-guard`-style `PreToolUse` safety net. `--append-system-prompt` touches no hooks and avoids that risk.

### tmux sessions

tmux session names follow the `cctg-<name>` convention. Sessions are detached, so tmux would otherwise cap the width at 80 columns and truncate `logs`/snapshot capture. CCTG pins the width with `new-session -x`. The effective width resolves in this order (first valid wins): the bot's `CCTG_SESS_WIDTH` (`cctg config <name> width`) → env `CC_TG_SESS_WIDTH` → the global default `sess_width` (`cctg common width`, in `~/.config/cctg/config`) → the built-in default `100`. Each candidate must be an integer ≥ 20.

### The `up` launch line

On `up`, the launcher does roughly:

1. `cd <cwd>`
2. export the channel `STATE_DIR`
3. source `.env` (token) and `launch.env` (options)
4. run, inside a detached tmux session:

```bash
caffeinate -is claude --channels <plugin> --settings <shared> [--permission-mode <mode>] \
  [--append-system-prompt "$(cat <reply-reminder>)"] [$CLAUDE_EXTRA_ARGS]
```

`caffeinate -is` prevents the system from sleeping while the bot runs. The `--append-system-prompt` flag is added only when the [reply-reminder](#channel-reply-reminder) file is non-empty.

### Channels

Channels are described by a `channel_spec` in `lib/channels.sh` (8 fields). `telegram` and `discord` are implemented; `imessage` / `fakechat` names are reserved.

## Log snapshots

### Snapshot on graceful `down`

On a graceful `down`, CCTG saves a snapshot of the tmux pane (rendered text, scrollback up to ~2000 lines) to `<state>/last-session.log` (`chmod 600`), so `cctg logs` keeps working after the bot stops (it falls back to this snapshot). `attach` still needs a running session. The snapshot can contain conversation content — treat it like the rest of the `0700` state dir.

### Periodic snapshots (opt-in)

A crash or reboot never runs `down`, so to cover that, enable a periodic snapshot per bot (opt-in, off by default):

```bash
cctg config myproject snapshot 60    # snapshot every 60s while running (min 5)
cctg config myproject snapshot off   # disable (default)
```

While the bot runs, a lightweight background watcher re-captures the pane every N seconds to the same `last-session.log` and exits automatically when the session ends. After a crash/reboot, `cctg logs` then shows the most recent snapshot (at most N seconds stale). `restart` applies a changed interval.

---

[← Back to README](../README.md)

See also: [commands.md](commands.md) · [permissions.md](permissions.md) · [installation.md](installation.md)
