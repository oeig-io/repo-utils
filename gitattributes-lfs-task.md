# Git Attributes and LFS Task

The purpose of this task is to apply a standard `.gitattributes` configuration to a repository so that Git LFS tracks large binary assets consistently across every repo in the organization.

This is important because without LFS, large binaries bloat the git history, slow clones, and make merges fail with meaningless text-diff conflicts. Applying one canonical `.gitattributes` keeps behavior identical across all repos.

## Scope

This standard applies to **every repository whose origin is under the `oeig-io` GitHub organization**. Other repos (third-party forks, upstream mirrors) are out of scope.

The LFS binary-asset block is universal: the same file extensions mean the same thing in every repo, and the block is inert on repos that hold no binaries — no match, no effect. Repos not under `oeig-io` keep their own conventions.

## Prerequisites

- Git LFS installed on the host (verify with `git lfs version`).
- LFS enabled on the host once, globally: `git lfs install` (run once per developer machine). This installs the smudge/clean filters so tracked patterns route binaries through LFS automatically. Without this, clones of LFS-enabled repos will fetch pointer files instead of real content.

## Apply the Standard

The canonical LFS block lives in this repository at [`.gitattributes`](.gitattributes). For repos with no existing `.gitattributes`, copy it verbatim into the repository root:

```bash
cp repo-utils/.gitattributes <target-repo>/.gitattributes
cd <target-repo>
git add .gitattributes
```

For repos that already have a `.gitattributes` with line-ending rules but no LFS block, prepend the LFS block above the existing content, leaving the repo-specific line-ending rules untouched below:

```bash
{ cat repo-utils/.gitattributes; echo; cat <target-repo>/.gitattributes; } > /tmp/ga && mv /tmp/ga <target-repo>/.gitattributes
git add .gitattributes
```

For repos whose `.gitattributes` already contains the LFS block (the canonical lines from `repo-utils/.gitattributes` are present at the top), leave it as-is — it already follows the standard.

Do not paraphrase, trim, or hand-edit the LFS block. The single source of truth is the `repo-utils/.gitattributes` file. If the standard must change, edit `repo-utils/.gitattributes` first and re-copy — never maintain per-repo variants of the LFS block.

## What the Configuration Does

The `repo-utils/.gitattributes` file routes each listed file extension through the LFS filter:

```
filter=lfs diff=lfs merge=lfs -text
```

This tells git to store the binary content in LFS (not the object database), skip text-based diff/merge attempts, and prevent git from normalizing line endings inside the file. The file extensions covered are:

- Office documents: `.pdf`, `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`, `.odt`
- Raster images: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`
- Vector/design sources: `.svg`, `.psd`, `.ai`, `.sketch`, `.fig`
- Audio: `.mp3`, `.wav`
- Video: `.mp4`, `.mov`, `.avi`
- Archives: `.zip`

## Line-Ending Rules Are Separate

This LFS configuration does **not** set line-ending normalization for text/script files. Repositories that need `eol=lf` rules for `.sh`, `.sql`, `.conf`, etc. keep those as a separate block in their own `.gitattributes` appended **after** the LFS patterns. The line-ending block is intentionally per-repo — different repos use different languages and extensions (`netbird` uses `*.go`, `pi` needs `*.bat eol=crlf` for Windows scripts, etc.). Do not try to universalize it.

Example merged file (LFS standard on top, repo-specific line-ending rules below):

```gitattributes
*.pdf filter=lfs diff=lfs merge=lfs -text
... (standard LFS block from repo-utils/.gitattributes)

# Repository-specific line-ending rules
*.sh text eol=lf
*.conf text eol=lf
```

## Verify

After copying and committing `.gitattributes`, confirm LFS has picked up the patterns:

```bash
git lfs track
```

The output should list every extension from `repo-utils/.gitattributes` against the local `.gitattributes` file. Any newly added binary matching those extensions will now be stored through LFS rather than the regular git object store.

> **⚠️ Warning** - LFS only applies to files committed **after** `.gitattributes` is in place. Files already in history stay in the regular object store. To retroactively migrate existing files, use `git lfs migrate import` — confirm with the repo owner first, since this rewrites history.

## Commit

Commit `.gitattributes` on its own with a clear message so the change is easy to find later:

```bash
git commit -m "chore: add standard .gitattributes for LFS tracking"
```

Tags: #task-gitattributes #task-lfs #tool-git