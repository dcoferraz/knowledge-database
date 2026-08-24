---
title: Multi-runtime rule planting (belt-and-suspenders delivery)
type: solution
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement, tech:bash]
sources:
  - knowledge-db/install.sh:231-238
  - knowledge-db/install.sh:240-268
  - knowledge-db/install.sh:272-303
related:
  - explorations/2026-08-24-multi-runtime-rule-delivery-parity.md
  - solutions/2026-08-24-prompt-injected-rules-and-doc-writeback.md
---

## Summary

install.sh layer 6 refactored from "append HARD RULE to the first existing host
file" into planting the block in all 6 runtime files the major agents auto-ingest.
Closes parity items #1, #2, #4 from the parent-project feedback; `--check` audits
every target.

## Context / Question

Parent-project feedback: rules must live in auto-loaded context files for EVERY
runtime, in >= 2 files, with an `applyTo: '**'` Copilot instructions file — passive
artifacts requiring human copy-paste are the gap. Previous code planted exactly one
file (first of CLAUDE.md / AGENTS.md / copilot-instructions.md).

## Findings / What We Did

- `RULE_TARGETS` registry (knowledge-db/install.sh:231-238): CLAUDE.md, AGENTS.md,
  .github/copilot-instructions.md, .github/instructions/kb.instructions.md
  (`applyTo: '**'`), .cursor/rules/knowledge-db.mdc (`alwaysApply: true`),
  .windsurfrules. Restricting = deleting rows; `--check` mirrors the list.
- Shared body `emit_rule_block` + per-kind `emit_frontmatter`
  (knowledge-db/install.sh:240-268): single source for rule text, path-bound via
  `$KB_NAME`; frontmatter only when creating a file fresh, marker-merge append when
  it already exists.
- Plant loop (knowledge-db/install.sh:272-303): marker-guarded create-or-merge,
  idempotent; MISSING report names the exact files lacking the block.
- Conformance tests: all-6 planted, both frontmatter shapes, idempotent rerun,
  drift detection (tests/run-kb-tests.sh, suite 23 tests).
- Deferred from feedback: setup.ps1 (installer already requires bash+python3+git).

## Verification

```
$ tests/run-kb-tests.sh | tail -8
  all 6 runtime files planted... PASS
  copilot instructions applyTo frontmatter... PASS
  cursor mdc alwaysApply frontmatter... PASS
  installer idempotent (rerun changes nothing)... PASS
  check fails when a planted file is removed... PASS

Results: 23 passed, 0 failed
All KB conformance tests passed

$ knowledge-db/install.sh --check | tail -1
IN PLACE   agent hard rules (all 6 runtime files reference knowledge-db/AGENT.md)
```
