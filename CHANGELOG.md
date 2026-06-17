# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-06-17

### Added
- **Discord channel support** (`cctg add --channel discord`): the channel abstraction now drives Discord bots end to end (`add`/`up`/`down`/`logs`/`status`), not just Telegram. The token is stored as `DISCORD_BOT_TOKEN`. Because Discord's access model differs from Telegram's, the per-channel `channel_spec` descriptor grew from 4 to 8 fields (`display`, `id_label`, `id_required`, `seed_policy`) so `add` branches on them: Discord seeds `access.json` with `dmPolicy: "pairing"` and an empty allowlist by default (the plugin returns a pairing code approved later via `/discord:access pair`), while passing `--id <user snowflake>` seeds `dmPolicy: "allowlist"` directly. Telegram keeps requiring `--id` non-interactively.
- **`cctg add --group <id>[:nomention][:allow=m1,m2,...]`** (Discord server channels): pre-seed server channels into `access.json` `groups` at registration time. Repeatable; the compound token sets per-channel `requireMention` (default true, `:nomention` flips it) and `allowFrom` (default all members, `:allow=...` restricts to listed member snowflakes). Channel and member IDs are validated as numeric before any registry write — a non-numeric value is refused and nothing is registered. bash/zsh completions list `--group`.
- **`cctg status` channel + topology**: the text view now shows each bot's channel display name (`Telegram`/`Discord`); with `jq` and an `access.json` present it also shows the connection topology — the DM policy and seeded group count, e.g. `channel=Discord (pairing, 0 groups)`. Without `jq` it degrades to the display name only (no error).

### Changed
- Channel-specific descriptor metadata is now the single source of truth for human-facing strings: message catalog keys (`ADD_PROMPT_TGID`, `STATUS_GLOBAL`, `STATUS_HINT_NO_TOKEN`, `DOCTOR_PLUGIN_HINT`) and the completion `--channel` candidates no longer hardcode `telegram` / `TELEGRAM_BOT_TOKEN` / `/telegram`; they read the channel's `id_label` / `token_key` / `display` or the `IMPLEMENTED_CHANNELS` list. Adding a channel is now a `channel_spec` case block plus one `IMPLEMENTED_CHANNELS` entry (and the completion mirror variable). The `access.json` seed no longer writes the unused `"pending": {}` field for any channel. The registry schema is unchanged — legacy 3-column rows still read as `telegram`.

## [0.3.0] - 2026-06-16

### Added
- Channel abstraction (multi-gateway scaffold): a per-channel descriptor (`lib/channels.sh` — `channel_spec`) plus a 4th `channel` column in the registry (legacy 3-column rows read as `telegram`) decouple the telegram-specific plugin id / state-dir env var / token key. `cctg add --channel <name>` selects the channel (only `telegram` is implemented today; other names are refused with a clear message), and `status --json` / `config show` report it. No behaviour change for existing telegram bots (`lib/session.sh up_one` resolves the same values through the descriptor). Adding Discord/iMessage later is a localized `channel_spec` entry + `IMPLEMENTED_CHANNELS` listing, pending verification of their plugin ids/conventions.
- Developer tooling: `.editorconfig` (shell = 2-space, LF, UTF-8, final newline) and `.shellcheckrc` (`disable=SC2207` for the completion `compgen` idiom, `external-sources` so `shellcheck cc-tg.sh` follows the `lib/*.sh` modules, and documentation of why `messages/*.sh` (SC2034 data catalog) is excluded from the CI lint command).
- Shell completions for `rm --purge` and `rename --keep-dir` (bash and zsh).

### Changed
- `uninstall.sh` now resolves `BINDIR` from the install manifest (`bindir=`) before falling back to the default, and cleans up the install manifest, the language-preference config, and the shell-rc `*.cctg-bak` backups it created (deletions are announced; state dirs under `~/.claude/channels/` are still preserved).
- CI and release workflows pinned to `actions/checkout@v5` (Node.js 20 deprecation); `release.yml` hardens the `VERSION` read against stray whitespace (`tr -d`).
- `.gitignore` now also ignores `.env`, `RELEASE_NOTES.md`, and the `_ai-workspace/` pipeline workspace.
- Internal refactor: the monolithic `cc-tg.sh` was split into a thin entry point + runtime-sourced `lib/*.sh` modules (`env`/`output`/`config`/`util`/`registry`/`session`/`commands`). No change to commands, output, or behavior — bats 81/81 unchanged, verified in both dev (symlink) and copy (libexec) installs. `install.sh` now packages `lib/` alongside `messages/`; `scripts/check-i18n-keys.sh` and the `bash -n` CI gate also scan `lib/`.

### Removed
- Undocumented `remove`/`mv` aliases for `rm`/`rename` (minimal command surface; the canonical names are unchanged).

## [0.2.0] - 2026-06-16

