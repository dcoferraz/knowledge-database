#!/bin/bash
# Conformance suite for knowledge-db/bin/kb.
#
# - tests/fixtures/pass/           must exit 0
# - tests/fixtures/fail/KBxxx/     must exit non-zero AND name that rule ID
#   (KB009 and KB011 are diff-mode rules: the fixture is copied into a temp
#   git repo, a source file is modified and staged, then `kb check --staged`)
#
# Zero dependencies beyond bash, git, python3.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KB="$REPO_ROOT/knowledge-db/bin/kb"
FIXTURES="$REPO_ROOT/tests/fixtures"
PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  $1... PASS"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  $1... FAIL: $2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

echo "KB Conformance Suite"
echo

echo "Testing pass fixture"
OUT=$("$KB" --kb-dir "$FIXTURES/pass/knowledge-db" check 2>&1)
if [[ $? -eq 0 ]]; then
    pass "pass/ exits 0"
else
    fail "pass/ exits 0" "$OUT"
fi

echo "Testing kb index idempotency"
TMP_IDEM=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP_IDEM/"
"$KB" --kb-dir "$TMP_IDEM/knowledge-db" index 2>/dev/null
BEFORE=$(cat "$TMP_IDEM/knowledge-db/INDEX.md")
"$KB" --kb-dir "$TMP_IDEM/knowledge-db" index 2>/dev/null
AFTER=$(cat "$TMP_IDEM/knowledge-db/INDEX.md")
if [[ "$BEFORE" == "$AFTER" ]]; then
    pass "index twice produces no diff"
else
    fail "index twice produces no diff" "output changed on second run"
fi
rm -rf "$TMP_IDEM"

echo "Testing static fail fixtures"
for DIR in "$FIXTURES"/fail/KB*; do
    RULE=$(basename "$DIR")
    case "$RULE" in KB009|KB011) continue ;; esac
    OUT=$("$KB" --kb-dir "$DIR/knowledge-db" check 2>&1)
    CODE=$?
    if [[ $CODE -ne 0 ]] && echo "$OUT" | grep -q "^$RULE "; then
        pass "$RULE detected"
    else
        fail "$RULE detected" "exit=$CODE output=$OUT"
    fi
done

echo "Testing diff-mode fail fixtures"
for RULE in KB009 KB011; do
    TMP=$(mktemp -d)
    cp -R "$FIXTURES/fail/$RULE/." "$TMP/"
    git -C "$TMP" init -q
    git -C "$TMP" -c user.email=t@t -c user.name=t add -A
    git -C "$TMP" -c user.email=t@t -c user.name=t commit -qm base
    echo "changed" >> "$TMP/src/app.txt"
    git -C "$TMP" add src/app.txt
    OUT=$("$KB" --kb-dir "$TMP/knowledge-db" check --staged 2>&1)
    CODE=$?
    if [[ $CODE -ne 0 ]] && echo "$OUT" | grep -q "^$RULE "; then
        pass "$RULE detected (staged diff)"
    else
        fail "$RULE detected (staged diff)" "exit=$CODE output=$OUT"
    fi
    rm -rf "$TMP"
done

echo "Testing AGENT.md is a declared KB root file"
TMP_AG=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP_AG/"
echo "# agent rules" > "$TMP_AG/knowledge-db/AGENT.md"
OUT=$("$KB" --kb-dir "$TMP_AG/knowledge-db" check 2>&1)
if [[ $? -eq 0 ]]; then
    pass "AGENT.md at KB root not flagged by KB002"
else
    fail "AGENT.md at KB root not flagged by KB002" "$OUT"
fi
rm -rf "$TMP_AG"

echo "Testing kb new scaffolds a valid entry"
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
OUT=$("$KB" --kb-dir "$TMP/knowledge-db" new exploration scaffold-test 2>&1)
if [[ $? -eq 0 ]] && "$KB" --kb-dir "$TMP/knowledge-db" check >/dev/null 2>&1; then
    pass "kb new output passes kb check"
else
    fail "kb new output passes kb check" "$OUT"
fi
rm -rf "$TMP"

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ $FAIL_COUNT -eq 0 ]] || exit 1
echo "All KB conformance tests passed"
