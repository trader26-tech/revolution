#!/usr/bin/env bash
#
# Multi-agent worktree manager.
#
# Gives each AI agent an isolated git worktree + branch so agents can work
# in parallel without clobbering each other's files. Branches merge back to
# main via pull requests.
#
# Usage:
#   scripts/agent-worktree.sh new  <agent-name> [base-branch]   # create
#   scripts/agent-worktree.sh list                              # list all
#   scripts/agent-worktree.sh pr   <agent-name> [title]         # open a PR
#   scripts/agent-worktree.sh rm   <agent-name>                 # remove
#
# Worktrees live in ../revolution-worktrees/<agent-name> so they sit beside
# (not inside) the main checkout.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
WT_DIR="$(dirname "${REPO_ROOT}")/revolution-worktrees"
cmd="${1:-}"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

case "${cmd}" in
  new)
    agent="${2:?agent name required}"
    base="${3:-main}"
    branch="agent/${agent}"
    path="${WT_DIR}/${agent}"

    git fetch --quiet origin "${base}" || true
    mkdir -p "${WT_DIR}"

    if git show-ref --quiet "refs/heads/${branch}"; then
      git worktree add "${path}" "${branch}"
    else
      git worktree add -b "${branch}" "${path}" "origin/${base}" 2>/dev/null \
        || git worktree add -b "${branch}" "${path}" "${base}"
    fi
    echo "Created worktree for '${agent}':"
    echo "  branch: ${branch}"
    echo "  path:   ${path}"
    echo "Point the agent's working directory at that path."
    ;;

  list)
    git worktree list
    ;;

  pr)
    agent="${2:?agent name required}"
    branch="agent/${agent}"
    title="${3:-Work from agent ${agent}}"
    git push -u origin "${branch}"
    if command -v gh >/dev/null 2>&1; then
      gh pr create --base main --head "${branch}" \
        --title "${title}" --body "Automated PR for agent \`${agent}\`." \
        --fill 2>&1 || gh pr view "${branch}" --web
    else
      echo "gh CLI not found. Branch pushed; open a PR manually for ${branch}."
    fi
    ;;

  rm)
    agent="${2:?agent name required}"
    path="${WT_DIR}/${agent}"
    git worktree remove "${path}" --force
    echo "Removed worktree ${path} (branch agent/${agent} kept)."
    ;;

  *)
    usage
    ;;
esac
