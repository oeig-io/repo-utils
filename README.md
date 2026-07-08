# repo-utils

Purpose: Repository management utilities for synchronizing local development environments with the oeig-io organization.

## TOC

- [Summary](#summary)
- [Quick Start](#quick-start)
- [Scripts](#scripts)

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
| `install-mcpc-skill.sh` | Snapshot `mcpc help --skill` into `wi-mcpc/mcpc-tool.md` (re-run after upgrading `@apify/mcpc`) | `mcpc` CLI installed (`npm install -g @apify/mcpc`) |

See [git-shortcuts-tool](git-shortcuts-tool/SKILL.md) for the `gs` (git status) and `gp` (add, commit, pull --rebase, push) shell shortcuts used across developer machines.

### Reading git-status-all.sh colors

The purpose of the colors is to let you scan for **red = action needed** without reading every line. Each repo header also shows origin's org in parentheses; a non-`oeig-io` org (e.g. a personal fork) is colored so it stands out at a glance — deliberately in **blue**, not yellow, so the eye doesn't read it as the `[ahead]`/`[behind]` warning.

| Signal | Color | Meaning |
|--------|-------|---------|
| On home branch, up to date, clean | none | nothing to do |
| `(non-oeig-io org)` in section header | blue | origin points elsewhere (e.g. personal fork) — informational, not a warning |
| `[behind N]` / `[ahead N]` | yellow | current branch drifted from its upstream |
| `[on <branch>, not <home>]` | red | parked off home base — finish up and `git switch` back |
| `[<home> behind N]` | red | your local home branch is stale even while you sit elsewhere |
| `[changes]` | red | uncommitted local changes |

"Home base" is the remote's default branch (usually `main`). External repos that intentionally track a different branch — for example `idempiere-core` pinned to our production `release-13` — are declared in `git-utils.conf` via `EXPECTED_BRANCH` so they read as clean rather than red. Set `EXPECTED_ORG` there to the org that owns your canonical repos.

### Recommended fork/PR remote setup

The purpose of this setup is to contribute through a fork while keeping `origin` pointed at the canonical repo. This is important because `git-status-all.sh` measures "home base" and "behind" against `origin` — if you re-point `origin` at your fork, those signals stop tracking the canonical repo and the guardrails go quiet.

So leave `origin` alone (repo-utils cloned it correctly) and add your fork as a *separate* named remote:

```bash
# origin stays canonical (oeig-io); add your fork under your username
git remote add fork git@github.com:<your-username>/<repo>.git

# branch from an up-to-date home base, then push the branch to your fork
git switch main && git pull
git switch -c my-change
git push -u fork my-change

# open the PR against the canonical repo
gh pr create --repo <org>/<repo> --base main

# when the PR is open, return to home base so you keep pulling updates
git switch main
```

With `origin` canonical, the header org label stays `oeig-io`, `[main behind N]` keeps warning you when the canonical branch moves, and `[on my-change, not main]` reminds you to switch back once the PR is filed.

Both scripts operate from the parent directory (where repositories should live).

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
