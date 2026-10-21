#!/usr/bin/env bash

# Pull latest changes for all git repositories in subdirectories

# Get the directory where this script is located, then navigate up
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/.."

# Source configuration
source "${SCRIPT_DIR}/git-utils.conf"
source "${SCRIPT_DIR}/git-report.sh"

mapfile -t REPOS < <(git_repo_dirs)

for repo_name in "${REPOS[@]}"; do
    REPO_COUNT=$((REPO_COUNT + 1))

    # Unborn branch (no commits yet) — common right after cloning an
    # empty upstream repo. rev-parse prints the literal "HEAD" and `git
    # pull` would fail with "no such ref was fetched". Nothing to pull,
    # so it is a note rather than a problem.
    if ! git -C "$repo_name" rev-parse --verify HEAD >/dev/null 2>&1; then
        echo "${COLOR_FORK}${DELIMITER} Skipping $repo_name (unborn branch / no commits yet) ${DELIMITER}${COLOR_RESET}"
        note "$repo_name" "unborn branch, nothing to pull"
        echo
        continue
    fi

    branch=$(git -C "$repo_name" rev-parse --abbrev-ref HEAD 2>/dev/null)
    echo "${COLOR_INFO}${DELIMITER} Pulling $repo_name ${DELIMITER}${COLOR_RESET}"
    echo "Branch: ${branch}"

    if [ "$branch" = "HEAD" ]; then
        # Detached checkout (e.g. a repo pinned at a release tag): `git
        # pull` would fail with "not currently on a branch". Fetch instead
        # so refs and tags stay current without moving HEAD.
        echo "Detached at $(git -C "$repo_name" describe --tags --exact-match HEAD 2>/dev/null \
            || git -C "$repo_name" rev-parse --short HEAD); fetching only"
        git -C "$repo_name" fetch --prune --tags || issue "$repo_name" "fetch failed"
    elif ! has_upstream "$repo_name" "$branch"; then
        # No remote configured: `git pull` would do nothing but print a usage
        # hint. repo_issues below reports this as an issue, so stay quiet here.
        echo "No upstream configured; skipping pull"
    else
        git -C "$repo_name" pull || issue "$repo_name" "pull failed"
    fi

    # Whatever is still wrong after the pull: uncommitted work, a repo parked
    # off its home base, or a stale local home branch.
    repo_issues "$repo_name" "$repo_name"
    for label in "${REPO_ISSUES[@]}"; do
        issue "$repo_name" "$label"
    done

    echo
done

report_summary
exit $?
