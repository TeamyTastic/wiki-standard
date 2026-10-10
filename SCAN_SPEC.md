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

---

## Improvements (2026-10-10)

### 4. Diagnosing awk logic bugs requires the full loop, not just the print statement

When a lint script produces false positives (e.g. broken links, missing matches), the root
cause is almost always a flag variable (`matched`, `found`, `seen`) that is never set or
never reset between iterations — not the output `print` statement itself. To confirm the
bug, you need the full `for`/`while` loop body, not just the line that writes to output.

If the full loop is not visible in the snippet: assume the bug is a missing flag
initialisation or a missing `self_match` branch, and write the fix at that level. Do NOT
hedge to REVIEW just because the initialisation line is off-screen — the output line alone
is sufficient evidence of the logic error.

Applies to: `scripts/lint-content.sh` — any awk block that sets a `matched` or equivalent
flag inside a loop and uses it to control output after the loop ends.

### 5. "unknown" is the correct git-version fallback; downstream tools must tolerate it

When a `.git` guard (see Improvement #3) writes `"unknown"` to a version file, this is
intentional and correct — do not downgrade the finding to REVIEW on the grounds that
downstream tools "might require a real hash." Wiki-standard's version-tracking is
informational only; no build step, no migration, and no install check gates on a parseable
hash. Any future script that does gate on a hash must be fixed at that script, not by
making the fallback harder.

Applies to: any script that writes a `.wiki-standard-version` file.

### 6. Prefer fail-fast (exit 2) for invalid numeric CLI arguments in scripts/

Scripts in `scripts/` are used in both CI pipelines and direct developer invocation.
When validating numeric options (e.g. `--stale-months`), reject non-integer input with
`exit 2` and a clear error message rather than silently substituting a default. Silent
defaults hide misconfiguration in CI and produce misleading reports. Pattern:

```sh
case $2 in
  ''|*[!0-9]*) echo "Error: --stale-months requires a positive integer" >&2; exit 2 ;;
esac
```

Do NOT recommend a warning-and-continue approach unless the option is explicitly documented
as having a safe default — that would require evidence in the script's usage text.

Applies to: `scripts/lint-content.sh` and any future script that accepts numeric thresholds.
