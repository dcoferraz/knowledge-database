#!/bin/bash
# knowledge-db enforcement installer. Idempotent and merging: re-runnable,
# never clobbers existing agent settings, hooks, or CI.
#
# Installs six layers:
#   1. KB scaffold           (knowledge-db/ with config, tool, buckets) — only if absent
#   2. Agent Stop hook       merged into committed .claude/settings.json (kb check)
#   3. Agent prompt rules    UserPromptSubmit hook merged into .claude/settings.json
#                            (kb rules): hard rules injected on EVERY prompt — active
#                            immediately, survives mid-session installs and context loss
#   4. Git pre-commit hook   .githooks/pre-commit + core.hooksPath (kb check --staged)
#   5. CI job                .github/workflows/kb-check.yml
#   6. Agent hard rules      HARD RULE block planted into EVERY runtime file the
#                            major agents auto-ingest (CLAUDE.md, AGENTS.md,
#                            .github/copilot-instructions.md, .github/instructions/
#                            kb.instructions.md with applyTo '**', .cursor/rules/
#                            knowledge-db.mdc with alwaysApply, .windsurfrules);
#                            full rules live in <KB>/AGENT.md
#
# Usage:
#   knowledge-db/install.sh           install/repair; prints changed vs already-in-place
#   knowledge-db/install.sh --check   report drift, change nothing; non-zero if any layer missing
#
# Zero third-party dependencies: bash + python3 (stdlib) + git.

set -euo pipefail

KB_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$KB_DIR/.." && pwd)"
KB_NAME="$(basename "$KB_DIR")"
CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

SETTINGS="$REPO_ROOT/.claude/settings.json"
HOOK_CMD="\"\$CLAUDE_PROJECT_DIR/$KB_NAME/bin/kb\" check 1>&2 || exit 2"
PRECOMMIT="$REPO_ROOT/.githooks/pre-commit"
WORKFLOW="$REPO_ROOT/.github/workflows/kb-check.yml"

CHANGED=()
IN_PLACE=()
MISSING=()

note_ok()      { IN_PLACE+=("$1"); }
note_changed() { CHANGED+=("$1"); }
note_missing() { MISSING+=("$1"); }

# ---------------------------------------------------------------- 1. scaffold

if [[ -f "$KB_DIR/kb.config.json" && -x "$KB_DIR/bin/kb" ]]; then
    note_ok "KB scaffold ($KB_NAME/)"
else
    if $CHECK_ONLY; then
        note_missing "KB scaffold ($KB_NAME/kb.config.json or bin/kb missing)"
    else
        echo "KB scaffold incomplete: $KB_DIR must contain kb.config.json and bin/kb" >&2
        echo "(this installer ships inside the KB folder — copy the whole $KB_NAME/ folder first)" >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------- 2. agent hook

has_agent_hook() {
    [[ -f "$SETTINGS" ]] && python3 - "$SETTINGS" <<'EOF'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
for group in data.get("hooks", {}).get("Stop", []):
    for hook in group.get("hooks", []):
        if "kb\" check" in hook.get("command", "") or "kb check" in hook.get("command", ""):
            sys.exit(0)
sys.exit(1)
EOF
}

if has_agent_hook; then
    note_ok "agent Stop hook (.claude/settings.json)"
elif $CHECK_ONLY; then
    note_missing "agent Stop hook (.claude/settings.json)"
else
    mkdir -p "$REPO_ROOT/.claude"
    HOOK_CMD="$HOOK_CMD" SETTINGS="$SETTINGS" python3 - <<'EOF'
import json, os
path = os.environ["SETTINGS"]
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
hooks = data.setdefault("hooks", {})
stop = hooks.setdefault("Stop", [])
stop.append({"hooks": [{"type": "command", "command": os.environ["HOOK_CMD"]}]})
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
EOF
    note_changed "agent Stop hook merged into .claude/settings.json"
fi

# ---------------------------------------------------------------- 3. prompt rules hook

RULES_CMD="\"\$CLAUDE_PROJECT_DIR/$KB_NAME/bin/kb\" rules"

