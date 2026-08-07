# OKF v0.2 Profile

wiki-standard concept documents use portable [Open Knowledge Format (OKF)
v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md):
a directory of Markdown documents with YAML frontmatter. OKF deliberately
does not prescribe an editor, agent, runtime, storage service, or taxonomy.

Profile infrastructure at the workspace root is not automatically part of an
OKF bundle. Select a dedicated content directory as the bundle root or export
concept documents into a clean bundle; see `WIKI_PROFILE.md`.

## Mapping

| OKF concept | wiki-standard equivalent |
|---|---|
| Knowledge bundle | an explicitly selected content directory or clean export |
| Concept document | any non-reserved Markdown note |
| Concept ID | note path without `.md` |
| `type` | required, open-vocabulary concept kind |
| `title`, `description`, `tags` | recommended portable display and discovery fields |
| `sources` | structured provenance mappings |
| Standard Markdown link | portable relationship between concepts |
| `index.md` | optional progressive-disclosure listing |
| `log.md` | optional newest-first update history |

## Required and recommended fields

`type` is the only universally required frontmatter key. wiki-standard
templates recommend `title`, `description`, `created`, `updated`, `status`,
`tags`, and `aliases` for common personal-knowledge workflows. Consumers
must tolerate unknown types and preserve unknown fields when round-tripping.

Use OKF lifecycle values for portable `status`:

- `draft` — incomplete or under review;
- `stable` — ready for normal consumption; this is the default when absent;
- `deprecated` — preserved for history and links but no longer current.

An implementation may add workflow-specific fields, but it must not require a
general OKF consumer to understand them.

## Provenance

Record derivation in `sources`, not in a scalar `source` field:

```yaml
sources:
  - id: source-key
    resource: https://example.com/source
    title: Optional source title
```

`resource` is required within each source entry. Other OKF credibility signals
are optional. Do not invent `author`, `generated`, `verified`, timestamps, or
source relationships. A body link expresses navigation or a relationship; it
does not by itself assert provenance.

For per-claim attribution, use a Markdown footnote whose label matches a
`sources[].id` value.

## Links

Produce standard Markdown links. Bundle-root-relative links are preferred for
stable internal identities:

```markdown
[Growth strategy](/concepts/growth-strategy.md)
```

Relative Markdown paths are also valid. Consumers tolerate broken links.
Legacy wikilinks may remain readable compatibility input, but they are not the
portable output format.

## Reserved files

- `index.md` is a link-list index and is not a concept document. A root index
  may declare `okf_version: "0.2"`.
- `log.md` is an optional, date-grouped update history with newest dates first.

Whether indexes and logs are edited manually or generated is an implementation
choice. The implementation must declare ownership before an agent edits them.

## Conformance checklist

- [ ] Every non-reserved Markdown document has parseable YAML frontmatter.
- [ ] Every concept has a non-empty `type`.
- [ ] New internal relationships use standard Markdown links.
- [ ] Known provenance uses structured `sources` entries.
- [ ] Unknown types and fields are preserved.
- [ ] `index.md` and `log.md` follow their reserved-file formats when present.
