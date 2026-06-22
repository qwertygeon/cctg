**English** | [한국어](README.ko.md)

# CCTG — Claude Code Tmux Gateway

[![CI](https://github.com/qwertygeon/cctg/actions/workflows/ci.yml/badge.svg)](https://github.com/qwertygeon/cctg/actions/workflows/ci.yml)

**CCTG** (Claude Code Tmux Gateway) is a macOS launcher that ties together **tmux + Claude Code + a chat gateway (Telegram or Discord)**, so you can run and manage a per‑project Claude Code chat bot from your phone or any chat client. The command is `cctg`.

Each project bot has its own state directory, token, working directory, and isolated tmux session — and CCTG never touches the global channel bot at `~/.claude/channels/<channel>/`.

> ⚠️ **Privacy — read this first.** A bot relays the messages it receives to a Claude Code process running in its working directory, and Claude Code **sends that content to the Anthropic API** for processing. Conversations, code, and file contents you exchange with the bot therefore pass through a third party (Anthropic) and through Telegram/Discord infrastructure. Think twice before attaching a bot to a sensitive repository, and strictly limit who can reach it via the `access.json` allowlist (yourself, or trusted users only).
>
> ℹ️ **Unofficial tool.** CCTG is an unofficial, third‑party tool not built or endorsed by Anthropic. "Claude Code" and "Claude" are trademarks of Anthropic; this project is not affiliated with Anthropic.
>
> 📜 **Your use is subject to upstream terms.** Talking to a bot sends content to the Anthropic API, so your use is governed by your own Anthropic plan terms and Usage Policy; running a bot also makes you a Telegram/Discord bot operator (e.g. Discord requires a privacy policy, and you should disclose the bot is an AI if others can reach it). See **[SECURITY.md → Your responsibilities as a bot operator](SECURITY.md#your-responsibilities-as-a-bot-operator)**.

## Table of Contents

- [Who is this for?](#who-is-this-for)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
  - [Step 1 — Install the prerequisites](#step-1--install-the-prerequisites)
  - [Step 2 — Install CCTG](#step-2--install-cctg)
  - [Step 3 — Create and connect your bot](#step-3--create-and-connect-your-bot)
  - [Step 4 — Start the bot](#step-4--start-the-bot)
  - [Step 5 — Message it and check status](#step-5--message-it-and-check-status)
- [Everyday commands](#everyday-commands)
- [Permissions in one minute](#permissions-in-one-minute)
- [Supported channels](#supported-channels)
- [Documentation](#documentation)
- [Uninstall](#uninstall)
- [Contributing & license](#contributing--license)

## Who is this for?

You want to talk to Claude Code in one of your project directories from Telegram or Discord — for example to kick off a task from your phone, or to keep a long‑running assistant attached to a repo — without leaving a terminal open and babysitting permission prompts. CCTG gives each project its own isolated bot and keeps it alive in a detached tmux session.

## Requirements

> **macOS only.** CCTG relies on `caffeinate` (a macOS built‑in) and assumes the macOS shell/tooling layout. Linux and WSL are **not supported** at this time.

| Dependency | Purpose | Required? |
|---|---|---|
| `claude` | Claude Code CLI — the assistant each bot runs | ✅ Required |
| `tmux` | Runs the bot in a detached background session | ✅ Required |
| `caffeinate` | Prevents the Mac from sleeping while a bot runs | Built into macOS |
| `jq` | `status --json`, structured `common` edits, Discord `--group` seeding | Optional |
| channel plugin | The Telegram/Discord integration, installed globally in Claude Code | ✅ Required for the channel you use |

Install details, PATH setup, and update/uninstall are in **[docs/installation.md](docs/installation.md)**.

## Quick Start

The fastest path from zero to a working bot. The example uses **Telegram**; for Discord, swap Step 3 for **[docs/discord-setup.md](docs/discord-setup.md)**.

### Step 1 — Install the prerequisites

1. Install **Claude Code** and **tmux** (e.g. `brew install tmux`). Optionally `brew install jq`.
2. Install the channel plugin **globally inside Claude Code**:

   ```text
   /plugin install telegram@claude-plugins-official
   ```

   (For Discord: `/plugin install discord@claude-plugins-official`.)

### Step 2 — Install CCTG

```bash
git clone https://github.com/qwertygeon/cctg.git
cd cctg
./install.sh
```

`install.sh` checks dependencies, places `cctg` at `~/.local/bin/cctg`, installs shell completions, and adds a managed block to your shell rc for PATH + completions. It is safe to re‑run. Then open a new terminal (or `source ~/.zshrc`) and verify:

```bash
cctg doctor
```

If `~/.local/bin` is not on your PATH, the installer prints the exact line to add. See **[docs/installation.md](docs/installation.md)** for install modes (release vs. `--dev`), `BINDIR`, completions, and more.

### Step 3 — Create and connect your bot

For Telegram you need two things — a **bot token** and **your numeric Telegram ID**:

1. **Create a NEW bot** with [@BotFather](https://t.me/BotFather): send `/newbot`, pick a name and a username. BotFather gives you a **token** like `123456789:ABCdef...`. It must be a brand‑new bot (not one already running elsewhere).
2. **Get your numeric ID**: DM [@userinfobot](https://t.me/userinfobot); it replies with your numeric user ID.

Now register the bot. `<name>` is any label (letters/digits/`_`/`-`); `<dir>` is the project directory the bot will work in:

```bash
cctg add myproject ~/work/myproject
```

`add` prompts you for the token (masked), your numeric ID, and a permission mode. It scaffolds the state directory, stores the token with `600` permissions, and seeds the `access.json` allowlist with your ID — so **no separate pairing step is needed** for Telegram.

```console
$ cctg add myproject ~/work/myproject
Bot token (issued by @BotFather, must be a NEW bot): ********
Your Telegram numeric ID: 123456789
Permission mode [Enter=follow shared | acceptEdits auto bypassPermissions default dontAsk plan]:
Registered: myproject → cwd=/Users/you/work/myproject, state=/Users/you/.claude/channels/myproject
  seeded 123456789 into the allowlist (no pairing needed)
```

> Full walkthroughs, including non‑interactive registration for CI: **[docs/telegram-setup.md](docs/telegram-setup.md)** · **[docs/discord-setup.md](docs/discord-setup.md)**.

### Step 4 — Start the bot

```bash
cctg up myproject
```

This launches the bot in a detached tmux session (`cctg-myproject`) under `caffeinate -is`, so your Mac won't sleep while it runs.

```console
$ cctg up myproject
UP   myproject  (cwd=/Users/you/work/myproject, state=/Users/you/.claude/channels/myproject, tmux=cctg-myproject)
```

### Step 5 — Message it and check status

Open Telegram and DM your new bot — it responds right away, with Claude Code running in your project directory. Check on it any time:

```bash
cctg status            # is it running? for how long? which mode/channel?
cctg logs myproject    # recent output (works even after the bot is stopped)
cctg attach myproject  # watch the live session (detach with Ctrl-b d)
```

That's it. Stop with `cctg down myproject`, restart with `cctg restart myproject`.

> 💬 **Bots are told to reply through the channel.** So that a bot always answers in chat (instead of "thinking" only in its terminal), CCTG injects a short reply-reminder into every bot via `claude --append-system-prompt`. It's **on by default**, seeded at `~/.claude/channels/cctg-reply-reminder.txt`. Edit that file to customize the wording, or empty it to turn the reminder off. `cctg doctor` shows whether it's on. Details: **[docs/configuration.md → Channel reply reminder](docs/configuration.md#channel-reply-reminder)**.

## Everyday commands

```text
cctg <command> [args]
  add <name> <cwd> [--channel telegram|discord] [--id <num>]
                   [--token-env <VAR>|--token-stdin] [--mode <m>] [--group ...]
  rm <name> [--purge]      rename <old> <new> [--keep-dir]
  up <name...|all>         down <name...|all>       restart <name...|all>
  status [--json]          logs <name> [N]          attach <name>
  config <name> [...]      common [...]             lang [show|en|ko|clear]
  doctor    update    version    help
```

| Command | What it does |
|---|---|
| `add` / `rm` / `rename` | Register, unregister, or rename a bot |
| `up` / `down` / `restart` | Start / stop / restart one or more bots (names, `telegram`/`discord`, or `all`) |
| `status` / `logs` / `attach` | See state and uptime / read logs / attach to the live session |
| `config` / `common` | Per‑bot options / shared permission policy |
| `lang` | Switch CLI output language (English/Korean) |
| `doctor` / `update` / `version` | Diagnose the environment / update CCTG / print version |

The full reference for every command and flag is in **[docs/commands.md](docs/commands.md)**.

## Permissions in one minute

A bot is a Claude Code TUI running headless in tmux — nobody is there to answer a permission prompt, so a prompt would stall it. CCTG's answer is **"auto‑approve what's harmless, block what's dangerous with deny rules."**

- A **shared policy** (`cctg common`) applies to all bots: it defaults to `bypassPermissions` plus a deny safety net (`sudo`, `rm -rf /`, force‑push, reading `~/.ssh`, …). Deny rules and PreToolUse hooks still apply even under `bypassPermissions`.
- A **per‑bot mode** (`cctg config <name> mode ...`) overrides the shared default for one bot.

The full model — every mode, the default deny list, and how to tighten it — is in **[docs/permissions.md](docs/permissions.md)**.

## Supported channels

CCTG follows Claude Code's **channels** layout (`~/.claude/channels/`): each channel plugin keeps its global bot under `~/.claude/channels/<channel>/`, overridable per process via that plugin's `<CHANNEL>_STATE_DIR`.

| Channel | Claude Code plugin | CCTG support |
|---|---|---|
| **Telegram** | `telegram@claude-plugins-official` | ✅ Supported — see [docs/telegram-setup.md](docs/telegram-setup.md) |
| **Discord** | `discord@claude-plugins-official` | ✅ Supported — DM via pairing by default, server channels via `--group`; see [docs/discord-setup.md](docs/discord-setup.md) |
| iMessage | `imessage@claude-plugins-official` | ⛔ Planned — name reserved |
| fakechat | `fakechat@claude-plugins-official` | ⛔ Not applicable — name reserved |
| Slack | `slack@claude-plugins-official` | ➖ Out of scope — not a tmux‑hosted message bridge |

> CCTG **reserves** the names `telegram`, `discord`, `imessage`, and `fakechat` so a project bot can never overwrite a global channel bot's token or allowlist. It also refuses to reuse a state directory that already holds a non‑CCTG channel bot's state. How channels are wired (the `channel_spec` descriptor) is covered in [docs/configuration.md](docs/configuration.md).

## Documentation

| Document | Contents |
|---|---|
| [Installation](docs/installation.md) | Detailed install, modes, PATH, completions, updating, uninstall |
| [Telegram setup](docs/telegram-setup.md) | Create a bot with BotFather, get your ID, connect step by step |
| [Discord setup](docs/discord-setup.md) | Discord application/bot, token, pairing, server‑channel `--group` |
| [Command reference](docs/commands.md) | Every command and flag, with examples |
| [Permissions & policy](docs/permissions.md) | Shared policy + per‑bot modes, deny/allow, the default deny list |
| [Configuration & internals](docs/configuration.md) | CLI language, env vars/paths, how it works, log snapshots |

Project meta: [Contributing](CONTRIBUTING.md) · [Security policy](SECURITY.md) · [Changelog](CHANGELOG.md) · [Packaging structure](docs/packaging.md) · [Releasing](docs/RELEASING.md) · [TODO / future work](docs/TODO.md)

## Uninstall

```bash
./uninstall.sh
```

This removes the `cctg` launcher, completions, the shell rc managed block, and CCTG's own config — but **never** touches the registry or state directories under `~/.claude/channels/`, so your bot registrations and tokens survive a reinstall. Details in [docs/installation.md](docs/installation.md#uninstall).

## Contributing & license

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). The version is sourced from the `VERSION` file at the repository root (the single source of truth); check it with `cctg version`, and `cctg update` shows the before/after versions. Licensed under [MIT](LICENSE).
