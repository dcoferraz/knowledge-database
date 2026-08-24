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
    case "$RULE" in KB009|KB011|KB013) continue ;; esac
    OUT=$("$KB" --kb-dir "$DIR/knowledge-db" check 2>&1)
    CODE=$?
    if [[ $CODE -ne 0 ]] && echo "$OUT" | grep -q "^$RULE "; then
        pass "$RULE detected"
    else
        fail "$RULE detected" "exit=$CODE output=$OUT"
    fi
done

echo "Testing diff-mode fail fixtures"
for RULE in KB009 KB011 KB013; do
    TMP=$(mktemp -d)
    cp -R "$FIXTURES/fail/$RULE/." "$TMP/"
    git -C "$TMP" init -q
    git -C "$TMP" -c user.email=t@t -c user.name=t add -A
    git -C "$TMP" -c user.email=t@t -c user.name=t commit -qm base
    case "$RULE" in
        KB013) TOUCH="CLAUDE.md" ;;
        *)     TOUCH="src/app.txt" ;;
    esac
    echo "changed" >> "$TMP/$TOUCH"
    git -C "$TMP" add "$TOUCH"
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

echo "Testing kb rules prints injectable hard-rules block"
OUT=$("$KB" --kb-dir "$FIXTURES/pass/knowledge-db" rules 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "<kb-hard-rules" && echo "$OUT" | grep -q "READ FIRST"; then
    pass "kb rules output"
else
    fail "kb rules output" "$OUT"
fi

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

echo "Testing installer plants rules in all runtime files"
TMP=$(mktemp -d)
mkdir -p "$TMP/knowledge-db"
cp -R "$REPO_ROOT/knowledge-db/bin" "$TMP/knowledge-db/"
cp "$REPO_ROOT/knowledge-db/kb.config.json" "$REPO_ROOT/knowledge-db/install.sh" "$REPO_ROOT/knowledge-db/AGENT.md" "$TMP/knowledge-db/"
mkdir -p "$TMP/knowledge-db/explorations" "$TMP/knowledge-db/solutions" "$TMP/knowledge-db/errors" "$TMP/knowledge-db/decisions"
git -C "$TMP" init -q
"$TMP/knowledge-db/bin/kb" index >/dev/null 2>&1
"$TMP/knowledge-db/install.sh" >/dev/null 2>&1
PLANT_OK=true
for f in CLAUDE.md AGENTS.md .github/copilot-instructions.md .github/instructions/kb.instructions.md .cursor/rules/knowledge-db.mdc .windsurfrules; do
    grep -qF "kb:agent-rules:start" "$TMP/$f" || { PLANT_OK=false; break; }
done
if $PLANT_OK; then
    pass "all 6 runtime files planted"
else
    fail "all 6 runtime files planted" "marker missing in $f"
fi
head -2 "$TMP/.github/instructions/kb.instructions.md" | grep -q "applyTo: '\*\*'" \
    && pass "copilot instructions applyTo frontmatter" \
    || fail "copilot instructions applyTo frontmatter" "$(head -3 "$TMP/.github/instructions/kb.instructions.md")"
grep -q "alwaysApply: true" "$TMP/.cursor/rules/knowledge-db.mdc" \
    && pass "cursor mdc alwaysApply frontmatter" \
    || fail "cursor mdc alwaysApply frontmatter" "$(head -4 "$TMP/.cursor/rules/knowledge-db.mdc")"
RERUN=$("$TMP/knowledge-db/install.sh" 2>/dev/null | grep -c "^CHANGED")
if [[ "$RERUN" -eq 0 ]]; then
    pass "installer idempotent (rerun changes nothing)"
else
    fail "installer idempotent (rerun changes nothing)" "$RERUN CHANGED lines on rerun"
fi
rm "$TMP/.windsurfrules"
if ! "$TMP/knowledge-db/install.sh" --check >/dev/null 2>&1; then
    pass "check fails when a planted file is removed"
else
    fail "check fails when a planted file is removed" "exit 0 despite missing .windsurfrules"
fi
rm -rf "$TMP"

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ $FAIL_COUNT -eq 0 ]] || exit 1
echo "All KB conformance tests passed"
