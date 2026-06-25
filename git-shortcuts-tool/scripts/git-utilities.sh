#!/usr/bin/env bash
#
# git-utilities.sh - OEIG git shortcut aliases and functions.
#
# Source this file from your shell rc (e.g. ~/.bashrc) to get `gs` and `gp`.
# The standard way to deploy it is the bundled installer, which appends the
# `source` line below to your rc for you:
#
#   ./git-shortcuts-tool/scripts/install.sh
#
# This file is meant to be *sourced*, not executed. It therefore intentionally
# does not enable `set -euo pipefail` so it does not alter the caller's shell
# options. See the Bash Best Practices skill for why sourcable files stay
# option-neutral.
#
# Tags: #git #repo-management

# gs - quick 'git status' (the name mirrors the classic svn->git reflex)
alias gs="git status "

# gd - quick 'git diff' (companion shortcut, kept for discoverability)
alias gd="git diff "

# gp - one-shot "ship it" workflow:
#   1. stage everything
#   2. commit with the given message (default: "regular commit")
#   3. pull --rebase to absorb upstream changes
#   4. show resulting status
#   5. push the current branch to its tracked origin
#
# Usage:
#   gp                 # commits with "regular commit"
#   gp "fix login bug" # commits with a custom message
#
# `git commit` is allowed to fail (e.g. nothing staged) without aborting the
# rest of the workflow via `|| true`; the subsequent pull/push still run so a
# rebase-only sync is possible.
gp() {
  git add --all
  git commit -m "${1:-regular commit}" || true
  git pull --rebase && \
    git status && \
    git push -u origin HEAD
}