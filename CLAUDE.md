# CLAUDE.md — Operating Model for This Wiki

This file tells an LLM agent (Claude Code or otherwise) how to work inside a
markdown wiki that has adopted the **wiki-standard**. The standard is a set of
shared conventions, templates, and scripts — it does NOT define or own any of
the actual content in this wiki. Content is private and local; only the
operating model is shared. See `README.md` (in the wiki-standard source repo)
for the philosophy behind that split.

If this file's guidance ever conflicts with something more specific written
elsewhere in this wiki (a local note, a project-specific rule), the local
instruction wins for that wiki — but flag the conflict to the user rather than
silently picking one.

## Folder Conventions

A wiki adopting this standard is expected to have (at minimum):

- **Content folders** — wherever the user's actual notes live (e.g. `notes/`,
  `areas/`, or a flat root). Wiki-standard never dictates these names or
  touches their contents. This is the private, independent part.
- **`conventions/`** — the rules this file points to (naming, metadata,
  linking, editing). Shared, updated via `scripts/install-standard.sh`.
- **`templates/`** — starting structure for each note type. Copy, don't
  reference live — a template used in a note becomes that note's own content
  from that point on.
- **`_staging/`** — landing zone for uncertain, half-formed, or unverified
  material. See "Staging Uncertain Material" below.
- **`_archive/`** — where superseded or removed content goes. Nothing is ever
  just deleted; it moves here first. See "Preserving Information" below.
- **`log.md`** — a single append-only operation log at the wiki root. See
  "Operation Log" below.
- **`scripts/`** — `check-standard.sh` (verifies the install) and whatever
  local automation the wiki owner has added.

Do not invent new top-level shared folders without updating `conventions/`
first — the point of the standard is that every wiki that adopts it looks
similar at the operating-model layer, even though content differs completely.

## Naming

Full rules: `conventions/naming.md`. Summary: lowercase-hyphenated file names,
no spaces, evergreen notes (concepts/people/projects) have no date prefix,
time-bound notes (meetings, daily logs) are prefixed `YYYY-MM-DD-`.

## Frontmatter

Full schema: `conventions/metadata.md`. Every note gets YAML frontmatter with
at minimum `title`, `type`, `created`, `updated`, `status`. Check a note's
`type` field before assuming which template governs its shape.

## Linking

Full rules: `conventions/linking.md`. Wikilinks (`[[Note Name]]`) are the
default way to connect notes. Don't leave a concept unlinked just because the
target note doesn't exist yet — read the linking conventions for how stubs and
red links are handled.

## Safe Editing

Full rules: `conventions/editing-rules.md`. The short version: edits are
additive by default, conflicting information is surfaced rather than silently
resolved, and major rewrites are archived-before-replaced, not overwritten in
place.

## Preserving Information — Never Silently Delete

This is a hard rule, not a preference. An agent must never remove content from
a note (or remove a whole note) without a trace. Every removal falls into one
of these buckets:

1. **Superseded content** → move the old version to `_archive/`, dated, before
   writing the replacement. Keep a one-line pointer in the new note
   (`> superseded: see _archive/2026-06-01-old-name.md`) if the change is
   substantial.
2. **Uncertain / unverified content already in a note** → do not delete it.
   Either move it to `_staging/` with a note on why it's uncertain, or leave it
   in place under a `## Conflicts` or `## Unverified` heading (see
   `conventions/editing-rules.md`).
3. **Genuinely redundant duplicates** (e.g. two identical notes created by
   accident) → merge into one, archive the other, and log the merge in the
   surviving note's frontmatter or a `## Merge Log` section.

If you are ever unsure whether something counts as "safe to remove," it
doesn't — archive it and let the user decide.

## Staging Uncertain Material

Use `_staging/` (equivalently `_uncertain/` if the wiki owner prefers that
name — pick one per-wiki and stay consistent) for:

- Notes captured quickly (voice memo dumps, meeting fragments, half-formed
  ideas) that haven't been clarified yet.
- Content whose factual accuracy is in doubt — a claim you can't verify, a
  detail that might be wrong, a note where two sources disagree.
- Anything an agent generates on the user's behalf that hasn't been reviewed
  (auto-summaries, extracted action items, inferred connections).

Staged notes still get frontmatter (`status: staged` — see
`conventions/metadata.md`) so they're queryable, but they are NOT linked into
the main body of the wiki as if they were settled fact. Don't wikilink from a
mature note into a staging note without flagging it as provisional.

## Avoiding Silent Deletion (Restated as a Check)

Before any `rm`, any overwrite of a whole file, or any large deletion within a
note: stop and ask "where does this content go, not just does it go." Record
the removal in `log.md` (see "Operation Log" below) — what was removed, when,
and why. This is the same principle as "Preserving Information" above, stated
as a pre-action checklist rather than a policy.

## Operation Log

Every wiki adopting this standard keeps a single append-only `log.md` at its
root. It is a running record of non-trivial operations an agent performs on
the wiki — not a substitute for git history, but a human-and-agent-readable
summary that doesn't require diffing commits to understand.

