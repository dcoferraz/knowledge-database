# Knowledge Database

This folder is the project's **durable memory**. Never investigate the same thing twice. Never re-introduce a fixed bug.

## The Hard Rule (Mandatory, Not Opt-In)

Every non-trivial task follows this loop — **no exceptions**:

1. **READ FIRST** — Check INDEX.md (Ready-Answer Table + entries). If answered, USE IT and STOP.
2. **DO THE WORK** — Explore or implement.
3. **WRITE BACK** — Run Write-Back Checklist. Task is INCOMPLETE until checklist passes.

"Non-trivial" = anything requiring search, reading multiple files, debugging, or making decisions.

## Folder Structure

```
knowledge-db/
  README.md        <- You are here
  INDEX.md         <- Front door: Ready-Answer Table + entry catalog
  _TEMPLATE.md     <- Copy this to create new entries
  explorations/    <- "What is true" - findings from investigation
  solutions/       <- "What we did" - implementation details
  errors/          <- "What broke + the fix" - reproducible traps
  decisions/       <- "Why we chose X" - design trade-offs
```

## Which Bucket?

| Your intent | Bucket |
|-------------|--------|
| Understanding how something works | `explorations/` |
| Building or changing something | `solutions/` |
| A build/runtime/test failure | `errors/` |
| Choosing between options | `decisions/` |

File under dominant intent. Cross-link related entries.

## Entry Format

Named `YYYY-MM-DD-short-kebab-slug.md` with YAML front-matter:

```yaml
---
title: Short human title
type: exploration | solution | error | decision
status: verified | tentative | superseded
date: YYYY-MM-DD
tags: [area:<area>, layer:<layer>]
sources:
  - path/to/file.ts:42-56    # REQUIRED: ground every claim
related:
  - solutions/other-entry.md  # REQUIRED if superseded
---
```

## Status Rules

| Status | Meaning | Requirements |
|--------|---------|--------------|
| `verified` | Proven true | Verification block with ACTUAL PROOF |
| `tentative` | Best understanding | Any unsourced claim |
| `superseded` | Outdated | `related:` MUST link replacement |

**No proof = no verified.** Verification block must contain: command + output, test result, row count, or screenshot.

## Error Entries

MUST have all four sections:

1. **Symptom** — Exact error message/behavior
2. **Root Cause** — Why? (cite source files)
3. **Fix** — What changes? (file paths + code)
4. **Prevention** — How to avoid in future?

## Lock-Step Invariants

Some changes require paired updates. Check INDEX.md for declared invariants:
- Schema change → schema doc
- API change → API doc
- Config change → deployment doc

Task is INCOMPLETE if code changed but paired doc didn't.

## Write-Back Checklist

Run at END of every non-trivial task:

```
[ ] Entry in correct bucket (YYYY-MM-DD-slug.md)
[ ] EVERY claim has source file (path:line-range)
[ ] Status correct (verified requires proof)
[ ] INDEX.md row added (newest on top)
[ ] Related entries cross-linked
[ ] Superseded any now-wrong entries
[ ] Lock-step invariants satisfied
[ ] Searched for duplicates first
```

## Maintenance Rules

- **Reuse tags**: `grep -r "tags:" knowledge-db/` before creating new
- **Search before creating**: update existing entry if near-duplicate
- **Fix wrong entries**: set superseded + link replacement
- **Keep INDEX current**: newest rows on top, all entries listed
