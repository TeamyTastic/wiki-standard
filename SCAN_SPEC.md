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
if [ -e "$REPO_DIR/.git" ]; then
  COMMIT_HASH="$(git -C "$REPO_DIR" rev-parse HEAD)"
else
  COMMIT_HASH="unknown"
fi
```

Use `-e`, not `-d`: linked worktrees and submodules store `.git` as a file.
Checking only `git -C "$REPO_DIR" rev-parse HEAD` is insufficient because Git
walks up to an ancestor worktree and can return an unrelated repository's commit.

Do NOT flag the absence of this guard as "uncertain" — it is a definite bug whenever the
script is expected to run outside a git repo. Document that expectation in the finding.

Applies to: `scripts/install-standard.sh` and any future install/update scripts.

---

## Improvements (2026-08-06)

### 4. Self-link detection must use the ownership graph, not just filename equality

Spec item 1 says "exclude self-links from BROKEN_LINKS." The implementation question
that caused hedging tonight: what counts as a self-link when the awk ownership pass
runs? Answer: a link is a pure self-link when **every owner in the ownership graph
equals the source file** — i.e. `matched` stays 0 not because no file references the
target, but because the only file that does is `$1` itself. In that case the link is
intentional and MUST be skipped, not written to BROKEN_LINKS.

Concretely: if a note `foo.md` contains `[[foo]]` and `foo.md` is the only file in the
ownership map that lists `foo` as a target, `matched` will be 0 at the end of the awk
pass — but that is NOT a broken link. The fix is a separate `self_link` counter
incremented when `owner == source`, and a guard that skips BROKEN_LINKS when
`matched == 0 && self_link > 0`.

Do NOT flag this ambiguous case as "uncertain." The ownership-graph rule is definitive:
zero external owners + at least one self-owner = pure self-link = not broken.

Applies to: `scripts/lint-content.sh` — the awk ownership block around line 290.

### 5. Git-guard requirement extends to skills/ scripts, not just scripts/

Spec item 3 names `scripts/install-standard.sh` as the primary target. Tonight's
finding was in `skills/wiki-standard-adopt/SKILL.md` — a skills script that also
calls `git -C "$WIKI_STANDARD_SRC" rev-parse HEAD` with no guard. The rule applies
equally to any file under `skills/` that shells out to git against a directory that
may not be a git repo at runtime.

The authoritative guard pattern (from item 3) requires a `.git` entry directly in
the source directory, using `-e` because `.git` is a *file* in worktrees and submodules:

```sh
if [ -e "$WIKI_STANDARD_SRC/.git" ] && \
   STANDARD_VERSION=$(git -C "$WIKI_STANDARD_SRC" rev-parse HEAD 2>/dev/null); then
  printf '%s\n' "$STANDARD_VERSION" > "$TARGET_DIR/.wiki-standard-version"
else
  echo "unknown" > "$TARGET_DIR/.wiki-standard-version"
fi
```

Do NOT mark the absence of this guard as "uncertain" — it is a definite bug. Confidence
is 4/5 (AUTOFIX), not lower, because the runtime context (installed copy, no `.git`)
is explicitly documented in item 3.

Applies to: `skills/wiki-standard-adopt/SKILL.md` and any future skill that installs
or inspects the wiki-standard source directory.

### 6. SCAN_SPEC entries are authoritative — do not downgrade their verdict

When a SCAN_SPEC entry already classifies a pattern as a "definite bug" or "not
uncertain," the scanner MUST NOT re-label the same finding as "uncertain" in its
report. The spec is the resolved ground truth from a prior scan cycle; hedging on
an already-resolved question adds noise and delays fixes.

Operationally: before assigning a safety score to any finding, check whether a
SCAN_SPEC item already covers that finding. If it does, inherit the spec's verdict
directly. Only assign a lower confidence score when the finding is genuinely *new*
and has no matching spec entry.

Applies to: the scanner's scoring and reporting phase for all findings.
