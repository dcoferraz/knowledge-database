#!/bin/bash
# knowledge-db enforcement installer. Idempotent and merging: re-runnable,
# never clobbers existing agent settings, hooks, or CI.
#
# Installs five layers:
#   1. KB scaffold           (knowledge-db/ with config, tool, buckets) — only if absent
#   2. Agent Stop hook       merged into committed .claude/settings.json (kb check)
#   3. Git pre-commit hook   .githooks/pre-commit + core.hooksPath (kb check --staged)
#   4. CI job                .github/workflows/kb-check.yml
#   5. Agent hard rules      HARD RULE block appended to host instructions file
#                            (CLAUDE.md / AGENTS.md / copilot-instructions.md; full
#                            rules live in <KB>/AGENT.md)
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

# ---------------------------------------------------------------- 3. git hook

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

# ---------------------------------------------------------------- 4. CI job

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

# ---------------------------------------------------------------- 5. agent rules

find_host_file() {
    for f in "CLAUDE.md" "AGENTS.md" ".github/copilot-instructions.md"; do
        if [[ -f "$REPO_ROOT/$f" ]]; then
            echo "$REPO_ROOT/$f"
            return
        fi
    done
    echo "$REPO_ROOT/CLAUDE.md"
}

HOST_FILE="$(find_host_file)"
HOST_REL="${HOST_FILE#"$REPO_ROOT"/}"
MARKER="<!-- kb:agent-rules:start -->"

if [[ ! -f "$KB_DIR/AGENT.md" ]]; then
    if $CHECK_ONLY; then
        note_missing "agent hard rules ($KB_NAME/AGENT.md)"
    fi
elif [[ -f "$HOST_FILE" ]] && grep -qF "$MARKER" "$HOST_FILE"; then
    note_ok "agent hard rules ($HOST_REL references $KB_NAME/AGENT.md)"
elif $CHECK_ONLY; then
    note_missing "agent hard rules (HARD RULE block absent from $HOST_REL)"
else
    mkdir -p "$(dirname "$HOST_FILE")"
    cat >> "$HOST_FILE" <<EOF

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

Full rules: \`$KB_NAME/AGENT.md\`. Rule table (KB001-KB011): \`$KB_NAME/README.md\`.
<!-- kb:agent-rules:end -->
EOF
    note_changed "agent hard rules appended to $HOST_REL"
fi

# ---------------------------------------------------------------- report

for item in "${CHANGED[@]:-}";  do [[ -n "$item" ]] && echo "CHANGED    $item"; done
for item in "${IN_PLACE[@]:-}"; do [[ -n "$item" ]] && echo "IN PLACE   $item"; done
for item in "${MISSING[@]:-}";  do [[ -n "$item" ]] && echo "MISSING    $item"; done

if $CHECK_ONLY && [[ ${#MISSING[@]} -gt 0 ]]; then
    exit 1
fi
exit 0
