# Working with multiple AI agents

This repo is set up so several AI agents (or humans) can work in parallel
without stepping on each other, and so changes are committed automatically.

## 1. Auto-commit + push

A Claude Code **Stop hook** ([.claude/settings.json](.claude/settings.json))
runs [scripts/auto-commit.sh](scripts/auto-commit.sh) after each agent turn.
It:

- stages **only known project paths** (an allow-list in the script:
  `backend/`, `frontend/`, `orbit/`, `scripts/`, `.claude/`, and the root
  docs) so stray files never get swept in — add a path there to track a new
  area,
- commits those changes on the **current branch**,
- pushes that branch to `origin`,
- does nothing on a clean tree or a detached HEAD,
- never force-pushes.

So an agent working on `agent/foo` auto-commits to `agent/foo` — never
directly onto `main` unless that is the checked-out branch.

## 2. Isolation: one worktree + branch per agent

Each agent gets its own git worktree and branch via
[scripts/agent-worktree.sh](scripts/agent-worktree.sh):

```bash
# create an isolated workspace for an agent
scripts/agent-worktree.sh new alice          # branch agent/alice
scripts/agent-worktree.sh new bob            # branch agent/bob

# see all active worktrees
scripts/agent-worktree.sh list

# when an agent's work is ready, open a PR into main
scripts/agent-worktree.sh pr alice "Add login flow"

# tear down the worktree (branch is kept)
scripts/agent-worktree.sh rm alice
```

Worktrees are created in `../revolution-worktrees/<agent>` — beside the main
checkout, so each has its own files and index. Start each agent with its
working directory set to that path.

## 3. Merge discipline

- `main` is the integration branch. Agents do **not** commit to it directly;
  they land work through PRs.
- Rebase or merge `main` into your `agent/*` branch before opening a PR to
  resolve conflicts in your own workspace.
- Keep changes scoped: backend agents touch `backend/`, frontend agents touch
  `frontend/`. Cross-cutting changes should be coordinated (see below).

## 4. Coordination conventions

- **Claim your area** in a PR description so others know what's in flight.
- **Small, frequent PRs** beat long-lived branches — less conflict surface.
- **Shared files** (`README.md`, `package.json`, config) are the usual
  conflict hot-spots; edit them in isolation and merge quickly.

## 5. Secrets

Never commit real credentials. `.env` and `*.local` are git-ignored; only
`.env.example` and placeholder config are tracked.
