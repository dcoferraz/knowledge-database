#!/bin/bash
# knowledge-db enforcement installer + setup wizard. Idempotent and merging:
# re-runnable, never clobbers existing agent settings, hooks, or CI.
#
# Run it with no arguments in a terminal and it asks how you want to use the KB
# (in-repo / context workspace / local memory, which agents, which gates), then
# installs exactly that. Piped, in CI, or with --yes it installs the full
# default set without asking, so agents and scripts keep working unattended.
#
# Layers:
#   0. Wizard answers        recorded in <KB>/.install.json so --check audits the
#                            layers this project asked for (never kb.config.json:
#                            that is a vocabulary, and projects lockstep it)
#   1. KB scaffold           (knowledge-db/ with config, tool, buckets) — only if absent
#   2. Agent hooks           merged into committed .claude/settings.json:
#                            Stop + SubagentStop run `kb stop-hook` (loop-safe check),
#                            UserPromptSubmit runs `kb rules` (hard rules injected on
#                            EVERY prompt, so they cannot fall out of context)
#   3. Git pre-commit hook   .githooks/pre-commit + core.hooksPath (kb check --staged);
#                            in workspace mode also planted INSIDE each nested repo so
#                            code commits there are gated against the workspace KB
#   4. CI job                .github/workflows/kb-check.yml
#   5. Agent hard rules      HARD RULE block planted into EVERY runtime file the major
#                            agents auto-ingest (CLAUDE.md, AGENTS.md, .github/
#                            copilot-instructions.md, .github/instructions/
#                            kb.instructions.md with applyTo '**', .cursor/rules/
#                            knowledge-db.mdc with alwaysApply, .windsurfrules).
#                            Text and target list come from `bin/kb rules --plant`
#                            / `--targets`, and a stale block is REPLANTED.
#
# Usage:
#   knowledge-db/install.sh                   wizard when interactive, else full install
#   knowledge-db/install.sh --yes             no questions; install the default set
#   knowledge-db/install.sh --wizard          force the wizard even when piped
#   knowledge-db/install.sh --check           report drift, change nothing; non-zero if incomplete
#   knowledge-db/install.sh --mode workspace  in-repo | workspace | local (implies --yes)
#   knowledge-db/install.sh --no-git-hooks --no-ci --no-rule-files --no-agent-hooks
#
# Zero third-party dependencies: bash + python3 (stdlib) + git.

set -uo pipefail

KB_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$KB_DIR/.." && pwd)"
KB_NAME="$(basename "$KB_DIR")"
KB_BIN="$KB_DIR/bin/kb"
CONFIG="$KB_DIR/kb.config.json"
# Wizard answers live in their own file, NOT in kb.config.json: the config is a
# vocabulary that projects put under lockstep rules (KB009), and an installer
# that rewrote it would trip those rules on every run. Dot-prefixed so KB002
# ignores it.
STATE="$KB_DIR/.install.json"

CHECK_ONLY=false
ASSUME_YES=false
FORCE_WIZARD=false
MODE=""
WANT_AGENT_HOOKS=true
WANT_GIT_HOOKS=true
WANT_CI=true
WANT_RULE_FILES=true
NESTED_REPOS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)          CHECK_ONLY=true ;;
        --yes|-y)         ASSUME_YES=true ;;
        --wizard)         FORCE_WIZARD=true ;;
        --mode)           MODE="${2:-}"; ASSUME_YES=true; shift ;;
        --mode=*)         MODE="${1#*=}"; ASSUME_YES=true ;;
        --local)          MODE="local"; ASSUME_YES=true ;;
        --no-agent-hooks) WANT_AGENT_HOOKS=false; ASSUME_YES=true ;;
        --no-git-hooks)   WANT_GIT_HOOKS=false; ASSUME_YES=true ;;
        --no-ci)          WANT_CI=false; ASSUME_YES=true ;;
        --no-rule-files)  WANT_RULE_FILES=false; ASSUME_YES=true ;;
        -h|--help)        sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "install.sh: unknown argument '$1' (try --help)" >&2; exit 2 ;;
    esac
    shift
