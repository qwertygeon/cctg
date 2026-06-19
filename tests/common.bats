#!/usr/bin/env bats
# `cctg common` — shared permission-policy settings (jq-backed).

load test_helper

@test "common show: seeds the shared settings file and prints it" {
  run cctg common show
  [ "$status" -eq 0 ]
  [ -f "$SHARED_SETTINGS" ]
  echo "$output" | grep -q '"defaultMode"'
}

@test "common: seeded defaults use bypassPermissions with a deny safety net" {
  cctg common show >/dev/null
  run jq -r '.permissions.defaultMode' "$SHARED_SETTINGS"
  [ "$output" = "bypassPermissions" ]
  run jq -e '.permissions.deny | length > 0' "$SHARED_SETTINGS"
  [ "$status" -eq 0 ]
}

@test "common mode: changes defaultMode" {
  run cctg common mode plan
  [ "$status" -eq 0 ]
  run jq -r '.permissions.defaultMode' "$SHARED_SETTINGS"
  [ "$output" = "plan" ]
}

@test "common mode: refuses an invalid mode" {
  run cctg common mode bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid mode"* ]]
}

@test "common deny add: appends a rule (deduplicated)" {
  cctg common show >/dev/null
  run cctg common deny add "Bash(foo *)"
  [ "$status" -eq 0 ]
  run jq -e '.permissions.deny | index("Bash(foo *)") != null' "$SHARED_SETTINGS"
  [ "$status" -eq 0 ]
  # Adding the same rule again must not duplicate it.
  cctg common deny add "Bash(foo *)" >/dev/null
  run jq -r '[.permissions.deny[] | select(. == "Bash(foo *)")] | length' "$SHARED_SETTINGS"
  [ "$output" = "1" ]
}

@test "common deny rm: removes a rule" {
  cctg common show >/dev/null
  cctg common deny add "Bash(foo *)" >/dev/null
  run cctg common deny rm "Bash(foo *)"
  [ "$status" -eq 0 ]
  run jq -e '.permissions.deny | index("Bash(foo *)") == null' "$SHARED_SETTINGS"
  [ "$status" -eq 0 ]
}

@test "common allow add: appends an allow rule" {
  cctg common show >/dev/null
  run cctg common allow add "Bash(ls *)"
  [ "$status" -eq 0 ]
  run jq -e '.permissions.allow | index("Bash(ls *)") != null' "$SHARED_SETTINGS"
  [ "$status" -eq 0 ]
}

@test "common: rejects an unknown action" {
  run cctg common frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown common action"* ]]
}

# ---------------------------------------------------------------------------
# global default session width (v0.6.0/001-session-width-config)
# ---------------------------------------------------------------------------

@test "common width: sets the global default in the config file" {
  run cctg common width 150
  [ "$status" -eq 0 ]
  [[ "$output" == *"Default session width: 150"* ]]
  grep -q '^sess_width=150$' "$XDG_CONFIG_HOME/cctg/config"
}

@test "common width clear: resets to the built-in default" {
  cctg common width 150 >/dev/null
  run cctg common width clear
  [ "$status" -eq 0 ]
  [[ "$output" == *"(built-in default)"* ]]
  ! grep -q '^sess_width=' "$XDG_CONFIG_HOME/cctg/config"
}

@test "common width: refuses a below-minimum value" {
  run cctg common width 5
  [ "$status" -ne 0 ]
  [[ "$output" == *"width must be an integer"* ]]
}

@test "common show: reports the global default width and source" {
  run cctg common show
  [ "$status" -eq 0 ]
  [[ "$output" == *"Default session width: 100 (default)"* ]]
  cctg common width 150 >/dev/null
  run cctg common show
  [[ "$output" == *"Default session width: 150 (config)"* ]]
}

@test "up: applies the global default width when no per-bot value" {
  cctg common width 150 >/dev/null
  seed_bot mybot
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/tmux-lastcmd"
  run cctg up mybot
  [ "$status" -eq 0 ]
  grep -qxF -- '150' "$FAKE_TMUX_LASTCMD"   # global default applied
}

@test "up: env CC_TG_SESS_WIDTH overrides the config-file global default" {
  cctg common width 150 >/dev/null
  seed_bot mybot
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/tmux-lastcmd"
  CC_TG_SESS_WIDTH=180 run cctg up mybot
  [ "$status" -eq 0 ]
  grep -qxF -- '180' "$FAKE_TMUX_LASTCMD"   # env wins over config
  ! grep -qxF -- '150' "$FAKE_TMUX_LASTCMD"
}
