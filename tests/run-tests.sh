#!/bin/bash
# Test runner for KB tools
# Usage: ./tests/run-tests.sh

# Note: No set -e, we handle failures ourselves

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

# Test helper
run_test() {
    local name="$1"
    local cmd="$2"
    TOTAL=$((TOTAL + 1))

    echo -n "  $name... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        FAILED=$((FAILED + 1))
        # Show output on failure
        echo "    Command: $cmd"
        eval "$cmd" 2>&1 | sed 's/^/    /' || true
    fi
}

# Test that expects failure (non-zero exit)
run_test_fails() {
    local name="$1"
    local cmd="$2"
    TOTAL=$((TOTAL + 1))

    echo -n "  $name... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${RED}FAIL (expected non-zero exit)${NC}"
        FAILED=$((FAILED + 1))
    else
        echo -e "${GREEN}PASS${NC}"
        PASSED=$((PASSED + 1))
    fi
}

# Setup temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}KB Tools Test Suite${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# --- init-knowledge-db.sh tests ---
echo -e "${BLUE}Testing init-knowledge-db.sh${NC}"

run_test "creates KB structure" "$ROOT_DIR/scripts/init-knowledge-db.sh $TEMP_DIR/test-kb1"
run_test "creates INDEX.md" "test -f $TEMP_DIR/test-kb1/INDEX.md"
run_test "creates _TEMPLATE.md" "test -f $TEMP_DIR/test-kb1/_TEMPLATE.md"
run_test "creates explorations/" "test -d $TEMP_DIR/test-kb1/explorations"
run_test "creates solutions/" "test -d $TEMP_DIR/test-kb1/solutions"
run_test "creates errors/" "test -d $TEMP_DIR/test-kb1/errors"
run_test "creates decisions/" "test -d $TEMP_DIR/test-kb1/decisions"
run_test "is idempotent" "$ROOT_DIR/scripts/init-knowledge-db.sh $TEMP_DIR/test-kb1"

echo ""

# --- kb-lint tests ---
echo -e "${BLUE}Testing kb-lint${NC}"

# Setup test KB
"$ROOT_DIR/scripts/init-knowledge-db.sh" "$TEMP_DIR/lint-test-kb" > /dev/null

run_test "runs on empty KB" "$ROOT_DIR/scripts/kb-lint $TEMP_DIR/lint-test-kb"
run_test "shows help" "$ROOT_DIR/scripts/kb-lint --help"
run_test_fails "fails on missing KB" "$ROOT_DIR/scripts/kb-lint $TEMP_DIR/nonexistent"

# Create entry not in INDEX
cat > "$TEMP_DIR/lint-test-kb/explorations/2026-01-01-test-entry.md" << 'EOF'
---
title: Test Entry
type: exploration
status: tentative
date: 2026-01-01
tags: [area:test]
sources:
  - test.ts:1-10
---

## Summary

Test entry for lint testing.
EOF

run_test_fails "detects entry missing from INDEX" "$ROOT_DIR/scripts/kb-lint $TEMP_DIR/lint-test-kb"

# Test --fix
run_test "--fix adds missing INDEX entry" "$ROOT_DIR/scripts/kb-lint $TEMP_DIR/lint-test-kb --fix"
run_test "entry now in INDEX" "grep -q '2026-01-01-test-entry.md' $TEMP_DIR/lint-test-kb/INDEX.md"

# Test verified without proof
cat > "$TEMP_DIR/lint-test-kb/explorations/2026-01-02-no-proof.md" << 'EOF'
---
title: No Proof Entry
type: exploration
status: verified
date: 2026-01-02
tags: [area:test]
sources:
  - test.ts:1-10
---

## Summary

This is verified but has no Verification section.
EOF

run_test_fails "detects verified without proof" "$ROOT_DIR/scripts/kb-lint $TEMP_DIR/lint-test-kb"
run_test "--fix downgrades to tentative" "$ROOT_DIR/scripts/kb-lint $TEMP_DIR/lint-test-kb --fix"
run_test "status now tentative" "grep -q 'status: tentative' $TEMP_DIR/lint-test-kb/explorations/2026-01-02-no-proof.md"

echo ""

# --- kb-ingest tests ---
echo -e "${BLUE}Testing kb-ingest${NC}"

run_test "shows help" "$ROOT_DIR/scripts/kb-ingest --help"

# Test auto-bucket detection
run_test "detects error bucket from content" "echo 'Error: something failed. Stack trace at line 42.' | $ROOT_DIR/scripts/kb-ingest --dry-run --auto --kb-dir $TEMP_DIR/lint-test-kb | grep -q 'errors/'"
run_test "detects exploration from question" "echo 'How does the auth middleware work?' | $ROOT_DIR/scripts/kb-ingest --dry-run --auto --kb-dir $TEMP_DIR/lint-test-kb | grep -q 'explorations/'"
run_test "uses explicit bucket" "echo 'test' | $ROOT_DIR/scripts/kb-ingest --dry-run --bucket decisions --kb-dir $TEMP_DIR/lint-test-kb | grep -q 'decisions/'"

echo ""

# --- kb-discover tests ---
echo -e "${BLUE}Testing kb-discover${NC}"

run_test "shows help" "$ROOT_DIR/scripts/kb-discover --help"
run_test "runs on directory" "$ROOT_DIR/scripts/kb-discover $ROOT_DIR/scripts --summary"

echo ""

# --- Summary ---
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Results: $PASSED/$TOTAL passed${NC}"
echo -e "${BLUE}======================================${NC}"

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}$FAILED test(s) failed${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed${NC}"
    exit 0
fi
