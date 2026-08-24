---
title: "Upgrade experience: kb version, KB014, extra_root_files, UPGRADING.md"
type: solution
status: verified
date: 2026-08-24
tags: [area:tooling, layer:cli, tech:python]
sources:
  - knowledge-db/bin/kb:895-916
  - knowledge-db/bin/kb:228-231
  - UPGRADING.md:1-10
related:
  - explorations/2026-08-24-downstream-upgrade-field-report.md
---

## Summary

The three gaps from the downstream upgrade field report closed in v0.5.3:
version drift is now visible (`kb version` + warning-only KB014), project
files at the KB root have a config escape (`extra_root_files`), and the
upgrade order plus every field-verified trap is documented in UPGRADING.md.

## Context / Question

First real downstream upgrade (older minimal copy to v0.5.2) succeeded but was
fully manual: no version marker existed, KNOWN_ROOT_FILES had no config escape,
and the safe order had to be derived from scratch. See the related exploration
for the full report.

## Findings / What We Did

- `kb_version` recorded in kb.config.json; `check_version_drift`
  (knowledge-db/bin/kb:895-916) emits WARN KB014 on missing/mismatched value —
  warning-only so a mid-upgrade state never hard-fails, and `cmd_version`
  prints tool + config versions. All shipped configs and fixtures stamped.
- KB002 root-file check now accepts names declared in the config's
  `extra_root_files` list (knowledge-db/bin/kb:228-231); the finding message
  names the escape hatch.
- UPGRADING.md (UPGRADING.md:1-10): vendor-tooling / adapt-config /
  migrate-entries order, the trap list (generated INDEX manual regions, strict
  sources grammar, honest KB004 downgrades, closed statuses,
  recent-but-false verified entries), and the audit-first install.sh note.
  Linked from the README guides section.
- Deliberately NOT built: `kb upgrade` automation (one data point is not a
  pattern) and any status-vocabulary widening (the downstream's `resolved`
  mapping was the system working as intended).

## Verification

```
$ knowledge-db/bin/kb version
kb tool version: 0.5.3
kb.config.json kb_version: 0.5.3

$ tests/run-kb-tests.sh | tail -10
  kb version output... PASS
  KB014 warns on version drift without failing... PASS
  undeclared root file fails KB002... PASS
  declared extra_root_files passes... PASS
  ...
Results: 27 passed, 0 failed
All KB conformance tests passed
```
