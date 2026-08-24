---
name: knowledge-database
description: >
  Manage durable project memory. Trigger on: "knowledge base", "durable memory",
  "never explore twice", "record what I learned", "log this bug and fix",
  "start of task", "before exploring", "bootstrap knowledge database",
  "initialize KB", "what do we know about X".
trigger_phrases:
  - knowledge base
  - knowledge database
  - durable memory
  - never explore twice
  - record what I learned
  - log this bug
  - bootstrap knowledge database
  - initialize KB
  - what do we know about
---

# Knowledge Database Skill

Build and maintain a repo's durable memory so you never investigate the same thing twice and never re-introduce a fixed bug.

## Core Loop (EVERY non-trivial task)

```
READ FIRST  -> search KB before exploring; reuse proven entry
DO THE WORK -> explore or implement
WRITE BACK  -> record findings, update INDEX.md
```

"Non-trivial" = anything requiring search, multi-file reads, debugging, or decisions.
Skip only pure one-liners (rename var, fix typo).

---

## 1. BOOTSTRAP (run once per repo, idempotent)

```
IF knowledge-db/ missing:
  1. Create folder structure (copy the FULL knowledge-db/ skeleton, including
     the enforcement tooling — not just templates):
     knowledge-db/
       README.md        (rule table KB001-KB011)
       AGENT.md         (portable agent hard rules)
       INDEX.md         (generated: run bin/kb index after copying)
       _TEMPLATE.md
       kb.config.json   (closed vocabularies — single source of truth)
       bin/kb           (zero-dep CLI: new / index / check)
       install.sh       (idempotent enforcement installer)
       explorations/.gitkeep
       solutions/.gitkeep
       errors/.gitkeep
       decisions/.gitkeep

  2. Run knowledge-db/install.sh — it wires ALL enforcement layers, including
     appending the HARD-RULE block to the host instructions file
     (CLAUDE.md / AGENTS.md / .github/copilot-instructions.md; creates
     CLAUDE.md if none exists). Idempotent, marker-guarded, never clobbers.

  3. If install.sh cannot run (no bash/python3), append the HARD-RULE block
     below to the host instructions file manually (check before append).
```

Bootstrap is safe to run multiple times. Never overwrites existing entries.

---

## 2. READ Loop (ALWAYS — start of EVERY task)

1. Open `knowledge-db/INDEX.md` (Ready-Answer Table first, then entry catalog)
2. Grep folder for keywords: `grep -r "keyword" knowledge-db/`
3. If **verified** entry answers question -> use it, stop exploring
4. If **tentative** entry exists -> build on it, upgrade to verified when proven
5. **EMPTY KB** (or nothing relevant): say so, then suggest BOTH bootstrap paths —
   a codebase exploration to seed it (`scripts/kb-discover <dir>` or manual
   investigation recorded as exploration entries), OR manual document/context
   input from the user (specs, docs, transcripts -> `scripts/kb-ingest` or direct
   entries). Suggest, then continue the task — never block on it.

---

## 3. WRITE Loop (as insights occur)

### Auto-Capture (Mandatory)

**Non-trivial work = KB entry created.** This is not optional.

### Incremental Capture (Session Resilience)

**Record findings AS THEY OCCUR, not batched at session end.**

Sessions can end unexpectedly (context exhaustion, logout, crash). Memory not committed = memory lost.

| Event | Action |
|-------|--------|
| Made choice between A and B | Create decision entry NOW |
| Discovered how something works | Create exploration entry NOW |
| Fixed a bug | Create error entry NOW |
| Completed a feature | Create solution entry NOW |

**Rule**: If session ended RIGHT NOW, would this insight survive? If no, record it.

### Entry Granularity

| Bucket | Granularity | Example |
|--------|-------------|---------|
| solutions/ | One per feature/fix | "KB v2 security fixes" |
| errors/ | One per bug | "YAML injection in kb-ingest" |
| explorations/ | One per question | "How does auth middleware work?" |
| decisions/ | **One per CHOICE** | "Why mandatory vs optional auto-capture" |

**decisions/ rule**: Multiple debates in session = multiple decision entries.

#### What Triggers Auto-Capture

| Task | Record? | Bucket |
|------|---------|--------|
| Debug failing test | YES | errors/ |
| Investigate "how does X work" | YES | explorations/ |
| Add feature (multi-file) | YES | solutions/ |
| Choose between approaches | YES | decisions/ |
| Rename with reasoning | YES | decisions/ |
| Fix obvious typo | NO | - |

**Rule**: If there was reasoning, record it. Future you will ask "why?"

#### Priority (Most Valuable First)

