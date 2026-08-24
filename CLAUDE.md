# Knowledge Database

This repo implements a **durable memory pattern** for AI coding agents. Never investigate the same thing twice. Never re-introduce a fixed bug.

---

## Workspace Rules

These rules apply to ALL work in this repository:

### No Emojis

Do not use emojis in any file. If visual distinction is needed, use text labels, ASCII art, or markdown formatting instead. Emojis add no value that a few words cannot provide better.

### No AI Co-Author Attribution

Do not add `Co-Authored-By` lines for AI assistants in commit messages. The human is the author. AI is a tool, like a compiler or linter.

---

## HARD RULE: Mandatory on EVERY Non-Trivial Task

**This is not opt-in.** Do not wait for phrases like "record what I learned". The loop is MANDATORY on every non-trivial task.

"Non-trivial" = anything requiring search, reading multiple files, debugging, or decisions. Skip only pure one-liners (rename var, fix typo).

### The Loop

1. **READ FIRST** — Search `knowledge-db/INDEX.md` + canonical docs. If a verified entry or ready-answer doc answers it, USE IT and STOP.
2. **DO THE WORK** — Explore or implement.
3. **WRITE BACK** — Run the Write-Back Checklist below. Task is INCOMPLETE until checklist passes.

---

## The Ten Enforcement Mechanisms

> **Implementation Status**: Mechanically checkable mechanisms are enforced by `knowledge-db/bin/kb check` as rules KB001-KB011 (see knowledge-db/README.md for the rule table). `knowledge-db/install.sh` wires three enforcement layers: agent Stop hook (.claude/settings.json), git pre-commit (.githooks/), and CI (.github/workflows/kb-check.yml). What cannot be mechanically checked remains agent convention, labelled as such.

### 1. Always-On Enforcement

- Loop is mandatory, not triggered by user phrases
- Enforced: `knowledge-db/install.sh` merges a Stop hook running `kb check` into the committed `.claude/settings.json`, and KB011 fails any diff that touches production code without touching `knowledge-db/`

### 2. Routing to Canonical Docs

- `INDEX.md` indexes BOTH KB entries AND external sources of truth (schemas, design docs, API refs)
- Maintain a "Ready-Answer Table": topic → the one doc to read BEFORE re-investigating
- Rule: if a canonical doc answers the question, read that instead of exploring

### 3. Lock-Step Sync Invariants

- Declare paired artifacts that MUST change together:
  - Schema change → update schema snapshot doc
  - API route change → update route reference
  - Config change → update deployment docs
- Before finishing: verify each invariant held. Code changed but paired doc didn't? Task is INCOMPLETE.

> **Note**: Enforced as KB009. Pairs are declared in `knowledge-db/kb.config.json` (`lockstep`) and checked against the diff by `kb check --staged` (pre-commit) and `kb check --diff-base` (CI).

### 4. Source-of-Truth Hierarchy + Hard Grounding

Rank authorities explicitly:
1. Real source assets (code, actual configs)
2. Generated/ETL definitions
3. Outbound feeds
4. Migration/DDL docs

When sources disagree: trust higher rank, note the stale one.

**Ground EVERY claim** in a real source file (path:line-range). No unsourced assertions. Unsourced → `status: tentative`.

### 5. Verified-Evidence Coupling

`status: verified` is ONLY allowed when entry contains a **Verification** block with actual proof:
- Command run + output
- Test name + result
- Row count / parity check
- Screenshot / log snippet

No proof → `status: tentative`. Period.

`status: superseded` → MUST link replacement in `related:`.

### 6. Tiered Memory Scopes

Memory belongs at different levels. Write to the appropriate scope:

| Scope | Contents | Location |
|-------|----------|----------|
| **repo** | Verified codebase facts, build/deploy gotchas, conventions | `knowledge-db/` |
| **session** | Task-only working notes (discardable) | In-memory or temp file |

Write build/runtime traps and fixes to **repo scope** so they're reused, not rediscovered.

