---
title: "Forward agent hard rules on install: AGENT.md + install.sh layer 5"
type: solution
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement]
sources:
  - knowledge-db/AGENT.md:1-54
  - knowledge-db/install.sh:174-217
  - scripts/init-knowledge-db.sh:42-68
  - knowledge-database/SKILL.md:37-72
related:
  - solutions/2026-08-24-kb-enforcement-tooling.md
  - decisions/2026-08-24-autonomous-superseding-no-prompts.md
  - decisions/2026-08-24-kb-tracked-by-default.md
---

## Summary

Installing the KB on a target project now forwards the agent hard rules through every install path: `knowledge-db/AGENT.md` (portable rules: always-read-first, empty-KB bootstrap suggestions, never-prompt) travels with the KB folder, and `install.sh` layer 5 appends a marker-guarded HARD RULE block to the host instructions file (CLAUDE.md / AGENTS.md / copilot-instructions.md, creating CLAUDE.md if none).

## Context / Question

Audit found the hard rules were NOT reliably forwarded: only the plugin/SKILL.md path appended a HARD-RULE block (agent-driven, easy to skip); `scripts/init-knowledge-db.sh` forwarded nothing agent-facing and did not copy the v0.4.0 enforcement (kb.config.json, bin/kb, install.sh); install.sh wired hooks but no agent instructions. Maintainer requirements: agents ALWAYS check the KB; empty KB triggers a suggestion (exploration OR manual document/context input); never prompt the user; never withhold saving.

## Findings / What We Did

- knowledge-db/AGENT.md:1-54 — portable hard rules, 4 sections: ALWAYS READ FIRST, EMPTY KB (suggest kb-discover exploration OR manual docs via kb-ingest, then continue — never block), NEVER PROMPT NEVER WITHHOLD, WRITE BACK.
- knowledge-db/install.sh:174-217 — layer 5: detects host file (CLAUDE.md > AGENTS.md > .github/copilot-instructions.md, creates CLAUDE.md if none), appends `<!-- kb:agent-rules:start -->`-guarded block; `--check` asserts the marker.
- scripts/init-knowledge-db.sh:42-68 — now copies AGENT.md + kb.config.json (generic template) + bin/kb + install.sh, and generates INDEX.md via `kb index` instead of copying a stale template.
- knowledge-database/SKILL.md:37-72 — bootstrap copies the full skeleton and delegates rule-forwarding to install.sh; READ loop is "ALWAYS — start of EVERY task" with the empty-KB step.
- .kb-templates/ synced (README, _TEMPLATE, AGENT.md, generic kb.config.json); stale INDEX.md template removed.

## Verification

Fresh temp git repo end-to-end (captured 2026-08-24):

```bash
$ scripts/init-knowledge-db.sh && knowledge-db/bin/kb check; echo CHECK=$?
CHECK=0
$ knowledge-db/install.sh
CHANGED    agent Stop hook merged into .claude/settings.json
CHANGED    pre-commit hook written to .githooks/pre-commit
CHANGED    git core.hooksPath set to .githooks
CHANGED    CI job written to .github/workflows/kb-check.yml
CHANGED    agent hard rules appended to CLAUDE.md
IN PLACE   KB scaffold (knowledge-db/)
$ grep -c "kb:agent-rules:start" CLAUDE.md
1
$ CI=1 knowledge-db/install.sh --check; echo AUDIT=$?
AUDIT=0
```

Second install run: all six layers IN PLACE (idempotent). This repo dogfoods layer 5: same block appended to its own CLAUDE.md.
