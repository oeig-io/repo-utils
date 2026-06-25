---
name: git-shortcuts-tool
description: gs (git status) and gp (add, commit, pull --rebase, push) shell shortcuts used across OEIG developer machines
compatibility: opencode
metadata:
  type: tool
  category: git
  scope: repo-utils
---

# Git Shortcuts Tool

## TOC

- [Summary](#summary)
- [What It Provides](#what-it-provides)
- [Installation](#installation)
- [Usage](#usage)
- [Behavior Notes](#behavior-notes)

## Summary

The purpose of this tool is to give every OEIG developer the same `gs` and `gp` git shortcuts so daily status checks and publish workflows are one keystroke away and consistent across machines.

This is important because the one-shot `gp` workflow bundles add, commit, rebase, status, and push into a single command — standardizing it prevents the half-pushed branches and forgotten `git add` steps that happen when each step is run by hand.

## What It Provides

| Command | Kind | Effect |
|---------|------|--------|
| `gs` | alias | `git status` |
| `gd` | alias | `git diff` (companion shortcut) |
| `gp [message]` | function | add all → commit → pull --rebase → status → push current branch to origin |

`gp` is a function rather than an alias because it chains several git commands and accepts an optional commit message argument.

## Installation

The standard deploy step is the bundled installer. It resolves its own absolute path and idempotently appends a fenced `source` block to your shell rc, so the shortcuts load in every new shell regardless of where `repo-utils/` is cloned.

```bash
./git-shortcuts-tool/scripts/install.sh            # default: target ~/.bashrc
./git-shortcuts-tool/scripts/install.sh ~/.zshrc   # target a different rc file
```

Then start a new shell (or `source ~/.bashrc`). The installer is safe to re-run — it detects its own marker block and skips if already present.

Confirm the install in a new shell:

```bash
type gs   # alias gs='git status '
type gp   # gp is a function
```

> 🔗 **Reference** - The installer sources `scripts/git-utilities.sh`, the file that defines `gs`, `gd`, and `gp`. To deploy manually instead, add a single line to your rc and point it at that file:
> ```bash
> source "/path/to/repo-utils/git-shortcuts-tool/scripts/git-utilities.sh"
> ```

> 💡 **Note** - These shortcuts historically shipped through the `chuboe-system-configurator` sourced dotfiles (`.my_bash`). This tool is the machine-agnostic replacement so every developer gets the same vocabulary without adopting that full configurator.

## Usage

Check working-tree state:

```bash
gs
```

Ship the current branch with a default message:

```bash
gp
```

Ship with a meaningful commit message:

```bash
gp "fix login redirect on expired session"
```

## Behavior Notes

- `git commit` runs with `|| true`, so an empty staging area (nothing to commit) does not abort the workflow — `gp` still pulls, rebases, and pushes any pending upstream changes.
- `gp` pushes the **current** branch to its tracked upstream (`git push -u origin HEAD`). Make sure you are on the branch you intend to publish.
- `gp` rebases on top of upstream before pushing, so keep branch histories linear.
- This file is **sourced**, not executed. It intentionally does not enable strict mode so it does not mutate the caller's shell options.

---

Tags: #tool-git #repo-management