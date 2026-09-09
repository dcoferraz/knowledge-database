---
title: "KB008 staleness is opt-in and warns by default"
type: decision
status: verified
date: 2026-09-04
tags: [area:tooling, layer:enforcement]
sources:
  - knowledge-db/bin/kb:388-402
  - knowledge-db/kb.config.json:56
related:
  - 2026-09-04-audit-fixes-v070
---

## Summary

The 90-day expiry on `verified` entries is gone from shipped configs. KB008 now
fires only when a project declares `staleness_days.verified`, and then it warns;
`"mode": "error"` restores the hard gate.

## Context / Question

KB008 was a hard failure at 90 days. Every entry in this repo carries the same
date, so on one specific later day the whole KB would start failing at once —
and because `kb check` backs the pre-commit hook, the CI job and the agent Stop
hook, that single day would block every commit and every session end in the
repo until each entry was re-verified. What should staleness cost?

## Findings / What We Did

Options considered:

1. **Opt-in, warning by default** (chosen) — nothing expires unless a project
   asks for it; a declared budget nags without blocking; `mode: error` is there
   for teams that want the gate.
2. Keep the gate, add `kb reverify` tooling and an early-warning window — still
   converts a date into a repo-wide outage, just with better ergonomics.
3. Warning always — simplest, but removes a legitimate freshness gate for teams
   that do want CI to fail on rotten entries.

Reasoning: freshness is a judgment call about a project's rhythm, not a
mechanical property of an entry, and the cost of the old default was
catastrophic-by-calendar. A rule that can take a repo down on a date nobody
picked is not enforcement, it is a time bomb. The user's call was explicit:
remove the 90-day expiry.

Kept as a rule ID rather than deleted, because "enforce or delete rule IDs" only
forbids unenforceable rules — this one is enforceable, just configured off.

## Verification

```
$ python3 -c "
import json; p='knowledge-db/kb.config.json'
print(json.load(open(p))['staleness_days'])"
{}

$ bash tests/run-kb-tests.sh 2>&1 | grep -A2 "KB008 staleness is opt-in"
Testing KB008 staleness is opt-in
  no staleness budget: an old verified entry passes... PASS
  declared budget: warns without failing... PASS

$ bash tests/run-kb-tests.sh 2>&1 | grep "KB008 detected"
  KB008 detected... PASS
```
