# Knowledge Database — Agent Hard Rules

Portable rules for ANY agent working in a repo with a `knowledge-db/`. This file
travels with the KB folder and is referenced from the host instructions file
(CLAUDE.md / AGENTS.md / copilot-instructions) by `install.sh`.

## 1. ALWAYS READ FIRST

Start EVERY task by checking the KB — no exceptions, no trigger phrases needed:

1. Open `knowledge-db/INDEX.md` (Ready-Answer Table first, then entry catalog).
2. Grep for keywords: `grep -r "<keyword>" knowledge-db/`
3. A `verified` entry that answers the question: USE IT, stop exploring.
4. A `tentative` entry: build on it; upgrade to verified when proven.

## 2. EMPTY KB: bootstrap, don't skip

If the KB has no entries (or none relevant), do NOT silently proceed. Tell the
user the KB is empty for this topic and offer both bootstrap paths:

- **Exploration**: propose scanning the codebase now (`scripts/kb-discover <dir>`
  or a manual investigation) and recording the findings as exploration entries.
- **Manual input**: invite the user to share existing docs, specs, transcripts, or
  context — ingest with `scripts/kb-ingest` or write entries from it directly.

Then continue the task; bootstrapping suggestions must not block the work.

## 3. NEVER PROMPT, NEVER WITHHOLD

Capturing knowledge is autonomous. Never ask permission to create, update, or
supersede a KB entry, and never skip recording something important because it
feels interruptive:

- Create/update entries the moment an insight occurs (incremental capture —
  a session can end at any time; memory not written to the KB is memory lost).
- Superseding a `verified` entry: do it autonomously WITH an audit trail —
  state the reason in the new entry, link the replacement in `related:` (KB005),
  never delete the old entry.
- The only user-facing move is informing, not asking: mention in your summary
  what was recorded or superseded.

## 4. WRITE BACK (non-trivial work = KB entry)

Non-trivial = anything requiring search, multi-file reads, debugging, or decisions.
Decisions count even when the only artifact is a doc edit: a new rule, constraint,
or choice written into CLAUDE.md / AGENTS.md / an ADR gets a `decisions/` entry in
the same breath (KB013 enforces this on staged/PR diffs).

- Scaffold with `knowledge-db/bin/kb new <type> <slug>` (starts `tentative`).
- Ground every claim in a real source: `path:Lstart-Lend` (KB003).
- `verified` only with captured command output in `## Verification` (KB004).
- `errors/` entries: Symptom, Root Cause, Fix, Prevention (KB006). One trap per entry (KB010).
- Regenerate the index: `knowledge-db/bin/kb index` — never hand-edit INDEX.md
  outside the `kb:manual` regions (KB007).
- Validate before finishing: `knowledge-db/bin/kb check` must exit 0.

The full rule table (KB001-KB015) lives in `knowledge-db/README.md`.
