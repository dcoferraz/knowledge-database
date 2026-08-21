#!/bin/bash
# Initialize Knowledge Database structure
# Safe to run multiple times - never overwrites existing files

set -e

KB_DIR="${1:-knowledge-db}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$REPO_ROOT/.kb-templates"

echo "Initializing Knowledge Database in '$KB_DIR/'..."

# Create folder structure
mkdir -p "$KB_DIR/explorations"
mkdir -p "$KB_DIR/solutions"
mkdir -p "$KB_DIR/errors"
mkdir -p "$KB_DIR/decisions"

# Add .gitkeep to empty folders
for dir in explorations solutions errors decisions; do
    touch "$KB_DIR/$dir/.gitkeep"
done

# Copy templates (don't overwrite existing)
for file in README.md INDEX.md _TEMPLATE.md; do
    if [ ! -f "$KB_DIR/$file" ]; then
        cp "$TEMPLATES_DIR/$file" "$KB_DIR/$file"
        echo "  Created $KB_DIR/$file"
    else
        echo "  Skipped $KB_DIR/$file (already exists)"
    fi
done

# Auto-update .gitignore if in a git repo
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

    # If we found a git repo and .gitignore handling makes sense
    if [[ -n "$gitignore_path" ]]; then
        local ignore_entry="$kb_name/"

        # Check if already in .gitignore (detect-before-append)
        if [[ -f "$gitignore_path" ]] && grep -qxF "$ignore_entry" "$gitignore_path" 2>/dev/null; then
            echo "  .gitignore already contains $ignore_entry"
        else
            # Append to .gitignore
            echo "" >> "$gitignore_path"
            echo "# Knowledge Database (local memory, not committed)" >> "$gitignore_path"
            echo "$ignore_entry" >> "$gitignore_path"
            echo "  Added $ignore_entry to .gitignore"
        fi
    fi
}

# Only update gitignore if KB_DIR is relative (installing in existing project)
if [[ ! "$KB_DIR" = /* ]]; then
    update_gitignore
fi

echo ""
echo "Knowledge Database initialized."
echo ""
echo "Structure:"
echo "  $KB_DIR/"
echo "    README.md      - Rules and usage"
echo "    INDEX.md       - Entry catalog (search here first)"
echo "    _TEMPLATE.md   - Copy this to create entries"
echo "    explorations/  - 'What is true'"
echo "    solutions/     - 'What we did'"
echo "    errors/        - 'What broke + fix'"
echo "    decisions/     - 'Why we chose X'"
echo ""
echo "Next: Read CLAUDE.md for the HARD RULE pattern."
