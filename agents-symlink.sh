#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
TARGET="repo-utils/AGENTS.md"

rm -f "$REPO_ROOT/AGENTS.md"
ln -s "$TARGET" "$REPO_ROOT/AGENTS.md"

echo "Created: $REPO_ROOT/AGENTS.md -> $TARGET"
