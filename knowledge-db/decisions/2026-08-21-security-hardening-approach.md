---
title: "Security hardening approach for CLI tools"
type: decision
status: verified
date: 2026-08-21
tags: [area:tooling, layer:cli, area:security]
sources:
  - scripts/kb-discover:106-122
  - scripts/kb-ingest:107-120
  - scripts/kb-lint:120-126
related:
  - solutions/2026-08-21-kb-v2-improvements.md
---

## Summary

Security fixes applied incrementally as subagent reviews found them. Approach: fix immediately, don't batch.

## Context / Question

Security auditor agent found three issues in v0.3.0:
1. Command injection via unsanitized dir path in kb-discover (Medium)
2. Path traversal in kb-ingest --kb-dir (Medium)
3. Temp file race condition in kb-lint (Low)

Question: Fix all at once or incremental releases?

## Options Considered

**Option A: Batch fixes into major release**
- Wait for more issues to accumulate
- Risk: Vulnerabilities remain exploitable longer

**Option B: Immediate patch release (chosen)**
- Fix as soon as discovered
- Release v0.3.1 with security fixes
- Matches incremental capture philosophy

## Decision

**Option B: Immediate patch release**

Rationale:
- Security vulnerabilities should not wait
- Incremental capture applies to fixes too
- Users get protection faster
- Clear changelog shows what was fixed

## Verification

```bash
$ ./tests/run-tests.sh
Results: 23/23 passed

$ ./scripts/kb-lint knowledge-db
Errors: 0
```

All fixes maintain backward compatibility. Tests pass on both macOS and Linux (sed portability fixed).
