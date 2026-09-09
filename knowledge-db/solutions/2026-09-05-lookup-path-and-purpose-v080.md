---
title: "v0.8.0: cheap lookup path, reuse rule, and a README that states the purpose"
type: solution
status: verified
date: 2026-09-05
tags: [area:tooling, area:release, layer:cli]
sources:
  - knowledge-db/bin/kb:1290-1420
  - knowledge-db/README.md:1-60
  - CHANGELOG.md:8-45
related:
  - 2026-09-05-reuse-ends-the-task
  - 2026-09-04-token-cost-benchmark
  - 2026-09-04-audit-fixes-v070
---

## Summary

Shipped `kb find` and `kb show` (a reuse costs ~400-650 tokens instead of
~3,000), the reuse-ends-the-task rule, and a KB README that finally says what the
thing is for and where it does not pay. All of it came from a benchmark that
failed to show the saving it was built to demonstrate.

## Context / Question

Three questions from the same conversation: fix the issues the demo exposed, cut
what an agent spends *using* the KB, and put the purpose in the README — which
until now documented fifteen rules and never said why anyone should follow them.

## Findings / What We Did

**Cheap lookup.** `kb find "<keywords>"` ranks entries by matches in title
(weight 8), tags (4), slug (3) and body (capped), and prints entry, status,
title, a three-line summary and the sources. `kb show <entry>` resolves a
bucket path, filename or slug fragment and prints the first three actionable
sections (Fix, Summary, Prevention, Root Cause, Decision, Findings) with
`--all` and `--lines` escape hatches. Both are stdlib-only, like the rest.

**Rules.** Rewritten in place, same budget: rule 1 is now LOOK UP FIRST (with
"not ls/find/INDEX.md"), rule 2 is REUSE ENDS IT, rule 5 is WRITE BACK NEW
KNOWLEDGE ONLY. The planted block gets the same five rules in full prose. Since
the planted text is generated (v0.7.0), every runtime file was replanted by
rerunning `install.sh`, and KB014 confirmed zero drift afterwards.

**Purpose in the README.** New "What it is for" section leading with the claim
the evidence supports — *your agents give the same answer twice, and can show
their work* — carried by the measured convergence result (two KB-less agents
invented two different APIs for the same fix; the KB-equipped one reproduced the
recorded API and call sites exactly). Plus a table of what you get and what
enforces it, a "where it pays and where it does not" section that names the
cases to walk away from, and an explicit cost line. The old header claim
("never investigate the same thing twice") was removed: it promises token
savings that the measurements do not support at small scale.

The same positioning went into `marketplace.json` and `SKILL.md`, so the pitch
matches the evidence everywhere it appears.

## Verification

```
$ knowledge-db/bin/kb find "half cent rounding" -n 1
errors/2026-01-20-half-cent-rounding.md  [tentative]
  Half-cent money rounding lost a cent
  round(x, 2) is banker's rounding on a binary float, so half-cents go down.
  sources: src/app.txt:1

$ bash tests/run-kb-tests.sh | tail -2
Results: 76 passed, 0 failed
All KB conformance tests passed

$ bash tests/run-tests.sh | tail -2
Results: 33/33 passed
All tests passed

$ knowledge-db/bin/kb version
kb tool version: 0.8.0
kb.config.json kb_version: 0.8.0

$ knowledge-db/bin/kb check; echo "exit=$?"
exit=0

$ knowledge-db/install.sh --check | tail -2
IN PLACE   CI job (.github/workflows/kb-check.yml)
IN PLACE   agent hard rules (all 6 runtime files current, referencing knowledge-db/AGENT.md)
```
