# Phase 3: GitHub Action — Team Knowledge Service

**Status**: Planned
**Goal**: Shared KB across team/org via GitHub infrastructure
**Depends on**: Phase 2 stable

---

## Overview

Evolve from local single-user KB to team-shared knowledge:
- Auto-generate KB entries from merged PRs
- Shared KB repository (private)
- Cross-repo knowledge search
- Team onboarding acceleration

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Team Repositories                         │
├─────────────┬─────────────┬─────────────┬─────────────────────┤
│   repo-a    │   repo-b    │   repo-c    │       ...           │
│  (local KB) │  (local KB) │  (local KB) │                     │
└──────┬──────┴──────┬──────┴──────┬──────┴─────────────────────┘
       │             │             │
       │  PR Merge   │  PR Merge   │  PR Merge
       ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Action: kb-sync                          │
│  - Parse PR description + diff                               │
│  - Generate KB entry draft                                   │
│  - Open PR to shared KB repo                                 │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│              Shared KB Repository (private)                  │
│  knowledge-db-team/                                          │
│  ├── INDEX.md          (cross-repo index)                   │
│  ├── by-repo/          (repo-specific entries)              │
│  │   ├── repo-a/                                            │
│  │   ├── repo-b/                                            │
│  │   └── repo-c/                                            │
│  └── shared/           (org-wide patterns)                  │
│      ├── explorations/                                      │
│      ├── solutions/                                         │
│      └── errors/                                            │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│              Consumers                                       │
│  - New developer onboarding (read shared KB)                │
│  - AI agents (query before exploring)                       │
│  - Search API (future)                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. GitHub Action: `kb-auto-entry`

**Trigger**: PR merged to main

**Behavior**:
1. Extract from PR:
   - Title + description
   - Files changed
   - Linked issues
   - Review comments (especially "why" explanations)
2. Score KB-worthiness (same algorithm as hooks)
3. If worthy:
   - Generate draft KB entry
   - Open PR to shared KB repo
   - Assign original PR author as reviewer

**Workflow file**:
```yaml
name: KB Auto Entry
on:
  pull_request:
    types: [closed]
    branches: [main]

jobs:
  kb-entry:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - uses: dcoferraz/kb-auto-entry@v1
        with:
          kb-repo: org/knowledge-db-team
          token: ${{ secrets.KB_PAT }}
```

---

### 2. Shared KB Repository Structure

```
knowledge-db-team/
├── INDEX.md                 # Master index (auto-generated)
├── CLAUDE.md                # Agent instructions for shared KB
├── by-repo/
│   ├── repo-a/
│   │   ├── INDEX.md         # Repo-specific index
│   │   ├── explorations/
│   │   ├── solutions/
│   │   └── errors/
│   └── repo-b/
│       └── ...
├── shared/                  # Org-wide knowledge
│   ├── explorations/        # Cross-cutting patterns
│   ├── solutions/           # Reusable approaches
│   ├── errors/              # Common gotchas
│   └── decisions/           # Org standards
└── .github/
    └── workflows/
        └── index-rebuild.yml  # Regenerate INDEX.md on entry merge
```

---

### 3. Search API (Future Enhancement)

Simple read-only API for agents to query KB before exploring:

```bash
# Query shared KB
curl "https://kb.example.com/search?q=auth+middleware&repo=repo-a"

# Response
{
  "entries": [
    {
      "title": "Auth middleware chain",
      "status": "verified",
      "path": "by-repo/repo-a/explorations/2026-08-15-auth-middleware.md",
      "summary": "Auth flows through 3 middleware: session → jwt → rbac."
    }
  ]
}
```

Implementation options:
- **Simple**: GitHub API + raw file search
- **Medium**: GitHub Pages + static JSON index
- **Full**: Serverless function + vector embeddings

---

## Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| M3.1 | GitHub Action: PR → KB entry draft | 📋 Planned |
| M3.2 | Shared KB repo template | 📋 Planned |
| M3.3 | Index auto-generation workflow | 📋 Planned |
| M3.4 | Cross-repo search (basic) | 📋 Planned |
| M3.5 | Agent integration (CLAUDE.md pattern) | 📋 Planned |
| M3.6 | Search API (optional) | 📋 Planned |

---

## Hard Problems to Solve

### 1. Entry Quality
- Auto-generated entries may be low quality
- Solution: Human review required (PR to KB repo)

### 2. Staleness
- Entries become outdated as code evolves
- Solution: Link entries to source files, detect drift

### 3. Context Boundaries
- When is knowledge repo-specific vs org-wide?
- Solution: Start repo-specific, promote to shared manually

### 4. Retrieval Precision
- Wrong knowledge worse than no knowledge
- Solution: Strong verification requirements, `tentative` vs `verified`

### 5. Merge Conflicts
- Multiple PRs generating entries simultaneously
- Solution: Each entry = separate file, INDEX.md regenerated

---

## Success Criteria

Phase 3 complete when:
- [ ] Team has shared KB repository with entries from multiple repos
- [ ] New PRs auto-generate KB entry drafts (human-reviewed)
- [ ] New team member's agent can query shared KB on day 1
- [ ] Same bug fixed in repo-a prevents reintroduction in repo-b
