# Linking Conventions

## Portable link style

Use standard Markdown links for new relationships. Prefer bundle-root-relative
targets for stable concept identities:

```markdown
[Growth Strategy](/projects/growth-strategy.md)
```

Relative links such as `[Decision](../decisions/vendor-selection.md)` are also
valid. The label is human-readable display text; the target is the actual
Markdown path. Encode spaces when a legacy filename contains them.

Existing `[[wikilinks]]` and `[[target|label]]` forms remain compatibility
input. Preserve them during unrelated edits. An explicit migration may convert
resolvable wikilinks, but must leave ambiguous or unresolved targets unchanged
and report them.

## Link versus tag

- Link when referring to a specific concept that exists—or should exist—as a
  subject of its own.
- Tag when applying a category or cross-cutting theme that does not need a
  dedicated concept.

If a dedicated note would be useful, prefer a link. If the term is primarily a
label shared by many notes, prefer a tag.

## Backlinks

Backlinks are derived data. Editors, agents, and indexers may compute them by
scanning Markdown links and compatible legacy syntax. Do not hand-maintain a
reciprocal backlink list in every note.

An incoming link does not require a reciprocal body link. Add a forward link
only when it helps a reader starting from that concept.

## Targets that do not exist yet

Choose one local workflow and document it in `AGENT.md`:

1. Link to the intended future path. Broken links are valid OKF and expose a
   knowledge gap: `[Future Note](/concepts/future-note.md)`.
2. Create a minimal stub with `type`, `status: draft`, and an optional title.

Do not silently invent a populated concept merely to satisfy a link.

## Cross-bundle targets

A bundle mounted inside a larger workspace may link to concepts outside its
root. Declare directories used only for lint-time target resolution in
`.lint-external-roots`, one path per line. Blank lines and `#` comments are
ignored; `~` is supported.

```text
# valid targets maintained in a separate bundle
~/knowledge/reference
```

External roots contribute candidate targets only. Their notes are not treated
as this bundle's content and cannot become its orphans or stale notes. Do not
add an entire unrelated knowledge base merely to suppress genuine broken-link
reports.

## Broken-link maintenance

During consolidation:

1. Update renamed targets to their new paths.
2. Point merged references at the surviving concept.
3. Keep historical references pointed at archived material when history is
   relevant.
4. Leave intentional future links unresolved or create an honest stub.
5. Remove only malformed link syntax when the surrounding information remains
   intact; link cleanup must not silently delete content.