### Added
- Automated release publishing (`.github/workflows/release.yml`): pushing a `VERSION` change to `main` re-runs the CI gates, creates the `v{VERSION}` tag, and publishes a GitHub Release with notes extracted from the matching `CHANGELOG.md` section (idempotent — skips if the tag already exists). `docs/RELEASING.md` now documents the `develop → main` branch policy and the version-bump-triggered flow.
- Opt-in periodic log snapshots for crash/reboot coverage: `cctg config <name> snapshot <seconds|off>` (min 5s, off by default). While the bot runs, a lightweight background watcher re-captures the tmux pane (rendered text) to `<state>/last-session.log` every N seconds and self-terminates when the session ends, so `cctg logs` shows a recent snapshot even after a crash or reboot that never ran `down`. `down` stops the watcher and takes a final snapshot. Shown in `cctg config <name> show`; bash/zsh completions updated.
- A [bats](https://github.com/bats-core/bats-core) test suite under `tests/` (81 tests) covering `add`/`rm`/`rename`/`config`/`common`/`status --json`/`lang`/`logs`/`up`/`down`/`restart`/`doctor`/`version`, the snapshot watcher lifecycle, the dispatcher, and the registry / reserved-name / state-dir safety guards. Tests run against an isolated state tree with a stateful fake `tmux` (`tests/stubs/tmux`), so they touch no real bots or tmux server. A `test` job runs them in CI.
- `cctg status --json` for machine-readable output (array of `{name, state, running, cwd, stateDir, mode, session, uptimeSeconds, issues}` with locale-independent tokens; requires `jq`), and per-reason recovery hints (`↳ ...`) printed under each `BROKEN` bot in the text view.
- Bot log persistence: `cctg down` snapshots the tmux pane (rendered text, ~2000 lines) to `<state>/last-session.log` (600 perms), and `cctg logs` falls back to that snapshot when the bot is stopped — so logs survive session end.
- Non-interactive `cctg add` flags for CI/scripting: `--id <num>`, `--token-env <VAR>`, `--token-stdin`, `--mode <m>`. A token flag switches `add` to non-interactive mode (then `--id` is required; `--mode` optional, defaulting to the shared policy). The token is never accepted as an argv to avoid process-list exposure. bash/zsh completions updated.
- GitHub Actions CI (`.github/workflows/ci.yml`): `bash -n` syntax check, `shellcheck -S warning` on logic scripts, and the `scripts/check-i18n-keys.sh` key-parity lint on every push/PR to `main`. Status badge added to both READMEs.
- `docs/RELEASING.md` documenting the version-bump → tag → GitHub Release procedure (VERSION is the SoT, tags are `v{VERSION}`).

### Fixed
- Exit codes for successful commands: `cctg config <bot> mode|args` on a *stopped* bot, and `cctg status` with one or more bots registered, no longer return a non-zero exit status (the command branch had ended on a falsy `is_running`/`found` test). Surfaced by the new test suite; matters for `&&` chaining and scripting.
- `cc-tg.sh` is now `shellcheck -S warning` clean (SC1090 dynamic-source directives, SC2155 declare-before-assign, SC2209 string-quote).

## [0.1.1] - 2026-06-16

### Added
- Bilingual CLI output (English/Korean) via `messages/en.sh` and `messages/ko.sh` catalogs.
- `cctg lang [show|en|ko|clear]` to view/change the output language at runtime, plus the `CCTG_LANG` environment override and `install.sh --lang en|ko` to seed the initial language. The preference lives in `~/.config/cctg/config`, separate from the install manifest, so `cctg update` preserves it.
- English `README.md` as the primary doc, with the Korean version preserved as `README.ko.md` and a language switcher on both.
- Privacy / data-flow notice and an "unofficial tool" disclaimer in the README.
- `.gitignore` for macOS, editor, and `*.cctg-bak` artifacts.
- Project meta files: `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`, and GitHub issue/PR templates.
- "Supported gateways" table in both READMEs documenting Claude Code's channel plugins (Telegram/Discord/iMessage/fakechat/Slack), their `~/.claude/channels/<channel>/` state dirs, `<CHANNEL>_STATE_DIR` overrides, and CCTG support status.

### Changed
- `install.sh` (copy mode) now installs the package into `~/.local/libexec/cctg/` (cc-tg.sh + VERSION + messages) and symlinks `~/.local/bin/cctg` to it, so companion files sit next to the launcher (Homebrew-style libexec layout). Dev installs (`--dev`) still symlink the repo directly.
- Internal refactor: the monolithic command dispatcher was split into `cmd_*()` functions; error messages now go to stderr. No change to command behavior or output content.

### Fixed
- Reserved-name guard now covers every global channel name (`telegram`, `discord`, `imessage`, `fakechat`), not just `telegram`. `add`/`rename` to any of these is refused so a project bot can't clobber a global channel bot's `.env`/`access.json`; `rm --purge` likewise refuses to delete any global channel dir.
- `add` refuses to reuse a state directory that already holds a non-CCTG channel bot's state (an `.env`/`access.json` with no CCTG `launch.env`), protecting future channel names beyond the reserved list.

## [0.1.0] - 2026-06-15

Initial release.

### Added
- `cctg` launcher tying together tmux + Claude Code + the Telegram gateway, managing per-project channel bots in isolated tmux sessions.
- Bot lifecycle commands: `add`, `rm` (with `--purge`), `rename` (with `--keep-dir`), `up`, `down`, `restart` (single bot or `all`).
- Observability: `status` (RUNNING/uptime/stopped/BROKEN + cwd/state paths), `logs`, `attach`, `doctor`.
- Permission/option management: shared policy via `cctg common` and per-bot overrides via `cctg config` (`launch.env`), injected into Claude Code at launch.
- `install.sh` with copy and `--dev` (symlink) modes, bash/zsh completions, idempotent shell-rc managed block, and `uninstall.sh` cleanup.
- `cctg update` driven by an install manifest, and `VERSION`-based `cctg version`.

[Unreleased]: https://github.com/qwertygeon/cctg/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/qwertygeon/cctg/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/qwertygeon/cctg/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/qwertygeon/cctg/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/qwertygeon/cctg/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/qwertygeon/cctg/releases/tag/v0.1.0
