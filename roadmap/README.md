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

**Phase 1: Local Tooling** (Complete - 2026-08-20; superseded by v0.4.0-v0.9.1)

Implemented tools:
- `kb-ingest` — Parse text/transcripts into KB entries
- `kb-discover` — Scan codebase, generate exploration entries
- `kb-lint` — Validate KB health, auto-fix issues
- `init-knowledge-db.sh` — Initialize KB structure

## Status of the Original Gaps

This page used to list five gaps and say the enforcement did not exist. Four of
the five shipped; the table was months out of date.

| Feature | Status | Shipped in |
|---------|--------|------------|
| Auto-append to agent configs | **Done** — planted into 6 agent runtime files, replanted when stale | v0.5.0, refreshed v0.7.0 |
| Lock-step validation (automated) | **Done** — KB009, checked against the diff | v0.4.0 |
| Git hooks for KB suggestions | **Done** — `.githooks/pre-commit` runs `kb check --staged`; workspace mode also plants a hook inside each nested repo | v0.4.0, nested repos v0.7.0 |
| GitHub Action for shared KB | **Done** — `.github/workflows/kb-check.yml` | v0.4.0 |
| User-scope memory (`~/.kb/user/`) | Not started, and no longer obviously wanted | — |

The enforcement mechanisms in CLAUDE.md are **not** conventions. Fifteen rules
(KB001-KB015) are implemented in `knowledge-db/bin/kb check`, each with a
conformance fixture, and they reach the agent from six places: per-prompt rule
injection, Stop and SubagentStop hooks, the planted rule blocks, git pre-commit,
and CI. What cannot be checked mechanically is labelled "Guidance (not checked)"
in `knowledge-db/README.md` and carries no rule ID.

See [ENFORCEMENT.md](../ENFORCEMENT.md) for how the layers fit together and
[CHANGELOG.md](../CHANGELOG.md) for what landed when.

## Quick Links

- [Phase 1: Local Tooling](phases/phase-1-local-tooling.md)
- [Phase 2: Git Hooks](phases/phase-2-git-hooks.md)
- [Phase 3: GitHub Action](phases/phase-3-github-action.md)
