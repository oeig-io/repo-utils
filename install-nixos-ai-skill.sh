#!/usr/bin/env bash
# install-nixos-ai-skill.sh - (Re)generate the nixos-ai-skill from
# marceloeatworld/nixos-ai-skill (always-latest from upstream main)
#
# This script shallow-clones https://github.com/marceloeatworld/nixos-ai-skill,
# copies the upstream SKILL.md and references/ directory into
# wi-nixos/nixos-ai-skill-tool/, validates the frontmatter, rewrites the
# skill name to satisfy the workspace -tool suffix convention, and appends
# a generation trailer with the upstream commit SHAs.
#
# wi-base/refresh-skills.sh publishes wi-nixos/nixos-ai-skill-tool/ as
# .pi/skills/nixos-ai-skill-tool/ and .opencode/skills/nixos-ai-skill-tool/
# using the directory form (so references/ inside the skill resolves
# correctly through the symlink to the real on-disk location).
#
# wi-nixos/.gitignore excludes nixos-ai-skill-tool/ - this script recreates
# it on every run, so re-run after a `git pull` or whenever you want the
# latest upstream references.
#
# If git is missing this script fails fast; unlike install-mcpc-skill.sh
# there is no bootstrap install (git is required by every other workflow
# here and is expected to be present).
#
# Usage: ./repo-utils/install-nixos-ai-skill.sh
# Exit codes: 0 = success, non-zero = error

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$REPO_ROOT/wi-nixos/nixos-ai-skill-tool"
README_FILE="$SKILL_DIR/README.md"
UPSTREAM_REPO="https://github.com/marceloeatworld/nixos-ai-skill.git"

# --- prerequisites -----------------------------------------------------------

if ! command -v git >/dev/null 2>&1; then
    echo "Error: git not found on PATH. Install git first." >&2
    exit 1
fi

# --- fetch upstream ----------------------------------------------------------
# Shallow clone into a temp directory; clean up on exit.
work=$(mktemp -d)
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"; rm -rf "$work"' EXIT

if ! git clone --depth 1 --quiet "$UPSTREAM_REPO" "$work/upstream" 2>/dev/null; then
    echo "Error: failed to clone $UPSTREAM_REPO" >&2
    exit 1
fi

upstream_commit=$(git -C "$work/upstream" rev-parse --short HEAD)
upstream_date=$(git -C "$work/upstream" log -1 --format=%ci)

# Capture upstream provenance from references/.wiki-version (if present) so we
# can stamp the generation trailer with the exact content-source commits we
# pulled. The file uses `key='value'` format with single quotes.
declare -A commits=()
version_file="$work/upstream/references/.wiki-version"
if [[ -f "$version_file" ]]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[a-z_]+_(commit|date)$ ]] || continue
        # Strip surrounding single quotes if present.
        value="${value%\'}"
        value="${value#\'}"
        commits[$key]="$value"
    done < "$version_file"
fi

# --- write SKILL.md atomically ------------------------------------------------
# Mirror install-mcpc-skill.sh validation: frontmatter must have a `name:`
# matching ^[a-z0-9]+(-[a-z0-9]+)*$, and the workspace -tool suffix convention
# requires the published name end in `-tool`. Upstream uses `nixos`; we
# rewrite to `nixos-ai-skill-tool`.
mkdir -p "$SKILL_DIR"

if ! cp "$work/upstream/SKILL.md" "$tmp_file"; then
    echo "Error: failed to copy upstream SKILL.md." >&2
    exit 1
fi

skill_name=$(sed -n '/^---$/,/^---$/{/^---$/d; /^name: /p}' "$tmp_file" | sed 's/^name: //' | head -1)

if [[ -z "$skill_name" ]]; then
    echo "Error: upstream SKILL.md is missing frontmatter 'name'." >&2
    exit 1
fi

if [[ ! "$skill_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "Error: nixos-ai-skill has invalid name '$skill_name' (must be lowercase, digits, hyphens)." >&2
    exit 1
fi

# Workspace convention requires the type suffix on the published skill name
# (refresh-skills.sh audits this). Rewrite 'nixos' -> 'nixos-ai-skill-tool'
# before write. Mirror install-mcpc-skill.sh's rewrite of 'mcpc' -> 'mcpc-tool'.
if [[ "$skill_name" == "nixos" ]]; then
    sed -i '0,/^name: nixos$/{s|^name: nixos$|name: nixos-ai-skill-tool|}' "$tmp_file"
    skill_name="nixos-ai-skill-tool"
    echo "Note: rewrote name 'nixos' -> 'nixos-ai-skill-tool' (workspace convention requires type suffix)"
fi

if [[ "$skill_name" != "nixos-ai-skill-tool" ]]; then
    echo "Warning: expected skill name 'nixos-ai-skill-tool' but got '$skill_name'." >&2
fi

# Append a generation marker so anyone reading the file can see which
# upstream snapshot produced this skill and when. The HTML comment is after
# the closing frontmatter `---` and is invisible to markdown renderers and
# skill loaders.
{
    cat "$tmp_file"
    echo ""
    echo "<!-- Generated from marceloeatworld/nixos-ai-skill @ ${upstream_commit} (${upstream_date}) on $(date -u +%Y-%m-%d) by repo-utils/install-nixos-ai-skill.sh -->"
    if [[ ${#commits[@]} -gt 0 ]]; then
        echo "<!-- Content sources (.wiki-version):"
        for k in nixdev_commit nixpkgs_commit pills_commit release_commit; do
            [[ -n "${commits[$k]:-}" ]] && echo "<!--   $k=${commits[$k]}"
        done
        echo "<!-- -->"
    fi
} > "$SKILL_DIR/SKILL.md"

# --- copy references ----------------------------------------------------------
# Replace the previous references/ wholesale - the entire content is
# auto-generated and tracked only by upstream's commit, so a fresh clone is
# always canonical.
rm -rf "$SKILL_DIR/references"
cp -r "$work/upstream/references" "$SKILL_DIR/references"

ref_count=$(find "$SKILL_DIR/references" -name '*.md' | wc -l)

echo "Refreshed nixos-ai-skill: $SKILL_DIR/"
echo "  upstream commit: $upstream_commit"
echo "  upstream date:   $upstream_date"
echo "  skill name:      $skill_name"
echo "  references:      $ref_count files"
echo ""
# Recreate README on every run so it stays accurate and the script stays
# idempotent. Don't hand-edit; this file is regenerated each run.
cat > "$README_FILE" <<'EOF'
# nixos-ai-skill

This directory and the `SKILL.md` skill index inside it are generated by
[`repo-utils/install-nixos-ai-skill.sh`](../repo-utils/install-nixos-ai-skill.sh).

Do not edit these files by hand - they are recreated on each run of that
script from the latest `marceloeatworld/nixos-ai-skill` upstream (shallow
clone of `main`). Re-run after a `git pull` or whenever you want the latest
upstream references:

```bash
./repo-utils/install-nixos-ai-skill.sh
```

The skill directory is `.gitignore`d at the `wi-nixos/` repo root - its files
are generated on demand and never committed.

Then run `./wi-base/refresh-skills.sh` to (re)create the `.pi/skills/` and
`.opencode/skills/` symlinks.
EOF

echo "Next: run ./wi-base/refresh-skills.sh to (re)create the .pi/skills/ and .opencode/skills/ symlinks."