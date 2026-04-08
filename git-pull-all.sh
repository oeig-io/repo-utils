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
        branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
        echo "${COLOR_INFO}${DELIMITER} Pulling $repo_name ${DELIMITER}${COLOR_RESET}"
        echo "Branch: ${branch}"
        git -C "$dir" pull
        echo
    fi
done

echo "${COLOR_SUCCESS}${DELIMITER} Done ${DELIMITER}${COLOR_RESET}"
