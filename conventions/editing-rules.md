# Safe Editing Rules

These rules govern how any edit — human or agent — is made to a note once it
exists. They exist to make "never silently delete" (see `CLAUDE.md`)
concrete and actionable at the moment of editing, not just as a policy
statement.

## Non-Destructive by Default

The default edit is **additive**: append new information, update a stale
fact in place with the old value struck through or moved to a
`## History`/`## Superseded` section, or extend a section — rather than
replacing a note's content wholesale.

Wholesale replacement is reserved for the "archive-before-rewrite" case
below, and even then the old version isn't lost, just relocated.

## Handling Conflicting Information Across Two Notes

If you (or an agent) discover that two notes make contradictory claims about
the same thing — never silently pick one and delete/edit away the other.
Instead:

1. **Surface the conflict explicitly.** Add a `## Conflicts` section to the
   note being actively edited (or to both, if both are being touched):
   ```markdown
   ## Conflicts
   - This note states X was decided on 2026-05-01. [[Other Note]] states
     X was decided on 2026-06-15. Not yet reconciled — check source
     material or ask the note owner.
   ```
2. **If neither note can be confidently corrected**, move the newer or more
   uncertain claim to `_staging/` as its own short note describing the
   conflict, rather than leaving two silently-contradicting "active" notes
   in place pretending to both be settled fact.
3. **Once resolved** (by the user, or by finding authoritative source
   material), update both notes: the corrected one gets the fix, the
   `## Conflicts` section is removed, and — if a whole note turns out to be
   wrong rather than just one claim — archive it per "Archive-Before-Rewrite"
   below rather than deleting it outright.

Never resolve a conflict by unilaterally deciding which note is "more
likely right" and quietly deleting the other's claim. Confidence calls like
that belong to the user.

## Flagging Uncertainty Inline

When a specific claim within an otherwise-solid note is uncertain (not the
whole note — see `_staging/` in `CLAUDE.md` for whole-note uncertainty), flag
it inline rather than either omitting it or stating it as fact:

```markdown
Alex joined the team in March 2025 (unconfirmed — need to check with HR).
```

Or, for a running list of such flags in one place within the note:

```markdown
## Unverified
- Start date: March 2025 (unconfirmed)
- Reporting line: unclear whether Alex reports to Priya or directly to the VP
```

An inline flag is a Clarify-stage signal — the note shouldn't be considered
fully Connected/Consolidated (per the lifecycle in `CLAUDE.md`) while
material `## Unverified` items remain open, though it's fine for the note to
otherwise be in active use.

## Archive-Before-Rewrite for Major Edits

A "major edit" is one that changes the substance of a note significantly —
not a typo fix or a small addition, but a restructure, a change in
conclusion, or a rewrite of most of the body.

Before making a major edit:

1. Copy the current full content of the note to `_archive/`, named with a
   date prefix and the original note name, e.g.
   `_archive/2026-07-04-crm-migration.md`.
2. Add a one-line pointer at the top of the archived copy noting it was
   superseded and by what date/reason, if known.
3. Then make the rewrite in the live note. Optionally leave a one-line
   breadcrumb in the rewritten note pointing back
   (`> earlier version: _archive/2026-07-04-crm-migration.md`) if the
   history is likely to matter later (e.g. for a decision note where the
   prior reasoning is worth being able to find).

Minor edits (typo fixes, small additions, frontmatter updates, fixing a
broken link per `linking.md`) do not require this — archive-before-rewrite is
specifically for edits that would otherwise destroy meaningfully different
prior content.

## Summary Checklist Before Any Edit

- Is this additive, or does it remove/replace something? → if removing,
  where does the removed content go (see `CLAUDE.md` → Preserving
  Information)?
- Does this edit contradict another note? → surface, don't silently resolve.
- Is any part of what I'm writing uncertain? → flag inline or stage it.
- Is this a major rewrite? → archive the prior version first.