done

SETTINGS="$REPO_ROOT/.claude/settings.json"
PRECOMMIT="$REPO_ROOT/.githooks/pre-commit"
WORKFLOW="$REPO_ROOT/.github/workflows/kb-check.yml"

CHANGED=()
IN_PLACE=()
MISSING=()
NOTES=()

note_ok()      { IN_PLACE+=("$1"); }
note_changed() { CHANGED+=("$1"); }
note_missing() { MISSING+=("$1"); }
note()         { NOTES+=("$1"); }

# The report is printed from an EXIT trap: a layer that dies (a git call in a
# non-repo used to abort the whole installer) must never swallow the record of
# what did get installed.
REPORT_DONE=false
print_report() {
    $REPORT_DONE && return 0
    REPORT_DONE=true
    local item
    for item in "${CHANGED[@]:-}";  do [[ -n "$item" ]] && echo "CHANGED    $item"; done
    for item in "${IN_PLACE[@]:-}"; do [[ -n "$item" ]] && echo "IN PLACE   $item"; done
    for item in "${MISSING[@]:-}";  do [[ -n "$item" ]] && echo "MISSING    $item"; done
    for item in "${NOTES[@]:-}";    do [[ -n "$item" ]] && echo "$item" >&2; done
}
trap print_report EXIT

is_git_repo() { git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; }

# ---------------------------------------------------------------- persisted choices
# The wizard's answers live in <KB>/.install.json, so --check knows which layers
# this project actually asked for instead of demanding all of them.

config_get_install() {
    python3 - "$STATE" "$1" <<'EOF'
import json, sys
try:
    install = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
key = sys.argv[2]
if key == "mode":
    print(install.get("mode", ""))
elif key == "nested":
    print(" ".join(install.get("nested_repos", [])))
else:
    layers = install.get("layers") or {}
    value = layers.get(key)
    print("" if value is None else ("true" if value else "false"))
EOF
}

save_install_choices() {
    MODE="$MODE" AGENT="$WANT_AGENT_HOOKS" GIT="$WANT_GIT_HOOKS" CI_="$WANT_CI" \
    RULES="$WANT_RULE_FILES" NESTED="$NESTED_REPOS" STATE="$STATE" python3 - <<'EOF'
import json, os
state = {
    "mode": os.environ["MODE"],
    "layers": {
        "agent_hooks": os.environ["AGENT"] == "true",
        "git_hooks": os.environ["GIT"] == "true",
        "ci": os.environ["CI_"] == "true",
        "rule_files": os.environ["RULES"] == "true",
    },
    "nested_repos": [r for r in os.environ["NESTED"].split() if r],
}
with open(os.environ["STATE"], "w") as fh:
    json.dump(state, fh, indent=2)
    fh.write("\n")
EOF
}

# ---------------------------------------------------------------- wizard

