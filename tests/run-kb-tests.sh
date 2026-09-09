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
# Guarded temp-dir removal: only ever a path from mktemp -d.
cleanup() { case "${1:-}" in /*/*) command rm -rf "$1" ;; esac; }

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
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "<kb-hard-rules" && echo "$OUT" | grep -q "LOOK UP FIRST"; then
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

echo "Testing kb version and KB014 drift warning"
OUT=$("$KB" --kb-dir "$FIXTURES/pass/knowledge-db" version 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "kb tool version:"; then
    pass "kb version output"
else
    fail "kb version output" "$OUT"
fi
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
python3 -c "
import json
p = '$TMP/knowledge-db/kb.config.json'
d = json.load(open(p)); d['kb_version'] = '0.0.1'
json.dump(d, open(p, 'w'), indent=2)"
OUT=$("$KB" --kb-dir "$TMP/knowledge-db" check 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "^WARN KB014 "; then
    pass "KB014 warns on version drift without failing"
else
    fail "KB014 warns on version drift without failing" "exit=$? output=$OUT"
fi
rm -rf "$TMP"

echo "Testing extra_root_files config escape"
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
echo "# release log" > "$TMP/knowledge-db/RELEASES.md"
OUT=$("$KB" --kb-dir "$TMP/knowledge-db" check 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q "^KB002 .*RELEASES.md"; then
    pass "undeclared root file fails KB002"
else
    fail "undeclared root file fails KB002" "$OUT"
fi
python3 -c "
import json
p = '$TMP/knowledge-db/kb.config.json'
d = json.load(open(p)); d['extra_root_files'] = ['RELEASES.md']
json.dump(d, open(p, 'w'), indent=2)"
if "$KB" --kb-dir "$TMP/knowledge-db" check >/dev/null 2>&1; then
    pass "declared extra_root_files passes"
else
    fail "declared extra_root_files passes" "$("$KB" --kb-dir "$TMP/knowledge-db" check 2>&1)"
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

echo "Testing installer in a NON-git project (v0.7.0: used to exit 128 half-installed)"
TMP=$(mktemp -d)
mkdir -p "$TMP/knowledge-db"
cp -R "$REPO_ROOT/knowledge-db/bin" "$TMP/knowledge-db/"
cp "$REPO_ROOT/knowledge-db/kb.config.json" "$REPO_ROOT/knowledge-db/install.sh" \
   "$REPO_ROOT/knowledge-db/AGENT.md" "$TMP/knowledge-db/"
mkdir -p "$TMP/knowledge-db/explorations" "$TMP/knowledge-db/solutions" \
         "$TMP/knowledge-db/errors" "$TMP/knowledge-db/decisions"
"$TMP/knowledge-db/bin/kb" index >/dev/null 2>&1
OUT=$("$TMP/knowledge-db/install.sh" --yes 2>&1)
CODE=$?
PLANT_OK=true
for f in CLAUDE.md AGENTS.md .github/copilot-instructions.md \
         .github/instructions/kb.instructions.md .cursor/rules/knowledge-db.mdc .windsurfrules; do
    grep -qF "kb:agent-rules:start" "$TMP/$f" 2>/dev/null || { PLANT_OK=false; break; }
done
if [[ $CODE -eq 0 ]] && $PLANT_OK; then
    pass "install.sh exits 0 and plants all rule files without git"
else
    fail "install.sh exits 0 and plants all rule files without git" "exit=$CODE output=$OUT"
fi
if echo "$OUT" | grep -q "not a git repository"; then
    pass "git-time layers skipped with a reason"
else
    fail "git-time layers skipped with a reason" "$OUT"
fi
if "$TMP/knowledge-db/install.sh" --check >/dev/null 2>&1; then
    pass "--check passes in a non-git project"
else
    fail "--check passes in a non-git project" "$("$TMP/knowledge-db/install.sh" --check 2>&1)"
fi
cleanup "$TMP"

echo "Testing stale planted rule block is replanted (not skipped on the marker)"
TMP=$(mktemp -d)
mkdir -p "$TMP/knowledge-db"
cp -R "$REPO_ROOT/knowledge-db/bin" "$TMP/knowledge-db/"
cp "$REPO_ROOT/knowledge-db/kb.config.json" "$REPO_ROOT/knowledge-db/install.sh" \
   "$REPO_ROOT/knowledge-db/AGENT.md" "$TMP/knowledge-db/"
mkdir -p "$TMP/knowledge-db/explorations" "$TMP/knowledge-db/solutions" \
         "$TMP/knowledge-db/errors" "$TMP/knowledge-db/decisions"
git -C "$TMP" init -q
"$TMP/knowledge-db/bin/kb" index >/dev/null 2>&1
cat > "$TMP/CLAUDE.md" <<'STALE'
# Project

<!-- kb:agent-rules:start -->
## HARD RULE: Knowledge Database

Old text planted by an older installer. Rule table (KB001-KB011).
<!-- kb:agent-rules:end -->

## Keep me
project-specific notes
STALE
if "$TMP/knowledge-db/install.sh" --check 2>&1 | grep -q "stale"; then
    pass "--check reports a stale planted block"
else
    fail "--check reports a stale planted block" "$("$TMP/knowledge-db/install.sh" --check 2>&1)"
fi
if "$TMP/knowledge-db/bin/kb" check 2>&1 | grep -q "^WARN KB014 CLAUDE.md"; then
    pass "KB014 warns about the stale block"
else
    fail "KB014 warns about the stale block" "$("$TMP/knowledge-db/bin/kb" check 2>&1)"
fi
"$TMP/knowledge-db/install.sh" --yes >/dev/null 2>&1
if diff <("$TMP/knowledge-db/bin/kb" rules --plant) \
        <(sed -n '/kb:agent-rules:start/,/kb:agent-rules:end/p' "$TMP/CLAUDE.md") >/dev/null \
   && grep -q "project-specific notes" "$TMP/CLAUDE.md"; then
    pass "stale block replanted in place, surrounding content kept"
else
    fail "stale block replanted in place, surrounding content kept" "$(cat "$TMP/CLAUDE.md")"
fi
cleanup "$TMP"

echo "Testing agent hooks: SubagentStop wired and legacy Stop command migrated"
TMP=$(mktemp -d)
mkdir -p "$TMP/knowledge-db" "$TMP/.claude"
cp -R "$REPO_ROOT/knowledge-db/bin" "$TMP/knowledge-db/"
cp "$REPO_ROOT/knowledge-db/kb.config.json" "$REPO_ROOT/knowledge-db/install.sh" \
   "$REPO_ROOT/knowledge-db/AGENT.md" "$TMP/knowledge-db/"
mkdir -p "$TMP/knowledge-db/explorations" "$TMP/knowledge-db/solutions" \
         "$TMP/knowledge-db/errors" "$TMP/knowledge-db/decisions"
"$TMP/knowledge-db/bin/kb" index >/dev/null 2>&1
cat > "$TMP/.claude/settings.json" <<'LEGACY'
{
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR/knowledge-db/bin/kb\" check 1>&2 || exit 2"}]}
    ]
  }
}
LEGACY
"$TMP/knowledge-db/install.sh" --yes >/dev/null 2>&1
if python3 - "$TMP/.claude/settings.json" <<'EOF'
import json, sys
hooks = json.load(open(sys.argv[1]))["hooks"]
def cmds(event):
    return [h.get("command", "") for g in hooks.get(event, []) for h in g.get("hooks", [])]
stop, sub, prompt = cmds("Stop"), cmds("SubagentStop"), cmds("UserPromptSubmit")
ok = (any("stop-hook" in c for c in stop)
      and not any("check 1>&2" in c for c in stop)
      and len(stop) == 1
      and any("stop-hook" in c for c in sub)
      and any("rules" in c for c in prompt))
sys.exit(0 if ok else 1)
EOF
then
    pass "Stop migrated to kb stop-hook, SubagentStop + UserPromptSubmit added"
else
    fail "Stop migrated to kb stop-hook, SubagentStop + UserPromptSubmit added" "$(cat "$TMP/.claude/settings.json")"
fi
cleanup "$TMP"

echo "Testing kb stop-hook loop guard"
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
if echo '{}' | "$KB" --kb-dir "$TMP/knowledge-db" stop-hook >/dev/null 2>&1; then
    pass "clean KB: stop-hook exits 0"
else
    fail "clean KB: stop-hook exits 0" "$(echo '{}' | "$KB" --kb-dir "$TMP/knowledge-db" stop-hook 2>&1)"
fi
cat > "$TMP/knowledge-db/explorations/2026-01-20-unproven.md" <<'EOF'
---
title: Unproven
type: exploration
status: verified
date: 2026-01-20
tags: []
sources: []
---

## Summary
No proof.
EOF
echo '{"stop_hook_active": false}' | "$KB" --kb-dir "$TMP/knowledge-db" stop-hook >/dev/null 2>&1
CODE=$?
ERR=$(echo '{"stop_hook_active": false}' | "$KB" --kb-dir "$TMP/knowledge-db" stop-hook 2>&1 >/dev/null)
if [[ $CODE -eq 2 ]] && echo "$ERR" | grep -q "KB004"; then
    pass "dirty KB: stop-hook exits 2 with findings on stderr"
else
    fail "dirty KB: stop-hook exits 2 with findings on stderr" "exit=$CODE stderr=$ERR"
fi
echo '{"stop_hook_active": true}' | "$KB" --kb-dir "$TMP/knowledge-db" stop-hook >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    pass "stop_hook_active: reports without blocking again (no stop loop)"
else
    fail "stop_hook_active: reports without blocking again (no stop loop)" "exited non-zero"
fi
cleanup "$TMP"

echo "Testing KB008 staleness is opt-in"
TMP=$(mktemp -d)
cp -R "$FIXTURES/fail/KB008/." "$TMP/"
python3 -c "
import json
p = '$TMP/knowledge-db/kb.config.json'
d = json.load(open(p)); d['staleness_days'] = {}
json.dump(d, open(p, 'w'), indent=2)"
if "$KB" --kb-dir "$TMP/knowledge-db" check >/dev/null 2>&1; then
    pass "no staleness budget: an old verified entry passes"
else
    fail "no staleness budget: an old verified entry passes" "$("$KB" --kb-dir "$TMP/knowledge-db" check 2>&1)"
fi
python3 -c "
import json
p = '$TMP/knowledge-db/kb.config.json'
d = json.load(open(p)); d['staleness_days'] = {'verified': 90}
json.dump(d, open(p, 'w'), indent=2)"
OUT=$("$KB" --kb-dir "$TMP/knowledge-db" check 2>&1)
CODE=$?
if [[ $CODE -eq 0 ]] && echo "$OUT" | grep -q "^WARN KB008 "; then
    pass "declared budget: warns without failing"
else
    fail "declared budget: warns without failing" "exit=$CODE $OUT"
fi
cleanup "$TMP"

echo "Testing workspace mode: nested repo gate"
TMP=$(mktemp -d)
mkdir -p "$TMP/knowledge-db" "$TMP/app/src"
cp -R "$REPO_ROOT/knowledge-db/bin" "$TMP/knowledge-db/"
cp "$REPO_ROOT/knowledge-db/kb.config.json" "$REPO_ROOT/knowledge-db/install.sh" \
   "$REPO_ROOT/knowledge-db/AGENT.md" "$TMP/knowledge-db/"
mkdir -p "$TMP/knowledge-db/explorations" "$TMP/knowledge-db/solutions" \
         "$TMP/knowledge-db/errors" "$TMP/knowledge-db/decisions"
python3 -c "
import json
p = '$TMP/knowledge-db/kb.config.json'
d = json.load(open(p))
d['writeback'] = {'code': ['src/**'], 'docs': [], 'exempt': [], 'grace_hours': 0}
d.pop('changelog_art', None)          # KB015 + lockstep are this repo's
d['lockstep'] = []                    # own practice, not the fixture's
json.dump(d, open(p, 'w'), indent=2)"
"$TMP/knowledge-db/bin/kb" index >/dev/null 2>&1
git -C "$TMP" init -q
echo "app/" > "$TMP/.gitignore"
echo "x" > "$TMP/app/src/index.js"
git -C "$TMP/app" init -q
git -C "$TMP/app" -c user.email=t@t -c user.name=t add -A
git -C "$TMP/app" -c user.email=t@t -c user.name=t commit -qm base
git -C "$TMP" -c user.email=t@t -c user.name=t add -A
git -C "$TMP" -c user.email=t@t -c user.name=t commit -qm base
"$TMP/knowledge-db/install.sh" --mode workspace --yes >/dev/null 2>&1
# Commit what the installer wrote, so the workspace KB is CLEAN: with
# grace_hours 0 there is then no write-back evidence at all.
git -C "$TMP" -c user.email=t@t -c user.name=t add -A
git -C "$TMP" -c user.email=t@t -c user.name=t commit -qm "install"
HOOK="$(git -C "$TMP/app" rev-parse --absolute-git-dir)/hooks/pre-commit"
if [[ -x "$HOOK" ]] && grep -q -- "--repo" "$HOOK"; then
    pass "nested repo pre-commit hook installed with --repo"
else
    fail "nested repo pre-commit hook installed with --repo" "no usable hook at $HOOK"
fi
echo "y" >> "$TMP/app/src/index.js"
git -C "$TMP/app" add src/index.js
OUT=$("$TMP/knowledge-db/bin/kb" check --staged --repo "$TMP/app" 2>&1)
CODE=$?
if [[ $CODE -ne 0 ]] && echo "$OUT" | grep -q "^KB011 "; then
    pass "KB011 fires for nested-repo code with no KB movement"
else
    fail "KB011 fires for nested-repo code with no KB movement" "exit=$CODE $OUT"
fi
"$TMP/knowledge-db/bin/kb" new solution nested-work >/dev/null 2>&1
if "$TMP/knowledge-db/bin/kb" check --staged --repo "$TMP/app" >/dev/null 2>&1; then
    pass "KB011 satisfied by a pending KB entry in the workspace"
else
    fail "KB011 satisfied by a pending KB entry in the workspace" \
         "$("$TMP/knowledge-db/bin/kb" check --staged --repo "$TMP/app" 2>&1)"
fi
cleanup "$TMP"

echo "Testing KB003 resolves @rev inside a nested repo"
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
mkdir -p "$TMP/nested"
git -C "$TMP/nested" init -q
printf 'one\ntwo\nthree\n' > "$TMP/nested/thing.txt"
git -C "$TMP/nested" -c user.email=t@t -c user.name=t add -A
git -C "$TMP/nested" -c user.email=t@t -c user.name=t commit -qm base
REV=$(git -C "$TMP/nested" rev-parse --short=8 HEAD)
printf 'one\ntwo\nthree\nfour\n' > "$TMP/nested/thing.txt"
cat > "$TMP/knowledge-db/explorations/2026-01-20-nested-source.md" <<EOF
---
title: Nested source
type: exploration
status: tentative
date: 2026-01-20
tags: []
sources:
  - nested/thing.txt:1-3@$REV
---

## Summary
Cites a file in a nested repository.
EOF
"$KB" --kb-dir "$TMP/knowledge-db" index >/dev/null 2>&1
OUT=$("$KB" --kb-dir "$TMP/knowledge-db" check 2>&1)
CODE=$?
if [[ $CODE -eq 0 ]] && echo "$OUT" | grep -q "WARN KB003.*changed since"; then
    pass "@rev drift in a nested repo warns (was a silent no-op)"
else
    fail "@rev drift in a nested repo warns (was a silent no-op)" "exit=$CODE $OUT"
fi
cleanup "$TMP"

echo "Testing kb discover and kb ingest write valid entries"
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
mkdir -p "$TMP/svc/src"
cat > "$TMP/svc/src/index.js" <<'EOF'
const app = require("express")();
app.get("/health", (req, res) => res.json({ok: true}));
EOF
echo '{"name":"svc","main":"src/index.js"}' > "$TMP/svc/package.json"
if "$KB" --kb-dir "$TMP/knowledge-db" discover "$TMP/svc" --summary 2>&1 | grep -q "project type"; then
    pass "kb discover --summary reports a scan"
else
    fail "kb discover --summary reports a scan" "$("$KB" --kb-dir "$TMP/knowledge-db" discover "$TMP/svc" --summary 2>&1)"
fi
"$KB" --kb-dir "$TMP/knowledge-db" discover "$TMP/svc" >/dev/null 2>&1
if "$KB" --kb-dir "$TMP/knowledge-db" check >/dev/null 2>&1; then
    pass "kb discover output passes kb check"
else
    fail "kb discover output passes kb check" "$("$KB" --kb-dir "$TMP/knowledge-db" check 2>&1)"
fi
printf 'TypeError: cannot read id of undefined\n  at src/app.txt:1:2\nFixed by a guard.\n' \
    | "$KB" --kb-dir "$TMP/knowledge-db" ingest >/dev/null 2>&1
if ls "$TMP/knowledge-db/errors"/*typeerror* >/dev/null 2>&1; then
    pass "kb ingest auto-detects the errors bucket"
else
    fail "kb ingest auto-detects the errors bucket" "$(ls "$TMP/knowledge-db/errors")"
fi
if "$KB" --kb-dir "$TMP/knowledge-db" check >/dev/null 2>&1; then
    pass "kb ingest output passes kb check"
else
    fail "kb ingest output passes kb check" "$("$KB" --kb-dir "$TMP/knowledge-db" check 2>&1)"
fi
cleanup "$TMP"

echo "Testing rule block and target list come from the tool"
OUT=$("$KB" --kb-dir "$FIXTURES/pass/knowledge-db" rules --plant 2>&1)
if echo "$OUT" | grep -q "kb:agent-rules:start" && echo "$OUT" | grep -q "Rule table (KB001-KB015)"; then
    pass "kb rules --plant prints the canonical block with the current range"
else
    fail "kb rules --plant prints the canonical block with the current range" "$OUT"
fi
if [[ "$("$KB" --kb-dir "$FIXTURES/pass/knowledge-db" rules --targets | wc -l | tr -d ' ')" == "6" ]]; then
    pass "kb rules --targets lists the 6 runtime files"
else
    fail "kb rules --targets lists the 6 runtime files" "$("$KB" --kb-dir "$FIXTURES/pass/knowledge-db" rules --targets)"
fi

echo "Testing supersede_with_consent switches the injected rule text"
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
if "$KB" --kb-dir "$TMP/knowledge-db" rules | grep -q "NEVER PROMPT"; then
    pass "default: autonomous superseding wording injected"
else
    fail "default: autonomous superseding wording injected" "$("$KB" --kb-dir "$TMP/knowledge-db" rules)"
fi
python3 -c "
import json
p = '$TMP/knowledge-db/kb.config.json'
d = json.load(open(p)); d['supersede_with_consent'] = True
json.dump(d, open(p, 'w'), indent=2)"
if "$KB" --kb-dir "$TMP/knowledge-db" rules | grep -q "ASK BEFORE SUPERSEDING"; then
    pass "supersede_with_consent: consent wording injected"
else
    fail "supersede_with_consent: consent wording injected" "$("$KB" --kb-dir "$TMP/knowledge-db" rules)"
fi
cleanup "$TMP"

echo "Testing kb upgrade (offline: an explicit --source, never the network)"
TMP=$(mktemp -d)
# a fake newer upstream: real tooling with a bumped version marker
UPSTREAM="$TMP/upstream"
mkdir -p "$UPSTREAM/knowledge-db/bin" "$UPSTREAM/.kb-templates" "$UPSTREAM/scripts"
sed 's/^KB_TOOL_VERSION = "[0-9.]*"/KB_TOOL_VERSION = "9.9.9"/' \
    "$REPO_ROOT/knowledge-db/bin/kb" > "$UPSTREAM/knowledge-db/bin/kb"
chmod +x "$UPSTREAM/knowledge-db/bin/kb"
cp "$REPO_ROOT/knowledge-db/install.sh" "$REPO_ROOT/knowledge-db/AGENT.md" \
   "$REPO_ROOT/knowledge-db/README.md" "$REPO_ROOT/knowledge-db/_TEMPLATE.md" \
   "$UPSTREAM/knowledge-db/"
cp "$REPO_ROOT/scripts/init-knowledge-db.sh" "$UPSTREAM/scripts/"
python3 -c "
import json
d = json.load(open('$REPO_ROOT/.kb-templates/kb.config.json'))
d['brand_new_key'] = True
json.dump(d, open('$UPSTREAM/.kb-templates/kb.config.json', 'w'), indent=2)"
# upstream also carries its own entries, which must NEVER be copied
mkdir -p "$UPSTREAM/knowledge-db/decisions"
cat > "$UPSTREAM/knowledge-db/decisions/2026-01-01-upstream-only.md" <<'EOF'
---
title: Upstream only
type: decision
status: tentative
date: 2026-01-01
tags: []
sources: []
---

## Summary
Documents the KB tool, not your project.
EOF

# a downstream project: our tooling, ITS OWN vocabulary, entries and root file
DOWN="$TMP/project"
mkdir -p "$DOWN/knowledge-db/bin" "$DOWN/src"
cp "$REPO_ROOT/knowledge-db/bin/kb" "$DOWN/knowledge-db/bin/kb"
cp "$REPO_ROOT/knowledge-db/install.sh" "$REPO_ROOT/knowledge-db/AGENT.md" \
   "$REPO_ROOT/knowledge-db/README.md" "$REPO_ROOT/knowledge-db/_TEMPLATE.md" \
   "$DOWN/knowledge-db/"
mkdir -p "$DOWN/knowledge-db/explorations" "$DOWN/knowledge-db/solutions" \
         "$DOWN/knowledge-db/errors" "$DOWN/knowledge-db/decisions"
python3 -c "
import json
d = json.load(open('$REPO_ROOT/.kb-templates/kb.config.json'))
d['tags']['area'] = ['billing', 'portal']
d['extra_root_files'] = ['NOTES.md']
json.dump(d, open('$DOWN/knowledge-db/kb.config.json', 'w'), indent=2)"
echo "# notes" > "$DOWN/knowledge-db/NOTES.md"
printf 'a\nb\nc\n' > "$DOWN/src/pay.ts"
cat > "$DOWN/knowledge-db/explorations/2026-06-01-billing.md" <<'EOF'
---
title: Billing flow
type: exploration
status: tentative
date: 2026-06-01
tags: [area:billing]
sources:
  - src/pay.ts:1-3
---

## Summary
Payments go through src/pay.ts.
EOF
git -C "$DOWN" init -q
"$DOWN/knowledge-db/bin/kb" index >/dev/null 2>&1

DOWN_KB="$DOWN/knowledge-db/bin/kb"
OUT=$("$DOWN_KB" upgrade --dry-run --source "$UPSTREAM" --no-network 2>&1)
if echo "$OUT" | grep -q "9.9.9" && echo "$OUT" | grep -q "would vendor" \
   && ! grep -q '"9.9.9"' "$DOWN_KB"; then
    pass "upgrade --dry-run reports the newer source and changes nothing"
else
    fail "upgrade --dry-run reports the newer source and changes nothing" "$OUT"
fi
if echo "$OUT" | grep -q "brand_new_key"; then
    pass "--dry-run surfaces new upstream config keys without applying them"
else
    fail "--dry-run surfaces new upstream config keys without applying them" "$OUT"
fi

OUT=$("$DOWN_KB" upgrade --source "$UPSTREAM" --no-network 2>&1)
CODE=$?
if [[ $CODE -eq 0 ]] && grep -q '"9.9.9"' "$DOWN/knowledge-db/bin/kb"; then
    pass "upgrade vendors the newer tool"
else
    fail "upgrade vendors the newer tool" "exit=$CODE $OUT"
fi
if python3 -c "
import json, sys
d = json.load(open('$DOWN/knowledge-db/kb.config.json'))
sys.exit(0 if (d['kb_version'] == '9.9.9'
               and d['tags']['area'] == ['billing', 'portal']
               and d.get('extra_root_files') == ['NOTES.md']
               and 'brand_new_key' not in d) else 1)"; then
    pass "kb_version bumped; project vocabulary and extra_root_files preserved"
else
    fail "kb_version bumped; project vocabulary and extra_root_files preserved" \
         "$(cat "$DOWN/knowledge-db/kb.config.json")"
fi
if [[ -f "$DOWN/knowledge-db/explorations/2026-06-01-billing.md" ]] \
   && [[ -f "$DOWN/knowledge-db/NOTES.md" ]] \
   && [[ ! -f "$DOWN/knowledge-db/decisions/2026-01-01-upstream-only.md" ]]; then
    pass "entries and root files kept; upstream's own entries not copied"
else
    fail "entries and root files kept; upstream's own entries not copied" \
         "$(ls -R "$DOWN/knowledge-db" | head -20)"
fi
if echo "$OUT" | grep -q "^backup      "; then
    pass "upgrade takes a backup first"
else
    fail "upgrade takes a backup first" "$OUT"
fi
if echo "$OUT" | grep -qE "replanted   [0-9]+ runtime file|installer   no changes"; then
    pass "upgrade reruns the installer (replant + hook migration)"
else
    fail "upgrade reruns the installer (replant + hook migration)" "$OUT"
fi
OUT=$("$DOWN/knowledge-db/bin/kb" upgrade --source "$UPSTREAM" --no-network 2>&1)
if echo "$OUT" | grep -q "already current"; then
    pass "second upgrade is a no-op (already current)"
else
    fail "second upgrade is a no-op (already current)" "$OUT"
fi
cleanup "$TMP"

echo "Testing kb upgrade with no source available"
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
mkdir -p "$TMP/knowledge-db/bin"
cp "$REPO_ROOT/knowledge-db/bin/kb" "$TMP/knowledge-db/bin/kb"
OUT=$(HOME="$TMP/nohome" CLAUDE_PLUGIN_ROOT="" "$TMP/knowledge-db/bin/kb" \
      upgrade --no-network 2>&1)
CODE=$?
if [[ $CODE -eq 1 ]] && echo "$OUT" | grep -q "no source available"; then
    pass "--no-network with no local checkout fails clearly, never clones"
else
    fail "--no-network with no local checkout fails clearly, never clones" "exit=$CODE $OUT"
fi
cleanup "$TMP"

echo "Testing the update notice (no network, cache never written by check)"
TMP=$(mktemp -d)
SRC="$TMP/newer"
mkdir -p "$SRC/knowledge-db/bin"
sed 's/^KB_TOOL_VERSION = "[0-9.]*"/KB_TOOL_VERSION = "9.9.9"/' \
    "$REPO_ROOT/knowledge-db/bin/kb" > "$SRC/knowledge-db/bin/kb"
PROJ="$TMP/proj"
mkdir -p "$PROJ"
cp -R "$FIXTURES/pass/." "$PROJ/"
mkdir -p "$PROJ/knowledge-db/bin"
cp "$REPO_ROOT/knowledge-db/bin/kb" "$PROJ/knowledge-db/bin/kb"
# a sibling checkout named knowledge-database is one of the probed candidates
ln -s "$SRC" "$TMP/knowledge-database"
OUT=$("$PROJ/knowledge-db/bin/kb" version 2>&1)
if echo "$OUT" | grep -q "9.9.9 available"; then
    pass "kb version reports an available update from a local checkout"
else
    fail "kb version reports an available update from a local checkout" "$OUT"
fi
OUT=$("$PROJ/knowledge-db/bin/kb" check 2>&1)
CODE=$?
if [[ $CODE -eq 0 ]] && echo "$OUT" | grep -q "9.9.9 is available"; then
    pass "KB014 warns that an update exists without failing the check"
else
    fail "KB014 warns that an update exists without failing the check" "exit=$CODE $OUT"
fi
if [[ ! -f "$PROJ/knowledge-db/.upgrade-cache.json" ]]; then
    pass "kb check stays read-only (no cache file written)"
else
    fail "kb check stays read-only (no cache file written)" "cache file created by check"
fi
cleanup "$TMP"

echo "Testing newest source wins over first-found"
TMP=$(mktemp -d)
OLDSRC="$TMP/plugin-clone"
NEWSRC="$TMP/knowledge-database"
mkdir -p "$OLDSRC/knowledge-db/bin" "$NEWSRC/knowledge-db/bin"
python3 - "$REPO_ROOT/knowledge-db/bin/kb" "$OLDSRC/knowledge-db/bin/kb" 0.0.1 <<'PYEOF'
import re, sys
src, dest, version = sys.argv[1], sys.argv[2], sys.argv[3]
text = re.sub(r'^KB_TOOL_VERSION = "[0-9.]+"', f'KB_TOOL_VERSION = "{version}"',
              open(src).read(), count=1, flags=re.M)
open(dest, "w").write(text)
PYEOF
python3 - "$REPO_ROOT/knowledge-db/bin/kb" "$NEWSRC/knowledge-db/bin/kb" 9.9.9 <<'PYEOF'
import re, sys
src, dest, version = sys.argv[1], sys.argv[2], sys.argv[3]
text = re.sub(r'^KB_TOOL_VERSION = "[0-9.]+"', f'KB_TOOL_VERSION = "{version}"',
              open(src).read(), count=1, flags=re.M)
open(dest, "w").write(text)
PYEOF
PROJ="$TMP/proj"
mkdir -p "$PROJ"
cp -R "$FIXTURES/pass/." "$PROJ/"
mkdir -p "$PROJ/knowledge-db/bin"
cp "$REPO_ROOT/knowledge-db/bin/kb" "$PROJ/knowledge-db/bin/kb"
# CLAUDE_PLUGIN_ROOT is probed FIRST and points at the OLD tree
OUT=$(CLAUDE_PLUGIN_ROOT="$OLDSRC/payload" "$PROJ/knowledge-db/bin/kb" \
      upgrade --dry-run --no-network 2>&1)
if echo "$OUT" | grep -q "9.9.9"; then
    pass "resolves the newest local source, not the first candidate"
else
    fail "resolves the newest local source, not the first candidate" "$OUT"
fi
cleanup "$TMP"

echo "Testing kb find / kb show (the cheap lookup path)"
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
cat > "$TMP/knowledge-db/errors/2026-01-20-half-cent-rounding.md" <<'EOF'
---
title: "Half-cent money rounding lost a cent"
type: error
status: tentative
date: 2026-01-20
tags: []
sources:
  - src/app.txt:1
---

## Summary
round(x, 2) is banker's rounding on a binary float, so half-cents go down.

## Symptom
A 50% share of 1000.05 paid out 500.02 instead of 500.03.

## Root Cause
Two stacked defects: float cannot hold the half-cent, and round() ties to even.

## Fix
Use Decimal(str(amount)).quantize(Decimal("0.01"), ROUND_HALF_UP).

## Prevention
Grep gate: no round(x, 2) on currency outside the money helper.
EOF
"$KB" --kb-dir "$TMP/knowledge-db" index >/dev/null 2>&1

OUT=$("$KB" --kb-dir "$TMP/knowledge-db" find "half cent rounding" 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "half-cent-rounding.md"; then
    pass "kb find locates an entry by keywords"
else
    fail "kb find locates an entry by keywords" "$OUT"
fi
if ! echo "$OUT" | grep -q "Prevention"; then
    pass "kb find prints hits only, not whole entries"
else
    fail "kb find prints hits only, not whole entries" "$OUT"
fi

# The point of the feature: a lookup must cost far less than scanning the catalog.
FIND_CH=$(echo -n "$OUT" | wc -c | tr -d ' ')
INDEX_CH=$(wc -c < "$TMP/knowledge-db/INDEX.md" | tr -d ' ')
if [[ "$FIND_CH" -lt "$INDEX_CH" ]]; then
    pass "kb find output is smaller than INDEX.md ($FIND_CH vs $INDEX_CH chars)"
else
    fail "kb find output is smaller than INDEX.md" "find=$FIND_CH index=$INDEX_CH"
fi

OUT=$("$KB" --kb-dir "$TMP/knowledge-db" find "nothing here about kubernetes" 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q "no KB entry matches"; then
    pass "kb find exits non-zero and says so when nothing matches"
else
    fail "kb find exits non-zero and says so when nothing matches" "$OUT"
fi

OUT=$("$KB" --kb-dir "$TMP/knowledge-db" show half-cent-rounding 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "ROUND_HALF_UP" && echo "$OUT" | grep -q "sources:"; then
    pass "kb show prints the fix and the sources"
else
    fail "kb show prints the fix and the sources" "$OUT"
fi
SHOW_CH=$(echo -n "$OUT" | wc -c | tr -d ' ')
FULL_CH=$(wc -c < "$TMP/knowledge-db/errors/2026-01-20-half-cent-rounding.md" | tr -d ' ')
if [[ "$SHOW_CH" -lt "$FULL_CH" ]]; then
    pass "kb show is smaller than the whole entry ($SHOW_CH vs $FULL_CH chars)"
else
    fail "kb show is smaller than the whole entry" "show=$SHOW_CH full=$FULL_CH"
fi
if "$KB" --kb-dir "$TMP/knowledge-db" show half-cent-rounding --all 2>&1 | grep -q "## Prevention"; then
    pass "kb show --all prints the entry verbatim"
else
    fail "kb show --all prints the entry verbatim" "no Prevention section"
fi
if ! "$KB" --kb-dir "$TMP/knowledge-db" show no-such-entry >/dev/null 2>&1; then
    pass "kb show fails clearly on an unknown entry"
else
    fail "kb show fails clearly on an unknown entry" "exit 0"
fi
cleanup "$TMP"

echo "Testing the reuse rule reaches the agent"
OUT=$("$KB" --kb-dir "$FIXTURES/pass/knowledge-db" rules 2>&1)
if echo "$OUT" | grep -q "REUSE ENDS IT" && echo "$OUT" | grep -q "kb find"; then
    pass "injected rules carry the reuse rule and the lookup path"
else
    fail "injected rules carry the reuse rule and the lookup path" "$OUT"
fi
SIZE=$(echo -n "$OUT" | wc -c | tr -d ' ')
if [[ "$SIZE" -lt 1400 ]]; then
    pass "injected rules stay small ($SIZE chars, paid every prompt)"
else
    fail "injected rules stay small" "$SIZE chars - budget is 1400"
fi
OUT=$("$KB" --kb-dir "$FIXTURES/pass/knowledge-db" rules --plant 2>&1)
if echo "$OUT" | grep -q "REUSE ENDS THE TASK" && echo "$OUT" | grep -q "LOOK UP FIRST"; then
    pass "planted block carries the reuse rule and the lookup path"
else
    fail "planted block carries the reuse rule and the lookup path" "$OUT"
fi

echo "Testing the search index (one file read, never stale, deep fallback)"
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
cat > "$TMP/knowledge-db/errors/2026-01-21-cache-key-drift.md" <<'EOF'
---
title: "Cache key drift on dict ordering"
type: error
status: tentative
date: 2026-01-21
tags: []
sources:
  - src/app.txt:1
---

## Summary
Cache keys built from str(dict) changed with insertion order.

## Symptom
Intermittent cache misses under load.

## Root Cause
str(dict) is order sensitive.

## Fix
Build the key from sorted items.

## Prevention
The word gribblenaut appears only in this body section, nowhere in metadata.
EOF
"$KB" --kb-dir "$TMP/knowledge-db" index >/dev/null 2>&1

if [[ -f "$TMP/knowledge-db/.search-index.json" ]]; then
    pass "kb index writes the search index"
else
    fail "kb index writes the search index" "no .search-index.json"
fi
if "$KB" --kb-dir "$TMP/knowledge-db" check >/dev/null 2>&1; then
    pass "the search index does not trip KB002 (dot-prefixed)"
else
    fail "the search index does not trip KB002" "$("$KB" --kb-dir "$TMP/knowledge-db" check 2>&1)"
fi

# A metadata hit must be served from the index, WITHOUT the deep-scan notice.
OUT=$("$KB" --kb-dir "$TMP/knowledge-db" find "cache key drift" -n 2 2>&1)
if echo "$OUT" | grep -q "cache-key-drift.md" && ! echo "$OUT" | grep -q "deep scan"; then
    pass "a title hit is served from the index, no body scan"
else
    fail "a title hit is served from the index, no body scan" "$OUT"
fi

# A body-only term must still be found, by automatic fallback, and say so.
OUT=$("$KB" --kb-dir "$TMP/knowledge-db" find "gribblenaut" -n 2 2>&1)
if echo "$OUT" | grep -q "cache-key-drift.md" && echo "$OUT" | grep -q "deep scan"; then
    pass "a body-only term falls back to a deep scan and reports it"
else
    fail "a body-only term falls back to a deep scan and reports it" "$OUT"
fi
if "$KB" --kb-dir "$TMP/knowledge-db" find "gribblenaut" --deep 2>&1 | grep -q "cache-key-drift.md"; then
    pass "--deep forces the body scan explicitly"
else
    fail "--deep forces the body scan explicitly" "no hit"
fi

# Stale index must never be served: edit an entry without running `kb index`.
BEFORE=$(python3 -c "
import json; print(json.load(open('$TMP/knowledge-db/.search-index.json'))['fingerprint'])")
cat >> "$TMP/knowledge-db/errors/2026-01-21-cache-key-drift.md" <<'EOF'

<!-- hand edit, no kb index run -->
EOF
OUT=$("$KB" --kb-dir "$TMP/knowledge-db" find "cache key drift" -n 1 2>&1)
AFTER=$(python3 -c "
import json; print(json.load(open('$TMP/knowledge-db/.search-index.json'))['fingerprint'])")
if [[ "$BEFORE" != "$AFTER" ]] && echo "$OUT" | grep -q "cache-key-drift.md"; then
    pass "a hand-edited KB rebuilds the index instead of serving a stale one"
else
    fail "a hand-edited KB rebuilds the index instead of serving a stale one" \
         "before=$BEFORE after=$AFTER out=$OUT"
fi

# A deleted index must be rebuilt transparently, not crash.
python3 -c "
import pathlib; pathlib.Path('$TMP/knowledge-db/.search-index.json').unlink()"
if "$KB" --kb-dir "$TMP/knowledge-db" find "cache key drift" -n 1 >/dev/null 2>&1 \
   && [[ -f "$TMP/knowledge-db/.search-index.json" ]]; then
    pass "a missing index is rebuilt on the next find"
else
    fail "a missing index is rebuilt on the next find" "no rebuild"
fi

# The one-call fast path: hits AND the fix from a single invocation.
OUT=$("$KB" --kb-dir "$TMP/knowledge-db" find "cache key drift" -n 1 -s 2>&1)
if echo "$OUT" | grep -q "cache-key-drift.md" && echo "$OUT" | grep -q "sorted items"; then
    pass "kb find -s returns the hit and the fix in one call"
else
    fail "kb find -s returns the hit and the fix in one call" "$OUT"
fi
cleanup "$TMP"

echo "Testing the lookup path stays the documented one"
OUT=$("$KB" --kb-dir "$FIXTURES/pass/knowledge-db" rules 2>&1)
if echo "$OUT" | grep -q 'find "<keywords>" -s' && echo "$OUT" | grep -qi "not ls/grep/INDEX.md"; then
    pass "injected rules name the one-call path and rule out grep/INDEX scans"
else
    fail "injected rules name the one-call path and rule out grep/INDEX scans" "$OUT"
fi

echo "Testing SKILL.md's sample rule block cannot drift from the tool"
# No literal backticks and no heredoc inside $(): bash 3.2 mis-parses a quoted
# heredoc containing ``` when it sits in a command substitution.
CANON=$("$REPO_ROOT/knowledge-db/bin/kb" --kb-dir "$REPO_ROOT/knowledge-db" rules --plant 2>/dev/null \
        | sed '/kb:agent-rules:/d' | tr -d '[:space:]')
SAMPLE=$(python3 -c '
import sys
fence = chr(96) * 3
text = open(sys.argv[1]).read()
start = text.index(fence + "markdown" + chr(10) + "## HARD RULE: Knowledge Database")
head = start + len(fence) + len("markdown") + 1
end = text.index(fence, head)
sys.stdout.write("".join(text[head:end].split()))
' "$REPO_ROOT/knowledge-database/SKILL.md")
if [[ -n "$SAMPLE" && "$CANON" == "$SAMPLE" ]]; then
    pass "SKILL.md sample matches the tool's canonical rule block"
else
    fail "SKILL.md sample matches the tool's canonical rule block" \
         "it has drifted - regenerate it from 'kb rules --plant'"
fi

echo "Testing the hot commands stay fast and offline"
# These run on every agent Stop, every commit and every CI job. A regression
# here (an accidental network call, an O(n^2) scan) must fail the suite, not
# quietly add minutes to someone's pre-commit.
TMP=$(mktemp -d)
cp -R "$FIXTURES/pass/." "$TMP/"
"$KB" --kb-dir "$TMP/knowledge-db" index >/dev/null 2>&1
BUDGET=5
for CMD in "check" "rules" "version" "find feature"; do
    START=$(python3 -c "import time; print(time.time())")
    # shellcheck disable=SC2086
    "$KB" --kb-dir "$TMP/knowledge-db" $CMD >/dev/null 2>&1
    ELAPSED=$(python3 -c "import time; print(f'{time.time() - $START:.2f}')")
    if python3 -c "import sys; sys.exit(0 if $ELAPSED < $BUDGET else 1)"; then
        pass "kb $CMD completes in ${ELAPSED}s (budget ${BUDGET}s)"
    else
        fail "kb $CMD completes under ${BUDGET}s" "took ${ELAPSED}s"
    fi
done
# With git sabotaged, the hot path must still work: it must not need the network.
SABOTAGE=$(mktemp -d)
printf '#!/bin/sh\nexit 127\n' > "$SABOTAGE/git"
chmod +x "$SABOTAGE/git"
if PATH="$SABOTAGE:$PATH" "$KB" --kb-dir "$TMP/knowledge-db" check >/dev/null 2>&1 \
   && PATH="$SABOTAGE:$PATH" "$KB" --kb-dir "$TMP/knowledge-db" find feature >/dev/null 2>&1; then
    pass "check and find work with git unavailable (no network dependency)"
else
    fail "check and find work with git unavailable" "they depend on git/network"
fi
cleanup "$SABOTAGE"
cleanup "$TMP"

echo
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ $FAIL_COUNT -eq 0 ]] || exit 1
echo "All KB conformance tests passed"