has_rules_hook() {
    [[ -f "$SETTINGS" ]] && python3 - "$SETTINGS" <<'EOF'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
for group in data.get("hooks", {}).get("UserPromptSubmit", []):
    for hook in group.get("hooks", []):
        if "kb\" rules" in hook.get("command", "") or "kb rules" in hook.get("command", ""):
            sys.exit(0)
sys.exit(1)
EOF
}

if has_rules_hook; then
    note_ok "agent prompt rules hook (.claude/settings.json UserPromptSubmit)"
elif $CHECK_ONLY; then
    note_missing "agent prompt rules hook (.claude/settings.json UserPromptSubmit)"
else
    mkdir -p "$REPO_ROOT/.claude"
    RULES_CMD="$RULES_CMD" SETTINGS="$SETTINGS" python3 - <<'EOF'
import json, os
path = os.environ["SETTINGS"]
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
hooks = data.setdefault("hooks", {})
ups = hooks.setdefault("UserPromptSubmit", [])
ups.append({"hooks": [{"type": "command", "command": os.environ["RULES_CMD"]}]})
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
EOF
    note_changed "agent prompt rules hook (UserPromptSubmit: kb rules) merged into .claude/settings.json"
fi

# ---------------------------------------------------------------- 4. git hook

precommit_ok() {
    [[ -f "$PRECOMMIT" ]] && grep -q "kb\" check --staged" "$PRECOMMIT"
}
hookspath_ok() {
    [[ "$(git -C "$REPO_ROOT" config core.hooksPath 2>/dev/null || true)" == ".githooks" ]]
}

if precommit_ok; then
    note_ok "pre-commit hook (.githooks/pre-commit)"
elif $CHECK_ONLY; then
    note_missing "pre-commit hook (.githooks/pre-commit)"
else
    mkdir -p "$REPO_ROOT/.githooks"
    if [[ -f "$PRECOMMIT" ]]; then
        # merge: append to existing hook, never clobber
        printf '\n# knowledge-db enforcement (KB rules; CI still gates on --no-verify bypass)\n"$(git rev-parse --show-toplevel)/%s/bin/kb" check --staged\n' "$KB_NAME" >> "$PRECOMMIT"
    else
        cat > "$PRECOMMIT" <<EOF
#!/bin/bash
# knowledge-db enforcement. Bypassable with --no-verify; CI still gates.
exec "\$(git rev-parse --show-toplevel)/$KB_NAME/bin/kb" check --staged
EOF
    fi
    chmod +x "$PRECOMMIT"
    note_changed "pre-commit hook written to .githooks/pre-commit"
fi

if hookspath_ok; then
    note_ok "git core.hooksPath = .githooks"
elif [[ -n "${CI:-}" ]]; then
    note_ok "git core.hooksPath (skipped: CI environment)"
elif $CHECK_ONLY; then
    note_missing "git core.hooksPath (run: git config core.hooksPath .githooks)"
else
    git -C "$REPO_ROOT" config core.hooksPath .githooks
    note_changed "git core.hooksPath set to .githooks"
fi

# ---------------------------------------------------------------- 5. CI job

if [[ -f "$WORKFLOW" ]]; then
    note_ok "CI job (.github/workflows/kb-check.yml)"
elif $CHECK_ONLY; then
    note_missing "CI job (.github/workflows/kb-check.yml)"
else
    mkdir -p "$REPO_ROOT/.github/workflows"
    cat > "$WORKFLOW" <<EOF
name: kb-check

on:
  push:
    branches: [main]
  pull_request:

jobs:
  kb-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Validate knowledge base
        run: $KB_NAME/bin/kb check
      - name: Assert enforcement is installed
        run: $KB_NAME/install.sh --check
      - name: KB conformance suite
        run: |
          if [ -x tests/run-kb-tests.sh ]; then tests/run-kb-tests.sh; fi
      - name: Write-back + lockstep rules (PR diff)
        if: github.event_name == 'pull_request'
        run: $KB_NAME/bin/kb check --diff-base "origin/\${{ github.base_ref }}"
EOF
    note_changed "CI job written to .github/workflows/kb-check.yml"
fi

# ---------------------------------------------------------------- 6. agent rules
# Belt-and-suspenders: the HARD RULE block is planted into EVERY runtime file the
# major agents auto-ingest, so whichever agent is active still sees it with zero
# human steps. Each target is marker-guarded (create-or-merge, idempotent).
# To restrict, delete unwanted paths from RULE_TARGETS — --check mirrors the list.

