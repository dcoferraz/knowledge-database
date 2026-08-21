---
title: CLI Tool Architecture
type: exploration
status: verified
date: 2026-08-20
tags: [area:tooling, layer:cli]
sources:
  - scripts/kb-ingest:1-50
  - scripts/kb-discover:1-60
  - scripts/kb-lint:1-70
  - scripts/init-knowledge-db.sh:1-40
related:
  - decisions/2026-08-20-bash-for-cli-tools.md
---

## Summary

Four CLI tools form the KB tooling layer: init, ingest, discover, lint. All bash scripts with no external dependencies beyond standard Unix tools.

## Context / Question

Understanding how the CLI tools work together and what each one does.

## Findings / What We Did

### Tool Overview

| Tool | Purpose | Input | Output |
|------|---------|-------|--------|
| `init-knowledge-db.sh` | Create KB structure | Target directory | INDEX.md + buckets |
| `kb-ingest` | Parse text into entries | stdin or file | KB entry file |
| `kb-discover` | Scan codebase | Directory path | Exploration entry |
| `kb-lint` | Validate KB | KB directory | Error/warning report |

### init-knowledge-db.sh (scripts/init-knowledge-db.sh:10-35)

Creates the KB folder structure from templates in `.kb-templates/`:
- Copies INDEX.md, README.md, _TEMPLATE.md
- Creates four bucket directories
- Adds .gitkeep files to empty buckets

Idempotent: running twice on same directory is safe.

### kb-ingest (scripts/kb-ingest:20-100)

Parses unstructured text (meeting notes, transcripts, error logs) into KB entries:
- `--auto` flag triggers bucket detection via keyword analysis
- Error signals: "Error:", "Exception:", "failed", "stack trace"
- Exploration signals: "How does", "What is", "Where is"
- Decision signals: "We chose", "decided to", "option"

Uses heredoc templating to generate YAML front-matter.

### kb-discover (scripts/kb-discover:30-150)

Scans a codebase directory and generates an exploration entry:
- Detects project type (package.json, go.mod, Cargo.toml, etc.)
- Finds entry points, routes, models, services
- Identifies external integrations (database, Redis, queues)
- `--summary` flag outputs brief overview instead of full entry

### kb-lint (scripts/kb-lint:60-250)

Validates KB health with 7 checks:
1. Entries missing from INDEX.md
2. Entries missing sources
3. Invalid status values
4. verified status without Verification block
5. superseded status without related link
6. Error entries missing required sections
7. Tag hygiene (single-use tags = potential typos)

`--fix` flag auto-repairs:
- Missing INDEX.md rows (adds them)
- verified without proof (downgrades to tentative)

## Verification

```bash
$ ./tests/run-tests.sh
KB Tools Test Suite
Testing init-knowledge-db.sh
  creates KB structure... PASS
  ...
Testing kb-lint
  --fix adds missing INDEX entry... PASS
  --fix downgrades to tentative... PASS
  ...
Results: 23/23 passed
All tests passed
```
