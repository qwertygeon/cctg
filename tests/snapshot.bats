#!/usr/bin/env bats
# Opt-in periodic log snapshot (crash/reboot coverage): config + watcher lifecycle.

load test_helper

@test "config snapshot <secs>: writes CCTG_LOG_SNAPSHOT_INTERVAL" {
  seed_bot mybot
  run cctg config mybot snapshot 30
  [ "$status" -eq 0 ]
  [[ "$output" == *"log snapshot: every 30s"* ]]
  grep -q 'CCTG_LOG_SNAPSHOT_INTERVAL="30"' "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "config snapshot off: clears the interval" {
  seed_bot mybot
  cctg config mybot snapshot 30 >/dev/null
  run cctg config mybot snapshot off
  [ "$status" -eq 0 ]
  [[ "$output" == *"log snapshot: off"* ]]
  grep -q 'CCTG_LOG_SNAPSHOT_INTERVAL=""' "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "config snapshot: rejects a value below the minimum" {
  seed_bot mybot
  run cctg config mybot snapshot 3
  [ "$status" -ne 0 ]
  [[ "$output" == *">= 5"* ]]
}

@test "config snapshot: rejects a non-numeric value" {
  seed_bot mybot
  run cctg config mybot snapshot abc
  [ "$status" -ne 0 ]
  [[ "$output" == *">= 5"* ]]
}

@test "config snapshot: with no value prints usage" {
  seed_bot mybot
  run cctg config mybot snapshot
  [ "$status" -ne 0 ]
  [[ "$output" == *"snapshot <seconds|off>"* ]]
}

@test "config show: reflects the snapshot setting (off then on)" {
  seed_bot mybot
  run cctg config mybot show
  [[ "$output" == *"log snapshot: off"* ]]
  cctg config mybot snapshot 60 >/dev/null
  run cctg config mybot show
  [[ "$output" == *"log snapshot: 60s"* ]]
}

@test "up: starts the snapshot watcher when an interval is configured" {
  seed_bot mybot
  cctg config mybot snapshot 5 >/dev/null
  run cctg up mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"log snapshot: every 5s"* ]]
  local pidf="$CC_CHANNELS_DIR/mybot/.snapshotter.pid"
  [ -f "$pidf" ]
  kill -0 "$(head -n1 "$pidf")"      # watcher process is alive
}

@test "up: does not start a watcher when snapshot is off (default)" {
  seed_bot mybot
  cctg up mybot >/dev/null
  [ ! -f "$CC_CHANNELS_DIR/mybot/.snapshotter.pid" ]
}

@test "down: stops the snapshot watcher and removes its pid file" {
  seed_bot mybot
  cctg config mybot snapshot 5 >/dev/null
  cctg up mybot >/dev/null
  local pidf="$CC_CHANNELS_DIR/mybot/.snapshotter.pid"
  [ -f "$pidf" ]
  local pid; pid="$(head -n1 "$pidf")"
  run cctg down mybot
  [ "$status" -eq 0 ]
  [ ! -f "$pidf" ]
  ! kill -0 "$pid" 2>/dev/null        # watcher process is gone
}

@test "down: does not kill an unrelated process when the pid was recycled (marker mismatch)" {
  seed_bot ghost
  # An unrelated long-lived process that happens to hold the recycled PID.
  sleep 30 &
  local unrel=$!
  # Stale pid file: recycled PID + our snapshotter marker, which the unrelated
  # `sleep` command line does NOT contain -> stop must refuse to kill it.
  local pidf="$CC_CHANNELS_DIR/ghost/.snapshotter.pid"
  printf '%s\ncctg-snapshotter:cctg-ghost\n' "$unrel" > "$pidf"
  run cctg down ghost
  [ "$status" -eq 0 ]
  [ ! -f "$pidf" ]                    # stale pid file is cleaned up regardless
  kill -0 "$unrel" 2>/dev/null        # unrelated process survives (not killed)
  kill "$unrel" 2>/dev/null || true   # cleanup
}

@test "down: marker match is exact-token, not substring — spares a sibling's recycled watcher" {
  # Regression: 'cctg-snapshotter:cctg-cc-tg' is a substring prefix of a sibling's
  # marker 'cctg-snapshotter:cctg-cc-tg-discord'. A substring (grep -F) match would
  # mis-kill the sibling's watcher when the PID was recycled; the match must be on a
  # whole whitespace-delimited argv token. (Same exact-match class as the tmux '=' fix.)
  seed_bot cc-tg
  # A live process whose argv carries the SIBLING's marker as a token (resident bash
  # loop so it isn't exec-optimized away, mirroring the real snapshotter shape).
  bash -c 'while :; do sleep 1; done' "cctg-snapshotter:cctg-cc-tg-discord" x x x &
  local sib=$!
  # Stale pid file for cc-tg: recycled PID + cc-tg's marker (a prefix of the sibling's).
  local pidf="$CC_CHANNELS_DIR/cc-tg/.snapshotter.pid"
  printf '%s\ncctg-snapshotter:cctg-cc-tg\n' "$sib" > "$pidf"
  run cctg down cc-tg
  [ "$status" -eq 0 ]
  [ ! -f "$pidf" ]                    # stale pid file cleaned up regardless
  kill -0 "$sib" 2>/dev/null          # sibling watcher must survive (not mis-killed)
  kill "$sib" 2>/dev/null || true     # cleanup
}