Format — one entry per operation, newest at the bottom, never edited or
reordered after being written:

```
## 2026-07-04 — archive | old-hosting-provider.md
Superseded by new-hosting-provider.md after the migration. Moved to
_archive/2026-07-04-old-hosting-provider.md.

## 2026-07-04 — merge | roborock-setup.md + roborock-notes.md
Duplicate notes created from separate captures. Merged into
roborock-setup.md, archived roborock-notes.md.
```

Log at minimum: archives, merges, any deletion-adjacent operation (per
"Avoiding Silent Deletion"), and promotions of a synthesized answer into a
new permanent note (see Capture, below). Routine edits, clarifications, and
new captures don't need a log entry — this is for operations that move or
remove content, where a later reader would otherwise have to guess what
happened.

## The Standard Note Lifecycle

Every note in this wiki moves through five stages. This is the most important
section in this file — apply it literally, not as vague inspiration.

### 1. Capture

**Definition:** Getting a thought, fact, or reference out of your head (or out
of a transcript/source) and into a file, with zero editorial effort spent on
polish or structure.

**Criteria to enter this stage:**
- The information doesn't exist as a note yet, in any form.
- Speed matters more than correctness — a rough capture beats a lost thought.
- Source can be anything: a conversation, a meeting transcript, a passing
  idea, an extracted fact from research, or an agent's own synthesized
  answer to a query that's worth keeping as permanent reference. Promoting a
  synthesized answer to a note is a valid, first-class capture path — treat
  it the same as any other capture, and log the promotion in `log.md`.

**Criteria to move to the next stage (Clarify):**
- The raw capture exists as a file (in `_staging/` if uncertain, or directly
  in a content folder if the note type and basic facts are already clear).
- It has at least placeholder frontmatter (`status: draft`).
- No further criteria — everything captured is eligible for clarification
  immediately; there's no minimum dwell time in Capture.

### 2. Clarify

**Definition:** Turning a rough capture into a coherent, correctly-typed note
— fixing structure, applying the right template, resolving obvious ambiguity,
and deciding what kind of note this actually is.

**Criteria to enter this stage:**
- A captured note exists (from Capture, or being revisited after sitting in
  `_staging/`).
- Someone (user or agent) has time/attention to give it a first real pass.

**Criteria to move to the next stage (Connect):**
- The note has a definite `type` (concept/person/project/decision/meeting)
  and matches that type's template structure.
- Frontmatter is complete per `conventions/metadata.md`.
- Any genuine factual uncertainty is either resolved or explicitly flagged
  (moved to `_staging/` if still too uncertain, or marked inline under
  `## Unverified` if the note is otherwise solid enough to keep in place).
- `status` moves from `draft` to `active` (or stays `staged` if uncertainty
  couldn't be resolved — see Staging Uncertain Material above).

### 3. Connect

**Definition:** Weaving the note into the wiki's link graph — adding
wikilinks to and from related notes so the note is discoverable through
navigation, not just search.

**Criteria to enter this stage:**
- The note is clarified (typed, structured, frontmatter complete).

**Criteria to move to the next stage (Consolidate):**
- The note links to at least the obviously-related existing notes (per
  `conventions/linking.md` — when to link vs. tag).
- At least one existing note links back to it, OR a deliberate decision was
  made that this note is meant to stand alone (e.g. a narrow reference note).
- No dangling "TODO: link this" markers left in the note body.

### 4. Consolidate

**Definition:** Periodic review where overlapping notes get merged, outdated
statements get updated, and the note earns its place as a stable, trustworthy
part of the wiki rather than a one-off capture.

**Criteria to enter this stage:**
- The note has been Connected for a while and is stable — nobody is actively
  rewriting large parts of it week to week.
- A review pass (manual or agent-run) touches this note, e.g. checking for
  duplicate concepts, broken links, or drift from newer notes.

**Criteria to move to the next stage (Archive) — or to stay Consolidated
indefinitely:**
- Most notes stay in Consolidate indefinitely — this is the resting state for
  living reference material (concepts, people, active projects).
- Move to Archive only when the note's subject is genuinely over: a project
  finished, a decision superseded, a person/context no longer relevant to
  active work.
- If consolidation reveals the note duplicates another, merge (see
  "Preserving Information," bucket 3) rather than leaving both live.

### 5. Archive

**Definition:** Retiring a note that is no longer part of the active wiki, but
preserving it in full rather than deleting it.

**Criteria to enter this stage:**
- The note's subject is closed/finished/superseded (project done, decision
  overturned, person/org no longer relevant).
- Or it's a superseded version of a note that was substantially rewritten.

**Criteria to move on from this stage:**
- There isn't a "next" stage — Archive is terminal. A note only leaves
  `_archive/` if it's explicitly resurrected (moved back to Consolidate)
  because it became relevant again, e.g. a shelved project restarts.
- Nothing in `_archive/` is ever hard-deleted by an agent. If truly permanent
  deletion is wanted, that is a manual user decision, made outside of any
  agent action described in this file.
