---
name: wiki-standard-adopt
category: Utility
description: "Adopts the wiki-standard operating model into an existing markdown wiki without touching its content; backs up conflicts, commits if git repo. Triggers: \"adopt wiki-standard\", \"adopt the standard\"."
defer_loading: true
---

# Wiki Standard Adopt

Installs the shared `wiki-standard` operating model (from the separate
`~/Projects/wiki-standard` repo) into a target markdown wiki, while leaving
every actual content note untouched. This is a one-way copy of *shared
infrastructure* (CLAUDE.md, conventions, templates, the check script) into
the target — never the reverse, and never anything content-related.

## When to use

- User asks to "adopt", "apply", or "install" wiki-standard into a vault.
- User wants an existing Obsidian-style wiki brought in line with the shared
  naming/metadata/linking/editing conventions.
- User wants to check/refresh an already-adopted wiki against a newer
  wiki-standard checkout (re-run this skill — it's idempotent).

**Do NOT use this to**: merge two wikis' content together, rewrite or
reformat existing notes to match the conventions, or touch anything outside
the standard file set listed below.

## Inputs

- **Target directory** — the wiki to adopt into. Defaults to the current
  working directory; accept an explicit path argument if given.
- **wiki-standard source** — resolved in this order:
  1. `$WIKI_STANDARD_HOME` env var, if set
  2. An explicit path argument, if the user gave one
  3. Default: `~/Projects/wiki-standard`

## Procedure

### 1. Resolve the target directory

```bash
TARGET_DIR="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
echo "$TARGET_DIR"
```

### 2. Confirm the target looks like a markdown wiki, and check git status

```bash
find "$TARGET_DIR" -maxdepth 2 -name "*.md" | head -10
git -C "$TARGET_DIR" rev-parse --is-inside-work-tree 2>/dev/null && echo "git repo" || echo "not a git repo"
```

If there are no `.md` files at all under the target, stop and confirm with
the user this is really the right directory before proceeding — don't
silently install into the wrong place.

### 3. Identify the content folders (safety step — do not skip)

List the top level of the target and explicitly name which entries are
**content** (untouchable) vs which are **standard infrastructure** (the only
things this skill may add/update):

```bash
ls -1a "$TARGET_DIR"
```

Standard infrastructure entries are exactly: `CLAUDE.md`, `conventions/`,
`templates/`, `scripts/check-standard.sh`, `scripts/lint-content.sh`,
`.wiki-standard-version`.
Everything else at the top level (e.g. `00_Inbox/`, `02_Areas/`,
`People/`, `Projects/`, `attachments/`, or whatever the vault's own
structure is) is **content** — state these folder names out loud in your
response before continuing, so it's on record what will NOT be touched.

### 4. Resolve the wiki-standard source

```bash
WIKI_STANDARD_SRC="${WIKI_STANDARD_HOME:-${2:-$HOME/Projects/wiki-standard}}"
if [ ! -d "$WIKI_STANDARD_SRC" ] || [ ! -f "$WIKI_STANDARD_SRC/scripts/install-standard.sh" ]; then
  echo "wiki-standard not found (or incomplete) at $WIKI_STANDARD_SRC"
  echo "Clone or create it there first — do not fabricate the standard files."
  exit 1
fi
```

If this fails, stop here and tell the user to set up `~/Projects/wiki-standard`
(or point `WIKI_STANDARD_HOME` at their checkout) before retrying.

### 5. Detect pre-existing conflicts and back them up first

Before running the installer, diff each standard path that already exists
in the target against the incoming version. Anything that already exists
and differs gets copied into a timestamped backup directory *before* it can
be overwritten:

```bash
BACKUP_DIR="$TARGET_DIR/.wiki-standard-backup-$(date +%Y%m%d-%H%M%S)"
CONFLICTS=()
for f in CLAUDE.md conventions templates scripts/check-standard.sh scripts/lint-content.sh; do
  if [ -e "$TARGET_DIR/$f" ] && [ -e "$WIKI_STANDARD_SRC/$f" ]; then
    if ! diff -rq "$TARGET_DIR/$f" "$WIKI_STANDARD_SRC/$f" >/dev/null 2>&1; then
      CONFLICTS+=("$f")
    fi
  fi
done

if [ ${#CONFLICTS[@]} -gt 0 ]; then
  mkdir -p "$BACKUP_DIR"
  for f in "${CONFLICTS[@]}"; do
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    cp -R "$TARGET_DIR/$f" "$BACKUP_DIR/$f"
  done
  echo "Backed up conflicting pre-existing files to: $BACKUP_DIR"
else
  echo "No pre-existing conflicts — nothing to back up."
fi
```

This is a belt-and-suspenders check: `install-standard.sh` is expected to
do its own backup too, but this skill verifies one exists regardless of
what the script does, since the report must be able to name a concrete
backup path whenever a conflict existed.

### 6. Run the installer

Prefer the real script:

```bash
bash "$WIKI_STANDARD_SRC/scripts/install-standard.sh" "$TARGET_DIR"
```

**Fallback only** if `install-standard.sh` is missing or clearly broken
(and step 5's backup has already run) — replicate its documented behavior
manually:

```bash
cp "$WIKI_STANDARD_SRC/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
mkdir -p "$TARGET_DIR/conventions" "$TARGET_DIR/templates" "$TARGET_DIR/scripts"
cp -R "$WIKI_STANDARD_SRC/conventions/." "$TARGET_DIR/conventions/"
cp -R "$WIKI_STANDARD_SRC/templates/." "$TARGET_DIR/templates/"
cp "$WIKI_STANDARD_SRC/scripts/check-standard.sh" "$TARGET_DIR/scripts/check-standard.sh"
cp "$WIKI_STANDARD_SRC/scripts/lint-content.sh" "$TARGET_DIR/scripts/lint-content.sh"
if [ -d "$WIKI_STANDARD_SRC/.git" ]; then
  git -C "$WIKI_STANDARD_SRC" rev-parse HEAD > "$TARGET_DIR/.wiki-standard-version"
else
  echo "unknown" > "$TARGET_DIR/.wiki-standard-version"
fi
```

### 7. Verify only the standard files changed

```bash
cat "$TARGET_DIR/.wiki-standard-version"
git -C "$TARGET_DIR" status --porcelain 2>/dev/null
```

Confirm the only new/modified paths are `CLAUDE.md`, `conventions/`,
`templates/`, `scripts/check-standard.sh`, `scripts/lint-content.sh`,
`.wiki-standard-version`. If anything under a content folder identified in
step 3 shows up as changed, stop and investigate before going further —
that should never happen.

### 8. Commit (only if the target is a git repo)

```bash
if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$TARGET_DIR" add CLAUDE.md conventions templates scripts/check-standard.sh scripts/lint-content.sh .wiki-standard-version
  git -C "$TARGET_DIR" commit -m "Adopt wiki-standard ($(cat "$TARGET_DIR/.wiki-standard-version" 2>/dev/null | cut -c1-12))"
else
  echo "Target is not a git repo — skipping commit."
fi
```

Stage only the standard files above — never `git add -A` or `.`, since the
wiki may have unrelated pending changes in its content folders.

## Report format

Always close with exactly these four sections:

**What was added**
List the standard files/dirs installed or updated (CLAUDE.md, conventions/,
templates/, scripts/check-standard.sh, scripts/lint-content.sh,
.wiki-standard-version), and whether a commit was made (with its
message/hash).

**What was backed up**
The timestamped backup path from step 5, and which files it contains — or
"nothing — no conflicts found" if `CONFLICTS` was empty.

**What was not touched**
Name the content folders identified in step 3 explicitly, e.g. "00_Inbox/,
02_Areas/, People/, attachments/ — untouched."

**How to update later**
Re-run this skill against the same target to pick up a newer wiki-standard
checkout, or re-run
`bash <wiki-standard>/scripts/install-standard.sh <target-dir>` directly.
To check for drift at any time without changing anything, run
`bash <target-dir>/scripts/check-standard.sh <target-dir> [<wiki-standard-path>]`.
To check the wiki's actual content health (orphan notes, broken links,
stale notes, open conflicts, missing connections) at Consolidate time, run
`bash <target-dir>/scripts/lint-content.sh <target-dir>` — report-only,
never edits anything.
