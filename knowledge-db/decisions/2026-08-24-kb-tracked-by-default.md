---
title: "KB is git-tracked by default; gitignore only via --local flag"
type: decision
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement]
sources:
  - scripts/init-knowledge-db.sh:5-19
  - scripts/init-knowledge-db.sh:71-105
related:
  - solutions/2026-08-24-agent-rules-forwarding.md
  - decisions/2026-08-24-writeback-trigger-not-checklist.md
---

## Summary

`init-knowledge-db.sh` no longer gitignores the KB by default; `--local` opts into an untracked personal KB. A committed KB is required for the write-back trigger to function and for knowledge to survive clones.

## Context / Question

The old init script always appended `knowledge-db/` to the target repo's .gitignore ("local memory, not committed"). Two problems: (1) KB011 compares diffs — a gitignored KB never appears in any diff, so the write-back trigger can never pass and would flag every code change forever; (2) an untracked KB dies with the working copy, contradicting "never keep from saving important information" — the durable-memory premise. Options: (A) keep gitignore default, (B) tracked default with `--local` opt-out.

## Findings / What We Did

Chose (B). Tracked default: scripts/init-knowledge-db.sh:5-19 (flag parsing, rationale comment); gitignore now runs only under `$LOCAL_KB` (scripts/init-knowledge-db.sh:103-105). Teams wanting personal scratch memory still get it with `--local`, accepting that KB011 diff enforcement will not see their entries.

## Verification

Fresh temp repo, default init, then install (captured 2026-08-24):

```bash
$ scripts/init-knowledge-db.sh && knowledge-db/bin/kb check; echo CHECK=$?
CHECK=0
$ cat .gitignore
no .gitignore (KB tracked)
```

Legacy suite unaffected: `tests/run-tests.sh` -> "Results: 23/23 passed".
