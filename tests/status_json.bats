#!/usr/bin/env bats
# `cctg status --json` — machine-readable schema and state classification.

load test_helper

@test "status --json: empty registry yields []" {
  run cctg status --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "status --json: a stopped bot reports stopped/null uptime/no issues" {
  seed_bot mybot
  run cctg status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].name == "mybot"'
  echo "$output" | jq -e '.[0].state == "stopped"'
  echo "$output" | jq -e '.[0].running == false'
  echo "$output" | jq -e '.[0].uptimeSeconds == null'
  echo "$output" | jq -e '.[0].issues == []'
  echo "$output" | jq -e '.[0].mode == "shared"'
  # stopped + no saved snapshot → last-activity unknown (null)
  echo "$output" | jq -e '.[0].lastActivitySeconds == null'
}

@test "status --json: a missing working dir surfaces a no-cwd issue and broken state" {
  registry_raw "broke | $BATS_TEST_TMPDIR/gone | $CC_CHANNELS_DIR/broke"
  mkdir -p "$CC_CHANNELS_DIR/broke"
  printf 'TELEGRAM_BOT_TOKEN=x\n' > "$CC_CHANNELS_DIR/broke/.env"
  run cctg status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].state == "broken"'
  echo "$output" | jq -e '.[0].issues | index("no-cwd") != null'
}

@test "status --json: a missing token surfaces a no-token issue" {
  registry_raw "notok | $WORK | $CC_CHANNELS_DIR/notok"
  mkdir -p "$CC_CHANNELS_DIR/notok"          # dir exists but no .env
  run cctg status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].issues | index("no-token") != null'
}

@test "status --json: a running bot reports running with a numeric uptime" {
  seed_bot mybot
  mark_running mybot
  run cctg status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].state == "running"'
  echo "$output" | jq -e '.[0].running == true'
  echo "$output" | jq -e '.[0].uptimeSeconds | type == "number"'
  # running → last-activity from tmux window_activity (numeric seconds)
  echo "$output" | jq -e '.[0].lastActivitySeconds | type == "number"'
}

@test "status --json: a stopped bot with a saved snapshot reports numeric lastActivitySeconds" {
  seed_bot mybot
  printf 'saved\n' > "$CC_CHANNELS_DIR/mybot/last-session.log"
  run cctg status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].state == "stopped"'
  echo "$output" | jq -e '.[0].lastActivitySeconds | type == "number"'
}

@test "status --json: running lastActivitySeconds reflects window_activity (deterministic)" {
  seed_bot mybot
  mark_running mybot
  export FAKE_TMUX_ACTIVITY=$(( $(date +%s) - 120 ))   # window_activity = 120s ago
  run cctg status --json
  [ "$status" -eq 0 ]
  local la; la="$(echo "$output" | jq '.[0].lastActivitySeconds')"
  [ "$la" -ge 118 ] && [ "$la" -le 125 ]               # ~120s, small slack for wall-clock
  unset FAKE_TMUX_ACTIVITY
}

@test "status --json: per-bot mode is reflected" {
  seed_bot mybot "$WORK" --mode plan
  run cctg status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].mode == "plan"'
}

@test "status --json: output is always a valid JSON array" {
  seed_bot a; seed_bot b
  run cctg status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'type == "array" and length == 2'
}
