---
title: "Incremental capture vs batched at session end"
type: decision
status: verified
date: 2026-08-21
tags: [area:tooling, layer:enforcement]
sources:
  - CLAUDE.md:164-196
  - knowledge-database/SKILL.md:89-103
last_verified: 2026-08-24
related:
  - decisions/2026-08-21-mandatory-vs-optional-auto-capture.md
  - solutions/2026-08-21-kb-v2-improvements.md
---

## Summary

Record findings AS THEY OCCUR, not batched at session end. This is Mechanism 10: Incremental Capture.

## Context / Question

During this session, we consolidated multiple decisions into one solutions/ entry. User pointed out:
- "every conversation can trigger a KB entry"
- "imagine user logged off mid session - we should prevent memory loss"
- "we need to make it iron proof"

Original design said "at END of every non-trivial task, create KB entry" - single point of failure.

## Options Considered

**Option A: Batch at session end (original)**
- Create entries when task completes
- Risk: Session ends unexpectedly = all insights lost
- Simpler - one capture moment

**Option B: Incremental capture (chosen)**
- Record findings as they occur
- Decision made? Create decision entry NOW
- Bug fixed? Create error entry NOW
- Session crash = only lose work since last capture

## Decision

**Option B: Incremental capture**

Rationale:
- Sessions end unexpectedly: context exhaustion, logout, crash, network issues
- Memory not committed = memory lost
- Each insight is valuable independently
- "If session ended RIGHT NOW, would this insight survive?" test
- Matches decisions/ granularity rule: one entry per choice

## Verification

Mechanism 10 stated in both docs (captured 2026-08-24):

```bash
$ sed -n '164p;166p' CLAUDE.md
### 10. Incremental Capture (Session Resilience)
**Record findings AS THEY OCCUR, not batched at session end.**
$ sed -n '89p;91p' knowledge-database/SKILL.md
### Incremental Capture (Session Resilience)
**Record findings AS THEY OCCUR, not batched at session end.**
```

The v0.3.0 session created separate decision entries during work (not batched at end), demonstrating the pattern.