nested_repo_candidates() {
    # Immediate subdirectories that are their own git repositories.
    local dir
    for dir in "$REPO_ROOT"/*/; do
        [[ -d "$dir" ]] || continue
        [[ "$(basename "$dir")" == "$KB_NAME" ]] && continue
        if [[ -e "$dir/.git" ]]; then
            echo "$(basename "$dir")"
        fi
    done
}

ask() {
    # ask <prompt> <default>  -> answer on stdout
    local prompt="$1" default="$2" reply=""
    printf '%s [%s] ' "$prompt" "$default" >&2
    IFS= read -r reply || reply=""
    [[ -z "$reply" ]] && reply="$default"
    echo "$reply"
}

ask_yes_no() {
    local reply
    reply="$(ask "$1" "$2")"
    case "$reply" in y|Y|yes|YES|true) echo true ;; *) echo false ;; esac
}

run_wizard() {
    local nested detected reply
    detected="$(nested_repo_candidates | tr '\n' ' ')"
    cat >&2 <<EOF

  knowledge-database setup
  ────────────────────────────────────────────────────────────
  KB folder : $KB_NAME/
  Project   : $REPO_ROOT
EOF
    if is_git_repo; then
        echo "  Git       : yes" >&2
    else
        echo "  Git       : no (git-time gates will be skipped)" >&2
    fi
    [[ -n "$detected" ]] && echo "  Nested    : $detected" >&2
    cat >&2 <<'EOF'

  1) How do you want to use the knowledge base?

     [1] in-repo    KB committed inside this repo, shared with the team (default)
     [2] workspace  KB lives above one or more nested app repos, alongside
                    specs/meetings/references (the context-workspace pattern)
     [3] local      personal memory, gitignored, never committed

EOF
    reply="$(ask "  choice" "1")"
    case "$reply" in
        2|workspace) MODE="workspace" ;;
        3|local)     MODE="local" ;;
        *)           MODE="in-repo" ;;
    esac

    echo >&2
    echo "  2) Agent wiring (Claude Code hooks + rule files for every major agent)" >&2
    WANT_AGENT_HOOKS="$(ask_yes_no "     install .claude/settings.json hooks? (y/n)" "y")"
    WANT_RULE_FILES="$(ask_yes_no "     plant the HARD RULE block in agent runtime files? (y/n)" "y")"

    echo >&2
    if [[ "$MODE" == "local" ]]; then
        # A gitignored KB can never appear in a diff, so the diff-time gates
        # would fail every commit. Skip them and say so.
        WANT_GIT_HOOKS=false
        WANT_CI=false
        echo "  3) Git-time gates skipped: a gitignored KB never shows up in a diff," >&2
        echo "     so pre-commit and CI write-back rules cannot apply in local mode." >&2
    elif is_git_repo; then
        echo "  3) Git-time gates" >&2
        WANT_GIT_HOOKS="$(ask_yes_no "     install the pre-commit write-back gate? (y/n)" "y")"
        WANT_CI="$(ask_yes_no "     add the CI job (.github/workflows/kb-check.yml)? (y/n)" "y")"
    else
        WANT_GIT_HOOKS=false
        WANT_CI=false
        echo "  3) Git-time gates skipped: $REPO_ROOT is not a git repository." >&2
    fi

    if [[ "$MODE" == "workspace" ]]; then
        echo >&2
        echo "  4) Nested repos to gate (code commits there require a KB entry here)" >&2
        if [[ -z "$detected" ]]; then
            echo "     none found — clone your app repo into this folder and re-run." >&2
        else
            for nested in $detected; do
                if [[ "$(ask_yes_no "     wire $nested/? (y/n)" "y")" == "true" ]]; then
                    NESTED_REPOS="$NESTED_REPOS $nested"
                fi
            done
        fi
    fi
    echo >&2
}

if $CHECK_ONLY; then
    # --check verifies what this project asked for, not a fixed ideal.
    MODE="$(config_get_install mode)"
    [[ -z "$MODE" ]] && MODE="in-repo"
    saved="$(config_get_install agent_hooks)"; [[ -n "$saved" ]] && WANT_AGENT_HOOKS="$saved"
    saved="$(config_get_install git_hooks)";   [[ -n "$saved" ]] && WANT_GIT_HOOKS="$saved"
    saved="$(config_get_install ci)";          [[ -n "$saved" ]] && WANT_CI="$saved"
    saved="$(config_get_install rule_files)";  [[ -n "$saved" ]] && WANT_RULE_FILES="$saved"
    NESTED_REPOS="$(config_get_install nested)"
elif $FORCE_WIZARD || { ! $ASSUME_YES && [[ -t 0 && -t 2 ]]; }; then
    run_wizard
fi

[[ -z "$MODE" ]] && MODE="in-repo"
case "$MODE" in
    in-repo|workspace|local) ;;
    *) echo "install.sh: --mode must be in-repo, workspace, or local (got '$MODE')" >&2; exit 2 ;;
esac
if ! is_git_repo; then
    WANT_GIT_HOOKS=false
    WANT_CI=false
fi

# Non-interactive workspace mode (--mode workspace --yes, CI, an agent): wire
# every nested repo we can see. Asking is impossible here, and a workspace whose
# app repo is ungated is the failure this mode exists to fix.
if [[ "$MODE" == "workspace" && -z "${NESTED_REPOS// /}" ]] && ! $CHECK_ONLY; then
    NESTED_REPOS="$(nested_repo_candidates | tr '\n' ' ')"
fi

# ---------------------------------------------------------------- 1. scaffold

if [[ -f "$CONFIG" && -x "$KB_BIN" ]]; then
    note_ok "KB scaffold ($KB_NAME/), mode: $MODE"
else
    if $CHECK_ONLY; then
        note_missing "KB scaffold ($KB_NAME/kb.config.json or bin/kb missing)"
    else
        echo "KB scaffold incomplete: $KB_DIR must contain kb.config.json and bin/kb" >&2
        echo "(this installer ships inside the KB folder — copy the whole $KB_NAME/ folder first)" >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------- 2. agent hooks

STOP_CMD="\"\$CLAUDE_PROJECT_DIR/$KB_NAME/bin/kb\" stop-hook"
RULES_CMD="\"\$CLAUDE_PROJECT_DIR/$KB_NAME/bin/kb\" rules"

# Stop/SubagentStop run `kb stop-hook` rather than `kb check` directly: the
# wrapper reads the hook payload and refuses to block twice on the same
# finding, so a KB the model cannot fix can never turn into a stop loop.
hook_state() {
    # prints: missing | legacy | ok
    [[ -f "$SETTINGS" ]] || { echo missing; return; }
    python3 - "$SETTINGS" <<'EOF'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    print("missing"); sys.exit(0)
hooks = data.get("hooks", {})

def commands(event):
    out = []
    for group in hooks.get(event, []):
        for hook in group.get("hooks", []):
            out.append(hook.get("command", ""))
    return out

stop = commands("Stop")
subagent = commands("SubagentStop")
prompt = commands("UserPromptSubmit")
has_stop_hook = any("stop-hook" in c for c in stop)
has_legacy = any("kb\" check" in c or "kb check" in c for c in stop)
has_sub = any("stop-hook" in c or "kb check" in c for c in subagent)
has_rules = any("kb\" rules" in c or "kb rules" in c for c in prompt)
if has_stop_hook and has_sub and has_rules:
    print("ok")
elif has_legacy or has_stop_hook or has_rules:
    print("legacy")
else:
    print("missing")
EOF
}

write_agent_hooks() {
    mkdir -p "$REPO_ROOT/.claude"
    STOP_CMD="$STOP_CMD" RULES_CMD="$RULES_CMD" SETTINGS="$SETTINGS" python3 - <<'EOF'
import json, os
path = os.environ["SETTINGS"]
stop_cmd, rules_cmd = os.environ["STOP_CMD"], os.environ["RULES_CMD"]
data = {}
if os.path.exists(path):
    with open(path) as fh:
        data = json.load(fh)
hooks = data.setdefault("hooks", {})

def upgrade(event, command, legacy_marks):
    groups = hooks.setdefault(event, [])
    for group in groups:
        for hook in group.get("hooks", []):
            current = hook.get("command", "")
            if current == command:
                return
            if any(mark in current for mark in legacy_marks):
                hook["command"] = command      # migrate the old command in place
                return
    groups.append({"hooks": [{"type": "command", "command": command}]})

upgrade("Stop", stop_cmd, ['kb" check', "kb check", "stop-hook"])
upgrade("SubagentStop", stop_cmd, ['kb" check', "kb check", "stop-hook"])
upgrade("UserPromptSubmit", rules_cmd, ['kb" rules', "kb rules"])
with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
EOF
}

if ! $WANT_AGENT_HOOKS; then
    note_ok "agent hooks (declined)"
else
    HOOK_STATE="$(hook_state)"
    if [[ "$HOOK_STATE" == "ok" ]]; then
        note_ok "agent hooks (.claude/settings.json: Stop + SubagentStop + UserPromptSubmit)"
    elif $CHECK_ONLY; then
        if [[ "$HOOK_STATE" == "legacy" ]]; then
            note_missing "agent hooks incomplete (.claude/settings.json — rerun install.sh: \
Stop/SubagentStop should run \`kb stop-hook\`, UserPromptSubmit \`kb rules\`)"
        else
            note_missing "agent hooks (.claude/settings.json)"
        fi
    else
        write_agent_hooks
        note_changed "agent hooks merged into .claude/settings.json \
(Stop + SubagentStop -> kb stop-hook, UserPromptSubmit -> kb rules)"
    fi
fi

# ---------------------------------------------------------------- 3. git hooks

precommit_ok() {
    [[ -f "$PRECOMMIT" ]] && grep -q "kb\" check --staged" "$PRECOMMIT"
}
hookspath_ok() {
    [[ "$(git -C "$REPO_ROOT" config core.hooksPath 2>/dev/null || true)" == ".githooks" ]]
}

nested_hook_path() {
    # Honors core.hooksPath inside the nested repo instead of assuming .git/hooks.
    local repo="$1" hooks
    hooks="$(git -C "$repo" config core.hooksPath 2>/dev/null || true)"
    if [[ -n "$hooks" ]]; then
        [[ "$hooks" = /* ]] && echo "$hooks/pre-commit" || echo "$repo/$hooks/pre-commit"
    else
        echo "$(git -C "$repo" rev-parse --absolute-git-dir)/hooks/pre-commit"
    fi
}

if ! $WANT_GIT_HOOKS; then
    if is_git_repo; then
        note_ok "git-time gates (declined)"
    else
        note_ok "git-time gates (skipped: $REPO_ROOT is not a git repository)"
    fi
else
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
fi

# ---------------------------------------------------------------- 3b. nested repos
# Workspace mode: the app lives in its own repo that this workspace ignores, so
# a commit in there can never show the KB in its diff. Plant a hook inside the
# nested repo that runs THIS KB's check with --repo, restoring the write-back
# gate for code that lives outside the KB's own repository.

if [[ "$MODE" == "workspace" && -n "${NESTED_REPOS// /}" ]]; then
    for NESTED in $NESTED_REPOS; do
        NESTED_PATH="$REPO_ROOT/$NESTED"
        if [[ ! -e "$NESTED_PATH/.git" ]]; then
            note_missing "nested repo gate ($NESTED/ is not a git repository)"
            continue
        fi
        HOOK_FILE="$(nested_hook_path "$NESTED_PATH")"
        # Reference the KB by a path relative to the nested repo, so the hook
        # line stays valid for anyone with the same workspace layout instead of
        # baking in one machine's absolute path.
        REL_KB="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' \
            "$KB_DIR" "$NESTED_PATH")"
        if [[ -f "$HOOK_FILE" ]] && grep -qF "bin/kb\" check --staged --repo" "$HOOK_FILE"; then
            note_ok "nested repo gate ($NESTED/ -> $KB_NAME)"
        elif $CHECK_ONLY; then
            note_missing "nested repo gate ($NESTED/: no pre-commit hook calling $KB_NAME/bin/kb)"
        else
            mkdir -p "$(dirname "$HOOK_FILE")"
            if [[ -f "$HOOK_FILE" ]]; then
                printf '\n# knowledge-db workspace enforcement\n"$(git rev-parse --show-toplevel)/%s/bin/kb" check --staged --repo "$(git rev-parse --show-toplevel)"\n' \
                    "$REL_KB" >> "$HOOK_FILE"
            else
                cat > "$HOOK_FILE" <<EOF
#!/bin/bash
# knowledge-db workspace enforcement: this repo's code is gated against the KB
# at ../$REL_KB. Bypassable with --no-verify.
exec "\$(git rev-parse --show-toplevel)/$REL_KB/bin/kb" check --staged --repo "\$(git rev-parse --show-toplevel)"
EOF
            fi
            chmod +x "$HOOK_FILE"
            note_changed "nested repo gate installed in $NESTED/ ($(basename "$(dirname "$HOOK_FILE")")/pre-commit)"
            case "$HOOK_FILE" in
                "$NESTED_PATH"/.git/*) ;;
                *) note "NOTE: $NESTED/ sets core.hooksPath, so its gate went into a TRACKED hook"
                   note "      file ($HOOK_FILE). That line will be committed to that repo — move"
                   note "      it out if the app repo should not reference this workspace." ;;
            esac
        fi
    done
fi

# ---------------------------------------------------------------- 4. CI job

if ! $WANT_CI; then
    note_ok "CI job (declined or not applicable)"
elif [[ -f "$WORKFLOW" ]]; then
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
    timeout-minutes: 10
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
# Belt-and-suspenders: the HARD RULE block is planted into EVERY runtime file the
# major agents auto-ingest, so whichever agent is active still sees it with zero
# human steps. The block text and the target list come from `bin/kb`, and a block
# that no longer matches the tool is REPLANTED (before v0.7.0 the marker guard
# froze old text in place forever).

MARKER="<!-- kb:agent-rules:start -->"
MARKER_END="<!-- kb:agent-rules:end -->"

RULE_TARGETS=()
while IFS= read -r line; do
    [[ -n "$line" ]] && RULE_TARGETS+=("$line")
done < <("$KB_BIN" rules --targets 2>/dev/null)
if [[ ${#RULE_TARGETS[@]} -eq 0 ]]; then
    RULE_TARGETS=("CLAUDE.md|append" "AGENTS.md|append" ".github/copilot-instructions.md|append" \
                  ".github/instructions/kb.instructions.md|copilot-fm" \
                  ".cursor/rules/knowledge-db.mdc|cursor-fm" ".windsurfrules|append")
fi

CANONICAL_BLOCK="$("$KB_BIN" rules --plant)"

emit_frontmatter() {
    case "$1" in
        copilot-fm) printf -- "---\napplyTo: '**'\n---\n\n" ;;
        cursor-fm)  printf -- "---\ndescription: Knowledge database hard rules (durable project memory)\nalwaysApply: true\n---\n\n" ;;
    esac
}

# Replace the marker-delimited region of a file with the canonical block.
replant() {
    FILE="$1" BLOCK="$CANONICAL_BLOCK" START="$MARKER" END="$MARKER_END" python3 - <<'EOF'
import os
path = os.environ["FILE"]
block, start, end = os.environ["BLOCK"], os.environ["START"], os.environ["END"]
with open(path, encoding="utf-8") as fh:
    text = fh.read()
head, rest = text.split(start, 1)
_, tail = rest.split(end, 1)
if not block.endswith("\n"):
    block += "\n"
if tail.startswith("\n"):
    tail = tail[1:]
with open(path, "w", encoding="utf-8") as fh:
    fh.write(head + block + tail)
EOF
}

planted_matches() {
    FILE="$1" BLOCK="$CANONICAL_BLOCK" START="$MARKER" END="$MARKER_END" python3 - <<'EOF'
import os, sys
path = os.environ["FILE"]
block, start, end = os.environ["BLOCK"], os.environ["START"], os.environ["END"]
try:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
except (OSError, UnicodeDecodeError):
    sys.exit(2)
if start not in text or end not in text:
    sys.exit(2)                       # not planted at all
current = start + text.split(start, 1)[1].split(end, 1)[0] + end
sys.exit(0 if current.strip() == block.strip() else 1)   # 1 = stale
EOF
}

if [[ ! -f "$KB_DIR/AGENT.md" ]] && $CHECK_ONLY; then
    note_missing "agent hard rules ($KB_NAME/AGENT.md)"
fi

NEW_PLANTS=0
RULES_MISSING=()
RULES_STALE=()
if ! $WANT_RULE_FILES; then
    note_ok "agent hard rules (declined)"
else
    for target in "${RULE_TARGETS[@]}"; do
        REL="${target%%|*}"
        KIND="${target##*|}"
        FILE="$REPO_ROOT/$REL"
        if [[ -f "$FILE" ]]; then
            planted_matches "$FILE"
            case $? in
                0) continue ;;                      # up to date
                1) if $CHECK_ONLY; then
                       RULES_STALE+=("$REL")
                   else
                       replant "$FILE"
                       note_changed "agent hard rules replanted in $REL (was stale)"
                       NEW_PLANTS=$((NEW_PLANTS + 1))
                   fi
                   continue ;;
            esac
        fi
        if $CHECK_ONLY; then
            RULES_MISSING+=("$REL")
        else
            mkdir -p "$(dirname "$FILE")"
            if [[ ! -f "$FILE" ]]; then
                { emit_frontmatter "$KIND"; printf '%s\n' "$CANONICAL_BLOCK"; } > "$FILE"
            else
                { printf "\n"; printf '%s\n' "$CANONICAL_BLOCK"; } >> "$FILE"
            fi
            note_changed "agent hard rules planted in $REL"
            NEW_PLANTS=$((NEW_PLANTS + 1))
        fi
    done

    if [[ ${#RULES_MISSING[@]} -gt 0 ]]; then
        note_missing "agent hard rules (HARD RULE block absent from: ${RULES_MISSING[*]})"
    fi
    if [[ ${#RULES_STALE[@]} -gt 0 ]]; then
        note_missing "agent hard rules stale (rerun install.sh to replant: ${RULES_STALE[*]})"
    fi
    if [[ ${#RULES_MISSING[@]} -eq 0 && ${#RULES_STALE[@]} -eq 0 && $NEW_PLANTS -eq 0 ]]; then
        note_ok "agent hard rules (all ${#RULE_TARGETS[@]} runtime files current, referencing $KB_NAME/AGENT.md)"
    fi
fi

# ---------------------------------------------------------------- local mode

if [[ "$MODE" == "local" ]] && ! $CHECK_ONLY && is_git_repo; then
    GITIGNORE="$REPO_ROOT/.gitignore"
    if [[ -f "$GITIGNORE" ]] && grep -qxF "$KB_NAME/" "$GITIGNORE"; then
        note_ok "local mode ($KB_NAME/ already gitignored)"
    else
        printf '\n# Knowledge Database (local memory, not committed)\n%s/\n' "$KB_NAME" >> "$GITIGNORE"
        note_changed "local mode: $KB_NAME/ added to .gitignore"
    fi
fi

# ---------------------------------------------------------------- finish

if ! $CHECK_ONLY; then
    save_install_choices
    if [[ $NEW_PLANTS -gt 0 ]]; then
        note "NOTE: the planted rule files load at each agent's NEXT session start."
        note "      Claude Code snapshots hooks when a session starts, so the hooks in"
        note "      .claude/settings.json apply to NEW sessions — in this one, review them"
        note "      with /hooks or restart Claude Code."
    fi
    if [[ "$MODE" == "workspace" && -z "${NESTED_REPOS// /}" ]]; then
        note "NOTE: workspace mode with no nested repo wired — code commits in your app"
        note "      repo are NOT gated. Re-run install.sh --wizard after cloning it here."
    fi
fi

print_report
if $CHECK_ONLY && [[ ${#MISSING[@]} -gt 0 ]]; then
    exit 1
fi
exit 0
