---
title: Inject hard rules every prompt, not only at session start
type: decision
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement]
sources:
  - knowledge-db/install.sh:98-140
  - knowledge-db/bin/kb:867-888
related:
  - solutions/2026-08-24-prompt-injected-rules-and-doc-writeback.md
---

## Summary

Chose a UserPromptSubmit hook running `kb rules` (context injection on every prompt)
over relying solely on the CLAUDE.md HARD RULE block (session-start only). Both are
kept: CLAUDE.md for humans and non-hook agents, the hook as the always-on layer.

## Context / Question

The CLAUDE.md-only approach failed in the field: rules appended mid-session never
entered the running agent's context, and long sessions can compact/lose early context.
Options: (A) session-start block only (status quo), (B) inject full AGENT.md per
prompt, (C) inject a compact rules block per prompt.

## Findings / What We Did

Chose (C):

- (A) fails mid-session installs and context loss — the observed bug.
- (B) costs ~650 tokens per prompt for prose the compact block covers.
- (C) is ~200 tokens per prompt, derives bucket names from kb.config.json at runtime
  (knowledge-db/bin/kb:867-888), and points to AGENT.md for the full rules.
- Hook merge is idempotent and non-clobbering, same pattern as the Stop hook
  (knowledge-db/install.sh:98-140).

Trade-off accepted: per-prompt token overhead on every request in exchange for rules
that cannot fall out of context. Tunable later (e.g. inject every N prompts) if cost
becomes an issue.

## Verification

```
$ knowledge-db/bin/kb rules | head -3
<kb-hard-rules source="knowledge-db/AGENT.md">
Durable memory lives in knowledge-db/ (buckets: explorations/, solutions/, errors/, decisions/). MANDATORY on every non-trivial task:
1. READ FIRST — check knowledge-db/INDEX.md before exploring; reuse verified entries.

$ knowledge-db/install.sh --check | grep prompt
IN PLACE   agent prompt rules hook (.claude/settings.json UserPromptSubmit)
```
