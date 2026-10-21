#!/usr/bin/env bash

# Show git status for all git repositories in subdirectories

# Get the directory where this script is located, then navigate up
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/.."

# Source configuration
source "${SCRIPT_DIR}/git-utils.conf"
source "${SCRIPT_DIR}/git-report.sh"

# Function to check if the current branch is behind/ahead of its upstream
get_tracking_status() {
    local dir="$1" behind ahead

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

# Extract the organization/owner from the origin remote URL (blank if none).
get_org() {
    local dir="$1" url
    url=$(git -C "$dir" remote get-url origin 2>/dev/null) || return
    [ -z "$url" ] && return
    echo "$url" | sed -E 's#^(ssh://)?(git@|https?://)##; s#:#/#; s#\.git/*$##; s#/+$##' | awk -F/ '{print $(NF-1)}'
}

mapfile -t REPOS < <(git_repo_dirs)

for repo_name in "${REPOS[@]}"; do
    REPO_COUNT=$((REPO_COUNT + 1))

    # Label the header with origin's org so a fork (non-EXPECTED_ORG) stands
    # out without adding a line. Unexpected orgs use COLOR_FORK (blue) so they
    # don't read like the COLOR_WARNING yellow used for [ahead]/[behind].
    org=$(get_org "$repo_name")
    if [ -z "$org" ]; then
        org_label=""
    elif [ "$org" = "$EXPECTED_ORG" ]; then
        org_label=" (${org})"
    else
        org_label=" ${COLOR_FORK}(${org})${COLOR_RESET}${COLOR_INFO}"
    fi
    echo "${COLOR_INFO}${DELIMITER} ${repo_name}${org_label} ${DELIMITER}${COLOR_RESET}"

    # An unborn branch (empty repo) has no HEAD at all, and rev-parse reports
    # the literal "HEAD" — which would read as a confusing "detached at ".
    unborn=0
    detached=0
    branch=$(git -C "$repo_name" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if ! git -C "$repo_name" rev-parse --verify HEAD >/dev/null 2>&1; then
        unborn=1
        branch="unborn branch (no commits yet)"
    elif [ "$branch" = "HEAD" ]; then
        detached=1
        branch="detached at $(git -C "$repo_name" describe --tags --exact-match HEAD 2>/dev/null \
              || git -C "$repo_name" rev-parse --short HEAD)"
    fi
    echo "Branch: ${branch}"

    # Resolve home base (default branch or EXPECTED_REF override) and the
    # real upstream of the current branch
    home_ref=$(get_home_ref "$repo_name" "$repo_name")
    upstream_ref=$(git -C "$repo_name" rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null)

    # Get tracking status (behind/ahead of current branch's upstream)
    tracking_status=$(get_tracking_status "$repo_name")

    # Get file status (without branch info)
    file_status=$(git -C "$repo_name" status --porcelain)

    # repo_issues defines what needs a human, so this listing and the closing
    # summary are always derived from the same checks.
    repo_issues "$repo_name" "$repo_name"
    if [ "$unborn" -eq 1 ]; then
        note "$repo_name" "unborn branch, nothing to pull"
    fi

    # Construct the output
    line_suffix=""
    if [ -n "$tracking_status" ]; then
        line_suffix="${line_suffix}${COLOR_WARNING}${tracking_status}${COLOR_RESET}"
    fi

    # CYAN: tag-pinned — deliberate staleness, so informational. It stands in
    # for the red "not at home" signal, which is why it only appears when the
    # repo is not flagged for being off the tag.
    if ! repo_has_issue "not at ${home_ref}"; then
        line_suffix="${line_suffix}$(pinned_note "$repo_name" "$home_ref")"
    fi

    for label in "${REPO_ISSUES[@]}"; do
        issue "$repo_name" "$label"
        # "no upstream" already reads in the branch line below as
        # "(no upstream)"; painting it again would just be noise.
        [ "$label" = "no upstream" ] && continue
        line_suffix="${line_suffix}${COLOR_CHANGES} [${label}]${COLOR_RESET}"
    done

    # An unborn or detached HEAD has no upstream by definition — restating it
    # adds noise, so the tracking line shows just where HEAD is.
    if [ "$unborn" -eq 1 ] || [ "$detached" -eq 1 ]; then
        echo "## ${branch}${line_suffix}"
    else
        echo "## ${branch}...${upstream_ref:-(no upstream)}${line_suffix}"
    fi
    if [ -n "$file_status" ]; then
        echo "$file_status"
    fi

    echo
done

report_summary
exit $?
