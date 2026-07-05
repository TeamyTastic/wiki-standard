# wiki-standard

A small, evolving repo of **shared operating-model assets** for independent
personal markdown wikis (Obsidian-style vaults, or any plain-markdown
knowledge base). It contains conventions, templates, an agent operating
manual, and scripts — and nothing else. No personal notes, no private
content, ever.

## Philosophy: Shared Operating Model, Independent Content

Most "wiki template" projects couple the operating model (how you name
things, structure frontmatter, link notes) to the content itself — you fork a
vault, and your notes live forever entangled with someone else's example
content and someone else's git history.

wiki-standard inverts that. It is a single, small repo containing **only**:

- `CLAUDE.md` — how an LLM agent should behave inside a wiki
- `conventions/` — the rules (naming, metadata, linking, editing)
- `templates/` — starting shapes for each note type
- `scripts/` — install and verify tooling

It contains **zero content**. Every wiki that adopts this standard keeps its
own private repo (or no repo at all) for its actual notes. The two never
share a git history, a remote, or a content folder. This means:

- You can evolve the standard (fix a naming rule, add a template, tighten an
  editing rule) in one place, and pull that improvement into every wiki you
  maintain — without ever risking cross-contamination of private content.
- Different wikis can adopt the standard at different times, skip an update,
  or diverge locally (see `CLAUDE.md`'s note on local overrides) without
  breaking the shared repo or each other.
- The shared repo can eventually be made public, shared with collaborators,
  or open-sourced without a content audit, because it never contained content
  in the first place.

One evolving shared operating model. Many independent knowledge bases.

## How It's Consumed

wiki-standard is not something you clone *as* your wiki. You clone it
separately, then run its install script against each wiki you maintain:

```bash
# once, anywhere convenient
git clone <PRIVATE_REPO_URL> ~/Projects/wiki-standard

# for each wiki that should adopt the standard
~/Projects/wiki-standard/scripts/install-standard.sh /path/to/my-vault
```

The install script copies in `CLAUDE.md`, `conventions/`, `templates/`,
`scripts/check-standard.sh`, and `scripts/lint-content.sh` — and only those.
It never touches any other folder in the target wiki, so your actual notes
are completely untouched by every install and every future update.

## How Updates Propagate

The standard evolves over time in this repo (new conventions, refined
templates, bug fixes to scripts). To pull an update into a wiki that already
adopted the standard:

```bash
cd ~/Projects/wiki-standard && git pull
~/Projects/wiki-standard/scripts/install-standard.sh /path/to/my-vault
```

Re-running the install script is always safe:

- It's **idempotent** — running it twice with no upstream changes is a no-op
  beyond refreshing the version marker.
- It **never silently overwrites local drift**. If the target wiki's copy of
  `CLAUDE.md` or `templates/` has been hand-edited and differs from what's
  about to be installed, the existing files are backed up first (to a
  timestamped `.wiki-standard-backup-<timestamp>/` folder inside the wiki)
  before the new version is written.
- It writes/updates a `.wiki-standard-version` file at the root of the
  target wiki, containing the exact git commit hash of wiki-standard that
  was installed. This is how you (or `scripts/check-standard.sh`) can tell
  which version of the standard any given wiki is running, and whether it's
  behind.

Run `scripts/check-standard.sh /path/to/my-vault` at any time to verify a
wiki's copy of the standard hasn't drifted or gone missing anything, without
needing to re-install.

Run `scripts/lint-content.sh /path/to/my-vault` at Consolidate time to check
the wiki's actual *content* — orphan notes, broken `[[links]]`, notes stale
past a configurable age, unresolved `## Conflicts` sections, and note pairs
sharing tags with no link between them. It's report-only; it never edits
anything.

## Quick Start (Adopting the Standard)

1. Clone this repo somewhere stable, e.g. `~/Projects/wiki-standard`.
2. Pick the wiki you want to adopt it into — any directory of markdown
   notes, Obsidian vault or otherwise.
3. Run:
   ```bash
   ~/Projects/wiki-standard/scripts/install-standard.sh /path/to/my-vault
   ```
4. Read the installed `CLAUDE.md` in your vault — it's written for both you
   and any LLM agent working in that vault, and explains the folder layout,
   naming/metadata/linking rules, and the capture → clarify → connect →
   consolidate → archive note lifecycle.

## Claude Code Skill

`skills/wiki-standard-adopt/SKILL.md` wraps the adoption flow above as a
Claude Code skill: point it at a target wiki and it inspects the vault,
identifies content folders (so it knows what never to touch), runs the
installer, backs up any conflicting pre-existing `CLAUDE.md`/`templates/`,
and commits the change as a single commit if the target is a git repo.

To use it, copy the skill into your Claude Code skills directory:

```bash
cp -R skills/wiki-standard-adopt ~/.claude/skills/
```

Then trigger it in a Claude Code session with something like "adopt
wiki-standard into this vault."
5. Start writing notes using the templates in `templates/` as your starting
   point (copy the template content into a new note — templates are not
   meant to be referenced live).
6. Periodically pull updates (see "How Updates Propagate" above).

## What This Repo Is Not

- Not a wiki itself — there's no example content, no sample vault.
- Not a sync tool — it doesn't watch, sync, or manage your actual notes.
- Not opinionated about *what* you write about — only about the shape and
  lifecycle conventions around how you write it.
