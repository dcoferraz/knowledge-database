# Roadmap Folder — Agent Instructions

This folder contains the evolution roadmap for Knowledge Database.

## What This Folder Is For

- Future feature planning
- Architecture Decision Records (ADRs)
- Phase-by-phase implementation specs
- NOT for runtime KB entries (those go in `knowledge-db/`)

## Maintenance Rules

1. **New features** → Add to appropriate phase doc or create new phase
2. **Architecture decisions** → Create ADR in `decisions/` using format `NNN-short-title.md`
3. **Completed items** → Mark with ✅ and date, don't delete
4. **Superseded plans** → Keep for history, add "SUPERSEDED BY: [link]" header

## ADR Format

```markdown
# NNN: Title

**Status**: proposed | accepted | deprecated | superseded
**Date**: YYYY-MM-DD
**Supersedes**: (if applicable)
**Superseded by**: (if applicable)

## Context
What is the issue?

## Decision
What did we decide?

## Consequences
What are the trade-offs?
```

## When Updating Roadmap

- Check if feature already planned (search phases/)
- Update phase status when items complete
- Link from main project README when shipping new capabilities
