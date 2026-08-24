---
title: Multi-runtime rule delivery parity (external feedback)
type: exploration
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement]
sources:
  - knowledge-db/install.sh:174-182@9ef9c08
  - knowledge-db/install.sh:198-215@9ef9c08
related:
  - solutions/2026-08-24-prompt-injected-rules-and-doc-writeback.md
  - solutions/2026-08-24-multi-runtime-rule-planting.md
---

## Summary

External feedback (parent project, 2026-08-24): enforcement content exists but the
delivery mechanism only auto-loads for ONE agent runtime. Parity gaps: no multi-file
rule planting (>= 2 runtime files), no Cursor/Windsurf targets, no Copilot
`applyTo: '**'` instructions file. Installer idempotence and path binding already
meet the bar; Claude Code hooks exceed it.

## Context / Question

What would the public GitHub version need, purely technically, to match an internal
setup where rules live in auto-loaded context files rather than passive artifacts a
human must copy-paste?

## Findings / What We Did

Checklist from feedback, evaluated against install.sh:

1. Pre-written auto-loaded files per runtime — PARTIAL: `find_host_file`
   (knowledge-db/install.sh:174-182@9ef9c08) plants the HARD RULE into the FIRST existing of
   CLAUDE.md / AGENTS.md / .github/copilot-instructions.md — exactly one file. No
   `.cursor/rules/*.mdc`, no `.windsurfrules`.
2. Copilot `.instructions.md` with `applyTo: '**'` frontmatter — MISSING.
3. Idempotent create-or-merge installer — HAVE (install.sh, marker-guarded,
   `--check`). Bash-only; no setup.ps1 (deferred: bash+python3+git already required).
4. Rule in >= 2 runtime files (belt-and-suspenders) — MISSING: we plant one.
5. Path binding (rule text uses the exact installed KB path) — HAVE: `$KB_NAME` is
   interpolated into the block (knowledge-db/install.sh:198-215@9ef9c08).

Beyond the checklist: UserPromptSubmit (`kb rules`) + Stop hooks are stronger than
auto-loaded files but Claude Code-only; other runtimes' ceiling is always-applied
rule files (Cursor `alwaysApply: true` .mdc is the closest analog).

SHIPPED same day (v0.5.0): layer 6 refactored into a `RULE_TARGETS` registry loop —
plain-append targets (CLAUDE.md, AGENTS.md, copilot-instructions.md, .windsurfrules)
+ frontmatter targets (.github/instructions/kb.instructions.md with `applyTo: '**'`,
.cursor/rules/knowledge-db.mdc with `alwaysApply: true`), one shared rule-body
generator, `--check` auditing every target. All planted by default; restricting =
editing the registry (planned `--agents` flag dropped as unneeded surface). See
solutions/2026-08-24-multi-runtime-rule-planting.md.

## Verification

```
$ grep -n "find_host_file()" knowledge-db/install.sh
219:find_host_file() {

$ grep -rn "cursor\|windsurf\|applyTo" knowledge-db/install.sh
(no output — no Cursor/Windsurf/applyTo targets exist yet)
```
