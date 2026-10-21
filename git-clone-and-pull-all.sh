#!/usr/bin/env bash

# Clone missing repos from oeig-io organization and pull all

# Get the directory where this script is located, then navigate up
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/.."

# Source configuration
source "${SCRIPT_DIR}/git-utils.conf"
source "${SCRIPT_DIR}/git-report.sh"

# Check if gh CLI is installed
if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI is not installed"
    echo "Install from https://cli.github.com/"
    exit 1
fi

# Check if gh CLI is authenticated
if ! gh auth status &>/dev/null; then
    echo "Error: gh CLI is not authenticated"
    echo "Run 'gh auth login' to authenticate"
    exit 1
fi

# Findings from this pass and from the pull pass below land in one file, so the
# run ends with a single closing verdict instead of two half-reports. The pull
# pass prints it (and sets the exit status) because it sweeps more repos than
# this pass sees.
ISSUE_LOG=$(mktemp "${TMPDIR:-/tmp}/oeig-git-utils-issues.XXXXXX")
trap 'rm -f "$ISSUE_LOG"' EXIT
export GIT_UTILS_ISSUE_LOG="$ISSUE_LOG"

# Get all repos from oeig-io organization using gh CLI
echo "${COLOR_INFO}${DELIMITER} Fetching repos from oeig-io organization ${DELIMITER}${COLOR_RESET}"
mapfile -t REMOTE_REPOS < <(gh repo list oeig-io --limit 1000 --json name -q '.[].name')

if [ ${#REMOTE_REPOS[@]} -eq 0 ]; then
    echo "No repos found or gh CLI not authenticated"
    exit 1
fi

echo "Found ${#REMOTE_REPOS[@]} remote repositories"

# Find and clone missing repos. Test for a real repo rather than a directory of
# the same name: a plain directory would otherwise silently suppress the clone
# and never be seen by the pull pass.
CLONED=0
CLONE_FAILED=0
for repo in "${REMOTE_REPOS[@]}"; do
    if [ ! -d "$repo/.git" ]; then
        echo "${COLOR_INFO}${DELIMITER} Cloning $repo ${DELIMITER}${COLOR_RESET}"
        if gh repo clone "oeig-io/$repo"; then
            CLONED=$((CLONED + 1))
        else
            CLONE_FAILED=$((CLONE_FAILED + 1))
            issue "$repo" "clone failed"
        fi
    fi
done

if [ "$CLONED" -eq 0 ] && [ "$CLONE_FAILED" -eq 0 ]; then
    echo "${COLOR_SUCCESS}All repos already present locally${COLOR_RESET}"
elif [ "$CLONE_FAILED" -eq 0 ]; then
    echo "${COLOR_SUCCESS}Cloned $CLONED missing repositories${COLOR_RESET}"
else
    echo "${COLOR_WARNING}Cloned $CLONED of $((CLONED + CLONE_FAILED)) missing repositories${COLOR_RESET}"
fi

echo ""

# Called, not exec'd: exec replaces this process image and would drop the EXIT
# trap that removes $ISSUE_LOG. A plain call keeps the cleanup and still lets the
# pull pass's exit status become this script's.
"${SCRIPT_DIR}/git-pull-all.sh"
