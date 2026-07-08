#!/usr/bin/env bash

# Show git status for all git repositories in subdirectories

# Get the directory where this script is located, then navigate up
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/.."

# Source configuration
source "${SCRIPT_DIR}/git-utils.conf"

# Function to check if the current branch is behind/ahead of its upstream
get_tracking_status() {
    local dir="$1"
    local behind ahead

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

# Resolve the repo's home branch: an explicit override from EXPECTED_BRANCH,
# else the remote's default branch, falling back to main/master.
get_home_branch() {
    local dir="$1" repo="$2" def
    if [ -n "${EXPECTED_BRANCH[$repo]}" ]; then
        echo "${EXPECTED_BRANCH[$repo]}"
        return
    fi
    def=$(git -C "$dir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null \
          | sed 's@^refs/remotes/origin/@@')
    if [ -z "$def" ]; then
        local b
        for b in main master; do
            if git -C "$dir" show-ref --verify --quiet "refs/heads/$b"; then
                def="$b"
                break
            fi
        done
    fi
    echo "$def"
}

# How far the LOCAL home branch is behind its own upstream, independent of HEAD.
# This surfaces "home base has updates you have not pulled" even while parked on
# a feature branch.
get_home_behind() {
    local dir="$1" home="$2" up behind
    [ -z "$home" ] && return
    up=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name "${home}@{upstream}" 2>/dev/null) || return
    behind=$(git -C "$dir" rev-list --count "${home}..${up}" 2>/dev/null)
    [ "${behind:-0}" -gt 0 ] && echo "$behind"
}

# Extract the organization/owner from the origin remote URL (blank if none).
get_org() {
    local dir="$1" url
    url=$(git -C "$dir" remote get-url origin 2>/dev/null) || return
    [ -z "$url" ] && return
    echo "$url" | sed -E 's#^(ssh://)?(git@|https?://)##; s#:#/#; s#\.git/*$##; s#/+$##' | awk -F/ '{print $(NF-1)}'
}

# Find all directories containing .git (git repositories)
for dir in */ .*/; do
    if [ -d "$dir/.git" ]; then
        repo_name="${dir%/}"

        # Label the header with origin's org so a fork (non-EXPECTED_ORG) stands
        # out without adding a line. Unexpected orgs use COLOR_FORK (blue) so they
        # don't read like the COLOR_WARNING yellow used for [ahead]/[behind].
        org=$(get_org "$dir")
        if [ -z "$org" ]; then
            org_label=""
        elif [ "$org" = "$EXPECTED_ORG" ]; then
            org_label=" (${org})"
        else
            org_label=" ${COLOR_FORK}(${org})${COLOR_RESET}${COLOR_INFO}"
        fi
        echo "${COLOR_INFO}${DELIMITER} ${repo_name}${org_label} ${DELIMITER}${COLOR_RESET}"

        # Get the current branch (no color for branch details)
        branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
        echo "Branch: ${branch}"

        # Resolve home base and the real upstream of the current branch
        home_branch=$(get_home_branch "$dir" "$repo_name")
        upstream_ref=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null)

        # Get tracking status (behind/ahead of current branch's upstream)
        tracking_status=$(get_tracking_status "$dir")

        # Get file status (without branch info)
        file_status=$(git -C "$dir" status --porcelain)

        # Construct the output
        line_suffix=""
        if [ -n "$tracking_status" ]; then
            line_suffix="${line_suffix}${COLOR_WARNING}${tracking_status}${COLOR_RESET}"
        fi

        # RED: parked off home base — the state that leads to orphaned branches
        if [ -n "$home_branch" ] && [ "$branch" != "$home_branch" ]; then
            line_suffix="${line_suffix}${COLOR_CHANGES} [on ${branch}, not ${home_branch}]${COLOR_RESET}"
        fi

        # RED: home base is stale — fires even while on a feature branch
        home_behind=$(get_home_behind "$dir" "$home_branch")
        if [ -n "$home_behind" ]; then
            line_suffix="${line_suffix}${COLOR_CHANGES} [${home_branch} behind ${home_behind}]${COLOR_RESET}"
        fi

        # RED: uncommitted local changes
        if [ -n "$file_status" ]; then
            line_suffix="${line_suffix}${COLOR_CHANGES} [changes]${COLOR_RESET}"
        fi

        echo "## ${branch}...${upstream_ref:-(no upstream)}${line_suffix}"
        if [ -n "$file_status" ]; then
            echo "$file_status"
        fi

        echo
    fi
done

echo "${COLOR_SUCCESS}${DELIMITER} Done ${DELIMITER}${COLOR_RESET}"
