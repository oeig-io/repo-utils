#!/usr/bin/env bash
#
# install.sh - Deploy git-shortcuts-tool into the current user's shell rc.
#
# This is the standard install procedure for git-shortcuts-tool. It idempotently
# appends a fenced `source` block to the target rc file so the gs/gd/gp shortcuts
# become available in every new interactive shell.
#
# Usage:
#   ./install.sh                 # default: append to ~/.bashrc
#   ./install.sh ~/.zshrc        # target a different rc file
#
# Re-running is safe: if the fenced block is already present, the file is left
# unchanged.
#
# Tags: #git #repo-management

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
UTILITIES="${SCRIPT_DIR}/git-utilities.sh"

RC_FILE="${1:-$HOME/.bashrc}"

if [[ ! -f "$UTILITIES" ]]; then
  echo "Error: git-utilities.sh not found next to this installer: $UTILITIES" >&2
  exit 1
fi

if [[ ! -f "$RC_FILE" ]]; then
  echo "Error: target rc file does not exist: $RC_FILE" >&2
  echo "Create it first (e.g. touch \"$RC_FILE\") or pass an existing rc file." >&2
  exit 1
fi

BEGIN_MARKER="# >>> git-shortcuts-tool >>>"
END_MARKER="# <<< git-shortcuts-tool <<<"

# Idempotency: skip if the block is already present.
if grep -Fxq "$BEGIN_MARKER" "$RC_FILE"; then
  echo "git-shortcuts-tool already installed in $RC_FILE — nothing to do."
  exit 0
fi

{
  printf '\n%s\n' "$BEGIN_MARKER"
  printf 'source "%s"\n' "$UTILITIES"
  printf '%s\n' "$END_MARKER"
} >> "$RC_FILE"

echo "Installed git-shortcuts-tool into $RC_FILE"
echo "Start a new shell or run:  source \"$RC_FILE\""