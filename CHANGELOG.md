# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- English `README.md` as the primary doc, with the Korean version preserved as `README.ko.md` and a language switcher on both.
- Privacy / data-flow notice and an "unofficial tool" disclaimer in the README.
- `.gitignore` for macOS, editor, and `*.cctg-bak` artifacts.
- Project meta files: `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`, and GitHub issue/PR templates.

## [0.1.0] - 2026-06-15

Initial release.

### Added
- `cctg` launcher tying together tmux + Claude Code + the Telegram gateway, managing per-project channel bots in isolated tmux sessions.
- Bot lifecycle commands: `add`, `rm` (with `--purge`), `rename` (with `--keep-dir`), `up`, `down`, `restart` (single bot or `all`).
- Observability: `status` (RUNNING/uptime/stopped/BROKEN + cwd/state paths), `logs`, `attach`, `doctor`.
- Permission/option management: shared policy via `cctg common` and per-bot overrides via `cctg config` (`launch.env`), injected into Claude Code at launch.
- `install.sh` with copy and `--dev` (symlink) modes, bash/zsh completions, idempotent shell-rc managed block, and `uninstall.sh` cleanup.
- `cctg update` driven by an install manifest, and `VERSION`-based `cctg version`.

[Unreleased]: https://github.com/qwertygeon/cctg/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/qwertygeon/cctg/releases/tag/v0.1.0