> **Future**: User-scope (`~/.kb/user/`) for cross-project preferences planned for Phase 2.

### 7. Maintenance + Dedup Discipline

- **Reuse tags**: grep existing tags before creating new ones; vocabulary lives in INDEX.md
- **Search before creating**: if near-duplicate exists, UPDATE it instead of adding new
- **Fix wrong entries**: set `status: superseded`, link replacement. Never leave known-wrong notes.
- **Periodic lint**: run `knowledge-db/bin/kb check` (KB001-KB012); `bin/kb index` regenerates INDEX.md + INDEX.html from front-matter — never hand-edit outside the `kb:manual` regions (KB007)
- **Archival at scale**: When INDEX.md exceeds ~100 entries, move older entries (6+ months) to `INDEX-archive-YYYY.md`. Keep INDEX.md focused on active knowledge.

### 8. Auto-Capture (Mandatory)

**Non-trivial work = KB entry created.** This is not optional.

```
Creating KB entry for: [describe work]
  Bucket: [suggested bucket]/
  Status: [verified if proven, tentative if not]
```

#### Entry Granularity

Different buckets have different granularity rules:

| Bucket | Granularity | Example |
|--------|-------------|---------|
| solutions/ | One per feature/fix | "KB v2 security fixes" |
| errors/ | One per bug | "YAML injection in kb-ingest" |
| explorations/ | One per question | "How does auth middleware work?" |
| decisions/ | **One per CHOICE** | "Why mandatory vs optional auto-capture" |

**decisions/ rule**: If you debated A vs B, that's one entry. Multiple debates = multiple entries.

**When to split**: If you would search for it separately, it deserves a separate entry.

#### What Triggers Auto-Capture

| Task | Record? | Bucket |
|------|---------|--------|
| Debug failing test | YES | errors/ |
| Investigate "how does X work" | YES | explorations/ |
| Add feature (multi-file) | YES | solutions/ |
| Choose between approaches | YES | decisions/ |
| Rename with reasoning ("why this name?") | YES | decisions/ |
| Fix obvious typo ("teh" -> "the") | NO | - |
| Mechanical find/replace (no judgment) | NO | - |

**Rule of thumb**: If there was reasoning behind the change, record it. Future you will ask "why?"

#### What's Most Valuable to Record

Priority order (highest value first):

1. **Errors with fixes** - Prevents bug reintroduction. Include: symptom, root cause, fix, prevention.
2. **"How X works" investigations** - Prevents re-exploration. Time saved = investigation time.
3. **Decisions with rationale** - Prevents re-debating. Include: options considered, why chosen.
4. **Multi-step solutions** - Prevents redoing work. Include: what was built, key files changed.

**The pattern that compounds**: Every error recorded is a bug that can never be reintroduced. Every exploration recorded is an investigation that never happens twice.

### 9. Autonomous Superseding with Audit Trail

**Never prompt the user** to create, update, or supersede entries — capture must not stall on permission,
and important knowledge must never go unsaved. When new evidence invalidates a VERIFIED entry,
supersede it immediately: state the reason, set `status: superseded`, link the replacement in
`related:` (KB005). Never delete the old entry. Inform the user in the task summary — informing, not asking.

**Opt-in:** `supersede_with_consent: true` in workspace CLAUDE.md restores ask-before-superseding (not recommended; blocks autonomous agents).

### 10. Incremental Capture (Session Resilience)

**Record findings AS THEY OCCUR, not batched at session end.**

Sessions can end unexpectedly:
- Context window exhausted
- User logs off mid-task
- Network disconnection
- System crash

**Memory not committed to KB = memory lost.**

#### Capture Timing

| Event | Action |
|-------|--------|
| Made choice between A and B | Create decision entry NOW |
| Discovered how something works | Create exploration entry NOW |
| Fixed a bug | Create error entry NOW |
| Completed a feature | Create solution entry NOW |

**Do NOT wait** for "task complete" to batch-create entries. Each insight is captured when it occurs.

#### Checkpoint Discipline

