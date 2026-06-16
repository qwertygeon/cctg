# test_helper.bash — shared setup for the cctg bats suite.
#
# Each test runs against a throwaway state tree under $BATS_TEST_TMPDIR, with a
# fake tmux on PATH, so nothing touches the user's real ~/.claude/channels,
# config, or tmux server. cc-tg.sh is driven as a subprocess via cctg().

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CCTG="$REPO_ROOT/cc-tg.sh"

  # Isolate every state path the script touches.
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  export CC_CHANNELS_DIR="$BATS_TEST_TMPDIR/channels"
  export CCTG_LANG=en            # stable English output for assertions
  mkdir -p "$HOME" "$XDG_CONFIG_HOME"

  # Default working dir for bots that need an existing cwd.
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"

  # Fake tmux first on PATH; real jq/awk/sed/etc. still resolve behind it.
  export PATH="$REPO_ROOT/tests/stubs:$PATH"
  export FAKE_TMUX_SESSIONS=""

  # Convenience handles to the files the script derives from CC_CHANNELS_DIR.
  REGISTRY="$CC_CHANNELS_DIR/projects.conf"
  SHARED_SETTINGS="$CC_CHANNELS_DIR/cctg-shared.settings.json"
}

# Run the script under test. Use with bats `run` for assertions.
cctg() { bash "$CCTG" "$@"; }

# Register a bot non-interactively. Extra args (e.g. --mode) are forwarded.
#   seed_bot <name> [cwd] [extra add args...]
seed_bot() {
  local name="$1" cwd="${2:-$WORK}"
  shift || true; [ $# -gt 0 ] && shift || true
  BOT_TOKEN="tok-$name" bash "$CCTG" add "$name" "$cwd" \
    --token-env BOT_TOKEN --id 555 "$@" >/dev/null
}

# Append a raw registry line, bypassing add() — used to craft edge cases
# (foreign/reserved/outside state dirs) that add() would otherwise refuse.
#   registry_raw "<name> | <cwd> | <state_dir>"
registry_raw() {
  mkdir -p "$CC_CHANNELS_DIR"
  [ -f "$REGISTRY" ] || printf '# name | working_dir | state_dir\n' > "$REGISTRY"
  printf '%s\n' "$1" >> "$REGISTRY"
}

# Portable file permission bits (e.g. "600"). GNU stat first, BSD/macOS fallback.
file_mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

# Mark a bot's session as running for the fake tmux.
mark_running() { export FAKE_TMUX_SESSIONS="cctg-$1"; }
