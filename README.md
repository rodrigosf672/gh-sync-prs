# gh-sync-prs

<p align="center">
  <img width="1536" alt="gh-sync-prs" src="https://github.com/user-attachments/assets/dbf276f7-df59-4a00-a8a6-a63aaaf15e82">
</p>

A GitHub CLI extension that keeps your open pull requests up to date by automatically merging the latest changes from both the remote branch and the base branch, then pushing the result so CI can run again.

It is aware of Git worktrees, so each pull request is updated in its corresponding worktree whenever possible.

## Why?

If you regularly work across multiple pull requests, you've probably experienced this workflow:

- A pull request is merged and `main` moves on.
- One or more of your pull requests become stale or their CI starts failing.
- You switch branches (or worktrees).
- Pull.
- Merge `main`.
- Push.
- Wait for CI.
- Repeat.

The individual steps are simple, but they interrupt your flow.

Instead, install the extension once:

```bash
gh extension install rodrigosf672/gh-sync-prs
```

Then keeping your pull requests up to date is as simple as:

```bash
gh sync-prs
```

By default, only pull requests with failing CI are updated.

---

## Features

- Updates multiple pull requests with a single command.
- Git worktree aware.
- Syncs only pull requests with failing CI by default.
- Merges both the latest remote branch and the latest base branch.
- Pushes updated branches automatically.
- Supports `--dry-run`.
- Supports custom base branches.

---

## How it works

For each selected pull request, `gh-sync-prs`:

1. Finds the corresponding Git worktree, if one exists.
2. Merges the latest `origin/<branch>`.
3. Merges the latest base branch (`origin/main` by default).
4. Pushes the updated branch.

GitHub Actions (or your CI) then runs against the updated branch.

```text
For each selected pull request

        │
        ▼
Find matching worktree
        │
        ▼
Merge origin/<branch>
        │
        ▼
Merge origin/main
        │
        ▼
Push
        │
        ▼
CI runs again
```

If a merge conflict occurs, that pull request is skipped and the tool continues with the remaining pull requests.

---

## Installation

```bash
gh extension install rodrigosf672/gh-sync-prs
```

Upgrade later with:

```bash
gh extension upgrade sync-prs
```

---

## Usage

```bash
# Update pull requests with failing CI (default)
gh sync-prs

# Preview what would happen
gh sync-prs --dry-run

# Update all open pull requests
gh sync-prs --all

# Update another author's pull requests
gh sync-prs --author octocat

# Merge a different base branch
gh sync-prs --base develop
```

---

## Options

| Option | Description | Default |
|---------|-------------|---------|
| `--author <author>` | Filter pull requests by author. | `@me` |
| `--all` | Sync all open pull requests from the author. | — |
| `--failed` | Sync only pull requests with failing CI. | Default |
| `--base <branch>` | Base branch to merge into each pull request branch. | `main` |
| `--dry-run` | Preview changes without modifying branches. | Off |
| `-h`, `--help` | Show help. | — |

---

## Default behavior

Running

```bash
gh sync-prs
```

will:

- Find your open pull requests.
- Select only those with failing CI.
- Locate the corresponding Git worktree, when available.
- Merge the latest `origin/<branch>`.
- Merge the latest base branch.
- Push the updated branch.

---

## Requirements

- Git
- GitHub CLI (`gh`)
- An authenticated GitHub CLI (`gh auth login`)

Run the command from inside a Git repository.

---

## Things to know

- Uses merge commits rather than rebasing.
- Pull requests with merge conflicts are skipped so the remaining pull requests can continue processing.
- Pull requests without a corresponding worktree are skipped, unless the repository is already checked out on that branch.
- Use `--dry-run` to preview changes before modifying branches.

---

## License

MIT © Rodrigo Silva Ferreira
