# Metadata Conventions

Every concept document starts with YAML frontmatter. Metadata makes notes
queryable and gives people, agents, and deterministic tools the same basic
contract without requiring a shared application.

## Portable minimum

| Field | Requirement | Description |
|---|---|---|
| `type` | Required | Non-empty, open-vocabulary concept kind |
| `title` | Recommended | Human-readable display name |
| `description` | Recommended | One-sentence summary for indexes and retrieval |
| `tags` | Optional | YAML list of cross-cutting categories |
| `status` | Optional | OKF lifecycle: `draft`, `stable`, or `deprecated` |
| `sources` | Optional | Structured provenance mappings |

`type` is deliberately open. The templates provide `concept`, `person`,
`project`, `decision`, and `meeting` as useful starting types, not a closed
registry. Consumers must treat unknown values as generic concepts.

Absent `status` means `stable`. Use `draft` for incomplete or unreviewed
knowledge and `deprecated` for material preserved for history but no longer
current.

## Operating-profile extensions

| Field | Description | Example |
|---|---|---|
| `created` | Original capture date, when known | `created: 2026-07-04` |
| `updated` | Most recent substantive edit date, when known | `updated: 2026-07-04` |
| `aliases` | Alternate display or lookup names | `aliases: [AC, Alexandra Chen]` |
| `workflow_stage` | `capture`, `clarify`, `connect`, `consolidate`, or `archive` | `workflow_stage: connect` |
| `confidence` | Explicit local uncertainty marker | `confidence: unverified` |
| `archived_from` | Original path when restoring archived content | `archived_from: _archive/old.md` |
| `merge_of` | Paths merged into this concept | `merge_of: [alex-chen-v1.md]` |

Add extension fields only when they carry information. Never invent a date,
actor, verification event, or source to fill an empty slot. Preserve unknown
fields during targeted edits.

## Provenance

Use OKF v0.2 `sources`, where every entry has a `resource`:

```yaml
sources:
  - id: planning-call
    resource: /meetings/2026-07-04-planning.md
    title: Planning call
```

Use an absolute URL, a bundle-relative path, or a relative path. `id` is
recommended when a body claim uses a matching footnote. A Markdown body link
is navigation; it must not be interpreted as verified provenance.

Legacy scalar `source` fields may be read as compatibility input. New notes
and explicit migrations use `sources`.

## Example

```yaml
---
type: project
title: CRM Migration
description: Replaces the legacy CRM without interrupting customer support.
status: stable
workflow_stage: connect
created: 2026-05-12
updated: 2026-07-04
tags: [engineering, q3-2026]
sources:
  - id: charter
    resource: /references/crm-migration-charter.md
---
```
