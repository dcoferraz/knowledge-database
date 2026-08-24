---
title: "decisions/ bucket: one entry per choice"
type: decision
status: verified
date: 2026-08-21
tags: [area:tooling, layer:enforcement]
sources:
  - CLAUDE.md:115-129
  - knowledge-database/SKILL.md:104-114
last_verified: 2026-08-24
related:
  - decisions/2026-08-21-incremental-vs-batched-capture.md
---

## Summary

The decisions/ bucket uses "one entry per CHOICE" granularity, not "one entry per task/session". Multiple choices in one session = multiple decision entries.

## Context / Question

During this session, we made 4+ distinct decisions but rolled them into one solutions/ entry. User asked: "why did we not save decisions we were making if we're using KB skill?"

Root cause: Original guidance said "one entry covers whole task" without distinguishing bucket-specific granularity.

## Options Considered

**Option A: One entry per task (all buckets)**
- Simple rule
- Consolidates related work
- Risk: Decisions get buried in solutions

**Option B: Bucket-specific granularity (chosen)**
- solutions/ = one per feature/fix
- errors/ = one per bug
- explorations/ = one per question
- decisions/ = one per CHOICE

## Decision

**Option B: Bucket-specific granularity**

Rationale:
- Different buckets serve different lookup patterns
- "How did we implement X?" = one solution entry
- "Why did we choose Y over Z?" = one decision entry per choice
- If you debated A vs B, that's one entry
- Future lookup is "why this choice?" not "what happened that session"

## Verification

Granularity table present in both docs (captured 2026-08-24):

```bash
$ sed -n '115p;124p' CLAUDE.md
#### Entry Granularity
| decisions/ | **One per CHOICE** | "Why mandatory vs optional auto-capture" |
$ sed -n '104p;111p' knowledge-database/SKILL.md
### Entry Granularity
| decisions/ | **One per CHOICE** | "Why mandatory vs optional auto-capture" |
```

The v0.3.0 session created 4 separate decision entries (this being one of them).
