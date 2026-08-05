#!/usr/bin/env bash
#
# Auto-commit + push hook.
#
# Invoked by the Claude Code "Stop" hook after an agent finishes making
# changes. Stages ONLY the known project paths (see ALLOWED_PATHS below),
# commits, and pushes the current branch to origin. Safe to run when there
# is nothing to commit (it just exits).
#
# Staging is restricted so a stray/unexpected top-level directory is never
# swept into the repo. To track a new area, add it to ALLOWED_PATHS.
#
# It NEVER commits on a detached HEAD, and it will not force-push.

set -euo pipefail

# Paths this hook is allowed to stage. Anything outside these is left alone.
ALLOWED_PATHS=(
  backend
  frontend
  .claude
  README.md
  .gitignore
)

# Resolve the repo root so the hook works regardless of the agent's CWD.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "auto-commit: not inside a git repo, skipping." >&2
  exit 0
fi
cd "${REPO_ROOT}"

# Bail on detached HEAD — we don't want to strand commits.
BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
if [[ -z "${BRANCH}" ]]; then
  echo "auto-commit: detached HEAD, skipping." >&2
  exit 0
fi

# Stage only the allowed paths that actually exist.
STAGE_PATHS=()
for p in "${ALLOWED_PATHS[@]}"; do
  [[ -e "${p}" ]] && STAGE_PATHS+=("${p}")
done
git add -A -- "${STAGE_PATHS[@]}"

# Nothing staged after restricting to allowed paths? Done.
if git diff --cached --quiet; then
  echo "auto-commit: no changes in tracked project paths, nothing to commit."
  exit 0
fi

# Build a short summary of what changed for the commit message.
SUMMARY="$(git diff --cached --stat | tail -1 | sed 's/^ *//')"
STAMP="$(date '+%Y-%m-%d %H:%M:%S')"

git commit -q -m "chore: auto-commit (${STAMP})" \
  -m "${SUMMARY}" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"

echo "auto-commit: committed on ${BRANCH}."

# Push. If the branch has no upstream yet, set it. Never force.
#
# If the push is rejected because origin moved ahead (another machine or
# worktree pushed first), pull with --rebase and retry once. This keeps
# changes from getting stranded when several agents/machines share a branch.
push_branch() {
  if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    git push --quiet origin "${BRANCH}"
  else
    git push --quiet -u origin "${BRANCH}"
  fi
}

if push_branch; then
  echo "auto-commit: pushed ${BRANCH} to origin."
else
  echo "auto-commit: push rejected, rebasing on origin/${BRANCH} and retrying..." >&2
  git fetch --quiet origin "${BRANCH}" || true
  if git rebase --quiet "origin/${BRANCH}"; then
    if push_branch; then
      echo "auto-commit: pushed ${BRANCH} to origin after rebase."
    else
      echo "auto-commit: push still failing after rebase. Resolve manually." >&2
      exit 1
    fi
  else
    # Conflict during rebase — don't leave the tree half-rebased.
    git rebase --abort || true
    echo "auto-commit: rebase conflict on ${BRANCH}. Resolve manually, then push." >&2
    exit 1
  fi
fi
