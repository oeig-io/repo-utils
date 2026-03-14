#!/usr/bin/env bash

# Show git status for all git repositories in subdirectories

# Get the directory where this script is located, then navigate up
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/.."

# Source configuration
source "${SCRIPT_DIR}/git-utils.conf"

# Function to check if repo is behind/ahead of upstream
get_tracking_status() {
    local dir="$1"
    local behind ahead tracking_info
    
    # Check if we have an upstream branch
    if ! git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name @{upstream} &>/dev/null; then
        return
    fi
    
    behind=$(git -C "$dir" rev-list --count HEAD..@{upstream} 2>/dev/null)
    ahead=$(git -C "$dir" rev-list --count @{upstream}..HEAD 2>/dev/null)
    
    if [ "$behind" -gt 0 ] && [ "$ahead" -gt 0 ]; then
        echo " [behind ${behind}, ahead ${ahead}]"
    elif [ "$behind" -gt 0 ]; then
        echo " [behind ${behind}]"
    elif [ "$ahead" -gt 0 ]; then
        echo " [ahead ${ahead}]"
    fi
}

# Find all directories containing .git (git repositories)
for dir in */ .*/; do
    if [ -d "$dir/.git" ]; then
        repo_name="${dir%/}"
        echo "${COLOR_INFO}${DELIMITER} $repo_name ${DELIMITER}${COLOR_RESET}"
        
        # Get the current branch
        branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
        
        # Get tracking status (behind/ahead)
        tracking_status=$(get_tracking_status "$dir")
        
        # Get file status (without branch info)
        file_status=$(git -C "$dir" status --porcelain)
        
        # Construct the output
        line_suffix=""
        if [ -n "$tracking_status" ]; then
            line_suffix="${COLOR_WARNING}${tracking_status}${COLOR_RESET}"
        fi
        if [ -n "$file_status" ]; then
            if [ -n "$line_suffix" ]; then
                line_suffix="${line_suffix}${COLOR_CHANGES} [changes]${COLOR_RESET}"
            else
                line_suffix="${COLOR_CHANGES} [changes]${COLOR_RESET}"
            fi
        fi
        
        echo "## ${branch}...origin/${branch}${line_suffix}"
        if [ -n "$file_status" ]; then
            echo "$file_status"
        fi
        
        echo
    fi
done

echo "${COLOR_SUCCESS}${DELIMITER} Done ${DELIMITER}${COLOR_RESET}"
