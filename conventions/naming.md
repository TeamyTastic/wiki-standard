# Naming Conventions

Rules for file and note names across any wiki adopting this standard.

## Case

Use **lowercase** for all file names. Never rely on case to distinguish two
notes (`Project.md` vs `project.md`) — filesystems and sync tools disagree on
case-sensitivity, and this is a reliable source of silent duplication.

## Word Separators

Use **hyphens** (`-`) between words, not spaces or underscores:

- `growth-strategy-2026.md`, not `Growth Strategy 2026.md` or
  `growth_strategy_2026.md`.

Rationale: hyphens are safe in URLs, shell paths, and every sync tool; spaces
require constant quoting and break some tooling; underscores read fine but
mixing the two conventions across a wiki creates inconsistency that compounds
over time.

Wikilink *display* text (`[[Growth Strategy 2026]]`) can and should use
normal spacing and capitalization — the naming convention governs the
underlying filename, not what's shown when you link to it. Keep the target
resolvable regardless of how it's typed by relying on your wiki tool's
fuzzy-match / alias support where available; otherwise, be consistent about
which form is canonical.

## Disambiguation for Duplicate Concepts

When two notes would otherwise share a name (e.g. two people named "Alex",
two projects called "Migration"):

1. **Prefer a qualifying suffix over a bare collision**:
   `alex-chen.md` / `alex-morgan.md`, or `migration-crm.md` /
   `migration-billing.md`. Pick the qualifier from context that's stable
   (surname, org, project domain) — not something that will change (current
   role, current status).
2. **Never silently overwrite** an existing note because a new one shares its
   working title. If you (or an agent) are about to create a note and a
   same-named one already exists, check whether they're actually the same
   subject first. If they're different subjects, disambiguate per (1). If
   they're the same subject, that's a merge, not a new note — see
   `editing-rules.md`.
3. Record the disambiguation reasoning briefly in the note's frontmatter or
   an opening line if it's non-obvious later (e.g. "there's another Alex —
   see `alex-morgan.md`").

## Date-Prefixing

**Time-bound notes** — content whose meaning is tied to a specific date and
which won't be substantially edited after creation — get a date prefix in
`YYYY-MM-DD-` format:

- Meeting notes: `2026-07-04-quarterly-planning.md`
- Daily logs / journal entries: `2026-07-04.md` or
  `2026-07-04-daily-log.md`
- One-off decisions tied to a moment in time may also date-prefix if the date
  itself is meaningful context (though `decision` notes more often use the
  `created` frontmatter field instead — see `metadata.md`).

**Evergreen notes** — concepts, people, and projects, whose content is meant
to be revisited and updated indefinitely — get **no date prefix**:

- `distributed-systems.md` (concept)
- `alex-chen.md` (person)
- `crm-migration.md` (project)

Rationale: evergreen notes are identified by subject, not by when they were
created — the `created`/`updated` frontmatter fields already carry that
information without polluting the filename. Date-prefixing an evergreen note
makes it harder to link to consistently and implies (wrongly) that it's a
point-in-time record rather than a living reference.

If a note type is ambiguous (e.g. a "project retrospective" — is it evergreen
or time-bound?), default to evergreen (no prefix) unless the note is
genuinely a snapshot that won't be edited again.