During long sessions, after each significant finding:
1. Note the finding (can be brief)
2. Create or update KB entry immediately
3. Continue work

**Rule**: If session ended RIGHT NOW, would this insight survive? If no, record it.

---

## Quick Reference

### Which Bucket?

| Intent | Bucket |
|--------|--------|
| Understanding how something works | `explorations/` |
| Building/changing something | `solutions/` |
| Build/runtime/test failure | `errors/` |
| Choosing between options | `decisions/` |

### Entry Naming

`YYYY-MM-DD-short-kebab-slug.md`

### Status Values

| Status | Meaning | Requirements |
|--------|---------|--------------|
| `verified` | Proven true | Verification block with actual proof |
| `tentative` | Best understanding, unproven | Any claim lacking source |
| `superseded` | Outdated | `related:` links to replacement |

### Error Entries

MUST record all four:
1. **Symptom** — What error/behavior was observed?
2. **Root Cause** — Why? (cite source files)
3. **Fix** — What changes? (file paths + code)
4. **Prevention** — How to avoid in future?

---

## Write-Back Checklist

The hard gate is automatic: KB011 fails any staged/PR diff that touches production
code paths (declared in `kb.config.json` `writeback.code`) without touching
`knowledge-db/`, and `kb check` enforces entry quality (KB001-KB010). The list
below is the manual walkthrough of what those rules check plus the judgment calls
they cannot:

```
[ ] Entry created/updated from _TEMPLATE.md in correct bucket (YYYY-MM-DD-slug.md)
[ ] EVERY claim grounded in real source file (path:line-range)
[ ] Status set correctly (verified REQUIRES proof in Verification block)
[ ] INDEX.md row added/updated (newest on top)
[ ] Related entries cross-linked
[ ] Superseded any now-wrong entries (with link to replacement)
[ ] Lock-step invariants satisfied (paired docs updated in same change)
[ ] Reusable traps written to repo-scope (not just session notes)
[ ] Searched for duplicates before creating new entry
```

**Leaving a task without satisfying this checklist is incomplete work.**

---

## Setup

```bash
./scripts/init-knowledge-db.sh   # creates knowledge-db/ with templates and empty buckets
knowledge-db/install.sh          # wires enforcement: agent hook, git pre-commit, CI
```

---

## Tooling

```bash
# Enforcement CLI (zero-dependency, Python 3 stdlib) — the authoritative validator
knowledge-db/bin/kb new <type> <slug>   # scaffold a valid entry, regen INDEX
knowledge-db/bin/kb index               # regenerate INDEX.md + INDEX.html from front-matter
knowledge-db/bin/kb check               # validate (KB001-KB012); --staged/--diff-base for diff rules
knowledge-db/install.sh                 # wire agent hook + pre-commit + CI (idempotent); --check to audit

# Legacy helpers (bash)
./scripts/kb-ingest --input notes.txt --auto   # ingest text/transcripts into KB entries
./scripts/kb-discover ./target-app             # discover codebase boundaries
./scripts/kb-lint                              # superseded by bin/kb check
```

<!-- kb:agent-rules:start -->
## HARD RULE: Knowledge Database

This repo keeps durable memory in `knowledge-db/`. For EVERY task:

1. **ALWAYS READ FIRST** — check `knowledge-db/INDEX.md` before exploring; reuse verified entries.
2. **EMPTY KB** — if no (relevant) entries exist, say so and suggest either a codebase
   exploration to seed it, or manual document/context input to ingest. Then continue the task.
3. **NEVER PROMPT, NEVER WITHHOLD** — create, update, and supersede KB entries autonomously,
   as insights occur. Superseding a verified entry needs a stated reason and a `related:`
   link to the replacement — never permission.
4. **WRITE BACK** — non-trivial work (search, multi-file reads, debugging, decisions) ends
   with KB entries. `knowledge-db/bin/kb check` must exit 0.

Full rules: `knowledge-db/AGENT.md`. Rule table (KB001-KB011): `knowledge-db/README.md`.
<!-- kb:agent-rules:end -->
