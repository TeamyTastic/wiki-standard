# wiki-standard

A small, evolving repo of **shared operating-model assets** for independent
Markdown knowledge bases. It contains a portable profile, conventions,
templates, an agent operating contract, deterministic scripts, and optional
runtime adapters—and nothing else. It requires no particular editor, model,
agent runtime, storage service, or automation product. No personal notes, no
private content, ever.

## Philosophy: Shared Operating Model, Independent Content

Most "wiki template" projects couple the operating model (how you name
things, structure frontmatter, link notes) to the content itself — you fork a
vault, and your notes live forever entangled with someone else's example
content and someone else's git history.

wiki-standard inverts that. It is a single, small repo containing **only**:

- `WIKI_PROFILE.md` — the normative, runtime-neutral profile
- `AGENT.md` — how any human or software agent should behave inside a wiki
- `AGENTS.md` / `CLAUDE.md` — thin discovery adapters that point to `AGENT.md`
- `conventions/` — the rules (naming, metadata, linking, editing)
- `templates/` — starting shapes for each note type
- `scripts/` — install and verify tooling
- `skills/wiki-standard-adopt/` — an optional skill-format adapter that wraps
  the adoption flow (see "Optional Adapters" below)

It contains **zero content**. Every wiki that adopts this standard keeps its
own private repo (or no repo at all) for its actual notes. The two never
share a git history, a remote, or a content folder. This means:

- You can evolve the standard (fix a naming rule, add a template, tighten an
  editing rule) in one place, and pull that improvement into every wiki you
  maintain — without ever risking cross-contamination of private content.
- Different wikis can adopt the standard at different times, skip an update,
  or diverge locally (see `AGENT.md`'s note on local overrides) without
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

The install script copies in `WIKI_PROFILE.md`, `AGENT.md`, the two discovery
adapters, `conventions/`, `templates/`, `scripts/check-standard.sh`,
`scripts/check-okf.sh`, and `scripts/lint-content.sh`—and only those. It never
touches any other folder in the target wiki, so actual notes remain untouched
by every install and update.

Preview the exact scope before writing:

```bash
~/Projects/wiki-standard/scripts/install-standard.sh --dry-run /path/to/my-vault
```

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
  `AGENT.md`, an adapter, or `templates/` has been hand-edited and differs from what's
  about to be installed, the existing files are backed up first (to a
  timestamped `.wiki-standard-backup-<timestamp>/` folder inside the wiki)
  before the new version is written.
- It writes/updates a `.wiki-standard-version` file at the root of the
  target wiki, containing the exact git commit hash of wiki-standard when
  the source has Git metadata of its own. An installed copy records
  `unknown` rather than borrowing an unrelated ancestor repository's hash.
  This is how you (or `scripts/check-standard.sh`) can tell which version of
  the standard a wiki is running when the source version is available.

Run `scripts/check-standard.sh /path/to/my-vault` at any time to verify a
workspace's profile infrastructure hasn't drifted or gone missing anything,
without needing to re-install. This does not claim that the workspace root is
an OKF bundle.

Run `scripts/check-okf.sh /path/to/content-bundle` to validate the minimum OKF
v0.2 document contract at an explicit content boundary. Keeping profile
infrastructure outside that boundary avoids misclassifying `AGENT.md`,
templates, and conventions as knowledge concepts.

Run `scripts/lint-content.sh /path/to/my-vault` at Consolidate time to check
the wiki's actual *content* — orphan notes, broken `[[links]]`, notes stale
past a configurable age, unresolved `## Conflicts` sections, and note pairs
sharing tags with no link between them. It's report-only; it never edits
anything.

## Quick Start (Adopting the Standard)

1. Clone this repo somewhere stable, e.g. `~/Projects/wiki-standard`.
2. Pick the Markdown knowledge workspace you want to adopt it into.
3. Run:
   ```bash
   ~/Projects/wiki-standard/scripts/install-standard.sh /path/to/my-vault
   ```
4. Read the installed `AGENT.md` in your vault—it is written for both you
   and any software agent working in that vault, and explains the folder layout,
   naming/metadata/linking rules, and the capture → clarify → connect →
   consolidate → archive note lifecycle.
5. Start writing notes using the templates in `templates/` as your starting
   point (copy the template content into a new note — templates are not
   meant to be referenced live).
6. Periodically pull updates (see "How Updates Propagate" above).

## Optional Adapters

`skills/wiki-standard-adopt/SKILL.md` wraps the adoption flow in the common
skill-directory shape used by several agent runtimes. Point it at a target wiki and it inspects the vault,
identifies content folders (so it knows what never to touch), runs the
installer, backs up conflicting standard infrastructure, and verifies scope.
It commits only when explicitly asked.

Install or register that adapter according to the runtime's skill-loading
mechanism. For example, a runtime that discovers `~/.claude/skills/` can use:

```bash
cp -R skills/wiki-standard-adopt ~/.claude/skills/
```

Then ask the runtime to "adopt wiki-standard into this vault." This path is
optional: running `scripts/install-standard.sh` directly is the canonical
workflow and has no agent-runtime dependency.

`AGENTS.md` and `CLAUDE.md` are also adapters. They contain no independent
policy; `AGENT.md` and `WIKI_PROFILE.md` remain authoritative.

## What This Repo Is Not

- Not a wiki itself—there is no example content or sample vault.
- Not a sync tool — it doesn't watch, sync, or manage your actual notes.
- Not opinionated about *what* you write about — only about the shape and
  lifecycle conventions around how you write it.
- Not an agent framework, editor plugin, retrieval engine, or storage format
  beyond its OKF v0.2-compatible Markdown contract. Those are implementation
  choices and may provide adapters without redefining the standard.
