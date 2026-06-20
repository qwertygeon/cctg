#!/usr/bin/env bats
# `cctg up` / `down` / `restart` — session lifecycle against the stateful fake tmux.

load test_helper

@test "up: starts a session and reports UP" {
  seed_bot mybot
  run cctg up mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"UP   mybot"* ]]
  grep -qxF "cctg-mybot" "$FAKE_TMUX_STATE"
}

@test "up: new-session uses the unified direct form with a pinned width (-x)" {
  # Guards two things routed through start_session: (1) the command is passed as
  # the direct multi-arg form `bash -lc <launch>` — so 'bash' and '-lc' are their
  # own argv tokens; the old single-arg 'bash -lc ...' form would record one
  # combined line and fail the exact-line match. (2) width is pinned with -x so
  # detached capture (logs/snapshot) isn't truncated at tmux's 80-col default.
  seed_bot mybot
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/tmux-lastcmd"
  run cctg up mybot
  [ "$status" -eq 0 ]
  grep -qxF -- '-x'   "$FAKE_TMUX_LASTCMD"   # width flag present
  grep -qxF -- '100'  "$FAKE_TMUX_LASTCMD"   # default SESS_WIDTH_DEFAULT
  grep -qxF -- 'bash' "$FAKE_TMUX_LASTCMD"   # direct form: bash is its own token
  grep -qxF -- '-lc'  "$FAKE_TMUX_LASTCMD"
}

@test "up: a second up is a no-op (already running)" {
  seed_bot mybot
  cctg up mybot >/dev/null
  run cctg up mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already running: mybot"* ]]
}

@test "up: fails when the working dir is missing" {
  registry_raw "mybot | $BATS_TEST_TMPDIR/gone | $CC_CHANNELS_DIR/mybot"
  run cctg up mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"working directory not found"* ]]
  # recovery hint aligned with status BROKEN hint (item: action-error hints)
  [[ "$output" == *"config mybot cwd"* ]]
}

@test "up: fails when the token file is missing" {
  mkdir -p "$CC_CHANNELS_DIR/mybot"
  registry_raw "mybot | $WORK | $CC_CHANNELS_DIR/mybot"   # dir exists, no .env
  run cctg up mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"token file not found"* ]]
}

@test "up: fails for an unregistered bot" {
  run cctg up ghost
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a registered project: ghost"* ]]
  # recovery hint points to registration
  [[ "$output" == *"add <name> <dir>"* ]]
}

@test "down: stops a running session, snapshots, and clears the session" {
  seed_bot mybot
  cctg up mybot >/dev/null
  run cctg down mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOWN mybot"* ]]
  ! grep -qxF "cctg-mybot" "$FAKE_TMUX_STATE"
  [ -f "$CC_CHANNELS_DIR/mybot/last-session.log" ]
}

@test "down: reports stopped when not running" {
  seed_bot mybot
  run cctg down mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopped: mybot"* ]]
}

@test "up all / down all: act on every registered bot" {
  seed_bot a; seed_bot b
  run cctg up all
  [ "$status" -eq 0 ]
  grep -qxF "cctg-a" "$FAKE_TMUX_STATE"
  grep -qxF "cctg-b" "$FAKE_TMUX_STATE"
  run cctg down all
  [ "$status" -eq 0 ]
  [ ! -s "$FAKE_TMUX_STATE" ]
}

# --- prefix-collision regression (exact-match '-t =name') ---
# tmux resolves a plain '-t name' by prefix when no exact session exists, so a
# bot whose name is a prefix of another (cc-tg vs cc-tg-discord) used to control
# the wrong session. cctg now passes '=' targets for all lookups/kills.
# These run against the isolated fake tmux only — never a real tmux server.

@test "up: a prefix-named bot starts even when only its longer sibling runs" {
  seed_bot cc-tg
  seed_bot cc-tg-discord
  cctg up cc-tg-discord >/dev/null      # only the longer-named sibling is up
  run cctg up cc-tg                      # shorter name must NOT match the longer
  [ "$status" -eq 0 ]
  [[ "$output" == *"UP   cc-tg"* ]]      # actually started (not "Already running")
  grep -qxF "cctg-cc-tg" "$FAKE_TMUX_STATE"
  grep -qxF "cctg-cc-tg-discord" "$FAKE_TMUX_STATE"
}

@test "down: a stopped prefix-named bot must not kill its running longer sibling" {
  seed_bot cc-tg
  seed_bot cc-tg-discord
  cctg up cc-tg-discord >/dev/null      # only the longer-named sibling is up
  run cctg down cc-tg                    # shorter name is not running
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopped: cc-tg"* ]]  # reports stopped, does not kill anything
  grep -qxF "cctg-cc-tg-discord" "$FAKE_TMUX_STATE"   # longer sibling untouched
}

@test "restart: stops then starts again, leaving the session running" {
  seed_bot mybot
  cctg up mybot >/dev/null
  run cctg restart mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOWN mybot"* ]]
  [[ "$output" == *"UP   mybot"* ]]
  grep -qxF "cctg-mybot" "$FAKE_TMUX_STATE"
}

# --- multi-target lifecycle (v0.6.0): up/down/restart accept several targets ---

@test "up: starts multiple targets sequentially with a summary (SC-001/004)" {
  seed_bot a; seed_bot b
  run cctg up a b
  [ "$status" -eq 0 ]
  grep -qxF "cctg-a" "$FAKE_TMUX_STATE"
  grep -qxF "cctg-b" "$FAKE_TMUX_STATE"
  [[ "$output" == *"2 succeeded"* ]]          # multi-target summary line
}

