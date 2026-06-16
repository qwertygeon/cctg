# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/qwertygeon/cctg/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/qwertygeon/cctg/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/qwertygeon/cctg/releases/tag/v0.1.0
