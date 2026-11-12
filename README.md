# repo-utils

Purpose: Repository management utilities for synchronizing local development environments with the oeig-io organization.

## TOC

- [Summary](#summary)
- [Quick Start](#quick-start)
- [Scripts](#scripts)
  - [The closing summary and exit status](#the-closing-summary-and-exit-status)

## Summary

The purpose of this directory is to provide automated utilities for managing multiple repositories in the oeig-io organization.

This is important because manual repository synchronization is error-prone and time-consuming when working across many projects.

## Prerequisites

- `gh` cli - see `./gh-install.sh` for details on how to install

`gh` installation details:

=== Option 1 ===
https://github.com/cli/cli/blob/trunk/docs/install_linux.md

=== Option 2 ===
nix profile add nixpkgs#gh

=== Authenticate ===
Run `gh auth login`

## Quick Start

Clone missing repositories and pull all updates:

```bash
./repo-utils/git-clone-and-pull-all.sh
```

Pull updates on existing repositories only:

```bash
./repo-utils/git-pull-all.sh
```

## Scripts

| Script | Purpose | Prerequisites |
|--------|---------|---------------|
| `git-clone-and-pull-all.sh` | Clone missing repos from oeig-io, then pull all | `gh` CLI installed and authenticated |
| `git-pull-all.sh` | Pull latest changes from all local repos | Git repositories in sibling directories |
| `git-status-all.sh` | Show branch, tracking, and change status for every repo, colored so red means "action needed" | Git repositories in sibling directories |
| `git-report.sh` | Shared, sourced by the three above — resolves each repo's home base, decides what counts as an issue, and prints the closing summary. Never run directly | — |
| `install-mcpc-skill.sh` | Snapshot `mcpc help --skill` into `wi-mcpc/mcpc-tool.md` (re-run after upgrading `@apify/mcpc`) | `mcpc` CLI installed (`npm install -g @apify/mcpc`) |
| `install-nixos-ai-skill.sh` | (Re)generate `wi-nixos/nixos-ai-skill-tool/` from `marceloeatworld/nixos-ai-skill` upstream (shallow clone of `main`, always-latest; gitignored) | Run `./wi-base/refresh-skills.sh` afterward to publish symlinks |

See [git-shortcuts-tool](git-shortcuts-tool/SKILL.md) for the `gs` (git status) and `gp` (add, commit, pull --rebase, push) shell shortcuts used across developer machines.

### Reading git-status-all.sh colors

The purpose of the colors is to let you scan for **red = action needed** without reading every line. Each repo header also shows origin's org in parentheses; a non-`oeig-io` org (e.g. a personal fork) is colored so it stands out at a glance — deliberately in **blue**, not yellow, so the eye doesn't read it as the `[ahead]`/`[behind]` warning.

| Signal | Color | Meaning |
|--------|-------|---------|
| On home ref, up to date, clean | none | nothing to do |
| `(non-oeig-io org)` in section header | blue | origin points elsewhere (e.g. personal fork) — informational, not a warning |
| `[behind N]` / `[ahead N]` | yellow | current branch drifted from its upstream |
| `[not at <home>]` | red | parked off home base — finish up and `git switch` back |
| `[<home> behind N]` | red | your local home branch is stale even while you sit elsewhere |
| `[changes]` | red | uncommitted local changes |
| `[pinned; <branch> N ahead]` | cyan | repo is pinned to a release tag — informational, and N is how far the default branch has moved past the pin |

`(no upstream)` in the branch line means the branch has no remote configured, so `git pull` cannot run for it. It is reported as an issue in the summary below rather than painted red inline, because the branch line already says it.

"Home base" is the remote's default branch (usually `main`). External repos whose reference point is something else are declared in `git-utils.conf` via `EXPECTED_REF`: a non-default branch (`idempiere-core` on our production `release-13`) or a release tag the repo is pinned to with `git switch --detach <tag>` (`netbird` at `v0.76.3`). Either way they read as clean rather than red. Set `EXPECTED_ORG` there to the org that owns your canonical repos.

### The closing summary and exit status

The purpose of the last line of every one of these scripts is to be the one thing you read. It answers "is this machine healthy?" without scrolling back through 90 repos.

```
=== All 89 repos good ===            green, exit 0

=== 2 issue(s) need action ===       red, exit 1
  repo-utils                 changes
  secretspec                 pull failed
Notes (no action needed):
  host-stewy                 unborn branch, nothing to pull
Run ./repo-utils/git-status-all.sh for per-repo detail.
```

**Exit status is the machine-readable half.** `0` means every repo is healthy, `1` means at least one issue is listed, so the scripts work under a wrapper that discards the color and the text. `git-clone-and-pull-all.sh` also exits `1` when `gh` is missing or unauthenticated, before it touches anything.

What counts as an issue is defined once, in `git-report.sh`, so the per-repo listing and the closing summary can never disagree. An issue is:

| Issue | Where it comes from |
|-------|--------------------|
| `clone failed` | this run only — `gh repo clone` failed |
| `pull failed` / `fetch failed` | this run only — the git command returned non-zero |
| `no upstream` | the branch has no remote configured, so nothing can be pulled |
| `not at <home>` | parked off home base (red in the listing) |
| `<home> behind N` | local home branch is stale (red in the listing) |
| `changes` | uncommitted local changes (red in the listing) |

An **empty repo** — cloned from an upstream that has no commits yet — is a *note*, not an issue: there is genuinely nothing to pull.

> ⚠️ **Expect red while you work.** `not at <home>` fires for a repo parked on a feature branch, which is the normal state while you have a PR open. That is intended — a repo left parked quietly stops receiving updates to its default branch — but it means the summary stays red until you `git switch` back. Use a worktree (see the `git-worktree` skill in `wi-github`) to keep the primary clone on home base if you would rather it never go red.

### Recommended fork/PR remote setup

The purpose of this setup is to contribute through a fork while keeping `origin` pointed at the canonical repo. This is important because `git-status-all.sh` measures "home base" and "behind" against `origin` — if you re-point `origin` at your fork, those signals stop tracking the canonical repo and the guardrails go quiet.

So leave `origin` alone (repo-utils cloned it correctly) and add your fork as a *separate* named remote. Let `gh` create both the fork and the remote — it emits a URL in whichever protocol `gh` is configured for, which is the only form that authenticates on hosts where `gh` is the sole GitHub credential:

```bash
# fork only when a change is ready to land — see AGENTS.md → "Fork only when a change needs one"
# origin stays canonical (oeig-io); the fork lands on its own remote
gh repo fork --remote --remote-name fork

# branch from an up-to-date home base, then push the branch to your fork
git switch main && git pull
git switch -c my-change
git push -u fork my-change

# open the PR against the canonical repo
gh pr create --repo <org>/<repo> --base main --head "$(gh api user -q .login):my-change"

# when the PR is open, return to home base so you keep pulling updates
git switch main
```

> ⚠️ **Warning** — `--remote-name fork` is not optional. By default `gh repo fork` renames `origin` to `upstream` and claims `origin` for your fork — precisely the re-pointing this setup exists to prevent.

`--head <user>:<branch>` names the fork that holds the commits, so `gh` skips its interactive "where should I push this?" prompt. Combined with `--repo` it makes the command safe to run unattended.

With `origin` canonical, the header org label stays `oeig-io`, `[main behind N]` keeps warning you when the canonical branch moves, and `[on my-change, not main]` reminds you to switch back once the PR is filed.

> 🔗 **Reference** — To avoid parking a repo on a feature branch at all, do the branch work in a git worktree: the primary clone stays on home base (still syncing) while the branch lives in a dedicated sibling directory beside the workspace. See the `git-worktree` skill (`wi-github`).

Both scripts operate from the parent directory (where repositories should live).

> ⚠️ **Note** — `git-clone-and-pull-all.sh` and `git-pull-all.sh` now exit `1` when they find issues (see [The closing summary and exit status](#the-closing-summary-and-exit-status)). They were previously always `0`. The onboarding steps in `host-ai-user/AGENTS.md` are separate commands, not chained with `&&`, so nothing there changes — but if you wrap these in a pipeline or a script, check the exit status before continuing.

## Additional Helpful Repos

Here are additional repositories you might was to also include for AI reference and assistance.
- https://github.com/idempiere/idempiere/
- https://github.com/idempiere/idempiere.github.io/
- https://github.com/bxservice/idempiere-rest/
- https://github.com/bxservice/idempiere-rest-docs
- https://github.com/anomalyco/opencode/
- https://github.com/badlogic/pi-mono
- https://github.com/paperclipai/paperclip

---

Tags: #tool-git #repo-management
