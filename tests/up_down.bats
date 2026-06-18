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
