---
title: ENFORCEMENT.md guide for the six-layer machinery
type: solution
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement]
sources:
  - ENFORCEMENT.md:1-6
  - README.md:465-472
related:
  - solutions/2026-08-24-prompt-injected-rules-and-doc-writeback.md
  - solutions/2026-08-24-multi-runtime-rule-planting.md
---

## Summary

The v0.5.x enforcement machinery (six layers, per-prompt injection, multi-runtime
planting, KB011/KB013 gates) now has a dedicated guide: ENFORCEMENT.md, peer to
ADVANCED.md, linked from the README guides section.

## Context / Question

v0.5.0/v0.5.1 shipped with README/CLAUDE.md mentions only — no deep-dive doc like
ADVANCED.md gives the context-workspace pattern. Users had no single place
explaining what each layer catches, the timing caveats, or how to tune
RULE_TARGETS and the writeback globs.

## Findings / What We Did

- ENFORCEMENT.md (ENFORCEMENT.md:1-6): layer table, per-prompt injection
  mechanics and token cost, multi-runtime planting semantics
  (create-or-merge, marker-guarded, path-bound, RULE_TARGETS restriction),
  KB011/KB013 tuning guidance, audit/repair flow, timing caveats, and the
  bash errexit portability rule.
- README guides section links it with a bullet summary (README.md:465-472),
  mirroring the ADVANCED.md link pattern.

## Verification

```
$ test -f ENFORCEMENT.md && grep -c "^## " ENFORCEMENT.md
6

$ grep -n "ENFORCEMENT.md" README.md
465:**How the enforcement machinery works: [ENFORCEMENT.md](ENFORCEMENT.md)**
```
