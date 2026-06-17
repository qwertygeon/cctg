#!/usr/bin/env bats
# Static / source-level assertions — no runtime behaviour. Covers descriptor
# registration, telegram-hardcoding removal, completion dynamism, and shell
# syntax checks. Each test greps a checked-in source file under $REPO_ROOT.

load test_helper

# --- descriptor source presence (SC-001/002) ---

@test "channels.sh: IMPLEMENTED_CHANNELS includes discord (SC-001)" {
  grep -qE '^IMPLEMENTED_CHANNELS=.*discord' "$REPO_ROOT/lib/channels.sh"
}

@test "channels.sh: discord descriptor arms are active, not commented (SC-002)" {
  local f="$REPO_ROOT/lib/channels.sh"
  # Active case arms (line must not start with '#').
  grep -qE '^[[:space:]]*discord:plugin\)' "$f"
  grep -qE '^[[:space:]]*discord:statedir_env\)' "$f"
  grep -qE '^[[:space:]]*discord:token_key\)' "$f"
  grep -qE '^[[:space:]]*discord:token_required\)' "$f"
}

# --- telegram-hardcoding removal in message catalogs (SC-012/013/014/015) ---
# Helper: extract the value of CCTG_MSG_<key> from a catalog file.
msg_val() { grep -E "^CCTG_MSG_$2=" "$1" | head -n1; }

@test "messages: ADD_PROMPT_TGID has no telegram-specific string (SC-012)" {
  local k v
  for k in en ko; do
    v="$(msg_val "$REPO_ROOT/messages/$k.sh" ADD_PROMPT_TGID)"
    [ -n "$v" ]
    [[ "$v" != *"Telegram"* ]]
    [[ "$v" != *"@userinfobot"* ]]
  done
}

@test "messages: STATUS_GLOBAL has no /telegram hardcoding (SC-013)" {
  local k v
  for k in en ko; do
    v="$(msg_val "$REPO_ROOT/messages/$k.sh" STATUS_GLOBAL)"
    [ -n "$v" ]
    [[ "$v" != *"/telegram"* ]]
  done
}

@test "messages: STATUS_HINT_NO_TOKEN has no TELEGRAM_BOT_TOKEN hardcoding (SC-014)" {
  local k v
  for k in en ko; do
    v="$(msg_val "$REPO_ROOT/messages/$k.sh" STATUS_HINT_NO_TOKEN)"
    [ -n "$v" ]
    [[ "$v" != *"TELEGRAM_BOT_TOKEN"* ]]
  done
}

@test "messages: DOCTOR_PLUGIN_HINT has no telegram-specific install path (SC-015)" {
  local k v
  for k in en ko; do
    v="$(msg_val "$REPO_ROOT/messages/$k.sh" DOCTOR_PLUGIN_HINT)"
    [ -n "$v" ]
    [[ "$v" != *"telegram@claude-plugins-official"* ]]
    [[ "$v" != *"telegram 플러그인"* ]]
  done
}

# --- completions: dynamic --channel + --group candidate (SC-016/017/029) ---

@test "completions/_cctg: --channel is not a bare telegram literal (SC-016)" {
  local f="$REPO_ROOT/completions/_cctg"
  # The --channel arm must reference a channel list variable, not 'compadd -- telegram' alone.
  ! grep -qE '^[[:space:]]*--channel\)[[:space:]]*compadd[[:space:]]+--[[:space:]]+telegram[[:space:]]*;;' "$f"
  grep -qE '^[[:space:]]*--channel\)' "$f"
}

@test "completions/cctg.bash: --channel is not a bare telegram literal (SC-017)" {
  local f="$REPO_ROOT/completions/cctg.bash"
  ! grep -qE -- '--channel\).*compgen -W "telegram"' "$f"
  grep -qE -- '--channel\)' "$f"
}

@test "completions: add flag candidates include --group (SC-029)" {
  grep -q -- '--group' "$REPO_ROOT/completions/_cctg"
  grep -q -- '--group' "$REPO_ROOT/completions/cctg.bash"
}

# --- shell syntax checks (SC-021) ---
# lib/commands.sh uses process substitution (`done < <(...)`), present since the
# baseline and unrelated to this change, which `bash --posix -n` cannot parse.
# Per GAP-002 it is checked with plain `bash -n`; the --posix check targets the
# other modified files.