MARKER="<!-- kb:agent-rules:start -->"

# "<relative path>|<kind>": append = marker block appended to (possibly existing)
# markdown; copilot-fm / cursor-fm = created with the frontmatter that runtime
# needs to auto-apply the rule to every task (merge if the file already exists).
RULE_TARGETS=(
    "CLAUDE.md|append"
    "AGENTS.md|append"
    ".github/copilot-instructions.md|append"
    ".github/instructions/kb.instructions.md|copilot-fm"
    ".cursor/rules/knowledge-db.mdc|cursor-fm"
    ".windsurfrules|append"
)

emit_rule_block() {
    cat <<EOF
$MARKER
## HARD RULE: Knowledge Database

This repo keeps durable memory in \`$KB_NAME/\`. For EVERY task:

1. **ALWAYS READ FIRST** — check \`$KB_NAME/INDEX.md\` before exploring; reuse verified entries.
2. **EMPTY KB** — if no (relevant) entries exist, say so and suggest either a codebase
   exploration to seed it, or manual document/context input to ingest. Then continue the task.
3. **NEVER PROMPT, NEVER WITHHOLD** — create, update, and supersede KB entries autonomously,
   as insights occur. Superseding a verified entry needs a stated reason and a \`related:\`
   link to the replacement — never permission.
4. **WRITE BACK** — non-trivial work (search, multi-file reads, debugging, decisions) ends
   with KB entries. \`$KB_NAME/bin/kb check\` must exit 0.

Full rules: \`$KB_NAME/AGENT.md\`. Rule table (KB001-KB015): \`$KB_NAME/README.md\`.
<!-- kb:agent-rules:end -->
EOF
}

emit_frontmatter() {
    case "$1" in
        copilot-fm) printf -- "---\napplyTo: '**'\n---\n\n" ;;
        cursor-fm)  printf -- "---\ndescription: Knowledge database hard rules (durable project memory)\nalwaysApply: true\n---\n\n" ;;
    esac
}

if [[ ! -f "$KB_DIR/AGENT.md" ]] && $CHECK_ONLY; then
    note_missing "agent hard rules ($KB_NAME/AGENT.md)"
fi

NEW_PLANTS=0
RULES_MISSING=()
for target in "${RULE_TARGETS[@]}"; do
    REL="${target%%|*}"
    KIND="${target##*|}"
    FILE="$REPO_ROOT/$REL"
    if [[ -f "$FILE" ]] && grep -qF "$MARKER" "$FILE"; then
        continue
    elif $CHECK_ONLY; then
        RULES_MISSING+=("$REL")
    else
        mkdir -p "$(dirname "$FILE")"
        if [[ ! -f "$FILE" ]]; then
            { emit_frontmatter "$KIND"; emit_rule_block; } > "$FILE"
        else
            { printf "\n"; emit_rule_block; } >> "$FILE"
        fi
        note_changed "agent hard rules planted in $REL"
        NEW_PLANTS=$((NEW_PLANTS + 1))
    fi
done

if [[ ${#RULES_MISSING[@]} -gt 0 ]]; then
    note_missing "agent hard rules (HARD RULE block absent from: ${RULES_MISSING[*]})"
elif [[ $NEW_PLANTS -eq 0 ]]; then
    note_ok "agent hard rules (all ${#RULE_TARGETS[@]} runtime files reference $KB_NAME/AGENT.md)"
fi

if [[ $NEW_PLANTS -gt 0 ]]; then
    echo "NOTE: planted rule files load at each agent's NEXT session start;" >&2
    echo "      the UserPromptSubmit hook (kb rules) covers the CURRENT Claude Code session from the next prompt." >&2
fi

# ---------------------------------------------------------------- report

for item in "${CHANGED[@]:-}";  do [[ -n "$item" ]] && echo "CHANGED    $item"; done
for item in "${IN_PLACE[@]:-}"; do [[ -n "$item" ]] && echo "IN PLACE   $item"; done
for item in "${MISSING[@]:-}";  do [[ -n "$item" ]] && echo "MISSING    $item"; done

if $CHECK_ONLY && [[ ${#MISSING[@]} -gt 0 ]]; then
    exit 1
fi
exit 0
