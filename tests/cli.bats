#!/usr/bin/env bats
#
# Tier 1: CLI behavior. These hit the deterministic, side-effect-free parts of
# the script (argument parsing and guards). No network, no real gh, no repo.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../gh-sync-prs"
  STUBS="$BATS_TEST_DIRNAME/stubs"
}

@test "--help prints usage and exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"gh sync-prs"* ]]
}

@test "-h prints usage and exits 0" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown option prints the error, the usage, and exits 1" {
  run "$SCRIPT" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option: --bogus"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "errors out when not inside a git repository" {
  # A gh stub on PATH lets the gh presence check pass so the script reaches
  # the git-repo guard. The temp dir is not a git repository.
  PATH="$STUBS:$PATH"
  cd "$BATS_TEST_TMPDIR"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"run this from inside a git repository"* ]]
}
