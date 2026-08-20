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
