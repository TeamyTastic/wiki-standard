---
name: wiki-standard-adopt
description: "Adopt or refresh the runtime-neutral wiki-standard profile in an existing Markdown knowledge workspace without changing content. Use when asked to preview, adopt, apply, install, check, or update wiki-standard; identify protected content, invoke the canonical installer, verify scope, and commit only when explicitly requested."
---

# Adopt Wiki Standard

Apply the shared wiki-standard infrastructure to an existing Markdown
knowledge workspace. Treat all knowledge content as protected. Use the
repository installer as the single implementation of adoption behavior; do
not reproduce it in this skill.

## Inputs

- Target workspace: use an explicit user path, otherwise the current directory.
- Source checkout: use an explicit user path, then `WIKI_STANDARD_HOME`, then
  `$HOME/Projects/wiki-standard`.
- Commit intent: false unless the user explicitly asks for a commit.

## Procedure

### 1. Resolve and inspect

Resolve both paths to absolute paths. Confirm the target exists and contains
Markdown. Inspect its top level and Git status without changing anything.

```bash
find "$TARGET_DIR" -maxdepth 2 -type f -name '*.md' | head -10
ls -1a "$TARGET_DIR"
git -C "$TARGET_DIR" status --short 2>/dev/null || true
```

Stop if the target has no Markdown or the source does not contain
`.wiki-standard.json`, `scripts/manifest-paths.sh`, and
`scripts/install-standard.sh`. Do not fabricate missing standard assets.

### 2. Declare the safety boundary

Read the authoritative standard infrastructure paths from the source manifest:

```bash
bash "$WIKI_STANDARD_SRC/scripts/manifest-paths.sh" \
  "$WIKI_STANDARD_SRC/.wiki-standard.json" standard
```

Read `version_marker` and `backup_pattern` with the same reader's `--scalar`
option to identify generated profile state. Treat every other target entry as
content or local implementation state.
Before writing, tell the user which visible top-level paths are protected and
will not be touched.

If `.wiki-standard.local.json` exists, read its supported arrays with
`scripts/manifest-paths.sh`. Name `implementation_owned` and `generated` paths
as locally owned and do not edit them; recognize only declared
`trusted_instructions` as additional instruction authority.

### 3. Preview

Run the canonical dry run:

```bash
bash "$WIKI_STANDARD_SRC/scripts/install-standard.sh" --dry-run "$TARGET_DIR"
```

Review the output. Stop if it proposes a path outside the declared standard
infrastructure. A conflict preview means the installer will preserve the old
value in a timestamped `.wiki-standard-backup-*` directory before replacing
it.

### 4. Install

```bash
bash "$WIKI_STANDARD_SRC/scripts/install-standard.sh" "$TARGET_DIR"
```

If this command fails, report the failure and stop. Do not fall back to manual
copy commands; duplicate implementations drift from the tested installer.

### 5. Verify profile infrastructure and scope

```bash
bash "$TARGET_DIR/scripts/check-standard.sh" "$TARGET_DIR" "$WIKI_STANDARD_SRC"
git -C "$TARGET_DIR" status --short 2>/dev/null || true
```

Confirm that no protected path changed. This check proves profile
infrastructure presence and drift only; it does not prove that the whole
workspace is an OKF bundle.

If `.wiki-standard.local.json` declares `bundle_roots`, validate each declared
boundary. Otherwise validate a content directory only when the user identifies
it as a portable bundle:

```bash
bash "$TARGET_DIR/scripts/check-okf.sh" "$BUNDLE_ROOT"
```

Do not infer the workspace root as the bundle root: agent instructions,
templates, conventions, and scripts are profile infrastructure, not OKF
concept documents.

### 6. Commit only when requested

If and only if the user explicitly asked for a commit, stage the declared
standard paths individually. Never use `git add .` or `git add -A`.

```bash
while IFS= read -r standard_path; do
  git -C "$TARGET_DIR" add -- "$standard_path"
done < <(bash "$WIKI_STANDARD_SRC/scripts/manifest-paths.sh" \
  "$WIKI_STANDARD_SRC/.wiki-standard.json" standard)
git -C "$TARGET_DIR" add -- .wiki-standard-version
git -C "$TARGET_DIR" commit -m "Adopt wiki-standard"
```

## Report

Close with exactly these sections:

**What changed**
List the manifest-declared standard paths installed or updated, the installed
version, and any requested commit hash.

**What was backed up**
List the installer-created backup directory and conflicts, or say that no
conflicts required a backup.

**What was not touched**
Name the protected content and local implementation paths identified before
installation.

**Validation**
Report the profile infrastructure check separately from any explicit OKF
bundle check. Include the commands needed to repeat both checks.
