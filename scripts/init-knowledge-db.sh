#!/bin/bash
# Initialize Knowledge Database structure
# Safe to run multiple times - never overwrites existing files
#
# Usage: init-knowledge-db.sh [KB_DIR] [--local] [--yes] [--no-install]
#   KB_DIR       target folder (default: knowledge-db)
#   --local      gitignore the KB (personal memory, not committed).
#                DEFAULT IS TRACKED: a committed KB is the point — shared memory,
#                and the write-back trigger (KB011) only works when KB files
#                appear in diffs.
#   --yes        hand --yes to the installer (no wizard, default layers)
#   --no-install scaffold only; do not run <KB_DIR>/install.sh
#
# By default this hands over to <KB_DIR>/install.sh when it finishes, so every
# install path ends in the same setup wizard (interactive) or the same default
# install (piped/CI). Nothing is half-wired.

set -e

KB_DIR="knowledge-db"
LOCAL_KB=false
RUN_INSTALL=true
INSTALL_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --local)      LOCAL_KB=true ;;
        --no-install) RUN_INSTALL=false ;;
        --yes|-y)     INSTALL_ARGS+=("--yes") ;;
        --mode=*)     INSTALL_ARGS+=("$arg") ;;
        -*)           echo "init-knowledge-db.sh: unknown option '$arg'" >&2; exit 2 ;;
        *)            KB_DIR="$arg" ;;
    esac
done
$LOCAL_KB && INSTALL_ARGS+=("--mode=local")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$REPO_ROOT/.kb-templates"
SOURCE_KB="$REPO_ROOT/knowledge-db"

echo "Initializing Knowledge Database in '$KB_DIR/'..."

# Create folder structure
mkdir -p "$KB_DIR/explorations"
mkdir -p "$KB_DIR/solutions"
mkdir -p "$KB_DIR/errors"
mkdir -p "$KB_DIR/decisions"
mkdir -p "$KB_DIR/bin"

# Add .gitkeep to empty folders
for dir in explorations solutions errors decisions; do
    touch "$KB_DIR/$dir/.gitkeep"
done

# Copy templates (don't overwrite existing)
for file in README.md _TEMPLATE.md AGENT.md kb.config.json; do
    if [ ! -f "$KB_DIR/$file" ]; then
        cp "$TEMPLATES_DIR/$file" "$KB_DIR/$file"
        echo "  Created $KB_DIR/$file"
    else
        echo "  Skipped $KB_DIR/$file (already exists)"
    fi
done

# Copy enforcement tooling (generic, same for every repo)
for file in bin/kb install.sh; do
    if [ ! -f "$KB_DIR/$file" ]; then
        cp "$SOURCE_KB/$file" "$KB_DIR/$file"
        chmod +x "$KB_DIR/$file"
        echo "  Created $KB_DIR/$file"
    else
        echo "  Skipped $KB_DIR/$file (already exists)"
    fi
done

# Generate INDEX.md from front-matter (INDEX is build output, rule KB007)
if [ ! -f "$KB_DIR/INDEX.md" ]; then
    "$KB_DIR/bin/kb" --kb-dir "$KB_DIR" index
    echo "  Generated $KB_DIR/INDEX.md"
else
    echo "  Skipped $KB_DIR/INDEX.md (already exists)"
fi

# Optional: gitignore the KB (only with --local; tracked is the default)
update_gitignore() {
    local kb_name
    kb_name=$(basename "$KB_DIR")
    local gitignore_path

    # Find the repo root (where .git is)
    local dir
    dir=$(cd "$(dirname "$KB_DIR")" 2>/dev/null && pwd)
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]]; then
            gitignore_path="$dir/.gitignore"
            break
        fi
        dir=$(dirname "$dir")
    done

    if [[ -n "$gitignore_path" ]]; then
        local ignore_entry="$kb_name/"

        # Check if already in .gitignore (detect-before-append)
        if [[ -f "$gitignore_path" ]] && grep -qxF "$ignore_entry" "$gitignore_path" 2>/dev/null; then
            echo "  .gitignore already contains $ignore_entry"
        else
            echo "" >> "$gitignore_path"
            echo "# Knowledge Database (local memory, not committed)" >> "$gitignore_path"
            echo "$ignore_entry" >> "$gitignore_path"
            echo "  Added $ignore_entry to .gitignore (--local)"
        fi
    fi
}

if $LOCAL_KB && ! $RUN_INSTALL && [[ ! "$KB_DIR" = /* ]]; then
    update_gitignore
fi

RULE_RANGE="$("$KB_DIR/bin/kb" --kb-dir "$KB_DIR" rules --plant 2>/dev/null \
    | sed -n 's/.*Rule table (\(KB[0-9]*-KB[0-9]*\)).*/\1/p' | head -1)"
[[ -z "$RULE_RANGE" ]] && RULE_RANGE="the rule table"

echo ""
echo "Knowledge Database initialized."
echo ""
echo "Structure:"
echo "  $KB_DIR/"
echo "    README.md      - Rules $RULE_RANGE and usage"
echo "    AGENT.md       - Portable agent hard rules"
echo "    INDEX.md       - GENERATED catalog (search here first)"
echo "    kb.config.json - Vocabularies (single source of truth)"
echo "    bin/kb         - CLI: new / index / check / rules / discover / ingest"
echo "    install.sh     - Enforcement installer"
echo "    _TEMPLATE.md   - Entry format reference"
echo "    explorations/  - 'What is true'"
echo "    solutions/     - 'What we did'"
echo "    errors/        - 'What broke + fix'"
echo "    decisions/     - 'Why we chose X'"
echo ""

if $RUN_INSTALL; then
    echo "Wiring enforcement ($KB_DIR/install.sh)..."
    echo ""
    if [[ ${#INSTALL_ARGS[@]} -gt 0 ]]; then
        "$KB_DIR/install.sh" "${INSTALL_ARGS[@]}"
    else
        "$KB_DIR/install.sh"
    fi
else
    echo "Next: run $KB_DIR/install.sh to wire enforcement"
    echo "      (agent hooks + HARD RULE block + git pre-commit + CI)."
fi
