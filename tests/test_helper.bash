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
  # A developer-exported width override would skew width-resolution assertions.
  unset CC_TG_SESS_WIDTH
  # Multi-target up/restart now staggers launches via await_up_settled. Default the
  # settle to 0 so generic lifecycle tests don't incur the real settle wait; the
  # serialization tests override CC_TG_UP_SETTLE and opt into the logging sleep stub.
  export CC_TG_UP_SETTLE=0
  mkdir -p "$HOME" "$XDG_CONFIG_HOME"

  # Default working dir for bots that need an existing cwd.
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"

  # Fake tmux first on PATH; real jq/awk/sed/etc. still resolve behind it.
  # FAKE_TMUX_STATE tracks which sessions the stub considers "running".
  export PATH="$REPO_ROOT/tests/stubs:$PATH"
  export FAKE_TMUX_STATE="$BATS_TEST_TMPDIR/.tmux-sessions"
  : > "$FAKE_TMUX_STATE"
  # Liveness (claude_alive): the tmux stub returns this as '#{pane_pid}', and the ps
  # stub's default tree gives that pid a `claude` child — so a running session reads
  # as RUNNING. Tests simulate DEAD by overriding FAKE_PS_TREE with a claude-less tree.
  export FAKE_TMUX_PANE_PID="700001"

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
mark_running() { printf 'cctg-%s\n' "$1" >> "$FAKE_TMUX_STATE"; }

# Stop any background log-snapshotter a test started (best-effort cleanup).
teardown() {
  local pidf
  for pidf in "$CC_CHANNELS_DIR"/*/.snapshotter.pid; do
    [ -f "$pidf" ] || continue
    kill "$(head -n1 "$pidf" 2>/dev/null)" 2>/dev/null || true
  done
}