@test "syntax: posix -n passes for channels.sh/en.sh/ko.sh/cctg.bash (SC-021)" {
  local f
  for f in lib/channels.sh messages/en.sh messages/ko.sh completions/cctg.bash; do
    run bash --norc --noprofile --posix -n "$REPO_ROOT/$f"
    [ "$status" -eq 0 ]
  done
}

@test "syntax: bash -n passes for commands.sh (SC-021, GAP-002 non-posix)" {
  run bash -n "$REPO_ROOT/lib/commands.sh"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# SC-007/008/009/012/013/022/023 (v0.5.0/001-cli-convenience-patches)
# ---------------------------------------------------------------------------

# SC-007: zsh completion offers all 6 permission modes for "config <name> mode"
@test "completions/_cctg: config mode offers 6 modes (SC-007)" {
  local f="$REPO_ROOT/completions/_cctg"
  grep -q 'acceptEdits' "$f"
  grep -q 'bypassPermissions' "$f"
  grep -q 'dontAsk' "$f"
  grep -q 'plan' "$f"
  # All six must appear together in the mode completion section; count them.
  local count
  count=$(grep -oE 'acceptEdits|auto|bypassPermissions|default|dontAsk|plan' "$f" | sort -u | wc -l | tr -d ' ')
  [ "$count" -ge 6 ]
}

# SC-008: bash completion offers all 6 permission modes for "config <name> mode"
@test "completions/cctg.bash: config mode offers 6 modes (SC-008)" {
  local f="$REPO_ROOT/completions/cctg.bash"
  local count
  count=$(grep -oE 'acceptEdits|auto|bypassPermissions|default|dontAsk|plan' "$f" | sort -u | wc -l | tr -d ' ')
  [ "$count" -ge 6 ]
}

# SC-009: both completion files include cwd and token in the config action list
@test "completions: config actions include cwd and token (SC-009)" {
  grep -q 'cwd' "$REPO_ROOT/completions/_cctg"
  grep -q 'token' "$REPO_ROOT/completions/_cctg"
  grep -q 'cwd' "$REPO_ROOT/completions/cctg.bash"
  grep -q 'token' "$REPO_ROOT/completions/cctg.bash"
}

# SC-012: both completion files include --help in subcommand flag candidates
@test "completions: subcommand flags include --help (SC-012)" {
  grep -q -- '--help' "$REPO_ROOT/completions/_cctg"
  grep -q -- '--help' "$REPO_ROOT/completions/cctg.bash"
}

# SC-013: en.sh / ko.sh key parity (check-i18n-keys.sh exits 0)
@test "i18n: en/ko key parity (SC-013)" {
  run bash "$REPO_ROOT/scripts/check-i18n-keys.sh"
  [ "$status" -eq 0 ]
}

# SC-022: reserved name (telegram/discord) is still blocked from add/rm/rename
@test "reserved: add telegram still rejected (SC-022)" {
  run cctg add telegram "$WORK" --id 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"reserved"* ]]
}

@test "reserved: add discord still rejected (SC-022 discord)" {
  run cctg add discord "$WORK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"reserved"* ]]
}

# SC-023: no Bash 4+ associative arrays in new source files
@test "syntax: no associative arrays / Bash4+ in new code (SC-023)" {
  local f
  for f in lib/commands.sh lib/session.sh lib/registry.sh lib/util.sh cc-tg.sh; do
    # declare -A is the canonical Bash 4+ associative array declaration.
    run grep -c 'declare -A' "$REPO_ROOT/$f"
    # Exit code 1 from grep means no matches — that is what we want.
    [ "$status" -ne 0 ] || [ "$output" = "0" ]
  done
}

@test "syntax: posix -n passes for new lib files (SC-023)" {
  local f
  for f in lib/registry.sh lib/session.sh lib/util.sh messages/en.sh messages/ko.sh; do
    run bash --norc --noprofile --posix -n "$REPO_ROOT/$f"
    [ "$status" -eq 0 ]
  done
}

@test "syntax: bash -n passes for commands.sh after v0.5.0 changes (SC-023)" {
  run bash -n "$REPO_ROOT/lib/commands.sh"
  [ "$status" -eq 0 ]
}

@test "syntax: bash -n passes for cc-tg.sh after v0.5.0 changes (SC-023)" {
  run bash -n "$REPO_ROOT/cc-tg.sh"
  [ "$status" -eq 0 ]
}
