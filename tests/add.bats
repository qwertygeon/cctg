#!/usr/bin/env bats
# `cctg add` — registration, scaffolding, and input validation.

load test_helper

@test "add: registers and scaffolds .env/access.json/launch.env/inbox" {
  BOT_TOKEN="abc123" run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 777
  [ "$status" -eq 0 ]
  [[ "$output" == *"Registered: mybot"* ]]

  local sd="$CC_CHANNELS_DIR/mybot"
  grep -qE '^mybot \| ' "$REGISTRY"
  [ -d "$sd/inbox" ]
  [ -f "$sd/.env" ]
  [ -f "$sd/access.json" ]
  [ -f "$sd/launch.env" ]
  grep -q 'TELEGRAM_BOT_TOKEN=abc123' "$sd/.env"
}

@test "add: .env is created with 600 permissions" {
  seed_bot mybot
  [ "$(file_mode "$CC_CHANNELS_DIR/mybot/.env")" = "600" ]
}

@test "add: access.json is valid JSON seeding the given id into the allowlist" {
  BOT_TOKEN="abc" run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 12345
  [ "$status" -eq 0 ]
  run jq -r '.allowFrom[0]' "$CC_CHANNELS_DIR/mybot/access.json"
  [ "$status" -eq 0 ]
  [ "$output" = "12345" ]
}

@test "add: --mode writes CCTG_PERMISSION_MODE into launch.env" {
  seed_bot mybot "$WORK" --mode acceptEdits
  grep -q 'CCTG_PERMISSION_MODE="acceptEdits"' "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "add: rejects an invalid name and registers nothing" {
  run cctg add "bad name" "$WORK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"may only contain letters/digits"* ]]
  ! grep -q 'bad name' "$REGISTRY"
}

@test "add: refuses a reserved global channel name" {
  run cctg add telegram "$WORK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"reserved global channel name"* ]]
  [ ! -d "$CC_CHANNELS_DIR/telegram" ] || [ -z "$(ls -A "$CC_CHANNELS_DIR/telegram" 2>/dev/null)" ]
}

@test "add: refuses a duplicate registration" {
  seed_bot mybot
  BOT_TOKEN="x" run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"already registered: mybot"* ]]
}

@test "add: refuses an invalid permission mode" {
  BOT_TOKEN="x" run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 1 --mode bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid permission mode"* ]]
}

@test "add: rejects an empty token" {
  EMPTYTOK="" run cctg add mybot "$WORK" --token-env EMPTYTOK --id 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"token is empty"* ]]
}

@test "add: rejects a non-numeric telegram id" {
  BOT_TOKEN="x" run cctg add mybot "$WORK" --token-env BOT_TOKEN --id abc
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a numeric ID"* ]]
}

@test "add: non-interactive without --id is refused" {
  BOT_TOKEN="x" run cctg add mybot "$WORK" --token-env BOT_TOKEN
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires --id"* ]]
}

@test "add: refuses an unknown flag" {
  BOT_TOKEN="x" run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 1 --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown add flag"* ]]
}

@test "add: refuses a state dir already holding a foreign channel bot" {
  mkdir -p "$CC_CHANNELS_DIR/foo"
  printf 'X=1\n' > "$CC_CHANNELS_DIR/foo/.env"   # foreign: .env present, no launch.env
  BOT_TOKEN="x" run cctg add foo "$WORK" --token-env BOT_TOKEN --id 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"another channel bot's state"* ]]
}
