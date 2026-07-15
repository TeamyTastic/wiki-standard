# Metadata Conventions (YAML Frontmatter Schema)

Every note in a wiki-standard wiki starts with a YAML frontmatter block. This
is what makes notes queryable and lets both humans and agents reason about
the wiki's state without opening every file.

## Required Fields

| Field     | Description                                                        | Example                  |
|-----------|---------------------------------------------------------------------|---------------------------|
| `title`   | Human-readable title of the note (can differ from the filename)     | `title: Alex Chen`        |
| `type`    | One of the five standard note types (see below)                     | `type: person`            |
| `created` | ISO date the note was first captured                                | `created: 2026-07-04`     |
| `updated` | ISO date of the most recent substantive edit                        | `updated: 2026-07-04`     |
| `status`  | Where the note sits in the lifecycle (see below)                    | `status: active`          |

## Optional Fields

| Field       | Description                                                          | Example                              |
|-------------|------------------------------------------------------------------------|----------------------------------------|
| `description`| One-sentence summary; powers index.md entries, search snippets, and OKF consumers (see `okf.md`) | `description: Moneghetti's 20min fartlek of shrinking reps.` |
| `tags`      | Free-form topical tags, for cross-cutting grouping beyond `type`        | `tags: [strategy, q3-2026]`            |
| `aliases`   | Alternate names this note should also resolve under for linking         | `aliases: [AC, Alexandra Chen]`        |
| `related`   | Explicit list of related note titles, supplementing inline wikilinks     | `related: [[Growth Strategy]]`         |
| `source`    | Where this note's content originated (transcript, conversation, doc)     | `source: 2026-07-04 planning call`     |
| `confidence`| Marks a note (or a claim within it) as provisional                      | `confidence: unverified`               |
| `archived_from` | If this note was restored from `_archive/`, the original path       | `archived_from: _archive/2026-01-old.md` |
| `merge_of`  | If this note is the result of merging duplicates, what was merged        | `merge_of: [alex-chen-v1.md]`          |

Optional fields should be added as needed, not front-loaded into every note —
an empty `tags: []` on every note is noise. Add a field when it carries real
information.

## Allowed `status` Values

| Value       | Meaning                                                                 |
|-------------|--------------------------------------------------------------------------|
| `draft`     | Just captured or being clarified; not yet a reliable reference (Capture/Clarify stages) |
| `staged`    | Living in or associated with `_staging/`; uncertain, unverified, or provisional |
| `active`    | Clarified, connected, in current use — the normal resting state for a live note |
| `archived`  | Retired; content preserved but no longer part of the active wiki       |

These map directly to the note lifecycle in `CLAUDE.md` (capture → clarify →
connect → consolidate → archive): `draft` covers Capture/Clarify, `active`
covers Connect/Consolidate, `archived` covers Archive, and `staged` is the
side-channel for uncertain material at any point in that flow.

## Allowed `type` Values

Matches the five templates in `templates/`:

| Value      | Template            | Use for                                                |
|------------|---------------------|---------------------------------------------------------|
| `concept`  | `templates/concept.md`  | An idea, term, framework, or abstract subject           |
| `person`   | `templates/person.md`   | An individual (colleague, contact, historical figure)   |
| `project`  | `templates/project.md`  | A bounded effort with a goal and (eventually) an end     |
| `decision` | `templates/decision.md` | A specific choice made, with reasoning and alternatives  |
| `meeting`  | `templates/meeting.md`  | A record of a specific meeting or call                   |

If a note doesn't cleanly fit one of these five, that's a signal to either
pick the closest fit and note the mismatch, or — if this happens repeatedly
for a class of notes — propose a new type via an update to this file and a
new template, rather than leaving `type` blank or inventing an ad-hoc value
per note.

## Example Frontmatter

```yaml
---
title: CRM Migration
type: project
created: 2026-05-12
updated: 2026-07-04
status: active
tags: [engineering, q3-2026]
related: [[Alex Chen]], [[Vendor Selection Decision]]
---
```
