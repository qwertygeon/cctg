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
