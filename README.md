# Knowledge Database

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-blueviolet)](https://claude.ai/claude-code)
[![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-compatible-green)](https://github.com/features/copilot)

**Stop re-investigating bugs you already fixed. Stop re-exploring code you already understood.**

A durable memory system for AI coding agents that compounds knowledge across sessions.

---

## The Problem

Without persistent memory, every AI session starts from zero:

```
Monday:    "How does the auth middleware work?" → 20 min investigation
Tuesday:   "How does the auth middleware work?" → 20 min investigation (again)
Wednesday: Same bug you fixed last week? Debug from scratch.
```

**You're paying tokens to rediscover the same things over and over.**

---

## The Solution

Knowledge Database creates a structured memory that agents read *before* exploring:

```
┌─────────────────────────────────────────────────────────┐
│                    EVERY TASK                           │
├─────────────────────────────────────────────────────────┤
│  1. READ FIRST   →  Check knowledge-db/INDEX.md         │
│  2. DO THE WORK  →  Explore or implement                │
│  3. WRITE BACK   →  Record findings, update index       │
└─────────────────────────────────────────────────────────┘
```

**Result:** Investigations compound. Bugs stay fixed. Onboarding is instant.

---

## Before & After

| | Without KB | With KB |
|---|---|---|
| Same question twice | 20 min each time | 30 sec (read entry) |
| Bug reintroduced | Debug from scratch | Entry shows exact fix |
| New team member | "Ask Sarah, she knows" | Self-service docs |
| Context across sessions | Lost | Permanent |

---

## Quick Start

### Install (pick one)

```bash
# Claude Plugin Marketplace
claude plugin marketplace add dcoferraz/knowledge-database

# Manual
git clone https://github.com/dcoferraz/knowledge-database.git
cp -r knowledge-database/knowledge-database ~/.claude/skills/

# Standalone (any agent)
git clone https://github.com/dcoferraz/knowledge-database.git
./scripts/init-knowledge-db.sh
```

### Use

Say any of:
- *"bootstrap knowledge database"*
- *"before exploring, check KB"*
- *"record what I learned"*
- *"log this bug and fix"*

### What Gets Created

```
knowledge-db/
├── INDEX.md           ← Search here first (catalog of all entries)
├── _TEMPLATE.md       ← Copy to create new entries
├── explorations/      ← "How does X work?"
├── solutions/         ← "How we built Y"
├── errors/            ← "Bug Z: symptom → root cause → fix"
└── decisions/         ← "Why we chose A over B"
```

---

## How It Works

### 1. Agent Checks KB First

Before exploring any topic, the agent searches `INDEX.md`:

```markdown
## Explorations
| Date | Title | Status | Entry |
|------|-------|--------|-------|
| 2026-08-15 | Auth middleware chain | verified | [→](explorations/2026-08-15-auth-middleware.md) |
```

If a **verified** entry exists → use it, skip investigation.

### 2. New Findings Get Recorded

After any non-trivial work, agent creates an entry:

```yaml
---
title: Auth middleware chain
type: exploration
status: verified
date: 2026-08-15
tags: [area:auth, layer:middleware]
sources:
  - src/middleware/auth.ts:42-89
---

## Summary
Auth flows through 3 middleware: session → jwt → rbac.

## Findings
The chain is defined in `src/middleware/auth.ts:45`...
```

### 3. Errors Capture Prevention

`errors/` entries require all four sections:

```markdown
## Symptom
TypeError: Cannot read property 'user' of undefined

## Root Cause
Session middleware skipped on /api/webhook routes (src/app.ts:23)

## Fix
Added explicit session check in webhook handler (src/routes/webhook.ts:15)

## Prevention
All routes must validate session presence before accessing req.user
```

**This bug will never be reintroduced** — the agent reads this before touching auth code.

---

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
  - errors/2026-08-10-session-bug.md
---
```

**Status meanings:**
- `verified` — Proven true (tests pass, output confirmed)
- `tentative` — Best understanding, needs confirmation
- `superseded` — Outdated, links to replacement

---

## Why Four Buckets?

| Bucket | Question it answers | Example |
|--------|---------------------|---------|
| `explorations/` | "How does X work?" | Auth flow, data pipeline, API structure |
| `solutions/` | "How did we build Y?" | Feature implementation, refactor approach |
| `errors/` | "What broke and how to fix?" | Stack traces, root causes, fixes |
| `decisions/` | "Why did we choose A?" | Tech choices, architecture tradeoffs |

One entry per task. File under dominant intent, cross-link the rest.

---

## Repository Structure

```
knowledge-database/
├── README.md                  ← You are here
├── LICENSE
├── CLAUDE.md                  ← HARD RULE (copy to your project)
├── .claude-plugin/
│   └── marketplace.json       ← Plugin marketplace metadata
├── knowledge-database/
│   └── SKILL.md               ← Skill definition
├── scripts/
│   └── init-knowledge-db.sh   ← Standalone bootstrap
└── .kb-templates/
    ├── README.md
    ├── INDEX.md
    └── _TEMPLATE.md
```

---

## Compatibility

| Agent | Install Method |
|-------|----------------|
| Claude Code | Plugin marketplace or manual skill |
| GitHub Copilot | Copy CLAUDE.md → `.github/copilot-instructions.md` |
| Cursor | Copy CLAUDE.md → `.cursor/rules/` |
| Any other | Run `init-knowledge-db.sh` + add HARD RULE to agent config |

---

## FAQ

**Q: How is this different from just writing notes in CLAUDE.md?**

Structured buckets + index + templates = searchable, maintainable, scalable. Notes become a mess at 20+ entries.

**Q: Won't this slow down simple tasks?**

The HARD RULE only applies to "non-trivial" tasks (multi-file investigation, debugging, decisions). One-liners skip it.

**Q: What if an entry becomes outdated?**

Mark as `superseded`, link to replacement. History preserved, readers directed to current truth.

---

## Contributing

PRs welcome. Key areas:
- More agent integrations
- Better templates for specific domains
- Tooling for KB maintenance

---

## License

MIT
