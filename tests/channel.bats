#!/usr/bin/env bats
# Channel abstraction (multi-gateway scaffold) — registry channel column, add --channel,
# descriptor-driven token key, and backward-compatible legacy-row handling.

load test_helper

@test "add: records the channel column (default telegram)" {
  seed_bot mybot
  grep -qE "^mybot \| .* \| .* \| telegram$" "$REGISTRY"
}

@test "add --channel telegram: explicit channel is recorded" {
  BOT_TOKEN=tok run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 5 --channel telegram
  [ "$status" -eq 0 ]
  grep -qE "^mybot \| .* \| .* \| telegram$" "$REGISTRY"
}

@test "add --channel <unsupported>: refused before anything is created" {
  BOT_TOKEN=tok run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 5 --channel discord
  [ "$status" -ne 0 ]
  [[ "$output" == *"not supported"* ]]
  ! grep -qE "^mybot \|" "$REGISTRY"          # nothing registered
  [ ! -d "$CC_CHANNELS_DIR/mybot" ]           # no state dir scaffolded
}

@test "add writes the channel-specific token key (telegram → TELEGRAM_BOT_TOKEN)" {
  seed_bot mybot
  grep -q '^TELEGRAM_BOT_TOKEN=' "$CC_CHANNELS_DIR/mybot/.env"
}

@test "status --json: reports the channel field" {
  seed_bot mybot
  run cctg status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].channel == "telegram"'
}

@test "config show: prints the channel" {
  seed_bot mybot
  run cctg config mybot show
  [ "$status" -eq 0 ]
  [[ "$output" == *"telegram"* ]]
}

@test "legacy 3-column registry row is treated as telegram" {
  registry_raw "legacy | $WORK | $CC_CHANNELS_DIR/legacy"
  mkdir -p "$CC_CHANNELS_DIR/legacy"
  printf 'TELEGRAM_BOT_TOKEN=x\n' > "$CC_CHANNELS_DIR/legacy/.env"
  run cctg status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].channel == "telegram"'
}
