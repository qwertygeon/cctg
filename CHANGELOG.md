# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Documented bot-operator legal responsibilities**: a new "Your responsibilities as a bot operator" section in [SECURITY.md](SECURITY.md) surfaces obligations that come from the upstream services rather than from CCTG — your use is governed by your own Anthropic plan terms (Commercial/Consumer) and Usage Policy (CCTG only invokes the official `claude` CLI and never extracts/reuses credentials); consumer-facing bots must disclose they are AI; Discord **requires** a per-bot privacy policy and prohibits commercializing platform "API data"; Telegram expects lawful data handling. The README privacy/disclaimer callout (en/ko) gained a pointer, and the Telegram/Discord setup guides (en/ko) gained an "Operator responsibilities" note. Documentation only; not legal advice. (`SECURITY.md`, `README.md`, `README.ko.md`, `docs/telegram-setup*.md`, `docs/discord-setup*.md`)

### Changed
- **Interactive `cctg add` permission-mode prompt is now a numbered menu**: instead of free-typing a mode name, the interactive prompt lists the choices `1) bypassPermissions  2) acceptEdits  3) auto  4) default  5) dontAsk  6) plan  7) (follow shared)` and reads a number. An invalid entry re-prompts instead of aborting; pressing Enter or `7` follows the shared policy; typing a mode name still works. Shell tab-completion cannot reach a running `read` prompt, so a menu is the only way to make the fixed value set selectable inline. The display order is fixed with `bypassPermissions` first and `acceptEdits` second (independent of the validation set order). (`lib/commands.sh`, `messages/*.sh`, docs)

### Fixed
- **`cctg add` no longer leaves a half-created bot on bad input**: all interactive inputs (token, channel ID, group specs, permission mode) are now collected and validated *before* anything is written to disk (validate-before-write). Previously a mistyped permission mode aborted *after* `.env`/`access.json` were written but *before* registration, leaving an unregistered state directory that the foreign-statedir guard then refused to overwrite on retry (a dead-end). As a defense-in-depth net, the state directory is created inside an `EXIT` trap that removes it if the process exits before registration completes — but only when `add` created the directory itself (a pre-existing directory is never deleted, per constitution P-002). (`lib/commands.sh`)
- **`cctg rename` rolls back a moved state directory if the registry update fails**: previously `rename` moved the directory and *then* rewrote the registry as two unguarded steps, so a registry-write failure left the directory at the new path while the registry still pointed at the old one (a broken bot). The directory move is now reverted on registry-update failure, keeping the two in sync. (`lib/commands.sh`)
- **Atomic token `.env` writes (`cctg add` / `cctg config <name> token`)**: the bot token file is now written via a `mktemp`(0600)→`mv` helper (`write_token_env`) instead of a direct `>` redirect. A direct redirect truncates the file before writing, so an interrupted write could leave an empty or partial `.env` and break authentication; the staged-then-renamed write is atomic and never exposes a world-readable window. `cctg config <name> token` additionally gained the missing write-failure guard. (`lib/config.sh`, `lib/commands.sh`)
- **Gateway reliability — `up`/`down` no longer report false outcomes**: `cctg up` now checks the `tmux new-session` exit code and reports a clear failure (`ERR_UP_FAILED`) instead of printing `UP` and then trying to attach a snapshot watcher to a session that never started; `cctg down` likewise checks `tmux kill-session`. `up` also refuses with a clear message when `claude` is absent from `PATH` (otherwise the session survives via `exec bash` and looks "up" while the bot is dead), and `up`/`down`/`restart`/`attach` refuse when `tmux` itself is absent. The snapshot watcher's start is now verified (`kill -0`); if it fails to launch, a warning is printed and the opt-in snapshot is simply disabled for that run rather than silently assumed on. (`lib/session.sh`, `lib/commands.sh`, `lib/util.sh`, `messages/*.sh`)
- **`cctg logs <name> <N>` validates the line count**: a non-numeric `N` is now rejected with a clear error instead of being passed through to `tail` (cryptic tool-level error). (`lib/commands.sh`)

## [0.5.0] - 2026-06-18

