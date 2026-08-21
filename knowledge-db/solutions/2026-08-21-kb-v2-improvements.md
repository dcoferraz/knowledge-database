---
title: "KB v2: Security, tests, mandatory auto-capture, releases"
type: solution
status: verified
date: 2026-08-21
tags: [area:tooling, area:test, layer:cli, area:release]
sources:
  - scripts/kb-lint:26-35
  - scripts/kb-ingest:27-40
  - scripts/init-knowledge-db.sh:35-60
  - tests/run-tests.sh:1-150
  - CLAUDE.md:103-127
  - knowledge-database/SKILL.md:79-100
  - README.md:147-164
  - CHANGELOG.md:1-60
related:
  - explorations/2026-08-20-cli-tool-architecture.md
  - errors/2026-08-20-fix-flag-not-implemented.md
  - decisions/2026-08-21-mandatory-vs-optional-auto-capture.md
  - decisions/2026-08-21-consent-only-for-superseding.md
  - decisions/2026-08-21-incremental-vs-batched-capture.md
  - decisions/2026-08-21-one-entry-per-choice.md
---

## Summary

Major evolution of Knowledge Database: security fixes, test suite, mandatory auto-capture (not optional), trigger guidance, and first three releases (v0.2.0, v0.2.1, v0.2.2).

## Context / Question

Code review by sub-agents identified critical issues:
- YAML injection in kb-ingest (unsanitized title/tags)
- sed injection in kb-lint --fix (unsanitized metadata)
- No test coverage
- Missing solutions/ example
- No .gitignore handling on init

User feedback refined auto-capture:
- Should be mandatory, not optional prompt
- Consent only for superseding verified entries
- Need clear examples of what triggers capture
- Need priority guidance for what's most valuable

## Findings / What We Did

### Security Fixes

**kb-ingest YAML injection** (scripts/kb-ingest:27-40):
- Added `sanitize_yaml()` function to escape special YAML characters
- Quotes titles in generated YAML frontmatter
- Validates slugs to prevent path traversal

**kb-lint sed injection** (scripts/kb-lint:26-35):
- Added `sanitize_for_sed()` and `sanitize_metadata()` functions
- Replaced sed with awk for INDEX.md row insertion
- Validates date format before use

### Test Suite

Created tests/run-tests.sh with 23 test cases:
- init-knowledge-db.sh: 8 tests (structure, idempotency)
- kb-lint: 9 tests (detection, --fix behavior)
- kb-ingest: 4 tests (bucket detection, explicit bucket)
- kb-discover: 2 tests (help, directory scan)

### Auto-Capture (Mandatory)

Mechanism 8 evolved through user feedback:
- v0.2.0: Optional prompt (Y/N/T)
- v0.2.1: Mandatory - non-trivial work = KB entry created
- User reviews content, not whether to create

**Trigger table** (README.md:147-156):
| Task | Record? | Bucket |
|------|---------|--------|
| Debug failing test | YES | errors/ |
| Investigate "how does X work" | YES | explorations/ |
| Add feature (multi-file) | YES | solutions/ |
| Choose between approaches | YES | decisions/ |
| Rename with reasoning | YES | decisions/ |
| Fix obvious typo | NO | - |

**Rule**: If there was reasoning, record it. Future you will ask "why?"

**Priority** (most valuable first):
1. Errors with fixes - Prevents bug reintroduction
2. Investigations - Prevents re-exploration
3. Decisions with rationale - Prevents re-debating
4. Multi-step solutions - Prevents redoing work

### Consent Mechanism

Mechanism 9: Only ask before superseding verified entries.
> "Entry '[title]' is verified. Mark as superseded because [reason]? [Y/N]"

No consent needed for tentative entries or creating new entries.

### Init Script Improvements

scripts/init-knowledge-db.sh now auto-updates .gitignore:
- Detects if running in git repo
- Adds `knowledge-db/` to .gitignore
- Detect-before-append (idempotent)

### Release Workflow

Created CHANGELOG.md following Keep a Changelog format.

Released:
- v0.2.0: Security fixes, tests, auto-capture
- v0.2.1: Mandatory auto-capture
- v0.2.2: Trigger table, priority guidance

All releases tagged and published to GitHub with notes.

## Verification

```bash
$ ./tests/run-tests.sh
Results: 23/23 passed
All tests passed

$ ./scripts/kb-lint knowledge-db
Errors: 0

$ git tag
v0.1.0
v0.2.0
v0.2.1
v0.2.2
```

All changes committed and pushed to main.
