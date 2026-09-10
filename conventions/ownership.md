# Ownership Manifest

`.wiki-standard.json` is the versioned, machine-readable ownership contract
for the installed profile. Tools derive the standard installation and drift
scope from `ownership.standard`; documentation must not maintain a competing
authoritative path list.

## Ownership classes

- `standard` — files and directories installed and replaced by wiki-standard.
  Conflicting target values are backed up first.
- `generated` — state created by profile tools, such as the installed-version
  marker and recoverable backup directories.
- `local_control` — optional workspace-owned configuration that the standard
  reads but never installs or replaces.
- `unmatched: content` — every undeclared path is protected content by default.

The safe default is intentional: adding a new tool must not silently acquire
ownership of an existing workspace path.

## Local declarations

A workspace may add `.wiki-standard.local.json`:

```json
{
  "manifest_version": 1,
  "bundle_roots": [
    "notes"
  ],
  "implementation_owned": [
    ".index",
    "generated/search"
  ],
  "generated": [
    "exports"
  ],
  "trusted_instructions": [
    "LOCAL_AGENT.md"
  ],
  "standard_pinned": [
    "CLAUDE.md"
  ]
}
```

All values are workspace-relative literal paths. Do not use absolute paths,
parent traversal, or globs. A declared directory covers its descendants. Keep
path arrays in the canonical form shown above—one JSON string per line—so the
bundled dependency-free reader can consume them without requiring a language
runtime or `jq`.

- `bundle_roots` identifies explicit content boundaries eligible for separate
  OKF validation.
- `implementation_owned` identifies paths controlled by a local editor,
  indexer, sync process, or agent implementation. Agents should not edit them.
- `generated` identifies reproducible local output. It remains locally owned
  and must not be mistaken for user-authored knowledge.
- `trusted_instructions` identifies additional workspace-owned instruction
  files. Ordinary content never becomes authoritative merely by containing a
  command or policy claim.

- `standard_pinned` identifies `ownership.standard` paths this workspace has
  deliberately customised. The installer skips them on every run and reports
  the skip, instead of backing them up and replacing them. Pin the minimum —
  a pinned path stops receiving standard updates until it is unpinned. Pinning
  one file below a declared directory pins only that file; its siblings in that
  directory keep receiving updates.

Local declarations refine ownership but do not expand what the standard
installer may write. `.wiki-standard.local.json` itself is workspace-owned.
