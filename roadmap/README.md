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

**Phase 1: Local Tooling** (in progress)

Tools being built:
- `kb-ingest` — Parse text/transcripts into KB entries
- `kb-discover` — Scan codebase, generate exploration entries

## Quick Links

- [Phase 1: Local Tooling](phases/phase-1-local-tooling.md)
- [Phase 2: Git Hooks](phases/phase-2-git-hooks.md)
- [Phase 3: GitHub Action](phases/phase-3-github-action.md)
