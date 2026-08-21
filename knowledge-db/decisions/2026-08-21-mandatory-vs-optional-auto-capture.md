---
title: "Mandatory vs optional auto-capture"
type: decision
status: verified
date: 2026-08-21
tags: [area:tooling, layer:enforcement]
sources:
  - CLAUDE.md:103-139
  - knowledge-database/SKILL.md:79-102
related:
  - solutions/2026-08-21-kb-v2-improvements.md
  - decisions/2026-08-21-incremental-vs-batched-capture.md
---

## Summary

Auto-capture is mandatory (non-trivial work = KB entry created), not an optional prompt.

## Context / Question

Original v0.2.0 design prompted user at task end:
```
This session involved [work]. Create KB entry?
  [Y] Create  [N] Skip  [T] Tentative
```

User feedback: "why does it prompt to record an entry? it should be a hard rule"

## Options Considered

**Option A: Optional prompt (original)**
- User decides whether to create entry
- Risk: Users skip entries, memory degrades
- Aligns with "user is in control"

**Option B: Mandatory capture (chosen)**
- Non-trivial work = entry created automatically
- User reviews content, not whether to create
- Aligns with KB's core promise: "never investigate twice"

## Decision

**Option B: Mandatory capture**

Rationale:
- KB value compounds with coverage - optional creation leads to gaps
- "Never investigate twice" requires comprehensive capture
- User still controls content quality, just not existence
- Skipping defeats the purpose of the system

## Verification

v0.2.1 released with mandatory auto-capture. CLAUDE.md:103-139 and SKILL.md:79-102 updated to remove Y/N/T prompt and state "This is mandatory, not a prompt."