### Added
- **Multiple targets for `up` / `down` / `restart`**: these commands now accept several targets in one call (e.g. `cctg up proj1 proj2 telegram`), processed sequentially left to right. Targets may mix registered bot names, the reserved channel names (`telegram` / `discord`), and `all`. Processing is **continue-on-error** — a failing target does not abort the rest; when two or more targets are processed a summary line is printed (succeeded / failed counts and the failed names), and the command exits non-zero if any target failed. A single target behaves exactly as before (no summary). `logs` / `attach` remain single-target. Shell completions (bash + zsh) now complete bot names at every target position for these three commands. (`lib/commands.sh`, `messages/*.sh`, `completions/*`)
- **`cctg config <name> cwd <path>`**: change the working directory of a registered bot without re-registering. The registry is updated atomically (awk+mktemp+mv, same pattern as the existing registry mutations). An error is printed if the target path does not exist; if the bot is running, a restart reminder is shown (FR-001).
- **`cctg config <name> token`**: replace a registered bot's token. The `.env` file is rewritten with the channel-specific key (`TELEGRAM_BOT_TOKEN` / `DISCORD_BOT_TOKEN`) and the file mode is set to `600`. Token input accepts the same three forms as `add`: interactive masked prompt, `--token-env <VAR>`, or `--token-stdin`. Passing the token as a plain argument remains refused (constitution P-003). If the bot is running, a restart reminder is shown (FR-002).
- **`--help` / `-h` per subcommand**: every subcommand now accepts `--help` or `-h` and prints a one-line usage summary, then exits `0`. Implemented via a pre-dispatch inspection loop in `cc-tg.sh` and a new `sub_usage()` function in `lib/util.sh`; the usage text is drawn from the i18n catalog (`USAGE_<SUBCMD>` keys) so it follows the active language (FR-005).
- **Shell completion improvements**: `cctg config <name> mode <TAB>` now completes to the six valid mode values (`acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, `plan`); `cctg config <name> <TAB>` includes the new `cwd` and `token` actions; every subcommand's flag list includes `--help`. Updated in both `completions/_cctg` (zsh) and `completions/cctg.bash` (bash) without sourcing `lib/channels.sh` (local literal mirror, ADR-003) (FR-003, FR-004, FR-005).
- **Reserved-name runtime: `up` / `down` / `restart` / `status` / `logs` for `telegram` and `discord`**: the four commands that previously refused the reserved names with `ERR_NOT_REGISTERED` now route through a dedicated code path that uses the global channel state directory (`~/.claude/channels/<channel>/`) instead of the registry. Details:
  - `cctg up telegram|discord` starts a `cctg-<channel>` tmux session. The working directory (`cwd`) is the caller's `$PWD` at invocation time (DEC-001). A **sole-owner guard** refuses startup if a `cctg-<channel>` session already exists or if `bot.pid` in the state directory holds a living PID (plugin runner active). A missing `.env` is also refused (FR-006).
  - `cctg down telegram|discord` kills only the `cctg-<channel>` tmux session. The plugin's own runner (`bot.pid` process) is **not** stopped — this limit is surfaced in the output message (NFR-003, FR-007).
  - `cctg restart telegram|discord` runs `down` then `up` in sequence (FR-008).
  - `cctg status` output now includes a `--- global channel bots ---` section for each reserved channel whose state directory (`~/.claude/channels/<channel>/`) exists. Status, mode, cwd (`$PWD`), and channel are shown in the same format as project bots (FR-009).
  - `cctg logs telegram|discord [N]` reads the live tmux pane when the session is running, or falls back to `last-session.log` if it exists (FR-010).
  - `cctg add`, `rm`, and `rename` still refuse reserved names with `ERR_RESERVED` (FR-011).

### Changed
- `cctg config <name>` synopsis updated to include the new `cwd` and `token` actions.
- Message catalog (`messages/en.sh`, `messages/ko.sh`) extended with 33 new keys covering the new actions and error/success messages; key parity between the two files is maintained (154 keys total).

### Fixed
- **Snapshot watcher PID-reuse guard**: `stop_snapshotter` no longer kills a PID blindly from `.snapshotter.pid`. The watcher is now launched with an identifying marker (`cctg-snapshotter:<session>`) in its argv, recorded as the pid file's second line; on stop, the PID is killed only if its command line (`ps -ww -o command=`) still carries that marker. A stale pid file whose PID was recycled by an unrelated process is cleaned up without killing that process. Pid files without a marker (created before this change) fall back to the previous behaviour. Regression test added in `tests/snapshot.bats`.
- **tmux session prefix collision**: when one bot's name was a prefix of another's (e.g. `cc-tg` and `cc-tg-discord`), `up` / `down` / `restart` / `status` / `logs` / `attach` could act on the wrong session. tmux resolves a `-t <name>` target by prefix (and fnmatch) when no exact session exists, so with only the longer-named session running, `status` showed the shorter bot as running and `down cc-tg` killed `cc-tg-discord`. All session *lookup/kill* targets now force exact matching via the `=<name>` prefix (`lib/session.sh`, `lib/commands.sh`); session *creation* (`new-session -s`) is unaffected. The fake-tmux test stub now reproduces real tmux's prefix matching (it previously matched only exactly, masking the bug), and `tests/up_down.bats` gains two prefix-collision regression tests.

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
