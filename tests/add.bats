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
  grep -q "TELEGRAM_BOT_TOKEN='abc123'" "$sd/.env"
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
  grep -q "CCTG_PERMISSION_MODE='acceptEdits'" "$CC_CHANNELS_DIR/mybot/launch.env"
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

# --- channel-branched add (FR-003/004/008): id_required, seed policy, --group ---
# discord has id_required=no, so it must register without --id; telegram keeps the
# required-id behaviour. seed_bot can't be reused for the no-id case (it injects
# --id 555), so these drive add directly with --token-env/--token-stdin.

@test "add: discord without --id proceeds (no ERR_ADD_NEED_ID) (SC-007)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN
  [ "$status" -eq 0 ]
  [[ "$output" != *"requires --id"* ]]
  [ -f "$CC_CHANNELS_DIR/mybot/access.json" ]
}

@test "add: telegram without --id is still refused (SC-008)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel telegram --token-env BOT_TOKEN
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires --id"* ]]
}

@test "add: discord --id absent seeds pairing/[]/{}, no pending (SC-009)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN
  [ "$status" -eq 0 ]
  local aj="$CC_CHANNELS_DIR/mybot/access.json"
  jq -e '.dmPolicy == "pairing"' "$aj"
  jq -e '.allowFrom == []' "$aj"
  jq -e '.groups == {}' "$aj"
  jq -e 'has("pending") == false' "$aj"
}

@test "add: discord --id present seeds allowlist with id, no pending (SC-010)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN --id 12345
  [ "$status" -eq 0 ]
  local aj="$CC_CHANNELS_DIR/mybot/access.json"
  jq -e '.dmPolicy == "allowlist"' "$aj"
  jq -e '.allowFrom | index("12345") != null' "$aj"
  jq -e 'has("pending") == false' "$aj"
}

@test "add: telegram seed has no pending field (SC-011)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel telegram --token-env BOT_TOKEN --id 12345
  [ "$status" -eq 0 ]
  local aj="$CC_CHANNELS_DIR/mybot/access.json"
  jq -e '.dmPolicy == "allowlist"' "$aj"
  jq -e '.allowFrom | index("12345") != null' "$aj"
  jq -e 'has("pending") == false' "$aj"
}

@test "add: discord writes DISCORD_BOT_TOKEN into .env (SC-022)" {
  printf 'dc-secret-token\n' | cctg add mybot "$WORK" --channel discord --token-stdin >/dev/null
  grep -q "^DISCORD_BOT_TOKEN='dc-secret-token'\$" "$CC_CHANNELS_DIR/mybot/.env"
}

@test "add: --group <id> once seeds that key (SC-025)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
    --group 846209781206941736
  [ "$status" -eq 0 ]
  local aj="$CC_CHANNELS_DIR/mybot/access.json"
  jq -e '.groups["846209781206941736"].requireMention == true' "$aj"
  jq -e '.groups["846209781206941736"].allowFrom == []' "$aj"
}

@test "add: --group twice seeds both keys (SC-026)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
    --group 111000111000111000 --group 222000222000222000
  [ "$status" -eq 0 ]
  local aj="$CC_CHANNELS_DIR/mybot/access.json"
  jq -e '.groups | has("111000111000111000")' "$aj"
  jq -e '.groups | has("222000222000222000")' "$aj"
}

@test "add: non-numeric --group id errors and registers nothing (SC-027)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
    --group abc
  [ "$status" -ne 0 ]
  # not registered: no mybot row in the registry (file may be absent entirely)
  ! { [ -f "$REGISTRY" ] && grep -qE "^mybot \|" "$REGISTRY"; }
}

@test "add: --group :nomention sets requireMention false (SC-030)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
    --group 846209781206941736:nomention
  [ "$status" -eq 0 ]
  jq -e '.groups["846209781206941736"].requireMention == false' \
    "$CC_CHANNELS_DIR/mybot/access.json"
}

@test "add: --group :allow= seeds the listed members (SC-031)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
    --group 846209781206941736:allow=184695080709324800,221773638772129792
  [ "$status" -eq 0 ]
  local aj="$CC_CHANNELS_DIR/mybot/access.json"
  jq -e '.groups["846209781206941736"].allowFrom | index("184695080709324800") != null' "$aj"
  jq -e '.groups["846209781206941736"].allowFrom | index("221773638772129792") != null' "$aj"
}

@test "add: --group :allow= with non-numeric member errors, registers nothing (SC-032)" {
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
    --group 846209781206941736:allow=abc
  [ "$status" -ne 0 ]
  ! { [ -f "$REGISTRY" ] && grep -qE "^mybot \|" "$REGISTRY"; }
}

