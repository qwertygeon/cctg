#!/usr/bin/env bats
# SC-010/011: subcommand --help flag prints usage and exits 0.
# (v0.5.0/001-cli-convenience-patches, FR-005)

load test_helper

@test "add --help: prints usage, exit 0 (SC-010)" {
  run cctg add --help
  [ "$status" -eq 0 ]
  # Must print something containing a usage token for the add subcommand.
  # The exact wording comes from USAGE_ADD in messages/en.sh; we check for
  # common tokens that any add-usage string should include.
  [[ "$output" == *"add"* ]]
}

@test "config --help: prints usage, exit 0 (SC-011)" {
  run cctg config --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"config"* ]]
}

@test "up --help: prints usage, exit 0 (SC-010 family)" {
  run cctg up --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"up"* ]]
}

@test "down --help: prints usage, exit 0 (SC-010 family)" {
  run cctg down --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"down"* ]]
}
