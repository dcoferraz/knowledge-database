# Knowledge Database Index

The front door to project memory. **Search here BEFORE investigating.**

---

## Ready-Answer Table

_Topic → the ONE doc to read. Check these BEFORE exploring._

| Topic | Canonical Source | Last Verified |
|-------|------------------|---------------|
| CLI tools | explorations/2026-08-20-cli-tool-architecture.md | 2026-08-20 |

<!-- Example rows:
| Database schema | docs/schema.md | 2026-08-15 |
| API endpoints | src/routes/README.md | 2026-08-10 |
| Auth flow | knowledge-db/explorations/2026-08-01-auth-flow.md | 2026-08-01 |
| Deployment process | docs/DEPLOY.md | 2026-08-05 |
-->

---

## Lock-Step Invariants

_Paired artifacts that MUST change together. Verify before completing any task._

| When This Changes | Must Also Update | Notes |
|-------------------|------------------|-------|
| | | |

<!-- Example rows:
| Database schema (migrations/) | docs/schema.md | Regenerate ERD |
| API routes (src/routes/) | docs/API.md | Update endpoint list |
| Environment variables | .env.example + docs/DEPLOY.md | Both files |
| Package dependencies | SECURITY.md (if security-related) | Note CVE if applicable |
-->

---

## Source-of-Truth Hierarchy

_When sources disagree, trust the higher rank. Note stale sources._

1. **Real source assets** — Code, actual configs, runtime behavior
2. **Generated definitions** — ETL outputs, compiled schemas
3. **Outbound feeds** — API responses, exports
4. **Documentation** — READMEs, design docs (can drift)

---

## Explorations

_"What is true" — findings from investigating existing behavior_

| Date | Title | Status | Tags | Entry |
|------|-------|--------|------|-------|
| 2026-08-20 | CLI Tool Architecture | verified | [area:tooling, layer:cli] | explorations/2026-08-20-cli-tool-architecture.md |

---

## Solutions

_"What we did" — how changes/features/fixes were implemented_

| Date | Title | Status | Tags | Entry |
|------|-------|--------|------|-------|
| 2026-08-21 | KB v2: Security fixes, tests, auto-capture | verified | [area:tooling, area:test] | solutions/2026-08-21-kb-v2-improvements.md |
| 2026-08-20 | Test Suite for CLI Tools | verified | [area:tooling, area:test] | solutions/2026-08-20-test-suite-implementation.md |

---

## Errors

_"What broke + the fix" — reproducible traps and their resolution_

| Date | Title | Status | Tags | Entry |
|------|-------|--------|------|-------|
| 2026-08-20 | kb-lint --fix not implemented | verified | [area:tooling, severity:high] | errors/2026-08-20-fix-flag-not-implemented.md |

---

## Decisions

_"Why we chose X" — design/architecture choices and trade-offs_

| Date | Title | Status | Tags | Entry |
|------|-------|--------|------|-------|
| 2026-08-21 | Security hardening approach for CLI tools | verified | [area:tooling, layer:cli, area:security] | decisions/2026-08-21-security-hardening-approach.md |
| 2026-08-21 | decisions/ bucket: one entry per choice | verified | [area:tooling, layer:enforcement] | decisions/2026-08-21-one-entry-per-choice.md |
| 2026-08-21 | Consent only for superseding verified entries | verified | [area:tooling, layer:enforcement] | decisions/2026-08-21-consent-only-for-superseding.md |
| 2026-08-21 | Incremental capture vs batched at session end | verified | [area:tooling, layer:enforcement] | decisions/2026-08-21-incremental-vs-batched-capture.md |
| 2026-08-21 | Mandatory vs optional auto-capture | verified | [area:tooling, layer:enforcement] | decisions/2026-08-21-mandatory-vs-optional-auto-capture.md |
| 2026-08-20 | Bash for Phase 1 CLI tools | verified | [area:tooling, layer:cli] | decisions/2026-08-20-bash-for-cli-tools.md |

---

## Canonical External Docs

_External sources of truth indexed here for quick reference_

| Doc | Purpose | Path/URL | Last Verified |
|-----|---------|----------|---------------|
| | | | |

<!-- Example rows:
| Schema reference | Database structure | docs/schema.md | 2026-08-15 |
| API spec | OpenAPI definition | docs/openapi.yaml | 2026-08-10 |
| Design system | UI components | https://design.example.com | 2026-08-01 |
-->

---

## Tag Vocabulary

_Reuse existing tags before creating new ones. Grep first: `grep -r "tags:" knowledge-db/`_

### Areas (domain)
- `area:auth` - Authentication/authorization
- `area:api` - API endpoints
- `area:ui` - User interface
- `area:db` - Database
- `area:payments` - Payment processing
- `area:infra` - Infrastructure/deployment
- `area:test` - Testing
- `area:tooling` - CLI tools, scripts, automation
- `area:security` - Security fixes and hardening

### Layers (architecture)
- `layer:controller` - Request handlers
- `layer:service` - Business logic
- `layer:model` - Data models
- `layer:middleware` - Request middleware
- `layer:util` - Utilities/helpers
- `layer:cli` - Command-line interface tools
- `layer:enforcement` - KB enforcement mechanisms and rules

### Severity (for errors)
- `severity:critical` - System down, data loss risk
- `severity:high` - Major functionality broken
- `severity:medium` - Degraded experience
- `severity:low` - Minor issue

### Tech (stack-specific)
- Add as needed: `tech:react`, `tech:node`, `tech:postgres`, etc.
