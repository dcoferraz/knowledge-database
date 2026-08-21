# Phase 2: Git Hooks

**Status**: Planned
**Goal**: Automatic KB prompts integrated into git workflow
**Depends on**: Phase 1 complete

---

## Overview

Integrate KB awareness into git workflow:
- Detect KB-worthy changes at commit/push time
- Suggest entry creation before substantial work is lost
- Warn when large changes have no KB documentation

---

## Hooks

### 1. `post-commit` — Suggest Recording

**Trigger**: After each commit

**Behavior**:
1. Analyze commit diff
2. Score "KB-worthiness":
   - Multi-file changes: +2
   - New patterns/abstractions: +3
   - Error handling changes: +2
   - Config/env changes: +1
   - Test-only changes: -2
3. If score > threshold:
   - Show: "This commit looks KB-worthy. Run `kb-suggest` to create entry?"
   - Non-blocking (just a reminder)

**Config**:
```bash
# .kb-config
KB_POST_COMMIT_THRESHOLD=3
KB_POST_COMMIT_ENABLED=true
```

---

### 2. `pre-push` — Warn on Undocumented Work

**Trigger**: Before push to remote

**Behavior**:
1. Scan commits being pushed
2. Calculate aggregate KB-worthiness
3. Check if any KB entries created in same timeframe
4. If high-worth + no entries:
   - Warning: "Pushing substantial changes with no KB entries. Continue? [y/N]"
   - Bypassable (not a blocker)

---

### 3. `prepare-commit-msg` — Auto-Tag (Optional)

**Trigger**: When composing commit message

**Behavior**:
- If commit touches files in known KB areas, suggest tags
- Example: Changing `src/auth/*` → suggest `[area:auth]` prefix

---

## Installation

```bash
./scripts/install-kb-hooks.sh

# Or selective
./scripts/install-kb-hooks.sh --only post-commit
```

Hooks installed to `.git/hooks/`, don't overwrite existing hooks (chain them).

---

## Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| M2.1 | KB-worthiness scoring algorithm | 📋 Planned |
| M2.2 | post-commit hook implementation | 📋 Planned |
| M2.3 | pre-push hook implementation | 📋 Planned |
| M2.4 | Hook installer script | 📋 Planned |
| M2.5 | Config file support (`.kb-config`) | 📋 Planned |

---

## Success Criteria

Phase 2 complete when:
- [ ] Developer gets helpful (non-annoying) prompts after meaningful commits
- [ ] Team can catch "should have documented this" before it hits remote
- [ ] Hooks are optional and easily disabled
