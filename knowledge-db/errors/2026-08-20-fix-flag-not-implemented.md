---
title: kb-lint --fix flag documented but not implemented
type: error
status: verified
date: 2026-08-20
tags: [area:tooling, layer:cli, severity:high]
sources:
  - scripts/kb-lint:8
  - scripts/kb-lint:30-34
  - README.md:217
related:
  - explorations/2026-08-20-cli-tool-architecture.md
---

## Summary

The `--fix` flag was documented in README.md and parsed by kb-lint, but had no actual implementation. Fixed by adding auto-repair logic for INDEX sync and status validation.

## Symptom

User runs `kb-lint --fix` expecting automatic repairs. Script runs but makes no changes. No error or warning indicates the feature is incomplete.

```bash
$ ./scripts/kb-lint knowledge-db --fix
# Reports errors but doesn't fix them
```

## Root Cause

Flag parsing existed (scripts/kb-lint:30-34):
```bash
case $arg in
    --fix)
        FIX_MODE=true
        shift
        ;;
```

But `FIX_MODE` was never used in any check logic. Variable set but ignored.

README.md:217 documented the flag:
```markdown
| `kb-lint` | Check KB health | `kb-lint --fix` |
```

Classic "documented before implemented" bug.

## Fix

Added --fix implementation in scripts/kb-lint for two fixable issues:

1. **Missing INDEX.md rows** (scripts/kb-lint:76-95): Extract metadata from entry, build row, insert into correct section using sed.

2. **verified without proof** (scripts/kb-lint:134-145): Downgrade status to tentative when Verification section missing or empty.

Also added:
- FIXED counter to summary output
- "Tip: Run with --fix" hint when errors found

## Prevention

1. **Test what you document**: Added test cases for --fix behavior in tests/run-tests.sh
2. **Code review checklist**: "Does documented behavior have corresponding implementation?"
3. **Grep for unused variables**: `FIX_MODE` was set but never read

## Verification

```bash
$ ./tests/run-tests.sh
Testing kb-lint
  --fix adds missing INDEX entry... PASS
  --fix downgrades to tentative... PASS
  status now tentative... PASS
```
