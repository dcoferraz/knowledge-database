#!/bin/bash
# Get or refresh a knowledge-db/ in the current repo, from anywhere.
#
# No KB yet  -> scaffold one, then run the setup wizard.
# KB present -> upgrade its tooling in place (entries and config untouched).
#
# The upgrade branch runs the NEW tool against the OLD KB folder, which is the
# only way a KB installed before v0.7.0 can be updated: its own `bin/kb` has no
# `upgrade` subcommand yet, so it cannot update itself.
#
# The published plugin ships this skill only — not the 1000-line CLI, the
# templates or the installer — so before v0.7.0 the skill's bootstrap step
# ("copy the full skeleton") had no source to copy from. This script finds a
# real source and uses it:
#
#   1. the plugin's own marketplace clone (already on disk after
#      `claude plugin marketplace add dcoferraz/knowledge-database`)
#   2. a sibling checkout of the repo
#   3. a shallow clone into a temp dir (needs network, last resort)
#
# Then it scaffolds the KB and hands over to the installer, which asks how you
# want to use it (in-repo / workspace / local) when run interactively.
#
# Usage: bootstrap.sh [KB_DIR] [--yes] [--no-install] [--dry-run]

set -uo pipefail

KB_DIR="knowledge-db"
INSTALL=true
DRY_RUN=false
INSTALL_ARGS=()
UPGRADE_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --no-install) INSTALL=false; UPGRADE_ARGS+=("--no-install") ;;
        --dry-run)    DRY_RUN=true; UPGRADE_ARGS+=("--dry-run") ;;
        --yes|-y)     INSTALL_ARGS+=("--yes") ;;
        --mode=*)     INSTALL_ARGS+=("$arg") ;;
        -*)           echo "bootstrap.sh: unknown option '$arg'" >&2; exit 2 ;;
        *)            KB_DIR="$arg" ;;
    esac
done

REPO="https://github.com/dcoferraz/knowledge-database.git"
SRC=""
CANDIDATES=(
    "${CLAUDE_PLUGIN_ROOT:-}/.."
    "$HOME/.claude/plugins/marketplaces/knowledge-database"
    "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
    "$(pwd)/../knowledge-database"
)
# Newest candidate wins, not the first: a plugin marketplace clone pinned to an
# old commit must never shadow a current checkout when the intent is "update".
src_version() {
    [[ -f "$1/knowledge-db/bin/kb" ]] || return 1
    sed -n 's/^KB_TOOL_VERSION[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' \
        "$1/knowledge-db/bin/kb" | head -1
}
SRC_VERSION=""
for candidate in "${CANDIDATES[@]}"; do
    [[ -n "$candidate" && -f "$candidate/scripts/init-knowledge-db.sh" \
       && -f "$candidate/knowledge-db/bin/kb" ]] || continue
    CANDIDATE_VERSION="$(src_version "$candidate" || true)"
    [[ -n "$CANDIDATE_VERSION" ]] || continue
    if [[ -z "$SRC_VERSION" ]] || \
       [[ "$(printf '%s\n%s\n' "$SRC_VERSION" "$CANDIDATE_VERSION" | sort -V | tail -1)" \
          == "$CANDIDATE_VERSION" ]]; then
        SRC="$(cd "$candidate" && pwd)"
        SRC_VERSION="$CANDIDATE_VERSION"
    fi
done

if [[ -z "$SRC" ]]; then
    TMP="$(mktemp -d)"
    echo "bootstrap: no local checkout found; cloning $REPO" >&2
    if ! git clone --depth 1 -q "$REPO" "$TMP/knowledge-database"; then
        echo "bootstrap: clone failed. Clone the repo manually, then run" >&2
        echo "           <checkout>/scripts/init-knowledge-db.sh $KB_DIR" >&2
        exit 1
    fi
    SRC="$TMP/knowledge-database"
fi

# --- already installed: upgrade instead of scaffolding ---------------------
if [[ -f "$KB_DIR/kb.config.json" ]]; then
    INSTALLED_VERSION="$(sed -n 's/^KB_TOOL_VERSION[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' \
        "$KB_DIR/bin/kb" 2>/dev/null | head -1)"
    # The source must be able to perform the upgrade: `kb upgrade` only exists
    # from v0.7.0 on, and a source at or behind the install has nothing to give.
    if [[ -n "$SRC_VERSION" && -n "$INSTALLED_VERSION" && \
          "$(printf '%s\n%s\n' "$SRC_VERSION" "$INSTALLED_VERSION" | sort -V | tail -1)" \
          == "$INSTALLED_VERSION" && "$SRC_VERSION" != "$INSTALLED_VERSION" ]]; then
        echo "bootstrap: $KB_DIR/ is $INSTALLED_VERSION; the newest source found is $SRC_VERSION"
        echo "           ($SRC) — nothing to upgrade from. Pull that checkout, or clone"
        echo "           https://github.com/dcoferraz/knowledge-database and pass it as the source."
        exit 0
    fi
    if ! grep -q '"upgrade"' "$SRC/knowledge-db/bin/kb"; then
        echo "bootstrap: source $SRC ($SRC_VERSION) predates \`kb upgrade\` — follow UPGRADING.md" >&2
        exit 1
    fi
    echo "bootstrap: $KB_DIR/ already exists ($INSTALLED_VERSION) — upgrading from $SRC ($SRC_VERSION)"
    if [[ ${#UPGRADE_ARGS[@]} -gt 0 ]]; then
        exec "$SRC/knowledge-db/bin/kb" --kb-dir "$KB_DIR" upgrade --source "$SRC" "${UPGRADE_ARGS[@]}"
    fi
    exec "$SRC/knowledge-db/bin/kb" --kb-dir "$KB_DIR" upgrade --source "$SRC"
fi

$DRY_RUN && { echo "bootstrap: no $KB_DIR/ yet — would scaffold it from $SRC"; exit 0; }

echo "bootstrap: scaffolding $KB_DIR/ from $SRC"
# Older checkouts (< v0.7.0) do not know --no-install and would read it as the
# target folder name, so only pass it when the source understands it.
if grep -q -- "--no-install" "$SRC/scripts/init-knowledge-db.sh"; then
    "$SRC/scripts/init-knowledge-db.sh" "$KB_DIR" --no-install || exit 1
else
    "$SRC/scripts/init-knowledge-db.sh" "$KB_DIR" || exit 1
fi

if $INSTALL; then
    if [[ ${#INSTALL_ARGS[@]} -gt 0 ]]; then
        "$KB_DIR/install.sh" "${INSTALL_ARGS[@]}"
    else
        "$KB_DIR/install.sh"
    fi
else
    echo "bootstrap: skipped enforcement install (run $KB_DIR/install.sh when ready)"
fi
