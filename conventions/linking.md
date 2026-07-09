# Linking Conventions

## Wikilink Style

Use double-bracket wikilinks for any reference to another note:
`[[Note Title]]`. Use the note's `title` frontmatter field as the display
text inside the brackets (not the raw filename) — this keeps links readable
regardless of the naming convention in `naming.md`, and keeps them stable if
a file gets renamed but the title doesn't change.

For a link with different display text than the target's title, use the
pipe form where your tooling supports it: `[[actual-note-title|shown text]]`.

## Link vs. Tag

Both connect notes to a broader context, but they serve different purposes:

- **Link** (`[[Note Title]]`) when the reference is to a *specific other
  note* that exists (or should exist) as its own subject — a person, a
  project, a concept, a decision. Links are how the wiki's graph of ideas
  gets built.
- **Tag** (`tags: [...]` in frontmatter, or inline `#tag` if your tool
  supports it) when the reference is to a *category or cross-cutting theme*
  that doesn't warrant its own note — `#q3-2026`, `#needs-review`,
  `tags: [engineering]`. Tags group; links connect.

Rule of thumb: if you could imagine writing a dedicated note about the thing
being referenced, it should eventually be a link. If it's better thought of
as a label applied to many notes, it's a tag.

## Backlink Expectations

Backlinks (which notes link *to* this one) are expected to be **automatic**,
computed by the wiki tool (Obsidian and most markdown-wiki tools do this by
scanning for `[[...]]` references) — not manually maintained by hand-editing
a "linked from" list in every note.

Do not try to manually keep a reciprocal link list in sync; that's exactly
the kind of bookkeeping automatic backlinking exists to remove. If your
tooling doesn't compute backlinks automatically, treat that as a tooling gap
to fix (e.g. via a script), not a discipline to enforce by hand.

That said, **reciprocity isn't automatic in content** — just because A links
to B doesn't mean B's *body text* should also explicitly reference A. Add an
explicit forward link from B only when it's genuinely useful for a reader
starting at B (per Connect-stage criteria in `CLAUDE.md`), not reflexively
for every incoming link.

## Linking to a Note That Doesn't Exist Yet

Two acceptable approaches — pick one per-wiki and stay consistent (record the
choice in the installed `CLAUDE.md` or a local override note if it needs to
diverge from this default):

1. **Default: allow red links.** Write `[[Future Note]]` even though the
   note doesn't exist. Most wiki tools render this distinctly (often in a
   different color) so it's visible as a gap, not a broken reference. This
   keeps the link graph honest about what *should* connect, even before
   every node exists.
2. **Alternative: create a stub immediately.** If red links tend to get
   forgotten in your workflow, create a minimal stub note the moment you
   link to it — frontmatter with `status: draft`, a title, and nothing else
   — so it shows up in searches and can be filled in later. This trades a
   cleaner "everything resolves" wiki for more stub-cleanup overhead.

Whichever approach is chosen, a stub or red link is a Capture-stage artifact
— it should move through the lifecycle (get clarified, connected) like any
other note, not linger indefinitely as a placeholder.

## Cross-Bundle Links (external roots)

A wiki that is mounted inside a larger vault (e.g. via a symlink) may hold
wikilinks whose targets live outside the bundle but resolve fine vault-wide.
Declare those target directories in a `.lint-external-roots` file at the
wiki root — one path per line, `~` allowed, `#` comments ignored:

```
# resolves vault-wide via the parent vault
~/eobsidian/reference/Bookshelf
```

`scripts/lint-content.sh` then treats notes under those roots as valid link
targets (matched by filename, `title`, and `aliases`) without scanning them
as content — they can't show up as orphans or stale.

**Accented titles**: visually identical titles can be byte-different
(NFD-vs-NFC Unicode — common in macOS/Notion/Airtable exports), which breaks
exact link matching invisibly. When a target's title carries accents, link by
its kebab-case **basename** instead of the title (learned 2026-07-10). Use this for genuine
cross-bundle references only; don't point it at another wiki wholesale to
silence honest red links.

## Handling Broken Links Found During Maintenance

A "broken link" here means a `[[...]]` reference to a note that used to
exist but was renamed, merged, or archived without the reference being
updated — different from an intentional red link to a not-yet-created note.

During a Consolidate-stage review pass (see `CLAUDE.md`):

1. **If the target was renamed** — update the link to the new name/title.
   Prefer aliases (`aliases:` frontmatter field, see `metadata.md`) going
   forward so renames don't break existing links as easily.
2. **If the target was merged into another note** — update the link to
   point to the surviving note.
3. **If the target was archived** — decide per-link whether the reference
   should now point into `_archive/` (if the historical reference is the
   point) or be removed from that specific sentence (if the surrounding text
   no longer makes sense without a live target). Removing a link is not the
   same as deleting content — the surrounding text and information stays;
   only the bracket syntax changes. If in doubt, leave the link pointing at
   the archived note rather than silently dropping the reference.
4. **If the target never existed and was clearly a typo or abandoned idea**
   — safe to just fix the typo or remove the link syntax (not the
   surrounding content) without an archive step; this isn't information loss,
   it's link-graph hygiene.

Log a broken-link sweep in the review the same way any Consolidate-stage
activity gets logged, if the wiki keeps a maintenance log.
