# Knowledge Database

A **durable memory pattern** for AI coding agents (Claude Code, GitHub Copilot, Cursor).

**Goal:** Never investigate the same thing twice. Never re-introduce a fixed bug.

## The Pattern

Every non-trivial task follows this loop:

```
READ FIRST  → Search knowledge-db/ before exploring
DO THE WORK → Explore or implement
WRITE BACK  → Record findings, update INDEX.md
```

## Install

### Option A: Claude Plugin Marketplace (recommended for Claude Code)

```bash
claude plugin marketplace add dcoferraz/knowledge-database
claude plugin install knowledge-database@dcoferraz-knowledge-database
```

### Option B: Manual skill install

```bash
git clone https://github.com/dcoferraz/knowledge-database.git
cp -r knowledge-database/knowledge-database ~/.claude/skills/
```

### Option C: Standalone (any project, any agent)

```bash
# Clone to your project
git clone https://github.com/dcoferraz/knowledge-database.git
cd knowledge-database

# Initialize the KB structure
./scripts/init-knowledge-db.sh

# Copy CLAUDE.md to your project root (or merge with existing)
cp CLAUDE.md your-project/
```

## Quick Start

After install, say any of:
- "bootstrap knowledge database"
- "initialize KB"
- "before exploring X, check knowledge base"

The skill creates:
```
knowledge-db/
  README.md        ← Rules and usage
  INDEX.md         ← Entry catalog (search here first)
  _TEMPLATE.md     ← Copy to create new entries
  explorations/    ← "What is true"
  solutions/       ← "What we did"
  errors/          ← "What broke + the fix"
  decisions/       ← "Why we chose X"
```

## Entry Format

```yaml
---
title: Short human title
type: exploration | solution | error | decision
status: verified | tentative | superseded
date: YYYY-MM-DD
tags: [area:auth, layer:service]
sources:
  - path/to/file.ts:42-56
related:
  - solutions/other-entry.md
---

## Summary
## Context / Question
## Findings / What We Did
## Verification
## Follow-ups
```

For `errors/` entries, also include:
- Symptom
- Root cause
- Fix
- Prevention

## Repository Structure

```
knowledge-database/
  README.md                    ← You are here
  LICENSE
  CLAUDE.md                    ← HARD RULE (copy to your project)
  .claude-plugin/
    marketplace.json           ← Plugin marketplace metadata
  knowledge-database/
    SKILL.md                   ← The skill definition
  scripts/
    init-knowledge-db.sh       ← Standalone bootstrap
  .kb-templates/
    README.md
    INDEX.md
    _TEMPLATE.md
```

## Why This Works

1. **Compound knowledge** — Investigations build on each other
2. **No duplicate work** — Check before exploring
3. **Bug prevention** — `errors/` entries prevent regression
4. **Onboarding** — New contributors learn from history
5. **AI context** — Agents read verified entries instead of re-exploring

## License

MIT
