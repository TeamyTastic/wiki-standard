# wiki-standard

A portable operating profile for Markdown knowledge workspaces.

wiki-standard gives people and software agents one shared contract for naming,
metadata, linking, provenance, safe editing, and knowledge lifecycle—without
requiring a particular editor, model, agent runtime, storage service, or
automation product.

It installs operating infrastructure only. Your notes remain independent and
under your control.

## User story

> As a knowledge-workspace owner, I want to adopt and update one operating
> model without changing my content, so I can move between editors, models,
> and agent runtimes without migrating or locking in my notes.

## Guarantees

- **Runtime neutral:** [`AGENT.md`](AGENT.md) is canonical. `AGENTS.md` and
  `CLAUDE.md` are thin discovery adapters with no independent policy.
- **Content safe:** undeclared workspace paths default to protected content.
- **Previewable:** every adoption can be inspected with `--dry-run`.
- **Recoverable:** conflicting standard infrastructure is backed up before it
  is replaced.
- **Explicitly owned:** [`.wiki-standard.json`](.wiki-standard.json) is the
  machine-readable authority for installation and generated state.
- **Portable:** concept documents follow the
  [Open Knowledge Format v0.2 profile](conventions/okf.md), with standard
  Markdown links and structured provenance.
- **Trust bounded:** ordinary notes and imported material are data, not agent
  instructions.

## Quick start

Requirements: Bash 3.2 or newer and standard Unix command-line tools. Git is
used to clone and update the source checkout and to record an exact installed
revision when available.

Clone the standard separately from the workspace that contains your notes:

```bash
git clone https://github.com/TeamyTastic/wiki-standard.git
cd wiki-standard
STANDARD_DIR="$PWD"
```

Preview the exact adoption scope:

```bash
bash "$STANDARD_DIR/scripts/install-standard.sh" --dry-run /path/to/workspace
```

Install after reviewing the preview:

```bash
bash "$STANDARD_DIR/scripts/install-standard.sh" /path/to/workspace
```

Verify the installed profile:

```bash
bash /path/to/workspace/scripts/check-standard.sh \
  /path/to/workspace "$STANDARD_DIR"
```

The installer never migrates, rewrites, moves, or normalizes content. Content
migration is a separate operation requiring explicit authorization.

## What adoption installs

The installer derives its scope from
`.wiki-standard.json` → `ownership.standard`; documentation and scripts do not
maintain competing authoritative path lists.

| Path | Purpose |
|---|---|
| `.wiki-standard.json` | Versioned ownership and installation manifest |
| `WIKI_PROFILE.md` | Normative Profile v1 contract |
| `AGENT.md` | Runtime-neutral operating instructions |
| `AGENTS.md`, `CLAUDE.md` | Compatibility discovery adapters |
| `conventions/` | Naming, metadata, linking, ownership, OKF, and editing rules |
| `templates/` | Optional starting shapes for common concept types |
| `scripts/` | Installation, drift, bundle, manifest, and content-health checks |

The installer also writes `.wiki-standard-version`. When an installed standard
path differs from the incoming version, its previous value is copied into a
timestamped `.wiki-standard-backup-*` directory before replacement.

Everything else remains workspace-owned content or local implementation state.

## Ownership and local declarations

The default ownership rule is deliberately conservative:

```text
declared standard path  → wiki-standard may install or update it
declared generated path → profile or local implementation state
undeclared path         → protected content
```

A workspace may add `.wiki-standard.local.json` to refine local ownership
without expanding installer authority:

```json
{
  "manifest_version": 1,
  "bundle_roots": [
    "notes"
  ],
  "implementation_owned": [
    ".index"
  ],
  "generated": [
    "exports"
  ],
  "trusted_instructions": [
    "LOCAL_AGENT.md"
  ]
}
```

Paths are workspace-relative literals. Declared directories cover their
descendants. Absolute paths, parent traversal, and globs are not accepted.
See [the ownership convention](conventions/ownership.md) for the complete
contract.

## Workspace profile versus OKF bundle

An adopted workspace is not automatically one OKF bundle. Profile
infrastructure such as `AGENT.md`, templates, and scripts is not knowledge
content.

Use a dedicated content directory as the bundle root, or export concepts into
a clean bundle. Validate that explicit boundary separately:

```bash
bash /path/to/workspace/scripts/check-okf.sh /path/to/workspace/notes
```

This separation keeps three different questions honest:

1. Is the wiki-standard profile installed and unmodified?
2. Does each concept document meet the portable minimum?
3. Is this explicitly selected directory a valid minimum OKF document set?

## Knowledge lifecycle

The operating model uses five stages:

```text
capture → clarify → connect → consolidate → archive
```

- **Capture:** preserve the raw thought, fact, reference, or synthesis.
- **Clarify:** type and structure it; flag uncertainty rather than hiding it.
- **Connect:** add useful standard Markdown relationships.
- **Consolidate:** review duplicates, drift, broken links, and conflicts.
- **Archive:** retire knowledge without silently deleting it.

Read [`AGENT.md`](AGENT.md) for the actionable criteria and
[`conventions/editing-rules.md`](conventions/editing-rules.md) for the
archive-before-replace policy.

## Checks

All bundled tools are deterministic and report-only unless explicitly named
as the installer.

```bash
# Profile infrastructure presence and drift
bash "$STANDARD_DIR/scripts/check-standard.sh" \
  /path/to/workspace "$STANDARD_DIR"

# Minimum OKF contract at an explicit content boundary
bash "$STANDARD_DIR/scripts/check-okf.sh" /path/to/workspace/notes

# Orphans, broken links, stale notes, conflicts, and connection suggestions
bash "$STANDARD_DIR/scripts/lint-content.sh" /path/to/workspace
```

The content linter understands standard Markdown links and compatible legacy
wikilinks. It reports findings for review; it never edits notes.

## Updating an adopted workspace

```bash
git -C "$STANDARD_DIR" pull --ff-only
bash "$STANDARD_DIR/scripts/install-standard.sh" --dry-run /path/to/workspace
bash "$STANDARD_DIR/scripts/install-standard.sh" /path/to/workspace
```

Re-running the installer is idempotent. Local differences in standard-owned
paths are backed up; undeclared content paths remain outside installation
scope.

## Optional adapters

[`skills/wiki-standard-adopt/SKILL.md`](skills/wiki-standard-adopt/SKILL.md)
wraps the canonical adoption flow in the common Agent Skills directory shape.
Register it using the chosen runtime's skill-loading mechanism, or invoke
`scripts/install-standard.sh` directly. The shell installer remains the
runtime-independent write path.

Product-, editor-, or runtime-specific integrations are adapters. They may
discover `AGENT.md`, invoke the installer, or render content, but they do not
redefine profile conformance.

## Repository contents

This repository contains the operating model and its tests—no personal notes,
example vault, or private content. Each adopting workspace keeps its own
storage, history, access controls, and content structure.

## Non-goals

- synchronizing or hosting notes;
- prescribing what subjects you write about;
- choosing an editor, model, runtime, indexer, or retrieval engine;
- treating the whole workspace root as an OKF bundle;
- migrating content during profile adoption.
