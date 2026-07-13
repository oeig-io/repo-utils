#!/usr/bin/env bash

# Pull latest changes for all git repositories in subdirectories

# Get the directory where this script is located, then navigate up
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
cd "${SCRIPT_DIR}/.."

# Source configuration
source "${SCRIPT_DIR}/git-utils.conf"

# Find all directories containing .git (git repositories)
for dir in */ .*/; do
    if [ -d "$dir/.git" ]; then
        repo_name="${dir%/}"
        # Unborn branch (no commits yet) — common right after cloning an
        # empty upstream repo. rev-parse prints the literal "HEAD" and `git
        # pull` would fail with "no such ref was fetched". Detect it and skip
        # with a friendly note instead of a scary error.
        if ! git -C "$dir" rev-parse --verify HEAD >/dev/null 2>&1; then
            echo "${COLOR_FORK}${DELIMITER} Skipping $repo_name (unborn branch / no commits yet) ${DELIMITER}${COLOR_RESET}"
            echo
            continue
        fi
        branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
        echo "${COLOR_INFO}${DELIMITER} Pulling $repo_name ${DELIMITER}${COLOR_RESET}"
        echo "Branch: ${branch}"
        git -C "$dir" pull
        echo
    fi
done

echo "${COLOR_SUCCESS}${DELIMITER} Done ${DELIMITER}${COLOR_RESET}"
