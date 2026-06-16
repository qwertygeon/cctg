**English** | [한국어](README.ko.md)

# CCTG — Claude Code Tmux Gateway

[![CI](https://github.com/qwertygeon/cctg/actions/workflows/ci.yml/badge.svg)](https://github.com/qwertygeon/cctg/actions/workflows/ci.yml)

**CCTG** (Claude Code Tmux Gateway) is a launcher for macOS that ties together **tmux + Claude Code + the Telegram gateway**, making it easy to spin up and manage per-project Claude Code Telegram channel bots. The command is `cctg`.

It never touches the global bot (`~/.claude/channels/telegram/`). Each project bot has its own state directory, token, and working directory, and runs in an isolated tmux session.

> **Supported channel scope** — CCTG's state directory follows Claude Code's **channels** (`~/.claude/channels/`) layout: each channel plugin keeps its global bot under `~/.claude/channels/<channel>/` (`.env`, `access.json`, `approved/`, `inbox/`), overridable per-process via that plugin's `<CHANNEL>_STATE_DIR`. CCTG drives **Telegram only** today; the others are not connectable yet.

**Supported gateways:**

| Gateway | Claude Code plugin | Global state dir | Per-process state override | CCTG support |
|---|---|---|---|---|
| **Telegram** | `telegram@claude-plugins-official` | `~/.claude/channels/telegram/` | `TELEGRAM_STATE_DIR` | ✅ **Supported** — `add`/`up` launch isolated per-project bots |
| Discord | `discord@claude-plugins-official` | `~/.claude/channels/discord/` | `DISCORD_STATE_DIR` | ⛔ Planned — name **reserved** to avoid clobbering the global bot |
| iMessage | `imessage@claude-plugins-official` | `~/.claude/channels/imessage/` | `IMESSAGE_STATE_DIR` | ⛔ Planned — name **reserved** |
| fakechat (local test) | `fakechat@claude-plugins-official` | `~/.claude/channels/fakechat/` | — (hard-coded) | ⛔ Not applicable — name **reserved** |
| Slack | `slack@claude-plugins-official` | — (MCP search/read, no bot state dir) | — | ➖ Out of scope — not a tmux-hosted message bridge |

> Because every channel plugin's global bot lives at `~/.claude/channels/<channel>/`, CCTG **reserves** the names `telegram`, `discord`, `imessage`, and `fakechat`: `cctg add <reserved>` / `cctg rename ... <reserved>` are refused so a project bot can never overwrite a global channel bot's token or allowlist. CCTG also refuses to reuse any state directory that already holds a non-CCTG channel bot's state (an `.env`/`access.json` without a CCTG `launch.env`), so even a future channel name is protected.

> ⚠️ **Privacy — data flow notice** — CCTG relays messages received over Telegram to a Claude Code process running in the bot's working directory, and Claude Code **sends that content to the Anthropic API** for processing. In other words, the conversations, code, and file contents exchanged with the bot pass through a third party (Anthropic) and through Telegram's infrastructure. Keep this in mind before attaching a bot to a repository that handles sensitive data, and strictly limit who can reach the bot via the `access.json` allowlist (yourself, or trusted users only).

> ℹ️ **Unofficial tool** — CCTG is an **unofficial, third-party tool** not built or endorsed by Anthropic. "Claude Code" and "Claude" are trademarks of Anthropic; this project is not affiliated with Anthropic.

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
  - [Install modes](#install-modes)
  - [PATH setup](#path-setup)
- [Usage](#usage)
  - [1. Register / remove a bot (add / rm)](#1-register--remove-a-bot-add--rm)
  - [2. Start / stop / restart a bot (up / down / restart)](#2-start--stop--restart-a-bot-up--down--restart)
  - [3. Status / logs (status / logs / attach)](#3-status--logs-status--logs--attach)
  - [4. Diagnostics (doctor)](#4-diagnostics-doctor)
- [Language](#language)
- [Permissions & options (config / common)](#permissions--options-config--common)
- [Updating](#updating)
- [How it works](#how-it-works)
- [Uninstall](#uninstall)
- [Further reading](#further-reading)

## Requirements

> **macOS only** — CCTG relies on `caffeinate` (a macOS built-in) and assumes the macOS shell/tooling layout. Linux and WSL are **not supported** at this time.

| Dependency | Purpose | Notes |
|---|---|---|
| `claude` | Claude Code CLI | Required |
| `tmux` | Runs the bot in a detached session | Required |
| `caffeinate` | Prevents system sleep while running | Built into macOS |
| `jq` | Structured edits of `cctg common` permission policy; `cctg status --json` output | Optional (without it, use `common edit` to edit directly; `status --json` errors) |
| telegram plugin | Telegram channel integration | Must be installed globally: `/plugin install telegram@claude-plugins-official` |

## Installation

```bash
git clone https://github.com/qwertygeon/cctg.git
cd cctg
./install.sh
```

`install.sh` checks dependencies and places `cc-tg.sh` at `~/.local/bin/cctg`. It is safe to re-run (idempotent).

### Install modes

| Command | Behavior | Use case |
|---|---|---|
| `./install.sh` | **Copies** `cc-tg.sh` to `~/.local/bin/cctg` | Release. Works even if you delete or move the repo. Update with `git pull` then re-install |
| `./install.sh --dev` | **Symlinks** `~/.local/bin/cctg` to the repo's `cc-tg.sh` | Development. Repo edits take effect immediately |

The installer also handles the following automatically:

- **Shell completions (bash/zsh)** — skip with `--no-completions`
- **Shell rc auto-setup** — adds an idempotent **managed block** (`# >>> cctg >>>` ... `# <<< cctg <<<`) enabling PATH and completions to the current shell's rc (`~/.zshrc`, or `~/.bashrc`/`~/.bash_profile`). It leaves a one-time `.cctg-bak` backup, never duplicates on re-run, and `uninstall.sh` cleanly removes just the block. Skip with `--no-shell-setup`.

To apply, open a new terminal or `source ~/.zshrc` (the relevant rc). Change the install location with `BINDIR`: `BINDIR=~/bin ./install.sh`

### PATH setup

If `~/.local/bin` is not on your PATH, `install.sh` prints the right command for your shell. Example (zsh):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

Verify after installing:

```bash
cctg status
```

## Usage

```
cctg <command> [args]
  add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>]
  rm <name> [--purge]   rename <old> <new> [--keep-dir]
  config <name> [...]   common [...]          (permissions/options — see "Permissions & options")
  up <name|all>         down <name|all>       restart <name|all>
  status [--json]       logs <name> [N]       attach <name>
  lang [show|en|ko|clear]                     (CLI output language — see "Language")
  doctor                update                version           help
```

> Bot names may only contain letters, digits, `_`, and `-` (to avoid clashing with tmux session names and registry separators). The global channel names `telegram`, `discord`, `imessage`, and `fakechat` are **reserved** and cannot be used — see the **Supported gateways** table near the top for why.

> **Sample output language** — The examples below show the **English** output. The CLI is bilingual (English/Korean); switch any time with `cctg lang` (see [Language](#language)). Paths/IDs are placeholders.

### 1. Register / remove a bot (add / rm)

```bash
cctg add myproject ~/work/myproject   # register
cctg rm  myproject                    # unregister (keeps state directory)
cctg rm  myproject --purge            # unregister + delete state directory
```

`add` interactively prompts for the following and scaffolds the state directory (`~/.claude/channels/<name>/`):

- **Bot token** — a token for a **new bot** issued by [@BotFather](https://t.me/BotFather) (masked input, stored in `.env` with 600 permissions)
- **Your numeric Telegram ID** — if you don't know it, DM [@userinfobot](https://t.me/userinfobot). The given ID is used to auto-generate the `access.json` allowlist, so no separate pairing is needed.

Example session (token input is masked):

```console
$ cctg add myproject ~/work/myproject
Bot token (issued by @BotFather, must be a NEW bot): ********
Your numeric Telegram ID (DM @userinfobot if unknown): 123456789
Permission mode [Enter=follow shared | acceptEdits auto bypassPermissions default dontAsk plan]:
Registered: myproject → cwd=/Users/you/work/myproject, state=/Users/you/.claude/channels/myproject
  seeded 123456789 into the allowlist (no pairing needed)
```

#### Non-interactive registration (CI / scripting)

Pass flags to skip the prompts. Supplying a **token flag** (`--token-env` or `--token-stdin`) switches `add` to non-interactive mode, which then **requires `--id`**; `--mode` is optional (omit to follow the shared policy).

| Flag | Meaning |
|---|---|
| `--id <num>` | Numeric Telegram ID for the allowlist (required when non-interactive) |
| `--token-env <VAR>` | Read the bot token from environment variable `VAR` |
| `--token-stdin` | Read the bot token from stdin (one line) |
| `--mode <m>` | Permission mode (`acceptEdits`/`auto`/`bypassPermissions`/`default`/`dontAsk`/`plan`) |

> The token is **never taken as a command-line argument** (it would leak via the process list). Use `--token-env` or `--token-stdin`.

```bash
# from an environment variable
BOT_TOKEN="123:ABC..." cctg add myproject ~/work/myproject \
  --token-env BOT_TOKEN --id 123456789 --mode bypassPermissions

# from stdin (e.g. piped from a secrets manager)
secrets get tg-token | cctg add myproject ~/work/myproject --token-stdin --id 123456789
```

By default `rm` **keeps** the state directory containing the token and allowlist (reusable on re-registration). A running bot must be stopped with `down` first. `--purge` also deletes the state directory, but for safety it never touches the global bot directory or paths outside `CHANNELS_DIR`.

### 1-1. Rename (rename)

```bash
cctg rename myproject newname              # rename + move the state directory too
cctg rename myproject newname --keep-dir   # rename only, keep the directory path
```

Because the registry stores the state directory path explicitly, the name and the data location are decoupled. The default behavior moves the directory to `<new>` and updates the registry **only** when the state directory is at the default path (`~/.claude/channels/<old>/`). For a custom path, or when `--keep-dir` is given, the directory is left in place and only the name (and the tmux session name `cctg-<name>`) changes. Since the session name is name-based, **stop a running bot with `down` first**; the command refuses if `<new>` is already registered or the target directory already exists.

### 2. Start / stop / restart a bot (up / down / restart)

```bash
cctg up myproject       # start a specific bot
cctg up all             # start all registered bots
cctg down myproject     # stop
cctg down all           # stop all
cctg restart myproject  # restart (down + up)
cctg restart all        # restart all
```

On start, `caffeinate -is` prevents sleep while the bot runs in a detached tmux session (`cctg-<name>`). After that, DM the bot and it responds right away.

```console
$ cctg up myproject
UP   myproject  (cwd=/Users/you/work/myproject, state=/Users/you/.claude/channels/myproject, tmux=cctg-myproject)
```

### 3. Status / logs (status / logs / attach)

```bash
cctg status              # per-bot status (RUNNING+uptime / stopped / BROKEN) + cwd/state paths
cctg status --json       # machine-readable status (for scripting/other tools; needs jq)
cctg logs myproject      # print the last 50 log lines (without attaching)
cctg logs myproject 200  # last 200 lines
cctg attach myproject    # attach to the tmux session for live view (detach: Ctrl-b d)
```

`status` shows each bot's `RUNNING` (+uptime) / `stopped` / `BROKEN` state along with its `cwd`/`state` paths. `BROKEN` means the bot is registered but its working directory is missing or its token file (`.env`) is absent — and a per-reason recovery hint (`↳ ...`) is printed beneath it. `status --json` emits a machine-readable array (`name`, `state`, `running`, `cwd`, `stateDir`, `mode`, `session`, `uptimeSeconds`, `issues`) with locale-independent tokens, for use by other tools (requires `jq`).

`logs` reads the live tmux pane while the bot is running. On `down`, CCTG saves a snapshot of the pane (the rendered text, up to ~2000 lines) to `<state>/last-session.log`, so `logs` keeps working **after** the bot is stopped — it falls back to that snapshot. `attach` still requires a running session.

> The snapshot is overwritten on each `down` (last session only) and lives inside the 0700 state directory with 600 permissions. It can contain conversation content, so treat it like the rest of the state directory. A crash or reboot that never runs `down` won't refresh the snapshot.

```console
$ cctg status
Global bot: /Users/you/.claude/channels/telegram (not managed by this script)
--- project bots ---
  [RUNNING] myproject  up 2h13m  (tmux=cctg-myproject)
            cwd=/Users/you/work/myproject  state=/Users/you/.claude/channels/myproject
            mode=shared
  [stopped] sandbox
            cwd=/Users/you/work/sandbox  state=/Users/you/.claude/channels/sandbox
            mode=bypassPermissions
  [BROKEN ] oldbot  (no-cwd, no-token)
            cwd=/Users/you/work/oldbot  state=/Users/you/.claude/channels/oldbot
            mode=shared
```

### 4. Diagnostics (doctor)

```bash
cctg doctor              # check dependencies (tmux/claude/caffeinate/jq), PATH, registry, shared permission policy
```

```console
$ cctg doctor
cctg doctor (v0.1.0)
--- dependencies ---
  ok   tmux (/opt/homebrew/bin/tmux)
  ok   claude (/Users/you/.local/bin/claude)
  ok   caffeinate (/usr/bin/caffeinate)
  ok   jq (/opt/homebrew/bin/jq)
--- PATH ---
  ok   ~/.local/bin is on PATH
--- registry ---
  file: /Users/you/.claude/channels/projects.conf
  registered project bots: 2
--- shared settings (permission policy) ---
  file: /Users/you/.claude/channels/cctg-shared.settings.json
  defaultMode: bypassPermissions
  deny: 5 / allow: 0
  (the telegram plugin must be installed globally: /plugin install telegram@claude-plugins-official)
```

## Language

The CLI prints its messages in **English** or **Korean**. The language is resolved in this order (first wins):

1. `CCTG_LANG` environment variable — a one-off override, e.g. `CCTG_LANG=ko cctg status`
2. The `lang` value in `~/.config/cctg/config` (set by `cctg lang`)
3. Locale auto-detection (`$LC_ALL`/`$LANG`; `ko*` → Korean, otherwise English)
4. Default: English

```bash
cctg lang            # show the current language and where it came from
cctg lang ko         # switch to Korean permanently (writes ~/.config/cctg/config)
cctg lang en         # switch to English permanently
cctg lang clear      # remove the preference (fall back to auto-detection)
```

Pick the initial language at install time with `./install.sh --lang en|ko` (without it, the installer seeds from your locale). The language preference lives in `~/.config/cctg/config`, separate from the install manifest, so `cctg update` preserves it.

> Message catalogs ship as `messages/en.sh` and `messages/ko.sh` next to the launcher. Some text remains language-neutral for now: the generated `launch.env` comments, missing-required-argument errors, and zsh completion descriptions.

## Permissions & options (config / common)

A bot runs as an **interactive TUI** inside tmux, but the operator is not in front of that TUI — they only interact over Telegram. So when a permission prompt appears, nobody can answer it and the bot stalls. CCTG solves this with an "**auto-approve what's harmless, block what's dangerous via deny**" model — eliminating the gray zone where prompts appear.

It is configured in two layers.

| Layer | Stored at | Injection | Edit command |
|---|---|---|---|
| **Shared** (all bots) | `~/.claude/channels/cctg-shared.settings.json` | `claude --settings <file>` | `cctg common ...` |
| **Per-bot** (takes precedence) | `~/.claude/channels/<name>/launch.env` | `claude --permission-mode <m>` + `$CLAUDE_EXTRA_ARGS` | `cctg config <name> ...` |

If a per-bot `CCTG_PERMISSION_MODE` is set, it overrides the shared `defaultMode`. Leave it empty to follow the shared value.

### Shared permission policy (common)

The shared settings file is auto-created on the first `add`/`up`. The defaults are `defaultMode: bypassPermissions` plus a dangerous-pattern deny safety net (it **merges** with the deny rules and PreToolUse hooks of the global `~/.claude/settings.json`; deny is a union and deny wins over allow).

```bash
cctg common                          # print current shared settings (= common show)
cctg common edit                     # edit directly with $EDITOR
cctg common mode acceptEdits         # change the shared defaultMode
cctg common deny add 'Bash(sudo *)'  # add a deny rule
cctg common deny rm  'Bash(sudo *)'  # remove a deny rule
cctg common allow add 'Read(/data/**)'   # add/remove an allow rule
```

> Structured edits like `mode`/`deny`/`allow` require `jq` (without it, use `common edit` to edit directly). `show`/`edit` work without `jq`.

### Per-bot options (config)

```bash
cctg config myproject                       # print bot options (= config ... show)
cctg config myproject mode bypassPermissions   # set this bot's permission mode
cctg config myproject mode clear            # clear it to follow the shared value
cctg config myproject args "--model opus"   # extra claude args for this bot only
cctg config myproject edit                  # edit launch.env directly
```

Permission mode values: `acceptEdits | auto | bypassPermissions | default | dontAsk | plan`.

| Mode | Behavior in the bot context |
|---|---|
| `bypassPermissions` | Auto-approve everything. **Deny rules and PreToolUse hooks (git-guard, etc.) still apply** → dangerous actions are blocked here |
| `acceptEdits` | Only edits and safe fs commands are automatic; other Bash/network actions prompt (can stall when headless) |
| `dontAsk` | Auto-rejects the gray zone instead of prompting (safe, but silently fails if not in allow) |

Configuration changes take effect on `up`/`restart` (if running, `cctg restart <name>`). Check the currently applied mode with `cctg status` / `cctg doctor`.

## Updating

```bash
cctg update
```

It reads the repo location and install mode from the manifest recorded at install time (`~/.config/cctg/install.conf`), runs `git pull --ff-only`, then re-runs `install.sh` (idempotent) for both modes.

- **Copy install**: `git pull` → re-run `install.sh` to re-copy the new `cc-tg.sh` to `cctg`.
- **Symlink (`--dev`) install**: `cctg` (the symlink) is up to date immediately after `git pull`, but completions are *copied* to `DATA_DIR`, so re-running `install.sh --dev` refreshes them too.

> If there are uncommitted local changes that prevent a fast-forward, `update` stops without overwriting. In that case, clean things up directly in the repo.

## How it works

- Registration info is stored in the registry (`~/.claude/channels/projects.conf`) as `name | working_dir | state_dir`.
- Per-bot state is isolated under `~/.claude/channels/<name>/` (`.env` token, `access.json` allowlist, `launch.env` per-bot options, `inbox/`).
- The shared permission policy lives in `~/.claude/channels/cctg-shared.settings.json` and is injected into every bot via `--settings`.
- Each bot is given a separate `TELEGRAM_STATE_DIR` so it never mixes with the global bot or other project bots.
- tmux session names follow the `cctg-<name>` convention.

You can change paths with environment variables.

| Variable | Default | Meaning |
|---|---|---|
| `CC_CHANNELS_DIR` | `~/.claude/channels` | Channel state root |
| `CC_TG_REGISTRY` | `$CC_CHANNELS_DIR/projects.conf` | Registry file |
| `CC_TG_SHARED_SETTINGS` | `$CC_CHANNELS_DIR/cctg-shared.settings.json` | Shared permission policy file |

## Uninstall

```bash
./uninstall.sh
```

This removes only `~/.local/bin/cctg` (after verifying we installed it) and never touches the registry or state directories (`~/.claude/channels/`), so bot registrations survive a re-install.

## Further reading

- [Contributing guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [Packaging structure and future promotion path](docs/packaging.md)
- [Future work candidates (TODO)](docs/TODO.md)

The version is sourced from the `VERSION` file at the repository root (SoT). Check it with `cctg version`; `cctg update` shows the before/after versions together.
