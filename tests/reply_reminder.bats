#!/usr/bin/env bats
# Channel reply-reminder (v0.7.0/001-channel-reply-hook).
#
# CCTG seeds a plain-text reminder ($CC_CHANNELS_DIR/cctg-reply-reminder.txt) and
# injects its contents into every bot via `claude --append-system-prompt` so the
# bot is told to answer through the channel reply tool (quote-reply). It is ON by
# default, edited by changing the file, and disabled by EMPTYING the file (an
# emptied file is preserved and skips injection; deleting it re-seeds on next up).
# The `--settings hooks` route was rejected (DEC-002): hooks merge vs replace is
# undocumented and could clobber the user's global git-guard hook in bot sessions.

load test_helper

REMINDER() { printf '%s' "$CC_CHANNELS_DIR/cctg-reply-reminder.txt"; }

@test "up: seeds the reply-reminder file with default text when absent" {
  seed_bot mybot
  rm -f "$(REMINDER)"      # add already seeded it; remove to verify up re-seeds when absent
  run cctg up mybot
  [ "$status" -eq 0 ]
  [ -s "$(REMINDER)" ]
  grep -qi 'reply' "$(REMINDER)"
}

@test "up: launch wires --append-system-prompt from the reply-reminder file" {
  seed_bot mybot
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/lastcmd"
  run cctg up mybot
  [ "$status" -eq 0 ]
  grep -q -- '--append-system-prompt' "$FAKE_TMUX_LASTCMD"
  grep -q 'cctg-reply-reminder.txt' "$FAKE_TMUX_LASTCMD"
  # injection is guarded by a non-empty test so an emptied file skips it at runtime
  grep -q -- '-s ' "$FAKE_TMUX_LASTCMD"
}

@test "up: a customized reply-reminder is preserved (not overwritten)" {
  seed_bot mybot
  mkdir -p "$CC_CHANNELS_DIR"
  printf 'CUSTOM REMINDER TEXT\n' > "$(REMINDER)"
  run cctg up mybot
  [ "$status" -eq 0 ]
  grep -qxF 'CUSTOM REMINDER TEXT' "$(REMINDER)"
}

@test "up: an emptied reply-reminder is preserved (opt-out) and not re-seeded" {
  seed_bot mybot
  mkdir -p "$CC_CHANNELS_DIR"
  : > "$(REMINDER)"            # opt-out: empty, do not delete
  run cctg up mybot
  [ "$status" -eq 0 ]
  [ -e "$(REMINDER)" ]
  [ ! -s "$(REMINDER)" ]       # still empty — was not re-seeded
}

@test "add: seeds the reply-reminder and prints the ON notice" {
  run env BOT_TOKEN=tok bash "$CCTG" add mybot "$WORK" --token-env BOT_TOKEN --id 555
  [ "$status" -eq 0 ]
  [ -s "$(REMINDER)" ]
  [[ "$output" == *"reply-reminder: ON"* ]]
}

@test "doctor: reports reply-reminder ON when seeded" {
  seed_bot mybot >/dev/null
  cctg up mybot >/dev/null
  run cctg doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Reply-reminder: ON"* ]]
}

@test "doctor: reports reply-reminder OFF when emptied" {
  seed_bot mybot >/dev/null
  cctg up mybot >/dev/null
  : > "$(REMINDER)"
  run cctg doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Reply-reminder: OFF"* ]]
}

# Behavioral contract: extract the REAL generated conditional from the launch
# string and eval it, proving a non-empty file yields the flag (single argv even
# with spaces/newlines) and an empty file yields no flag. This guards the runtime
# semantics that the static wiring grep above cannot.
@test "reply-reminder: launch conditional injects on non-empty, skips on empty" {
  seed_bot mybot
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/lastcmd"
  cctg up mybot >/dev/null
  # the launch is the single bash -lc argument; pull the reminder conditional out
  local launch cond
  launch="$(tr '\n' ' ' < "$FAKE_TMUX_LASTCMD")"
  cond="$(printf '%s' "$launch" | grep -oE '\{ \[ -s [^}]*set -- *; \}')"
  [ -n "$cond" ]

  # non-empty reminder → flag + content as one argv
  printf 'Line one.\nLine two.\n' > "$(REMINDER)"
  set --
  eval "$cond"
  [ "$#" -eq 2 ]
  [ "$1" = "--append-system-prompt" ]
  [ "$2" = "$(printf 'Line one.\nLine two.')" ]

  # emptied reminder → no flag
  : > "$(REMINDER)"
  set -- sentinel
  eval "$cond"
  [ "$#" -eq 0 ]
}
