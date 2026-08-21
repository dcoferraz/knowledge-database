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

## The Nine Enforcement Mechanisms

> **Implementation Status**: These mechanisms are conventions enforced by agent behavior (reading this file). They are NOT automated (no hooks, CI gates, or runtime validation). See Phase 2 in roadmap/ for planned automation.

### 1. Always-On Enforcement

- Loop is mandatory, not triggered by user phrases
- **Planned**: On adoption, auto-append HARD RULE to agent config. Not yet implemented - requires manual copy.

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

> **Note**: Currently manual verification via checklist. Automated detection (git hook or CI) planned for Phase 2.

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

| Scope | Contents | Location | Status |
|-------|----------|----------|--------|
| **user** | Cross-project preferences, personal patterns | `~/.kb/user/` or agent config | **Planned** |
| **repo** | Verified codebase facts, build/deploy gotchas, conventions | `knowledge-db/` | Implemented |
| **session** | Task-only working notes (discardable) | In-memory or temp file | Agent-native |

Write build/runtime traps and fixes to **repo scope** so they're reused, not rediscovered.

> **Note**: User-scope (`~/.kb/user/`) is not yet implemented. Currently all KB lives in repo scope.

### 7. Maintenance + Dedup Discipline

- **Reuse tags**: grep existing tags before creating new ones; vocabulary lives in INDEX.md
- **Search before creating**: if near-duplicate exists, UPDATE it instead of adding new
- **Fix wrong entries**: set `status: superseded`, link replacement. Never leave known-wrong notes.
- **Periodic lint**: every entry has sources, valid status, INDEX row; newest rows on top

### 8. Auto-Capture (Mandatory)

**At the END of every non-trivial task, CREATE a KB entry.**

```
Creating KB entry for: [describe work]
  Bucket: [suggested bucket]/
  Status: [verified if proven, tentative if not]

Review and confirm entry content.
```

This is NOT optional. Non-trivial work = KB entry created. The only user input is reviewing the entry content, not deciding whether to create it.

"Non-trivial" = search, multi-file reads, debugging, or decisions. One-liners (typo fix, rename) are trivial and skip this.

### 9. Consent Before Superseding Verified

**Before marking a VERIFIED entry as SUPERSEDED**, ask user:
> "Entry '[title]' is verified. Mark as superseded because [reason]? [Y/N]"

Verified entries represent proven knowledge. Never change their status without explicit user consent.

**Opt-out:** Add `supersede_without_consent: true` to workspace CLAUDE.md to allow autonomous superseding.

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

Run at END of every non-trivial task. Task is INCOMPLETE until all pass:

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
./scripts/init-knowledge-db.sh
```

Creates `knowledge-db/` with templates and empty buckets.

---

## Tooling

```bash
# Ingest text/transcripts into KB entries
./scripts/kb-ingest --input notes.txt --auto

# Discover codebase boundaries
./scripts/kb-discover ./target-app

# Lint KB for issues (missing sources, INDEX sync, etc.)
./scripts/kb-lint
```
