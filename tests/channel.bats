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

# SC-003: discord is now an implemented channel, so --channel discord must NOT
# be rejected as unsupported. (The old assertion expected ERR_CHANNEL_UNSUPPORTED;
# that is obsolete intended behaviour — discord is supported as of this spec.)
@test "add --channel discord: not refused as unsupported (SC-003)" {
  run cctg add mybot "$WORK" --token-stdin --channel discord < /dev/null
  # Empty stdin → ERR_EMPTY_TOKEN is allowed; the point is the channel passes the
  # implemented-channel gate (no "not supported" message).
  [[ "$output" != *"not supported"* ]]
}

# SC-003 (negative side): a genuinely unimplemented channel is still refused before
# anything is scaffolded — proves the UNSUPPORTED gate is intact, not removed.
@test "add --channel <unimplemented>: refused before anything is created" {
  BOT_TOKEN=tok run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 5 --channel fakechat
  [ "$status" -ne 0 ]
  [[ "$output" == *"not supported"* ]]
  ! grep -qE "^mybot \|" "$REGISTRY"          # nothing registered
  [ ! -d "$CC_CHANNELS_DIR/mybot" ]           # no state dir scaffolded
}

# --- descriptor: IMPLEMENTED_CHANNELS + channel_spec fields (SC-001/004/005/006) ---
# These source lib/channels.sh directly to assert the descriptor contract.

@test "channel_spec: telegram exposes all 8 fields (SC-004)" {
  source "$REPO_ROOT/lib/channels.sh"
  local f
  for f in plugin statedir_env token_key token_required display id_label id_required seed_policy; do
    run channel_spec telegram "$f"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
  done
}

@test "channel_spec: discord exposes all 8 fields (SC-005)" {
  source "$REPO_ROOT/lib/channels.sh"
  local f
  for f in plugin statedir_env token_key token_required display id_label id_required seed_policy; do
    run channel_spec discord "$f"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
  done
}

@test "channel_spec: discord display/id_required/seed_policy values (SC-006)" {
  source "$REPO_ROOT/lib/channels.sh"
  run channel_spec discord display;      [ "$output" = "Discord" ]
  run channel_spec discord id_required;  [ "$output" = "no" ]
  run channel_spec discord seed_policy;  [ "$output" = "pairing" ]
}

@test "channel_spec: an unimplemented channel field returns non-zero" {
  source "$REPO_ROOT/lib/channels.sh"
  run channel_spec fakechat plugin
  [ "$status" -ne 0 ]
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