@test "down: stops multiple targets sequentially (SC-002)" {
  seed_bot a; seed_bot b
  cctg up a b >/dev/null
  run cctg down a b
  [ "$status" -eq 0 ]
  ! grep -qxF "cctg-a" "$FAKE_TMUX_STATE"
  ! grep -qxF "cctg-b" "$FAKE_TMUX_STATE"
}

@test "up: continues past a failing target and exits non-zero (SC-003)" {
  seed_bot a
  run cctg up a ghost                          # ghost is unregistered -> fails
  [ "$status" -ne 0 ]                          # any failure -> non-zero exit
  grep -qxF "cctg-a" "$FAKE_TMUX_STATE"        # a still started despite ghost failing
  [[ "$output" == *"not a registered project: ghost"* ]]
  [[ "$output" == *"1 succeeded, 1 failed"* ]]
  [[ "$output" == *"failed: ghost"* ]]
}

@test "up: mixes reserved + project targets, routing each (SC-006)" {
  seed_bot myproj
  mkdir -p "$CC_CHANNELS_DIR/telegram"
  printf 'TELEGRAM_BOT_TOKEN=tok\n' > "$CC_CHANNELS_DIR/telegram/.env"
  run cctg up myproj telegram
  [ "$status" -eq 0 ]
  grep -qxF "cctg-myproj" "$FAKE_TMUX_STATE"
  grep -qxF "cctg-telegram" "$FAKE_TMUX_STATE"
  [[ "$output" == *"2 succeeded"* ]]
}

@test "restart: accepts multiple targets (SC-001 via restart)" {
  seed_bot a; seed_bot b
  run cctg restart a b
  [ "$status" -eq 0 ]
  grep -qxF "cctg-a" "$FAKE_TMUX_STATE"
  grep -qxF "cctg-b" "$FAKE_TMUX_STATE"
}

@test "up: single target prints no multi-target summary (SC-005 backward-compat)" {
  seed_bot a
  run cctg up a
  [ "$status" -eq 0 ]
  [[ "$output" != *"succeeded"* ]]             # summary suppressed for a single target
}

@test "up: with no target errors out and prints usage (FR-007)" {
  run cctg up
  [ "$status" -ne 0 ]
  [[ "$output" == *"at least one"* ]]
}

# ---------------------------------------------------------------------------
# v0.5.1/003-robustness-hardening — gateway reliability guards.
# Fault injection: FAKE_TMUX_FAIL_NEWSESSION / FAKE_TMUX_FAIL_KILL (tmux stub);
# PATH surgery for need_tmux / need_claude. coreutils live in /usr/bin:/bin.
# ---------------------------------------------------------------------------

@test "up: tmux new-session failure is reported, not a false UP (R1)" {
  seed_bot mybot
  FAKE_TMUX_FAIL_NEWSESSION=1 run cctg up mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"failed to start"* ]]
  [[ "$output" != *"UP   mybot"* ]]            # no false UP
  ! grep -qxF "cctg-mybot" "$FAKE_TMUX_STATE"  # nothing recorded as running
}

@test "up: refuses when tmux is absent (need_tmux, R2)" {
  seed_bot mybot
  # A controlled bin with the tools cctg needs but deliberately WITHOUT tmux, used as
  # the sole PATH — so tmux is absent regardless of OS. (A bare /usr/bin:/bin PATH is
  # not enough: ubuntu ships tmux in /usr/bin, so need_tmux would still find it; macOS
  # keeps tmux in homebrew so it happened to be absent there.)
  local bin="$BATS_TEST_TMPDIR/notmux-bin"; mkdir -p "$bin"
  local t src
  for t in bash sh env basename dirname readlink awk sed grep cut tr cat head tail mkdir chmod rm ln date stat; do
    src="$(command -v "$t" 2>/dev/null)" || continue
    ln -sf "$src" "$bin/$t"
  done
  run env PATH="$bin" bash "$CCTG" up mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"tmux not found"* ]]
}

@test "up: refuses when claude is absent (need_claude, R2)" {
  seed_bot mybot
  local nodir="$BATS_TEST_TMPDIR/noclaude"; mkdir -p "$nodir"
  ln -s "$REPO_ROOT/tests/stubs/tmux" "$nodir/tmux"   # tmux present so need_tmux passes
  run env PATH="$nodir:/usr/bin:/bin" bash "$CCTG" up mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"claude CLI not found"* ]]
}

@test "down: tmux kill-session failure is reported, not a false DOWN (R3)" {
  seed_bot mybot
  mark_running mybot
  FAKE_TMUX_FAIL_KILL=1 run cctg down mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"failed to stop"* ]]
  grep -qxF "cctg-mybot" "$FAKE_TMUX_STATE"    # still considered running
}

@test "logs: non-numeric line count is rejected (R4)" {
  seed_bot mybot
  run cctg logs mybot abc
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be a number"* ]]
}

@test "up: UP_OK renders ~ paths on separate aligned lines (F1)" {
  mkdir -p "$HOME/proj"
  seed_bot upbot "$HOME/proj"
  run cctg up upbot
  [ "$status" -eq 0 ]
  [[ "$output" == *"UP   upbot"* ]]      # header line preserved
  [[ "$output" == *"~/proj"* ]]          # cwd tilde-shortened
  ! grep -qE 'cwd.*state' <<<"$output"   # cwd and state on separate lines
}