1. **Errors with fixes** - Prevents bug reintroduction
2. **Investigations** - Prevents re-exploration
3. **Decisions with rationale** - Prevents re-debating
4. **Multi-step solutions** - Prevents redoing work

### Never Prompt, Never Withhold

Capturing knowledge is autonomous. Never ask permission to create, update, or
supersede entries, and never skip recording something important.

Superseding a VERIFIED entry: do it immediately WITH an audit trail — state the
reason in the new entry, set `status: superseded` on the old one, link the
replacement in `related:`. Never delete the old entry. Inform the user in the
task summary (informing, not asking).

Opt-in exception: `supersede_with_consent: true` in workspace CLAUDE.md restores
ask-before-superseding (not recommended; blocks autonomous agents).

### Pick Bucket by Intent

| Intent | Bucket | Example |
|--------|--------|---------|
| Understanding how something works | `explorations/` | "How does auth middleware chain?" |
| Building/changing something | `solutions/` | "Add rate limiting to API" |
| Build/runtime/test failure | `errors/` | "TypeError in payment flow" |
| Choosing between options | `decisions/` | "Why PostgreSQL over MongoDB" |

File under dominant intent, cross-link related entries. For decisions: one entry per choice made.

### Create Entry

1. Scaffold: `knowledge-db/bin/kb new <type> <slug>` (falls back to copying
   `_TEMPLATE.md` if the CLI is unavailable)
2. Name: `YYYY-MM-DD-short-kebab-slug.md` (kb new does this)
3. Fill front-matter:
   ```yaml
   ---
   title: Short human title
   type: exploration | solution | error | decision
   status: verified | tentative | superseded
   date: YYYY-MM-DD
   tags: [area:<area>, layer:<layer>]
   sources:
     - path/to/file.ts:42-56
   related:
     - solutions/other-entry.md
   ---
   ```
4. Write sections (see template)
5. Set status:
   - **verified** = proven (tests pass, output confirmed, repro'd)
   - **tentative** = best understanding, not yet proven
   - **superseded** = outdated, link to replacement
6. Regenerate the catalog: `knowledge-db/bin/kb index` (INDEX.md is generated —
   never hand-edit outside the `kb:manual` regions)
7. Cross-link related entries
8. Validate: `knowledge-db/bin/kb check` exits 0

### Content Rules

- Ground every claim in source file (path + line range)
- Unsourced claims -> tentative status
- Write the answer, not the journey
- `errors/` entries MUST have: Symptom -> Root cause -> Fix -> Prevention
- Keep current: wrong entry = fix it + mark superseded + link replacement
- Small + linked beats large + orphaned

---

## 4. Tag Vocabulary

Reuse existing tags. Common patterns:
- `area:<domain>` - auth, payments, api, ui, db
- `layer:<level>` - controller, service, model, infra
- `tech:<stack>` - react, node, postgres, redis

Check INDEX.md tag-vocab section before creating new tags.

---

## HARD-RULE Block (append to host instructions)

This block is what `knowledge-db/install.sh` appends (marker-guarded). Append it
manually only when install.sh cannot run:

```markdown
## HARD RULE: Knowledge Database

This repo keeps durable memory in `knowledge-db/` so we never explore the same thing twice and never re-introduce a fixed bug. For EVERY task (agent or human):

1) **ALWAYS READ FIRST** — search `knowledge-db/` (start with INDEX.md); reuse a verified entry.
2) **EMPTY KB** — if no relevant entries exist, say so and suggest a codebase exploration to seed it OR manual document/context input to ingest. Then continue the task.
3) **DO THE WORK**.
4) **WRITE BACK** — scaffold with `knowledge-db/bin/kb new <type> <slug>`, ground every claim in a real source file (path:Lstart-Lend), regenerate the index with `bin/kb index`. errors/ entries record Symptom -> Root cause -> Fix -> Prevention. `bin/kb check` must exit 0.

**AUTO-CAPTURE**: Non-trivial work = KB entry created. Mandatory, not optional.
**INCREMENTAL**: Record findings AS THEY OCCUR, not batched at session end. Session can end anytime.
**NEVER PROMPT, NEVER WITHHOLD**: Create, update, and supersede entries autonomously. Superseding a verified entry needs a stated reason + `related:` link to the replacement — never permission.

Leaving a task without KB entries is incomplete work.
```

---

## Bundled Templates

The following files are created during bootstrap. Content defined in companion files:
- `README.md` - KB rules and usage guide
- `INDEX.md` - Entry catalog (4 tables + tag vocab)
- `_TEMPLATE.md` - Entry format template
