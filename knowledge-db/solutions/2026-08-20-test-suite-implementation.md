---
title: "Test Suite for CLI Tools"
type: solution
status: verified
date: 2026-08-20
tags: [area:tooling, area:test, layer:cli]
sources:
  - tests/run-tests.sh:1-150
  - scripts/kb-lint:1-50
  - scripts/kb-ingest:1-100
related:
  - explorations/2026-08-20-cli-tool-architecture.md
  - errors/2026-08-20-fix-flag-not-implemented.md
---

## Summary

Added shell-based test suite covering all four CLI tools (init, lint, ingest, discover) with 23 test cases. No external dependencies - uses bash functions and temp directories.

## Context / Question

Code review identified critical gap: CLI tools had zero test coverage. Needed tests before fixing security issues to prevent regressions.

## Findings / What We Did

### Approach Decision

Considered three options:
1. **bats-core** - Full bash testing framework. Rejected: adds dependency.
2. **shunit2** - Another bash framework. Rejected: same reason.
3. **Custom runner** - Simple bash functions. Chosen: zero deps, sufficient for scope.

### Test Runner Architecture (tests/run-tests.sh:15-50)

Two helper functions handle all assertions:

```bash
run_test() {
    # Runs command, expects success (exit 0)
    if eval "$cmd" > /dev/null 2>&1; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
}

run_test_fails() {
    # Runs command, expects failure (exit non-zero)
    # Used for: missing KB, invalid args, lint errors
}
```

### Test Isolation

Each test group uses fresh temp directory:
```bash
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
```

Tests share state within groups (by design - tests later in sequence verify fixes from earlier tests).

### Coverage Matrix

| Tool | Happy Path | Error Cases | Edge Cases |
|------|------------|-------------|------------|
| init-knowledge-db.sh | 7 tests | 0 | 1 (idempotent) |
| kb-lint | 5 tests | 2 | 2 (--fix) |
| kb-ingest | 3 tests | 0 | 1 (auto-detect) |
| kb-discover | 2 tests | 0 | 0 |

### Key Test Patterns

**Structure verification** (init):
```bash
run_test "creates INDEX.md" "test -f $TEMP_DIR/test-kb/INDEX.md"
```

**Behavior verification** (lint --fix):
```bash
# Create entry not in INDEX
cat > "$TEMP_DIR/kb/explorations/test.md" << 'EOF'
...
EOF
run_test_fails "detects missing" "$ROOT_DIR/scripts/kb-lint $TEMP_DIR/kb"
run_test "--fix repairs" "$ROOT_DIR/scripts/kb-lint $TEMP_DIR/kb --fix"
run_test "now in INDEX" "grep -q 'test.md' $TEMP_DIR/kb/INDEX.md"
```

**Auto-detection verification** (ingest):
```bash
run_test "detects error bucket" \
    "echo 'Error: failed' | kb-ingest --auto --dry-run | grep -q 'errors/'"
```

## Verification

```bash
$ ./tests/run-tests.sh
KB Tools Test Suite
...
Results: 23/23 passed
All tests passed
```

Tests run in ~3 seconds on macOS. No flakiness observed across 10 consecutive runs.

## Follow-ups / Open Questions

1. **Missing edge case tests**: Unicode filenames, very large files, symlinks
2. **No concurrency tests**: Two simultaneous kb-lint --fix runs could corrupt INDEX
3. **CI integration**: Should add to GitHub Actions when repo goes public
