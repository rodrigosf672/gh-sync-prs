#!/usr/bin/env bats
#
# Tier 3: the real sync path. Each test stands up a throwaway bare origin and a
# working clone, registers fake PRs, and runs the script WITHOUT --dry-run, so
# the actual fetch -> checkout -> merge -> push pipeline executes against local
# repos. Helpers live in tests/helpers.bash.
#
# Between them these cover every exit path through the loop body: UPDATED++
# (worktree and current-branch), FAILED++ (merge conflict), and SKIPPED++ (no
# worktree on a different branch).

load 'helpers'

setup() {
  setup_repo
}

@test "worktree PR: merges base branch, pushes, counts UPDATED" {
  make_pr_branch feature/wt >/dev/null
  wt="$(make_worktree feature/wt)"
  advance_main_clean

  cd "$REPO"
  run "$SCRIPT" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Worktree: $wt"* ]]
  [[ "$output" == *"Updated: 1"* ]]
  [[ "$output" == *"Failed: 0"* ]]
  [[ "$output" == *"Skipped: 0"* ]]

  # The base-branch advance landed in the worktree and was pushed to origin.
  [ -f "$wt/main-extra.txt" ]
  git -C "$REPO" fetch -q origin
  git -C "$REPO" merge-base --is-ancestor origin/main origin/feature/wt
}

# When the PR's branch is the branch the main clone is already on, git lists the
# main working tree as that branch's worktree, so the script operates in place
# and updates it rather than skipping.
@test "PR branch is the repo's checked-out branch: merges, pushes, UPDATED" {
  make_pr_branch feature/cur >/dev/null
  advance_main_clean

  git -C "$REPO" fetch -q origin
  git -C "$REPO" checkout -q --track -b feature/cur origin/feature/cur

  cd "$REPO"
  run "$SCRIPT" --all
  [ "$status" -eq 0 ]
  [[ "$output" != *"skipping"* ]]
  [[ "$output" == *"Updated: 1"* ]]
  [[ "$output" == *"Skipped: 0"* ]]
  [ -f "$REPO/main-extra.txt" ]
}

@test "no worktree and on a different branch: skips, never switches branch" {
  make_pr_branch feature/orphan >/dev/null

  cd "$REPO"
  run "$SCRIPT" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
  [[ "$output" == *"Updated: 0"* ]]
  [[ "$output" == *"Skipped: 1"* ]]
  [ "$(git -C "$REPO" branch --show-current)" = "main" ]
}

@test "merge conflict is caught: FAILED, message printed, run continues" {
  make_pr_branch feature/conflict >/dev/null
  make_pr_branch feature/ok >/dev/null
  wt_conflict="$(make_worktree feature/conflict)"
  make_worktree feature/ok >/dev/null
  add_conflicting_commit feature/conflict

  cd "$REPO"
  run "$SCRIPT" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to update feature/conflict."* ]]
  [[ "$output" == *"$wt_conflict"* ]]
  [[ "$output" == *"Continuing with the next PR..."* ]]

  # feature/ok is processed after the conflict, proving the run did not abort.
  [[ "$output" == *"Updated: 1"* ]]
  [[ "$output" == *"Failed: 1"* ]]
}

@test "mixed batch: one updated, one failed, one skipped" {
  make_pr_branch feature/conflict >/dev/null
  make_pr_branch feature/ok >/dev/null
  make_pr_branch feature/orphan >/dev/null
  make_worktree feature/conflict >/dev/null
  make_worktree feature/ok >/dev/null
  # feature/orphan deliberately gets no worktree; REPO stays on main.
  add_conflicting_commit feature/conflict

  cd "$REPO"
  run "$SCRIPT" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated: 1"* ]]
  [[ "$output" == *"Failed: 1"* ]]
  [[ "$output" == *"Skipped: 1"* ]]
  [ "$(git -C "$REPO" branch --show-current)" = "main" ]
}

@test "worktree isolation: main clone's branch and tree are untouched" {
  make_pr_branch feature/iso >/dev/null
  wt="$(make_worktree feature/iso)"
  advance_main_clean
  before="$(git -C "$REPO" rev-parse main)"

  cd "$REPO"
  run "$SCRIPT" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated: 1"* ]]

  # The merge landed in the worktree...
  [ -f "$wt/main-extra.txt" ]
  # ...but the main clone never switched branches, moved main, or got dirtied.
  [ "$(git -C "$REPO" branch --show-current)" = "main" ]
  [ "$(git -C "$REPO" rev-parse main)" = "$before" ]
  [ -z "$(git -C "$REPO" status --porcelain)" ]
  [ ! -f "$REPO/main-extra.txt" ]
}
