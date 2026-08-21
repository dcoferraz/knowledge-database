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
│  1. READ FIRST   →  Check INDEX.md + canonical docs     │
│  2. DO THE WORK  →  Explore or implement                │
│  3. WRITE BACK   →  Run checklist, update index         │
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

## Enforcement Mechanisms

The KB isn't opt-in — it enforces **seven mechanisms** on every non-trivial task:

| # | Mechanism | What It Does |
|---|-----------|--------------|
| 1 | **Always-On** | Mandatory on every task, not triggered by phrases |
| 2 | **Routing to Canonical Docs** | INDEX.md points to external sources, not just entries |
| 3 | **Lock-Step Invariants** | Paired artifacts (schema + doc) must change together |
| 4 | **Source-of-Truth Hierarchy** | Explicit ranking when sources disagree |
| 5 | **Verified ↔ Evidence** | `verified` requires actual proof in Verification block |
| 6 | **Tiered Memory Scopes** | User / repo / session separation |
| 7 | **Maintenance Discipline** | Dedup, tag reuse, fix wrong entries |

See [CLAUDE.md](CLAUDE.md) for full enforcement rules.

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

### What Gets Created

```
knowledge-db/
├── INDEX.md           ← Search here first (Ready-Answer Table + catalog)
├── _TEMPLATE.md       ← Copy to create new entries
├── explorations/      ← "How does X work?"
├── solutions/         ← "How we built Y"
├── errors/            ← "Bug Z: symptom → root cause → fix → prevention"
└── decisions/         ← "Why we chose A over B"
```

---

## CLI Tools

```bash
# Initialize KB structure
./scripts/init-knowledge-db.sh

# Ingest text/transcripts into KB entries
./scripts/kb-ingest --input notes.txt --auto
cat conversation.txt | ./scripts/kb-ingest --bucket errors

# Discover codebase boundaries
./scripts/kb-discover ./legacy-app
./scripts/kb-discover ./src --summary

# Lint KB for issues
./scripts/kb-lint
./scripts/kb-lint --fix
```

---

## How It Works

### 1. Agent Checks KB First

Before exploring any topic, agent searches `INDEX.md`:

```markdown
## Ready-Answer Table
| Topic | Canonical Source | Last Verified |
|-------|------------------|---------------|
| Auth flow | explorations/2026-08-15-auth-middleware.md | 2026-08-15 |

## Explorations
| Date | Title | Status | Entry |
|------|-------|--------|-------|
| 2026-08-15 | Auth middleware chain | verified | [→](explorations/...) |
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

## Verification
$ npm test -- --grep "auth"
PASS src/middleware/auth.test.ts (3 tests)
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

## Status Rules

| Status | Meaning | Requirements |
|--------|---------|--------------|
| `verified` | Proven true | Verification block with ACTUAL PROOF |
| `tentative` | Best understanding | Any unsourced claim |
| `superseded` | Outdated | `related:` MUST link replacement |

**No proof = no verified.** The Verification block must contain command + output, test result, or screenshot.

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
├── CLAUDE.md                  ← HARD RULE + enforcement mechanisms
├── .claude-plugin/
│   └── marketplace.json       ← Plugin marketplace metadata
├── knowledge-database/
│   └── SKILL.md               ← Skill definition
├── scripts/
│   ├── init-knowledge-db.sh   ← Initialize KB structure
│   ├── kb-ingest              ← Parse text into KB entries
│   ├── kb-discover            ← Scan codebase for boundaries
│   └── kb-lint                ← Lint KB for issues
├── .kb-templates/
│   ├── README.md
│   ├── INDEX.md
│   └── _TEMPLATE.md
└── roadmap/                   ← Future evolution plans
    ├── README.md
    └── phases/
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

## Roadmap

See [roadmap/](roadmap/) for planned evolution:

- **Phase 1** (current): Local CLI tooling (`kb-ingest`, `kb-discover`, `kb-lint`)
- **Phase 2**: Git hooks for automatic KB prompts
- **Phase 3**: GitHub Action for team-shared KB

---

## FAQ

**Q: How is this different from just writing notes in CLAUDE.md?**

Structured buckets + index + templates + enforcement = searchable, maintainable, scalable. Notes become a mess at 20+ entries.

**Q: Won't this slow down simple tasks?**

The HARD RULE only applies to "non-trivial" tasks (multi-file investigation, debugging, decisions). One-liners skip it.

**Q: What if an entry becomes outdated?**

Mark as `superseded`, link to replacement. History preserved, readers directed to current truth.

**Q: What if I'm not sure if something is verified?**

If in doubt, use `tentative`. Upgrade to `verified` only when you have actual proof in the Verification block.

---

## Contributing

PRs welcome. Key areas:
- More agent integrations
- Better templates for specific domains
- Tooling improvements (kb-ingest, kb-discover, kb-lint)
- Phase 2/3 implementation (hooks, GitHub Action)

---

## License

MIT
