---
title: "Downstream upgrade field report: first real KB upgrade to v0.5.2"
type: exploration
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement, layer:cli]
sources:
  - knowledge-db/bin/kb:35-37
  - knowledge-db/kb.config.json:1-8
related:
  - solutions/2026-08-24-multi-runtime-rule-planting.md
  - errors/2026-08-24-writeback-gap-doc-only-decisions.md
---

## Summary

A downstream project (separate agent, older minimal KB copy) upgraded to
v0.5.2 and shared its decision entry. The upgrade succeeded (31 findings ->
exit 0, all entries preserved) but was fully manual. It validates the
config-driven design and exposes four product gaps: no version marker, no
upgrade guide, hardcoded KNOWN_ROOT_FILES, and no guard against
recent-but-false verified entries.

## Context / Question

What does the first real-world upgrade of an installed KB to current upstream
teach about the upgrade experience?

## Findings / What We Did

Validated by the report (worked as designed):

- Config-driven buckets absorbed project-specific `sessions/` and `releases/`
  without touching the CLI.
- `kb check` findings served as the migration worklist (31 findings driven to
  zero without suppressing rules).
- Closed status vocabulary correctly rejected a `resolved` status; they mapped
  it rather than widening the enum, preserving the proof requirement.
- KB004 forced honest downgrades to `tentative` for unreproducible past-state
  claims instead of manufactured proof.

Gaps exposed (their words: traps the upgrade actually hit):

1. **No version marker anywhere.** The old copy carried no version; drift was
   invisible until it hurt. Their follow-up asks for a recorded upstream
   version per upgrade.
2. **No upgrade guide.** They derived the order themselves: back up, pin
   version, vendor ONLY tooling (bin/kb, AGENT.md, README.md, _TEMPLATE.md;
   never upstream entries or generated INDEX), write config from their own
   tag usage instead of copying, treat check findings as migration list,
   regenerate index last.
3. **KNOWN_ROOT_FILES is hardcoded** (knowledge-db/bin/kb:35-37). A stray
   root file fails KB002 with no config escape. Their workaround — a declared
   bucket — is correct, but "extend config, never patch the vendored CLI"
   should be possible for root files too.
4. **Truth-rot outruns staleness.** Entries verified hours earlier carried
   already-false claims (bug listed as open after it was fixed). KB008 is
   time-based; nothing mechanical catches recent-but-false. Upgrade guidance
   must include re-reading every verified entry against HEAD.
5. **install.sh merge deserves an audit-first note.** Their settings.json
   already carried unrelated hooks; the installer merges correctly, but the
   doc should say run `--check` and review before installing.

## Verification

```
$ grep -n "KNOWN_ROOT_FILES" knowledge-db/bin/kb
34:KNOWN_ROOT_FILES = {"README.md", "INDEX.md", "INDEX.html", "_TEMPLATE.md", "AGENT.md",

$ grep -n "version" knowledge-db/kb.config.json
(no output — no version field exists in the shipped config)
```
