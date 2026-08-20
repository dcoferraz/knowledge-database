# Knowledge Database

This folder is the project's **durable memory**. Its purpose: never investigate the same thing twice, and never re-introduce a bug already fixed.

## The Hard Rule

Every non-trivial task follows this loop:

1. **READ FIRST** — Search this folder before exploring. Reuse a verified entry instead of re-exploring.
2. **DO THE WORK** — Explore or implement.
3. **WRITE BACK** — Record what you learned/changed/broke+fixed. Update INDEX.md.

"Non-trivial" = anything requiring search, reading multiple files, debugging, or making decisions.

## Folder Structure

```
knowledge-db/
  README.md        <- You are here
  INDEX.md         <- Front door: catalog of all entries
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

File under the dominant intent. Cross-link related entries.

## Entry Format

Every entry is named `YYYY-MM-DD-short-kebab-slug.md` with YAML front-matter:

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

## Status Meanings

- **verified** — Proven true (tests pass, output confirmed, reproduced)
- **tentative** — Best current understanding, not yet proven
- **superseded** — Kept for history; `related` points to replacement

## Content Rules

1. Ground every claim in a source file (path + line range)
2. Unsourced claims -> tentative status
3. Write the answer, not the journey
4. `errors/` entries MUST have: Symptom -> Root cause -> Fix -> Prevention
5. Keep entries current: wrong = fix it, mark superseded, link replacement
6. Small + linked beats large + orphaned
