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
| On home ref, up to date, clean | none | nothing to do |
| `(non-oeig-io org)` in section header | blue | origin points elsewhere (e.g. personal fork) — informational, not a warning |
| `[behind N]` / `[ahead N]` | yellow | current branch drifted from its upstream |
| `[not at <home>]` | red | parked off home base — finish up and `git switch` back |
| `[<home> behind N]` | red | your local home branch is stale even while you sit elsewhere |
| `[pinned; <branch> N ahead]` | cyan | repo is pinned to a release tag — informational, and N is how far the default branch has moved past the pin |
| `[changes]` | red | uncommitted local changes |

"Home base" is the remote's default branch (usually `main`). External repos whose reference point is something else are declared in `git-utils.conf` via `EXPECTED_REF`: a non-default branch (`idempiere-core` on our production `release-13`) or a release tag the repo is pinned to with `git switch --detach <tag>` (`netbird` at `v0.76.3`). Either way they read as clean rather than red. Set `EXPECTED_ORG` there to the org that owns your canonical repos.

### Recommended fork/PR remote setup

The purpose of this setup is to contribute through a fork while keeping `origin` pointed at the canonical repo. This is important because `git-status-all.sh` measures "home base" and "behind" against `origin` — if you re-point `origin` at your fork, those signals stop tracking the canonical repo and the guardrails go quiet.

So leave `origin` alone (repo-utils cloned it correctly) and add your fork as a *separate* named remote. Let `gh` create both the fork and the remote — it emits a URL in whichever protocol `gh` is configured for, which is the only form that authenticates on hosts where `gh` is the sole GitHub credential:

```bash
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
