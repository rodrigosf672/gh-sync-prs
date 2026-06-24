#!/usr/bin/env bash
#
# Shared helpers for Tier 3 (sync.bats).
#
# These stand up a throwaway, network-free world for the real sync path:
#
#   ORIGIN  a bare repo that plays the GitHub remote
#   SEED    a clone used only to advance branches "server-side" (other people's
#           pushes, base-branch movement, conflicting changes)
#   REPO    the user's working clone that the script actually runs in
#
# A PR is "registered" by appending a JSON object to the same fixture the gh
# stub already replays, so the script's own --jq query still does the selecting.
# Everything is local on-disk git; no gh, no network, no auth.

# Stand up ORIGIN + SEED + REPO with a single commit on main, and reset the
# per-test PR registry. Leaves REPO checked out on main.
setup_repo() {
  STUBS="$BATS_TEST_DIRNAME/stubs"
  SCRIPT="$BATS_TEST_DIRNAME/../gh-sync-prs"
  PATH="$STUBS:$PATH"
  export PATH

  # Make every git call deterministic and non-interactive regardless of the
  # host's global config (merge commits must not try to open an editor, and a
  # committer identity must always be available inside the script's subshell).
  export GIT_MERGE_AUTOEDIT=no
  export GIT_EDITOR=true
  export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.com"

  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  SEED="$BATS_TEST_TMPDIR/seed"
  REPO="$BATS_TEST_TMPDIR/work"

  git init -q --bare "$ORIGIN"

  git init -q -b main "$SEED"
  git -C "$SEED" remote add origin "$ORIGIN"
  printf 'base\n' >"$SEED/file.txt"
  git -C "$SEED" add file.txt
  git -C "$SEED" commit -q -m "init"
  git -C "$SEED" push -q origin main

  git clone -q "$ORIGIN" "$REPO"

  PR_COUNTER=100
  PR_ENTRIES=""
  FIXTURE="$BATS_TEST_TMPDIR/fixture.json"
  write_fixture
}

# The file a branch uniquely owns. Each branch only ever edits its own file, so
# a clean base-branch advance never collides with it and a conflicting advance
# can target exactly one branch.
branch_file() { printf '%s.txt' "${1//\//_}"; }

# make_pr_branch <branch> [conclusion]
# Create <branch> off origin/main with one commit on its own file, push it, and
# register a PR for it. Default CI conclusion is FAILURE so the default
# --failed mode would select it too. Prints the assigned PR number.
make_pr_branch() {
  local branch="$1" conclusion="${2:-FAILURE}"
  local file number entry
  PR_COUNTER=$((PR_COUNTER + 1))
  number="$PR_COUNTER"
  file="$(branch_file "$branch")"

  git -C "$SEED" fetch -q origin
  git -C "$SEED" checkout -q -B "$branch" origin/main
  printf 'branch:%s\n' "$branch" >"$SEED/$file"
  git -C "$SEED" add "$file"
  git -C "$SEED" commit -q -m "work on $branch"
  git -C "$SEED" push -q -u origin "$branch"

  entry="$(printf '{"number":%d,"title":"%s","headRefName":"%s","statusCheckRollup":[{"conclusion":"%s"}]}' \
    "$number" "$branch" "$branch" "$conclusion")"
  if [[ -n "$PR_ENTRIES" ]]; then
    PR_ENTRIES="$PR_ENTRIES,$entry"
  else
    PR_ENTRIES="$entry"
  fi
  write_fixture

  printf '%s' "$number"
}

# Advance origin/main with a commit that touches no PR branch's file, so every
# registered PR can merge it cleanly.
advance_main_clean() {
  git -C "$SEED" fetch -q origin
  git -C "$SEED" checkout -q -B main origin/main
  printf 'extra\n' >"$SEED/main-extra.txt"
  git -C "$SEED" add main-extra.txt
  git -C "$SEED" commit -q -m "advance main"
  git -C "$SEED" push -q origin main
}

# add_conflicting_commit <branch>
# Advance origin/main with a divergent change to <branch>'s own file, so that
# merging origin/main into <branch> is guaranteed to conflict (add/add).
add_conflicting_commit() {
  local branch="$1" file
  file="$(branch_file "$branch")"
  git -C "$SEED" fetch -q origin
  git -C "$SEED" checkout -q -B main origin/main
  printf 'main:conflict\n' >"$SEED/$file"
  git -C "$SEED" add "$file"
  git -C "$SEED" commit -q -m "conflicting change on main for $branch"
  git -C "$SEED" push -q origin main
}

# make_worktree <branch>
# Register a worktree for <branch> in REPO (tracking origin/<branch>) so the
# script discovers and operates inside it. Prints the worktree path exactly as
# git records it (canonicalized) — which is what the script's own
# `git worktree list` discovery prints, so callers can match it against output.
make_worktree() {
  local branch="$1" target
  target="$BATS_TEST_TMPDIR/wt-${branch//\//_}"
  git -C "$REPO" fetch -q origin
  git -C "$REPO" worktree add -q --track -b "$branch" "$target" "origin/$branch"
  git -C "$REPO" worktree list --porcelain |
    awk -v b="refs/heads/$branch" '$1 == "worktree" { p = $2 } $1 == "branch" && $2 == b { print p }'
}

# Serialize the registered PRs to the fixture the gh stub replays.
write_fixture() {
  printf '[%s]\n' "$PR_ENTRIES" >"$FIXTURE"
  export GH_STUB_PRLIST_FIXTURE="$FIXTURE"
}
