#!/usr/bin/env bash

# Shared repository inspection and summary reporting for the git-utils scripts.
# Sourced, never executed.
#
# This file owns the two things all three scripts must agree on:
#
#   1. how a repository's home base is resolved (EXPECTED_REF in git-utils.conf)
#   2. what counts as an issue — the same signals git-status-all.sh paints red,
#      so the per-repo listing and the closing summary can never disagree
#
# Callers record findings with issue()/note() and close with report_summary,
# which prints one verdict and returns non-zero when anything needs a human.
#
# A caller that runs another one of these scripts and wants a single verdict
# exports GIT_UTILS_ISSUE_LOG (see git-clone-and-pull-all.sh): findings then go
# to that file instead of the in-process arrays, and whichever process runs last
# prints the combined result.

_REPORT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${_REPORT_DIR}/git-utils.conf"

# Findings, each "<repo><TAB><reason>". Only filled in the process that prints
# the summary; otherwise they live in GIT_UTILS_ISSUE_LOG.
ISSUES=()
NOTES=()

# How many repositories the sweep examined, for the all-clear line.
REPO_COUNT=0

# Labels from the most recent repo_issues call.
REPO_ISSUES=()

# Print each workspace directory that is a git repository, one per line.
git_repo_dirs() {
    local dir
    for dir in */ .*/; do
        # -d, not -e: a linked worktree's .git is a *file*, and worktrees are
        # kept outside this workspace on purpose (see the git-worktree skill),
        # so -d matches real repos and ignores any stray worktree.
        if [ -d "$dir/.git" ]; then
            printf '%s\n' "${dir%/}"
        fi
    done
    return 0
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

# Resolve the repo's home ref: an explicit override from EXPECTED_REF, else the
# default branch. The override may name a branch (an external repo tracking a
# release branch) or a tag (pinned to an upstream release).
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

# Fill REPO_ISSUES with the labels that mean "action needed". An empty result
# means the repo is clean. Compared by commit so a tag home ref works.
repo_issues() {
    local dir="$1" repo="$2" branch home home_commit head_commit behind
    REPO_ISSUES=()

    # Unborn branch: no commits, so there is nothing to compare or pull.
    git -C "$dir" rev-parse --verify HEAD >/dev/null 2>&1 || return 0

    branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)

    # A live branch with no configured remote cannot be pulled at all. A
    # detached HEAD has no upstream by definition, so it is exempt.
    if [ "$branch" != "HEAD" ] && ! has_upstream "$dir" "$branch"; then
        REPO_ISSUES+=("no upstream")
    fi

    home=$(get_home_ref "$dir" "$repo")
    if [ -n "$home" ]; then
        # Parked off home base — the state that leads to orphaned branches.
        home_commit=$(git -C "$dir" rev-parse --quiet --verify "${home}^{commit}" 2>/dev/null)
        head_commit=$(git -C "$dir" rev-parse HEAD 2>/dev/null)
        if [ -z "$home_commit" ] || [ "$head_commit" != "$home_commit" ]; then
            REPO_ISSUES+=("not at ${home}")
        fi

        # Home base is stale — fires even while parked on a feature branch.
        behind=$(get_home_behind "$dir" "$home")
        [ -n "$behind" ] && REPO_ISSUES+=("${home} behind ${behind}")
    fi

    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
        REPO_ISSUES+=("changes")
    fi

    return 0
}

# True when the last repo_issues call reported LABEL as an issue.
repo_has_issue() {
    local label
    for label in "${REPO_ISSUES[@]}"; do
        [ "$label" = "$1" ] && return 0
    done
    return 1
}

# Whether BRANCH has a remote configured to pull from. Tests the config rather
# than @{upstream}: a clone that has never fetched has no remote-tracking ref
# yet, but `git pull` fetches and creates one, so such a repo pulls fine and
# must not be reported as untracked.
has_upstream() {
    local dir="$1" branch="$2"
    [ -n "$branch" ] || return 1
    git -C "$dir" config --get "branch.${branch}.remote" >/dev/null 2>&1
}

