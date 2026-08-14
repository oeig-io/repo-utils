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

# Resolve the repo's default branch: the remote's HEAD, falling back to
# main/master if present locally.
get_default_branch() {
    local dir="$1" def b
    def=$(git -C "$dir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null \
          | sed 's@^refs/remotes/origin/@@')
    if [ -z "$def" ]; then
        for b in main master; do
            if git -C "$dir" show-ref --verify --quiet "refs/heads/$b"; then
                def="$b"
                break
            fi
        done
    fi
    echo "$def"
}

# Resolve the repo's home ref: an explicit override from EXPECTED_REF,
# else the default branch. The override may name a branch (an external
# repo tracking a release branch) or a tag (pinned to an upstream release).
get_home_ref() {
    local dir="$1" repo="$2"
    if [ -n "${EXPECTED_REF[$repo]}" ]; then
        echo "${EXPECTED_REF[$repo]}"
        return
    fi
    get_default_branch "$dir"
}

# How far the LOCAL home branch is behind its own upstream, independent of HEAD.
# This surfaces "home base has updates you have not pulled" even while parked on
# a feature branch. A tag home ref has no upstream, so this no-ops for pins.
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

        # Get the current branch (no color for branch details). A detached
        # HEAD (repo checked out at a release tag) shows the tag or short
        # commit instead of the bare "HEAD".
        branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
        detached=0
        if [ "$branch" = "HEAD" ]; then
            detached=1
            branch="detached at $(git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null \
                  || git -C "$dir" rev-parse --short HEAD)"
        fi
        echo "Branch: ${branch}"

        # Resolve home base (default branch or EXPECTED_REF override) and the
        # real upstream of the current branch
        home_ref=$(get_home_ref "$dir" "$repo_name")
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

        # RED: parked off home base — the state that leads to orphaned branches.
        # Compared by commit so a tag home base works: a checkout parked at the
        # tag reads clean, anything else flags red.
        if [ -n "$home_ref" ]; then
            home_commit=$(git -C "$dir" rev-parse --quiet --verify "${home_ref}^{commit}" 2>/dev/null)
            head_commit=$(git -C "$dir" rev-parse HEAD 2>/dev/null)
            if [ -z "$home_commit" ] || [ "$head_commit" != "$home_commit" ]; then
                line_suffix="${line_suffix}${COLOR_CHANGES} [not at ${home_ref}]${COLOR_RESET}"
            # CYAN: tag-pinned — deliberate staleness, so informational. Shows
            # how far the default branch has moved past the pin, so a newer
            # release is visible without the pin reading as a problem.
            elif git -C "$dir" for-each-ref --format='%(refname:short)' refs/tags | grep -qx "$home_ref"; then
                default_branch=$(get_default_branch "$dir")
                pin_behind=$(git -C "$dir" rev-list --count "${home_ref}..origin/${default_branch}" 2>/dev/null)
                if [ -n "${default_branch}" ] && [ -n "${pin_behind}" ]; then
                    line_suffix="${line_suffix}${COLOR_INFO} [pinned; ${default_branch} ${pin_behind} ahead]${COLOR_RESET}"
                else
                    line_suffix="${line_suffix}${COLOR_INFO} [pinned]${COLOR_RESET}"
                fi
            fi
        fi

        # RED: home base is stale — fires even while on a feature branch
        home_behind=$(get_home_behind "$dir" "$home_ref")
        if [ -n "$home_behind" ]; then
            line_suffix="${line_suffix}${COLOR_CHANGES} [${home_ref} behind ${home_behind}]${COLOR_RESET}"
        fi

        # RED: uncommitted local changes
        if [ -n "$file_status" ]; then
            line_suffix="${line_suffix}${COLOR_CHANGES} [changes]${COLOR_RESET}"
        fi

        # A detached HEAD has no upstream by definition — restating it adds
        # noise, so the tracking line shows just where HEAD is.
        if [ "$detached" -eq 1 ]; then
            echo "## ${branch}${line_suffix}"
        else
            echo "## ${branch}...${upstream_ref:-(no upstream)}${line_suffix}"
        fi
        if [ -n "$file_status" ]; then
            echo "$file_status"
        fi

        echo
    fi
done

echo "${COLOR_SUCCESS}${DELIMITER} Done ${DELIMITER}${COLOR_RESET}"
