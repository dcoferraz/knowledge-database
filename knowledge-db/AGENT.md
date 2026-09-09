# Knowledge Database — Agent Hard Rules

Portable rules for ANY agent working in a repo with a `knowledge-db/`. This file
travels with the KB folder and is referenced from the host instructions file
(CLAUDE.md / AGENTS.md / copilot-instructions) by `install.sh`.

## 1. LOOK UP FIRST (and cheaply)

Start EVERY task in the KB — no exceptions, no trigger phrases needed. Use the
lookup commands; do NOT open `ls`, `find`, or the whole of `INDEX.md` first:

```bash
knowledge-db/bin/kb find "half cent rounding money" -s   # hits + the top hit's fix, ONE call
knowledge-db/bin/kb find "<keywords>"                    # hits only, ~130-360 tokens
knowledge-db/bin/kb show <entry>                         # one entry's core, ~280 tokens
knowledge-db/bin/kb show <entry> --all                   # the whole entry, when you need it
knowledge-db/bin/kb find "<keywords>" --deep             # force a body scan (rarely needed)
```

Reading `INDEX.md` end-to-end and then a full entry costs roughly 3,000 tokens;
`find -s` costs 400-650 for the same answer. The catalog exists for humans and
for `kb index`; agents should query, not scan.

**Why `-s`, and why not grep.** Every `kb` invocation costs ~55ms of interpreter
startup, so two calls cost twice that: `find` then `show` measured 105ms against
55ms for `find -s`. And `find` reads ONE generated index file
(`.search-index.json`, refreshed by `kb index`), ranking titles, tags, slugs,
summaries and cited paths. It only opens entry bodies when that index yields
nothing, or with `--deep`. On a 1,000-entry KB: 59ms indexed against 108ms
scanning every body. `grep -r` has neither ranking nor that shortcut, and
returns whole files.

1. `kb find "<keywords>" -s` with the words you would have grepped for.
2. A `verified` entry that answers the question: **apply it, stop exploring.**
   It carries captured proof (KB004) — re-deriving it is waste, not diligence.
3. A `tentative` entry: build on it; upgrade to verified when proven.
4. Nothing relevant: say so (rule 2), then explore.

## 2. EMPTY KB: bootstrap, don't skip

If the KB has no entries (or none relevant), do NOT silently proceed. Tell the
user the KB is empty for this topic and offer both bootstrap paths:

- **Exploration**: propose scanning the codebase now (`knowledge-db/bin/kb discover <dir>`
  writes a tentative exploration entry) or a manual investigation recorded the same way.
- **Manual input**: invite the user to share existing docs, specs, transcripts, or
  context — `knowledge-db/bin/kb ingest --input <file>` (or piped stdin) drafts an
  entry from it, or write entries from it directly.

Both commands ship inside the KB folder, so they exist in every install.

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

## 3b. REUSE ENDS THE TASK

If an existing entry answered it, **you are done when you refresh that entry** —
not when you write a new one:

- bump `last_verified` with fresh proof (the command you just ran), or
- add a one-line reuse note ("reused 2026-09-05 for the payout path"), or
- extend the existing entry if you learned something genuinely new.

Do NOT author a duplicate of an entry you just used. Measured: on a reuse, the
write-back costs more than the lookup saved, and it splits one answer into two
that will disagree later. Touching the existing entry also satisfies KB011/KB013,
which only require that the diff touch `knowledge-db/`.

New knowledge still gets a new entry — the test is "did the KB already hold
this?", not "did I do work?".

## 4. WRITE BACK (new knowledge = KB entry)

Non-trivial = anything requiring search, multi-file reads, debugging, or decisions.
Decisions count even when the only artifact is a doc edit: a new rule, constraint,
or choice written into CLAUDE.md / AGENTS.md / an ADR gets a `decisions/` entry in
the same breath (KB013 enforces this on staged/PR diffs).

- Scaffold with `knowledge-db/bin/kb new <type> <slug>` (starts `tentative`).
- **Write the fix as something applicable**: a diff, or the exact `file:line`
  list to change. The next agent should be able to act without opening the
  modules you already read. Prose about the journey costs tokens twice.
- Ground every claim in a real source: `path:Lstart-Lend` (KB003).
- `verified` only with captured command output in `## Verification` (KB004).
- `errors/` entries: Symptom, Root Cause, Fix, Prevention (KB006). One trap per entry (KB010).
- Regenerate the index: `knowledge-db/bin/kb index` — never hand-edit INDEX.md
  outside the `kb:manual` regions (KB007).
- Validate before finishing: `knowledge-db/bin/kb check` must exit 0.

## 5. Working outside the KB's own repo

In a context workspace the KB sits ABOVE the app repo (`workspace/knowledge-db/`,
`workspace/app/`). Two consequences to remember:

- Code you commit in the nested repo can never show the KB in its diff, so
  `install.sh` plants a hook there that runs `kb check --staged --repo <that repo>`.
  Evidence of write-back is then pending KB changes in the workspace, or a KB
  commit inside `writeback.grace_hours`. Record the entry BEFORE committing code.
- Cite nested sources as `app/src/thing.ts:12-40`; add `@rev` only for a rev that
  exists in the repo that owns the file.

The full rule table (KB001-KB015) lives in `knowledge-db/README.md`.
