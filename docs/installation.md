**English** | [한국어](installation.ko.md)

# Installing & Updating CCTG

> Full reference for installing, updating, and uninstalling the `cctg` launcher on macOS, including install modes, flags, and what each step touches.

## Table of Contents

- [Requirements](#requirements)
- [Quick install](#quick-install)
- [What `install.sh` does](#what-installsh-does)
- [Install modes](#install-modes)
  - [Copy install (default — release)](#copy-install-default--release)
  - [Dev install (`--dev` / `--link`)](#dev-install---dev----link)
- [Flags and environment variables](#flags-and-environment-variables)
- [Where files are placed](#where-files-are-placed)
  - [Completions](#completions)
  - [Shell rc managed block](#shell-rc-managed-block)
  - [Manifest and language config](#manifest-and-language-config)
- [PATH setup](#path-setup)
- [After installing](#after-installing)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [What survives an uninstall](#what-survives-an-uninstall)

## Requirements

CCTG is **macOS only** — it relies on `caffeinate`, a macOS builtin, to keep the machine awake.

Required dependencies (installation aborts if either is missing):

- `claude` — the Claude Code CLI.
- `tmux` — the terminal multiplexer the launcher runs inside.

Recommended / optional:

- `caffeinate` — built into macOS; prevents the Mac from sleeping. If it is missing, `install.sh` warns but does not abort.
- `jq` — optional. It is needed for `status --json`, structured `common` edits (mode/deny/allow), and `--group` seeding. Without `jq` those operations error, but the show/edit paths that don't need it still work.

You also need the relevant channel plugin installed globally inside Claude Code, for example:

```
/plugin install telegram@claude-plugins-official
/plugin install discord@claude-plugins-official
```

## Quick install

```bash
git clone https://github.com/qwertygeon/cctg.git
cd cctg
./install.sh
```

`install.sh` is **idempotent** — re-running it is safe and simply refreshes the existing installation.

## What `install.sh` does

Running `./install.sh` performs four steps:

1. **Checks dependencies.** `tmux` and `claude` are required; the installer aborts if either is not on your `PATH`. `caffeinate` is checked too, but a missing `caffeinate` only prints a warning.
2. **Places the launcher** at `~/.local/bin/cctg` (the install mode decides whether this is a copy or a symlink — see below).
3. **Installs shell completions** for bash and zsh.
4. **Adds an idempotent managed block** to your shell rc file that enables `PATH` and completions.

## Install modes

### Copy install (default — release)

```bash
./install.sh
# or, explicitly:
./install.sh --copy
```

Copies the package — `cc-tg.sh`, `VERSION`, `lib/`, and `messages/` — into `~/.local/libexec/cctg/`, then symlinks `~/.local/bin/cctg` to `~/.local/libexec/cctg/cc-tg.sh`.

Because the package is copied out of the repository, **the install keeps working even if you delete or move the cloned repo.** This is the release method. To update later, `git pull` in the repo and re-run `install.sh` (or use `cctg update`).

### Dev install (`--dev` / `--link`)

```bash
./install.sh --dev
# --link is an alias:
./install.sh --link
```

Symlinks `~/.local/bin/cctg` **directly** to the repository's `cc-tg.sh`. Edits you make in the repo take effect immediately — this is the development method. The repo must stay where it is, since the symlink points into it.

## Flags and environment variables

| Flag / variable | Effect |
|---|---|
| `--copy` | Copy install (the default). |
| `--dev` / `--link` | Symlink install pointing at the repo. |
| `--no-completions` | Skip installing bash/zsh completions. |
| `--no-shell-setup` | Skip adding the managed block to your shell rc. |
| `--lang en\|ko` | Seed the CLI output language. Without this, the installer auto-detects from `$LC_ALL`/`$LANG` (`ko*` or `*_KR*` → `ko`, otherwise `en`). |
| `--alias` / `--alias=NAME` | Install a short alias command that behaves identically to `cctg`, with completions. `install.sh` installs `cg` by default even without this flag; use `--alias=NAME` to choose a different name. The name is recorded in the manifest. |
| `--no-alias` | Do not install the alias (removes it if one exists). |
| `-h` / `--help` | Print help and exit. |
| `BINDIR=~/bin ./install.sh` | Change the install location (default `~/.local/bin`). |
| `CCTG_LIBEXEC=...` | Change the libexec package directory (default `~/.local/libexec/cctg`). |

## Where files are placed

### Completions

- **bash:** `$XDG_DATA_HOME` (or `~/.local/share`) `/bash-completion/completions/cctg`
- **zsh:** `$XDG_DATA_HOME` (or `~/.local/share`) `/zsh/site-functions/_cctg`

Completion install failures do not abort the overall install.

### Shell rc managed block

The installer writes a managed block delimited by markers:

```
# >>> cctg >>>
...
# <<< cctg <<<
```

This block enables `PATH` and completions. The first time the installer edits a file, it leaves a one-time `<rc>.cctg-bak` backup. Re-running never duplicates the block.

- **zsh:** edits `~/.zshrc`.
- **bash:** edits `~/.bashrc` and `~/.bash_profile`.
- **Unknown shell:** the installer skips the rc edit and prints the manual `PATH` command instead.

To apply the changes, open a new terminal or `source` the relevant rc (e.g. `source ~/.zshrc`).

### Manifest and language config

- `install.sh` writes a manifest at `~/.config/cctg/install.conf` with the keys: `repo`, `mode`, `version`, `bindir`, `libexecdir`, `bashcomp`, `zshcomp`, `shellrc`. Both `cctg update` and `uninstall.sh` read this manifest.
- The CLI language preference is stored separately in `~/.config/cctg/config` (`lang=...`) so that `cctg update` preserves it.

## PATH setup

If `~/.local/bin` is not already on your `PATH` (and you used `--no-shell-setup`, or your shell is unknown), add it manually:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

Verify with:

```bash
cctg doctor
```

## After installing

Open a new terminal or reload your shell, then run:

```bash
cctg doctor
```

`doctor` verifies dependencies, `PATH`, the registry, and the shared policy.

## Updating

```bash
cctg update
```

`cctg update` reads the repo location and install mode from the manifest, runs `git pull --ff-only`, then re-runs `install.sh` (which is idempotent). It prints the old → new version.

- For a **copy install**, the new launcher is re-copied into the libexec directory.
- For a **dev (`--dev`) install**, the launcher is already current right after the pull; completions are copied to the data directory, so re-running refreshes them.
- If uncommitted local changes prevent a fast-forward, `update` stops without overwriting anything — clean up the repo and try again.

## Uninstalling

```bash
./uninstall.sh
```

`uninstall.sh` removes everything CCTG installed:

- `~/.local/bin/cctg` — but **only after verifying CCTG installed it** (it checks the symlink target, or the identity string inside the copied file). If the path points somewhere else, it is left untouched.
- The libexec package directory (for copy installs).
- The bash/zsh completion files recorded in the manifest.
- The shell rc managed block — only the content between the `# >>> cctg >>>` / `# <<< cctg <<<` markers.
- The one-time `.cctg-bak` rc backups.
- The language config (`~/.config/cctg/config`).
- The manifest itself.

The `BINDIR` environment variable, or the manifest's `bindir` value, determines which bin path is cleaned.

## What survives an uninstall

`uninstall.sh` **never touches** the registry or state directories under `~/.claude/channels/`. Your bot registrations and tokens survive a reinstall, so you can remove and re-install CCTG without losing channel configuration.

---

[← Back to README](../README.md)

**See also:**

- [Telegram setup](telegram-setup.md)
- [Discord setup](discord-setup.md)
- [Commands](commands.md)
- [Configuration](configuration.md)
