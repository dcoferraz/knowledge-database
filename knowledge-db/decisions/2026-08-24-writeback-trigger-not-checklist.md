---
title: "Write-back as a diff-driven trigger (KB011), not an end-of-task checklist"
type: decision
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement]
sources:
  - knowledge-db/bin/kb:488-510
  - knowledge-db/kb.config.json:32-35
related:
  - solutions/2026-08-24-kb-enforcement-tooling.md
  - decisions/2026-08-21-incremental-vs-batched-capture.md
---

## Summary

The write-back gate is now automatic: KB011 fails any staged/PR diff that touches `writeback.code` paths without touching `knowledge-db/**`, naming the bucket the entry probably belongs in. The 8-item manual checklist is demoted to a walkthrough of what the rules already check.

## Context / Question

The evaluator's deployment shipped three waves of work with no KB entry despite the mandatory checklist — end-of-task rituals get skipped precisely when they matter (tired, late, "just one more commit"). Options: (A) keep the checklist and strengthen the prose, (B) one diff-driven rule that fires mechanically at commit and CI time.

## Findings / What We Did

Chose (B). Implementation: knowledge-db/bin/kb:488-510 (`check_diff_rules`); code paths declared in knowledge-db/kb.config.json:32-35. Runs in `kb check --staged` (pre-commit) and `kb check --diff-base` (CI PR job). One rule replaces the eight-item ritual as the hard gate; the checklist text survives in CLAUDE.md only as explanation.

## Verification

Conformance fixture: temp git repo, `src/` change staged with no KB entry (captured 2026-08-24):

```bash
$ tests/run-kb-tests.sh
  KB009 detected (staged diff)... PASS
  KB011 detected (staged diff)... PASS
Results: 14 passed, 0 failed
```
