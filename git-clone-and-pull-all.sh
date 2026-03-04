#!/usr/bin/env bash

# Clone missing repos from oeig-io organization and pull all

# Get the directory where this script is located, then navigate up
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
cd "${SCRIPT_DIR}/.."

# Source configuration
source "${SCRIPT_DIR}/git-utils.conf"

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

# Get all repos from oeig-io organization using gh CLI
echo "${COLOR_INFO}${DELIMITER} Fetching repos from oeig-io organization ${DELIMITER}${COLOR_RESET}"
mapfile -t REMOTE_REPOS < <(gh repo list oeig-io --json name -q '.[].name')

if [ ${#REMOTE_REPOS[@]} -eq 0 ]; then
    echo "No repos found or gh CLI not authenticated"
    exit 1
fi

echo "Found ${#REMOTE_REPOS[@]} remote repositories"

# Get array of local directories
mapfile -t LOCAL_DIRS < <(find . -maxdepth 1 -type d ! -name "." ! -name ".." -exec basename {} \;)

# Find and clone missing repos
MISSING_COUNT=0
for repo in "${REMOTE_REPOS[@]}"; do
    if [[ ! " ${LOCAL_DIRS[*]} " =~ " ${repo} " ]]; then
        echo "${COLOR_INFO}${DELIMITER} Cloning $repo ${DELIMITER}${COLOR_RESET}"
        gh repo clone "oeig-io/$repo"
        ((MISSING_COUNT++))
    fi
done

if [ $MISSING_COUNT -eq 0 ]; then
    echo "${COLOR_SUCCESS}All repos already present locally${COLOR_RESET}"
else
    echo "${COLOR_SUCCESS}Cloned $MISSING_COUNT missing repositories${COLOR_RESET}"
fi

echo ""

# Now run git-pull-all.sh to ensure everything is up to date
exec "${SCRIPT_DIR}/git-pull-all.sh"
