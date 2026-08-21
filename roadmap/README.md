# Knowledge Database Roadmap

Future evolution of the Knowledge Database project.

## Purpose

Track planned features, architectural decisions, and evolution toward a team-scale knowledge service.

## Structure

```
roadmap/
├── README.md           ← You are here
├── CLAUDE.md           ← Agent instructions for this folder
├── phases/             ← Phase-by-phase implementation plans
│   ├── phase-1-local-tooling.md
│   ├── phase-2-git-hooks.md
│   └── phase-3-github-action.md
└── decisions/          ← Architecture Decision Records (ADRs)
    └── 001-transcript-parser-approach.md
```

## Current Phase

**Phase 1: Local Tooling** (Alpha Complete - 2026-08-20)

Implemented tools:
- `kb-ingest` — Parse text/transcripts into KB entries
- `kb-discover` — Scan codebase, generate exploration entries
- `kb-lint` — Validate KB health, auto-fix issues
- `init-knowledge-db.sh` — Initialize KB structure

## Not Yet Implemented

Features documented in CLAUDE.md but not yet automated:

| Feature | Status | Planned |
|---------|--------|---------|
| User-scope memory (`~/.kb/user/`) | Documented only | Phase 2 |
| Auto-append to agent configs | Documented only | Phase 2 |
| Lock-step validation (automated) | Manual checklist | Phase 2 |
| Git hooks for KB suggestions | Not started | Phase 2 |
| GitHub Action for shared KB | Not started | Phase 3 |

The "Eight Enforcement Mechanisms" in CLAUDE.md are currently **conventions** that agents follow by reading the file. They are not enforced by hooks or CI gates yet.

## Quick Links

- [Phase 1: Local Tooling](phases/phase-1-local-tooling.md)
- [Phase 2: Git Hooks](phases/phase-2-git-hooks.md)
- [Phase 3: GitHub Action](phases/phase-3-github-action.md)