# The cyan informational tag for a repo deliberately parked at a release tag:
# staleness by choice, so it reports how far the default branch has moved past
# the pin. Empty when HOME names no tag or the repo is not sitting on it.
pinned_note() {
    local dir="$1" home="$2" default pin_behind
    [ -n "$home" ] || return 0
    git -C "$dir" for-each-ref --format='%(refname:short)' refs/tags | grep -qx "$home" || return 0
    default=$(get_default_branch "$dir")
    pin_behind=$(git -C "$dir" rev-list --count "${home}..origin/${default}" 2>/dev/null)
    if [ -n "$default" ] && [ -n "$pin_behind" ]; then
        echo "${COLOR_INFO} [pinned; ${default} ${pin_behind} ahead]${COLOR_RESET}"
    else
        echo "${COLOR_INFO} [pinned]${COLOR_RESET}"
    fi
}

# issue REPO REASON — record something that needs a human.
issue() {
    if [ -n "${GIT_UTILS_ISSUE_LOG:-}" ]; then
        printf 'issue\t%s\t%s\n' "$1" "$2" >>"$GIT_UTILS_ISSUE_LOG"
    else
        ISSUES+=("$1"$'\t'"$2")
    fi
    return 0
}

# note REPO REASON — record something worth knowing that is not a problem.
note() {
    if [ -n "${GIT_UTILS_ISSUE_LOG:-}" ]; then
        printf 'note\t%s\t%s\n' "$1" "$2" >>"$GIT_UTILS_ISSUE_LOG"
    else
        NOTES+=("$1"$'\t'"$2")
    fi
    return 0
}

# One line per repo, reasons merged in encounter order. Every finding reaches
# here as "<repo><TAB><reason>" — report_summary drops the issue log's leading
# kind field before handing them over.
print_findings() {
    local -A seen=()
    local entry repo reason
    local -a repos=()

    for entry in "$@"; do
        repo=${entry%%$'\t'*}
        reason=${entry#*$'\t'}
        case ";${seen[$repo]:-};" in
            *";$reason;"*) continue ;;
        esac
        if [ -n "${seen[$repo]+x}" ]; then
            seen[$repo]="${seen[$repo]}; $reason"
        else
            seen[$repo]="$reason"
        fi
    done

    [ "${#seen[@]}" -eq 0 ] && return 0
    mapfile -t repos < <(printf '%s\n' "${!seen[@]}" | sort)
    for repo in "${repos[@]}"; do
        printf "  %-26s %s\n" "$repo" "${seen[$repo]}"
    done
}

# The closing verdict. Returns 1 when anything needs a human, so a caller can
# end with `report_summary; exit $?` and get a non-zero exit from the script.
report_summary() {
    local -a issues=("${ISSUES[@]}") notes=("${NOTES[@]}")

    # Findings handed over by an earlier pass live in the log, so read them from
    # there instead of the (empty) in-process arrays.
    if [ -n "${GIT_UTILS_ISSUE_LOG:-}" ]; then
        issues=(); notes=()
        local kind repo reason
        while IFS=$'\t' read -r kind repo reason; do
            [ -n "${repo:-}" ] || continue
            if [ "$kind" = "note" ]; then
                notes+=("${repo}"$'\t'"$reason")
            else
                issues+=("${repo}"$'\t'"$reason")
            fi
        done <"$GIT_UTILS_ISSUE_LOG"
    fi

    echo
    if [ "${#issues[@]}" -eq 0 ]; then
        if [ "${#notes[@]}" -gt 0 ]; then
            echo "${COLOR_INFO}${DELIMITER} All ${REPO_COUNT} repos good (${#notes[@]} note(s)) ${DELIMITER}${COLOR_RESET}"
            print_findings "${notes[@]}"
        else
            echo "${COLOR_SUCCESS}${DELIMITER} All ${REPO_COUNT} repos good ${DELIMITER}${COLOR_RESET}"
        fi
        return 0
    fi

    echo "${COLOR_CHANGES}${DELIMITER} ${#issues[@]} issue(s) need action ${DELIMITER}${COLOR_RESET}"
    print_findings "${issues[@]}"
    if [ "${#notes[@]}" -gt 0 ]; then
        echo "${COLOR_INFO}Notes (no action needed):${COLOR_RESET}"
        print_findings "${notes[@]}"
    fi
    echo "Run ./repo-utils/git-status-all.sh for per-repo detail."
    return 1
}
