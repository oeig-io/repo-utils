#!/usr/bin/env bash

# Pull latest changes for all git repositories in subdirectories

# Get the directory where this script is located, then navigate up
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
cd "${SCRIPT_DIR}/.."

# Find all directories containing .git (git repositories)
for dir in */; do
    if [ -d "$dir/.git" ]; then
        echo "Pulling $dir..."
        git -C "$dir" pull
        echo
    fi
done

echo "Done!"
