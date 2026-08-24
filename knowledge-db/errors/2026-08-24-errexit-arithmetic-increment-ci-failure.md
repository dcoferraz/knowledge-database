---
title: set -e kills ((VAR++)) from zero on bash >= 4.1 (CI-only failure)
type: error
status: verified
date: 2026-08-24
tags: [area:test, layer:cli, tech:bash, severity:high]
sources:
  - scripts/kb-lint:10
  - scripts/kb-lint:289
---

## Summary

CI (ubuntu, bash 5) failed 3 legacy kb-lint tests that passed on macOS (bash 3.2).
`set -e` + `((WARNINGS++))` with WARNINGS=0: the post-increment expression evaluates
to 0, returns exit status 1, and bash >= 4.1 applies errexit to `((...))` — the
script dies mid-run. bash 3.2 (macOS default) does not, so it never reproduced locally.

## Symptom

kb-check CI job red on v0.4.1 and v0.5.0 pushes: "runs on empty KB",
"--fix adds missing INDEX entry", "--fix downgrades to tentative" FAIL — 20/23.
Locally 23/23. CI log shows kb-lint output ending right after the first
"WARN: Tags used only once" line (the first `((WARNINGS++))` from zero).

## Root Cause

scripts/kb-lint runs under `set -e` (scripts/kb-lint:10) and counted with
`((ERRORS++))` / `((WARNINGS++))` / `((FIXED++))`. `((VAR++))` returns the
pre-increment value as its status: from 0 that is status 1. bash changed in 4.1 to
honor errexit for arithmetic commands; macOS ships bash 3.2, which ignores it —
platform-dependent death. Trigger existed on every fresh KB: the README.md template
example line `tags: [area:tooling]` is counted by tag hygiene as a single-use tag,
guaranteeing one WARN increment from zero.

## Fix

Replaced every `((VAR++))` / `((VAR += N))` in scripts/kb-lint and scripts/kb-ingest
with `VAR=$((VAR + 1))` / `VAR=$((VAR + N))` — arithmetic ASSIGNMENT is always
status 0, errexit-safe on every bash.

## Prevention

- In any `set -e` bash script, never use bare `((VAR++))`; use `VAR=$((VAR + 1))`.
- Test suites for bash tools must run on Linux bash >= 4.1, not only macOS 3.2 —
  the CI job already does this and is what caught it; treat a red kb-check run as
  a release blocker.

## Verification

```
$ bash -c 'set -e; W=0; ((W++)); echo survived' ; echo "bash 3.2 exit: $?"
survived
bash 3.2 exit: 0        # macOS bash 3.2 ignores the failure -> hid the bug

$ tests/run-tests.sh | tail -3
Results: 23/23 passed
All tests passed

$ ./scripts/kb-lint <fresh-kb> >/dev/null; echo "lint-exit: $?"
lint-exit: 0            # WARN path taken, increment from 0, script survives
```
