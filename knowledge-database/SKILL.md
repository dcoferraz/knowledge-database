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
  - start of task
  - before exploring
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
  1. Create folder structure:
     knowledge-db/
       README.md
       INDEX.md
       _TEMPLATE.md
       explorations/.gitkeep
       solutions/.gitkeep
       errors/.gitkeep
       decisions/.gitkeep

  2. Detect host instructions file (first found):
     - .github/copilot-instructions.md
     - CLAUDE.md
     - AGENTS.md
     - .cursor/rules/
     Create if none exists (prefer CLAUDE.md).

  3. Append HARD-RULE block (check before append to avoid duplicates):
     [See HARD-RULE section below]
```

Bootstrap is safe to run multiple times. Never overwrites existing entries.

---

## 2. READ Loop (start of task)

1. Open `knowledge-db/INDEX.md`
2. Scan tables for relevant entries by title/tags
3. Grep folder for keywords: `grep -r "keyword" knowledge-db/`
4. If **verified** entry answers question -> use it, stop exploring
5. If **tentative** entry exists -> build on it, upgrade to verified when proven

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

### Consent Before Superseding

**Before marking a VERIFIED entry as SUPERSEDED:**
> "Entry '[title]' is verified. Mark as superseded because [reason]? [Y/N]"

Never change verified entry status without explicit user consent.

### Pick Bucket by Intent

| Intent | Bucket | Example |
|--------|--------|---------|
| Understanding how something works | `explorations/` | "How does auth middleware chain?" |
| Building/changing something | `solutions/` | "Add rate limiting to API" |
| Build/runtime/test failure | `errors/` | "TypeError in payment flow" |
| Choosing between options | `decisions/` | "Why PostgreSQL over MongoDB" |

File under dominant intent, cross-link related entries. For decisions: one entry per choice made.

### Create Entry

1. Copy `_TEMPLATE.md` to appropriate bucket
2. Name: `YYYY-MM-DD-short-kebab-slug.md`
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
6. Add row to INDEX.md (newest on top)
7. Cross-link related entries

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

```markdown
## HARD RULE: Build the Knowledge Database on every task

This repo keeps durable memory in `knowledge-db/` so we never explore the same thing twice and never re-introduce a fixed bug. For EVERY non-trivial task (agent or human):

1) **READ FIRST** — search `knowledge-db/` (start with INDEX.md); reuse a verified entry.
2) **DO THE WORK**.
3) **WRITE BACK** — copy _TEMPLATE.md into explorations|solutions|errors|decisions, ground every claim in a real source file, set status, update INDEX.md. errors/ entries must record Symptom -> Root cause -> Fix -> Prevention.

**AUTO-CAPTURE**: Non-trivial work = KB entry created. This is mandatory, not optional.
**INCREMENTAL**: Record findings AS THEY OCCUR, not batched at session end. Session can end anytime.
**CONSENT**: Only required before superseding verified entries.

Leaving a task without KB entries is incomplete work.
```

---

## Bundled Templates

The following files are created during bootstrap. Content defined in companion files:
- `README.md` - KB rules and usage guide
- `INDEX.md` - Entry catalog (4 tables + tag vocab)
- `_TEMPLATE.md` - Entry format template
