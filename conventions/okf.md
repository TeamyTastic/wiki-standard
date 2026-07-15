# OKF Compatibility (Open Knowledge Format v0.1)

wiki-standard wikis double as **OKF knowledge bundles** — Google's open
format for agent-readable knowledge corpora
([spec](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)).
OKF is markdown + YAML frontmatter with one required field and permissive
consumers, so a wiki-standard wiki is already ~90% conformant. This file
pins down the remaining 10%.

## Mapping

| OKF concept | wiki-standard equivalent |
|---|---|
| Knowledge Bundle | the wiki (its root = bundle root) |
| Concept document | a note |
| Concept ID (`path/no-ext`) | note path (lowercase-hyphenated per `naming.md`) |
| `type` (required, open vocabulary) | `type` (required, 5-value vocabulary per `metadata.md`) — stricter is conformant |
| `title` / `tags` / `timestamp` | `title` / `tags` / `updated` |
| `description` (recommended) | **adopted** — see below |
| `index.md` (reserved, progressive disclosure) | **adopted** — optional per directory, no frontmatter (except bundle root, which may carry `okf_version: "0.1"`) |
| `# Citations` numbered section | **adopted** — use for externally-sourced claims |
| Cross-links as markdown links | wikilinks `[[...]]` — see deviation 2 |

## What we adopt from OKF

1. **`description` frontmatter field** (optional-but-recommended, one
   sentence). Powers index generation, search snippets, and OKF consumers.
   Listed in `metadata.md`.
2. **`index.md` as a reserved filename** — never a concept/note; contains
   only grouped link lists with per-entry descriptions (OKF §6). Generate
   per-directory indexes when a folder grows past ~15 notes.
3. **`# Citations`** as the conventional heading for numbered external
   sources at the bottom of a note (OKF §8). Prefer it over ad-hoc
   "Sources"/"References" headings in new notes.
4. **Permissive consumption** — agents reading a wiki MUST tolerate unknown
   `type` values, unknown frontmatter keys, and broken links (OKF §9). This
   was already the spirit of `editing-rules.md`; it is now explicit.

## Known deviations (deliberate)

1. **`log.md` entry order** — RESOLVED 2026-07-09 (owner decision): adopted
   OKF §7 ordering. Logs are date-grouped, newest date first, bulleted with
   a leading bold op word; past groups immutable. `CLAUDE.md` "Operation
   Log" carries the format. Pre-existing logs in already-adopted wikis
   should be reversed on next touch.
2. **Wikilinks** — wiki-standard links notes with `[[Title]]`; OKF
   cross-links are plain markdown links. This does NOT break conformance
   (OKF links are a MAY, and consumers tolerate their absence), but OKF
   consumers won't traverse wikilinks. For bundles meant for external
   exchange, add markdown links for load-bearing relationships or convert
   at export time.
3. **Closed `type` vocabulary** — wiki-standard keeps its 5 types (+ the
   documented extension path in `metadata.md`) rather than OKF's open
   vocabulary. Conformant: OKF requires only that `type` is present and
   non-empty.

## Conformance checklist (OKF v0.1, §9)

- [ ] Every non-reserved `.md` has parseable YAML frontmatter
- [ ] Every frontmatter has non-empty `type`
- [ ] `index.md` files (if present) are link-list-only
- [ ] `log.md` follows §7 (adopted 2026-07-09 — newest date group first)
