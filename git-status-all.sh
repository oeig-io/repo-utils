#!/usr/bin/env bash

# Show git status for all git repositories in subdirectories

# Get the directory where this script is located, then navigate up
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
cd "${SCRIPT_DIR}/.."

# Find all directories containing .git (git repositories)
for dir in */; do
    if [ -d "$dir/.git" ]; then
        echo "Status for $dir:"
        git -C "$dir" status
        echo
    fi
done

echo "Done!"
