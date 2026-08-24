---
title: Prompt-injected rules and doc write-back (KB013)
type: solution
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement, tech:python, tech:bash]
sources:
  - knowledge-db/bin/kb:867-888
  - knowledge-db/bin/kb:854-862
  - knowledge-db/install.sh:98-140
  - knowledge-db/kb.config.json:77-90
related:
  - decisions/2026-08-24-inject-rules-every-prompt.md
---

## Summary

Two enforcement gaps closed: (1) `kb rules` subcommand + UserPromptSubmit hook inject
the hard rules into agent context on every prompt, so they are active immediately after
install and immune to mid-session installs or context loss; (2) KB013 extends the
write-back trigger to decision-bearing docs via `writeback.docs` globs.

## Context / Question

Field failure while dogfooding in the kb-central workspace: a user decision recorded
only in CLAUDE.md produced no KB entry despite full enforcement. Root causes: CLAUDE.md
rules load only at session start (install happened mid-session); Stop hook validates
entry format, cannot detect missing entries; KB011 covers only `writeback.code` globs
and only at commit time.

## Findings / What We Did

- `kb rules` (knowledge-db/bin/kb:867-888): prints a compact `<kb-hard-rules>` block
  (read-first, empty-KB, never-prompt, write-back-now) derived from config buckets.
- install.sh layer 3 (knowledge-db/install.sh:98-140): idempotently merges a
  UserPromptSubmit hook running `kb rules` into `.claude/settings.json`; `--check`
  audits it like every other layer.
- KB013 (knowledge-db/bin/kb:854-862): diff-mode rule — a staged/PR diff touching
  `writeback.docs` paths (knowledge-db/kb.config.json:77-90; default CLAUDE.md,
  AGENTS.md, docs/**, adr/**) without touching `knowledge-db/**` fails, pointing at
  `decisions/`.
- Conformance: fixture tests/fixtures/fail/KB013/ + `kb rules` output test in
  tests/run-kb-tests.sh; templates (.kb-templates/) synced.

## Verification

```
$ tests/run-kb-tests.sh
  ...
  KB011 detected (staged diff)... PASS
  KB013 detected (staged diff)... PASS
  kb rules output... PASS
Results: 18 passed, 0 failed
All KB conformance tests passed

$ knowledge-db/install.sh --check
IN PLACE   KB scaffold (knowledge-db/)
IN PLACE   agent Stop hook (.claude/settings.json)
IN PLACE   agent prompt rules hook (.claude/settings.json UserPromptSubmit)
IN PLACE   pre-commit hook (.githooks/pre-commit)
IN PLACE   git core.hooksPath = .githooks
IN PLACE   CI job (.github/workflows/kb-check.yml)
IN PLACE   agent hard rules (CLAUDE.md references knowledge-db/AGENT.md)
```
