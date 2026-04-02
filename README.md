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

`gh` details:

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
