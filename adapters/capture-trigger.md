# Capture Trigger — teaching agents outside the wiki

`conventions/capture-on-demand.md` defines what happens when someone says
**"save data"**. But it lives *inside* the wiki, and most of the time the user
is somewhere else — a code repo, a scratch directory, a chat with an assistant
that has no filesystem at all. An agent that never opens the wiki never reads
the protocol, so the protocol never runs.

This file fixes that with a short block installed into each runtime's
always-loaded instruction file. The block does exactly two things: **name the
trigger phrases, and route to the real protocol.** It never restates the
protocol. A copy of the rules that drifts from the original is worse than no
copy, because it looks authoritative while being stale.

## Resolving the wiki

An external agent has to find the wiki before it can read the contract. In
order:

1. `$WIKI_HOME`, if set.
2. The single path in `~/.wiki-home`, if that file exists.
3. Otherwise: ask the user. Do not guess, and do not create a wiki.

`~/.wiki-home` is a one-line file holding an absolute path. It is per-machine
local state, not part of the standard, and nothing installs it for you.

## The block

Install verbatim. Substitute nothing.

```markdown
## Wiki capture and retrieval

When the user says "save data", "save this", "capture this", "add this to the
wiki", or hands over material saying to keep it — this is the wiki capture
protocol, not an ordinary file write.

Resolve the wiki: `$WIKI_HOME`, else the path in `~/.wiki-home`, else ask.

Then read, in this order, and follow them:
1. `<wiki>/AGENT.md` — the operating contract.
2. `<wiki>/conventions/capture-on-demand.md` — the capture and retrieval rules.

Do not act from this summary. It exists only to send you to those two files;
they are authoritative and they change. In particular, do not skip the
duplicate search, and do not skip the closing report of what you did NOT save
and why — that report is the point of the protocol, not a courtesy.

The same applies in reverse: a question that should be answered from the
user's own notes ("what did we decide about X", "who owns Y", "have I written
about Z") means reading the wiki before answering from your own knowledge.
Retrieval is read-only — never write a note as a side effect of a question.
```

## Per-runtime install

A runtime takes the block one of two ways. Prefer whichever the runtime treats
as always-available:

- **Global instruction file** — the block goes in verbatim under its own
  heading. Guaranteed to load, but it spends the file's budget every session.
- **Skill** — the block becomes the body of a `save-data` skill, wrapped in
  frontmatter whose `description` carries the trigger phrases. Costs nothing
  until it matches. If the description omits the phrases it never activates,
  so that line is the whole install.

| Runtime | Install into | Notes |
|---|---|---|
| Claude Code | `~/.claude/skills/save-data/SKILL.md` | Also supports `~/.claude/CLAUDE.md`. Prefer the skill where that file is budgeted — descriptions are injected into the system prompt, so discovery is equivalent. |
| Codex | `~/.codex/AGENTS.md` | Global agent instructions. |
| pi | `~/.pi/skills/save-data/SKILL.md` | pi loads skills, not a global instruction file. |
| Any runtime with a project file | that project's `AGENTS.md` / `CLAUDE.md` | Only if that project should capture into the wiki. |

Verify after installing: from a directory that is *not* the wiki, say "save
data" with something trivial and confirm the agent opens
`conventions/capture-on-demand.md` rather than improvising a note.

## Runtimes that cannot capture

Some agents can read the wiki's contents but cannot write to it — a
retrieval-only assistant, a sandboxed agent, a chat model with no filesystem,
or an agent running as a different user that the filesystem denies.

**Do not install the capture half there.** An agent that accepts "save data"
and cannot commit will either fail confusingly or invent a workaround path,
and the user will believe something was saved when nothing was. Install the
retrieval half only, and give it one honest sentence:

```markdown
You can read this wiki but not write to it. If the user asks you to save
something, say plainly that you cannot write here, and tell them which agent
can. Do not stage it somewhere else and call it saved.
```

If such an agent has a legitimate staging path out — a shared drop directory
another process ingests — that is a capture into the *staging area*, not into
the wiki, and must be described as such to the user. It only becomes a
capture when an agent that can actually run the protocol picks it up.

## Runtimes that read an export, not the wiki

The stricter case: an agent that cannot reach the wiki **at all** — a
different filesystem user, a sandbox, a hosted model — but that is served a
periodically refreshed index built from the wiki. It has neither half. Install
nothing from this file; it cannot follow a path it cannot open.

What such an agent needs instead is one sentence about what it is actually
reading:

```markdown
You do not have the wiki. You have a search index built from a snapshot of it,
refreshed on a schedule. Answer from it, cite the note path, and say the answer
comes from the last snapshot — it can be a day stale and it omits whatever the
export excludes. You cannot save to the wiki; name the agent that can.
```

Two rules follow for whoever maintains that export, and both are the
standard's problem rather than the agent's:

- **Exclude the standard from the export.** `conventions/`, `adapters/`,
  `AGENT.md`, `AGENTS.md`, `CLAUDE.md`, `WIKI_PROFILE.md` and the manifests are
  the operating model, not the user's knowledge. Indexed, they surface as
  answers to the user's own questions and quietly become instructions the
  retrieval agent reads as if they were addressed to it.
- **Exclude by basename at every depth, not just at the root.** A wiki nested
  inside a wiki puts a second `conventions/` and a second `AGENT.md` well below
  the top level. A root-level admission table looks complete and governs none
  of them.
