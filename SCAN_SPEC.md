# SCAN_SPEC.md — Nightly Scanner Guidance

Additions here eliminate recurring guesswork or false positives observed in prior scans.
Each entry names the exact confusion it resolves.

---

## Focus

Scan `scripts/` for correctness issues: broken shell contracts, misleading comments,
missing input validation, and false-positive lint reports.

---

## Improvements (2026-07-05)

### 1. Self-links are NOT broken links

Do NOT flag a wikilink as broken when the link target matches the file that contains it.
Self-links (`[[Note Name]]` inside `note-name.md`) are legal and intentional — they arise
from templates and copy-paste. Any link-checker must track self-references separately and
exclude them from the BROKEN_LINKS output entirely. A false positive here pollutes every
Consolidate-stage report.

Applies to: `scripts/lint-content.sh` — any awk/grep block that classifies unresolved links.

### 2. Shell function return-value comments must match actual behaviour

When a shell function's comment describes its return-value contract (e.g. "returns 0 if X"),
the description must match what the code actually returns. Shell convention: 0 = true/success,
non-zero = false/failure. A comment saying "missing dst is NOT a difference worth backing up"
on a branch that `return 0` is a contradiction — flag it as a documentation bug, not a
maybe-intentional design choice. The code is authoritative; the comment is wrong.

Applies to: any shell function with a `# Returns 0/1 if …` comment.

### 3. Scripts that call git must guard against a missing .git directory

`install-standard.sh` is designed to be run from an *installed copy* of the wiki-standard
(which has no `.git` directory), not only from the source repo. Any `git -C "$DIR" …` call
that is not inside a genuine git worktree will fail with a fatal error. Guard pattern:

```sh
if [ -d "$REPO_DIR/.git" ]; then
  COMMIT_HASH="$(git -C "$REPO_DIR" rev-parse HEAD)"
else
  COMMIT_HASH="unknown"
fi
```

Do NOT flag the absence of this guard as "uncertain" — it is a definite bug whenever the
script is expected to run outside a git repo. Document that expectation in the finding.

Applies to: `scripts/install-standard.sh` and any future install/update scripts.
