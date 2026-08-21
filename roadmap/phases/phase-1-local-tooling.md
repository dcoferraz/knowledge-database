# Phase 1: Local Tooling

**Status**: Alpha Complete (2026-08-20)
**Goal**: CLI tools for single-user KB population

---

## Overview

Build tools that help individual developers populate their local KB faster:
- Parse transcripts/conversations into structured entries
- Discover codebase structure automatically
- Reduce manual entry creation friction

---

## Tools

### 1. `kb-ingest` — Transcript/Text Parser

**Purpose**: Convert unstructured text (conversations, notes, transcripts) into KB entries.

**Input**:
- Raw text file
- Claude Code session transcript
- Pasted conversation

**Output**:
- Draft KB entry in appropriate bucket
- Suggested tags based on content
- Source file references if mentioned

**Usage**:
```bash
# From file
./scripts/kb-ingest --input conversation.txt --bucket explorations

# From stdin (paste mode)
./scripts/kb-ingest --bucket errors

# Auto-detect bucket from content
./scripts/kb-ingest --input notes.md --auto
```

**Status**: Alpha Complete - basic text parsing, auto-bucket detection, file ref extraction

---

### 2. `kb-discover` — Codebase Scanner

**Purpose**: Analyze a codebase and generate exploration entries documenting its structure.

**Input**: Directory path

**Output**:
- Boundary exploration entry (entry points, modules, data flow)
- Optional: per-module explorations

**Usage**:
```bash
# Full discovery
./scripts/kb-discover ./legacy-app --output knowledge-db/explorations/

# Quick summary only
./scripts/kb-discover ./legacy-app --summary

# Focus on specific aspect
./scripts/kb-discover ./legacy-app --focus api-routes
```

**Status**: Alpha Complete - project type detection, entry point analysis, integration scanning

---

### 3. `kb-suggest` — Post-Task Suggestion (Future)

**Purpose**: After detecting substantial work, suggest KB entry creation.

**Trigger**: Git hook or manual

**Behavior**:
1. Analyze recent changes (git diff)
2. Detect if KB-worthy (multi-file, new patterns, bug fixes)
3. Prompt user with draft entry
4. User confirms/edits/skips

**Status**: 📋 Planned

---

## Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| M1.1 | `kb-ingest` alpha — basic text parsing | Done (2026-08-20) |
| M1.2 | `kb-discover` alpha — directory analysis | Done (2026-08-20) |
| M1.3 | `kb-lint` — KB validation with --fix | Done (2026-08-20) |
| M1.4 | Test suite for CLI tools | Done (2026-08-20) |
| M1.5 | Worked examples in KB | Done (2026-08-20) |
| M1.6 | `kb-ingest` beta — Claude session parsing | Planned |
| M1.7 | `kb-suggest` prototype | Planned (Phase 2 prerequisite) |

---

## Technical Notes

### Transcript Parsing Strategy

1. **Section detection**: Look for patterns like "## Findings", error messages, file paths
2. **Entity extraction**: File paths (`src/foo.ts:42`), error messages, decisions
3. **Bucket inference**:
   - Error messages/stack traces → `errors/`
   - "How does X work" questions → `explorations/`
   - "We decided to" / "chose X over Y" → `decisions/`
   - Implementation details → `solutions/`

### Discovery Strategy

1. **Entry points**: `package.json` scripts, `main`/`index` files, route definitions
2. **Module boundaries**: Directory structure, import graphs
3. **Data models**: Type definitions, schemas, interfaces
4. **Integration points**: API calls, DB connections, external services

---

## Success Criteria

Phase 1 complete when:
- [ ] User can convert a pasted conversation to KB entry in <30 seconds
- [ ] User can run discovery on unfamiliar codebase, get useful boundary map
- [ ] Tools don't require external dependencies beyond bash/standard unix
