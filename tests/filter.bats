#!/usr/bin/env bats
#
# Tier 2: PR discovery + the failing-CI filter, exercised end-to-end through
# the real script with --dry-run (so no branches are touched).
#
# A `gh` stub replays a fixture through the script's own --jq expression, so
# these tests pin down exactly which PRs the query selects. A throwaway repo
# with a real `origin` lets the script's top-level `git fetch origin` succeed.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../gh-sync-prs"
  STUBS="$BATS_TEST_DIRNAME/stubs"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"

  PATH="$STUBS:$PATH"
  export PATH
  export GH_STUB_PRLIST_FIXTURE="$FIXTURES/pr-list-mixed.json"

  REPO="$BATS_TEST_TMPDIR/work"
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  git init -q --bare "$ORIGIN"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.email test@example.com
  git -C "$REPO" config user.name "Test"
  git -C "$REPO" commit -q --allow-empty -m "init"
  git -C "$REPO" remote add origin "$ORIGIN"
  git -C "$REPO" push -q origin main
}

@test "default (--failed) selects only red and red+pending PRs" {
  cd "$REPO"
  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode: failed"* ]]

  # Selected: a failed check, or a failed check alongside a pending one.
  [[ "$output" == *"=== PR #102: feature/red ==="* ]]
  [[ "$output" == *"=== PR #104: feature/red-pending ==="* ]]

  # Skipped: green, pending, no-checks, pending status context.
  [[ "$output" != *"feature/green"* ]]
  [[ "$output" != *"feature/pending"* ]]
  [[ "$output" != *"feature/no-checks"* ]]
  [[ "$output" != *"feature/status-pending"* ]]
}

@test "--all selects every open PR regardless of CI state" {
  cd "$REPO"
  run "$SCRIPT" --all --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode: all"* ]]

  [[ "$output" == *"feature/green"* ]]
  [[ "$output" == *"feature/red"* ]]
  [[ "$output" == *"feature/pending"* ]]
  [[ "$output" == *"feature/red-pending"* ]]
  [[ "$output" == *"feature/no-checks"* ]]
  [[ "$output" == *"feature/status-pending"* ]]
}

@test "summary counters survive the loop (process-substitution fix)" {
  # If the loop ran in a pipeline subshell, these would all read 0.
  cd "$REPO"
  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated: 0"* ]]
  [[ "$output" == *"Failed: 0"* ]]
  [[ "$output" == *"Skipped: 2"* ]]
}

@test "--all counts every PR as skipped under --dry-run" {
  cd "$REPO"
  run "$SCRIPT" --all --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipped: 6"* ]]
}

@test "--author is reflected in the run header" {
  cd "$REPO"
  run "$SCRIPT" --author octocat --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Author: octocat"* ]]
}

@test "--base changes the base branch that gets merged" {
  cd "$REPO"
  run "$SCRIPT" --base develop --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Base: origin/develop"* ]]
}

@test "skips PRs without a worktree when not already on that branch" {
  cd "$REPO"
  run "$SCRIPT" --all
  [ "$status" -eq 0 ]
  [ "$(git -C "$REPO" branch --show-current)" = "main" ]
  [[ "$output" == *"skipping"* ]]
  [[ "$output" == *"Skipped: 6"* ]]
}

@test "does not switch the active branch when no worktree exists" {
  cd "$REPO"
  run "$SCRIPT" --all
  [ "$status" -eq 0 ]
  [ "$(git -C "$REPO" branch --show-current)" = "main" ]
}