@test "add: unknown --group modifier errors, registers nothing (defensive)" {
  # A typo'd modifier (e.g. 'nomeniton') must not be silently dropped — that would
  # seed an access policy different from the user's intent. It must fail loudly.
  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
    --group 846209781206941736:nomeniton
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown --group modifier"* ]]
  ! { [ -f "$REGISTRY" ] && grep -qE "^mybot \|" "$REGISTRY"; }
}

# ---------------------------------------------------------------------------
# v0.5.1/001-add-flow-hardening: interactive permission-mode menu (DEC-002),
# validate-before-write (DEC-003), and pre-registration cleanup (DEC-004).
# Interactive add prompts in order: token (silent), channel id, mode menu.
# Driven by piping those three lines into a fresh `bash cc-tg.sh add` process.
# ---------------------------------------------------------------------------

@test "add: interactive mode menu choice 1 selects bypassPermissions (DEC-002 order)" {
  printf 'tok\n555\n1\n' | bash "$CCTG" add mybot "$WORK" >/dev/null
  grep -q "CCTG_PERMISSION_MODE='bypassPermissions'" "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "add: interactive mode menu choice 2 selects acceptEdits (DEC-002 order)" {
  printf 'tok\n555\n2\n' | bash "$CCTG" add mybot "$WORK" >/dev/null
  grep -q "CCTG_PERMISSION_MODE='acceptEdits'" "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "add: interactive mode menu Enter follows shared (no per-bot mode)" {
  printf 'tok\n555\n\n' | bash "$CCTG" add mybot "$WORK" >/dev/null
  # template default left empty (set_env_kv not invoked)
  grep -q '^CCTG_PERMISSION_MODE=$' "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "add: interactive mode menu choice 7 also follows shared" {
  printf 'tok\n555\n7\n' | bash "$CCTG" add mybot "$WORK" >/dev/null
  grep -q '^CCTG_PERMISSION_MODE=$' "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "add: interactive mode menu accepts a typed mode name" {
  printf 'tok\n555\nplan\n' | bash "$CCTG" add mybot "$WORK" >/dev/null
  grep -q "CCTG_PERMISSION_MODE='plan'" "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "add: interactive mode menu re-prompts on invalid choice then accepts a valid one" {
  # 99 (out of range) and bogus (unknown) are rejected; 2 finally selected.
  printf 'tok\n555\n99\nbogus\n2\n' | bash "$CCTG" add mybot "$WORK" >/dev/null
  grep -q "CCTG_PERMISSION_MODE='acceptEdits'" "$CC_CHANNELS_DIR/mybot/launch.env"
  grep -qE '^mybot \|' "$REGISTRY"
}

@test "add: invalid interactive id writes nothing — no half-state (DEC-003)" {
  run bash -c "printf 'tok\nabc\n' | bash '$CCTG' add mybot '$WORK'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a numeric ID"* ]]
  # validate-before-write: the state dir was never created
  [ ! -e "$CC_CHANNELS_DIR/mybot" ]
  ! { [ -f "$REGISTRY" ] && grep -qE "^mybot \|" "$REGISTRY"; }
}

@test "add: empty interactive token writes nothing — no half-state (DEC-003)" {
  run bash -c "printf '\n' | bash '$CCTG' add mybot '$WORK'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"token is empty"* ]]
  [ ! -e "$CC_CHANNELS_DIR/mybot" ]
}

@test "add: .env written atomically via write_token_env — content, 600, no temp residue" {
  BOT_TOKEN="atomictok" run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 1
  [ "$status" -eq 0 ]
  grep -q "^TELEGRAM_BOT_TOKEN='atomictok'\$" "$CC_CHANNELS_DIR/mybot/.env"
  [ "$(file_mode "$CC_CHANNELS_DIR/mybot/.env")" = "600" ]
  # the mktemp staging file must have been mv'd into place (no .env.* residue)
  run bash -c 'ls "$CC_CHANNELS_DIR/mybot"/.env.* 2>/dev/null'
  [ -z "$output" ]
}

@test "add: a failed attempt leaves no foreign-statedir dead-end — retry succeeds (DEC-004)" {
  # First attempt dies on a bad id (after token), creating no state dir.
  run bash -c "printf 'tok\nabc\n' | bash '$CCTG' add mybot '$WORK'"
  [ "$status" -ne 0 ]
  [ ! -e "$CC_CHANNELS_DIR/mybot" ]
  # Retry with the same name now registers cleanly (no ERR_FOREIGN_STATEDIR).
  printf 'tok\n555\n1\n' | bash "$CCTG" add mybot "$WORK" >/dev/null
  grep -qE '^mybot \|' "$REGISTRY"
  [ -f "$CC_CHANNELS_DIR/mybot/launch.env" ]
}
