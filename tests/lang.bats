#!/usr/bin/env bats
# `cctg lang` — output-language preference (env > config > locale > en).

load test_helper

@test "lang show: reports the env override when CCTG_LANG is set" {
  CCTG_LANG=en run cctg lang show
  [ "$status" -eq 0 ]
  [[ "$output" == *"Current language: en (source: env)"* ]]
}

@test "lang ko: persists the choice to the config file" {
  unset CCTG_LANG
  run cctg lang ko
  [ "$status" -eq 0 ]
  [[ "$output" == *"Language set: ko"* ]]
  grep -q '^lang=ko' "$XDG_CONFIG_HOME/cctg/config"
}

@test "lang show: reads the persisted config when no env override" {
  unset CCTG_LANG
  cctg lang ko >/dev/null
  # No env override → detection falls to the persisted config. The displayed
  # text is in the selected language (ko), but the source token is not
  # translated, so assert on it language-independently.
  run env -u CCTG_LANG bash "$CCTG" lang show
  [ "$status" -eq 0 ]
  [[ "$output" == *"config"* ]]
  [[ "$output" == *"ko"* ]]
}

@test "lang clear: removes the persisted preference" {
  unset CCTG_LANG
  cctg lang ko >/dev/null
  run cctg lang clear
  [ "$status" -eq 0 ]
  [[ "$output" == *"cleared"* ]]
  ! grep -q '^lang=' "$XDG_CONFIG_HOME/cctg/config" 2>/dev/null
}

@test "lang: rejects an unsupported language" {
  run cctg lang fr
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported language"* ]]
}
