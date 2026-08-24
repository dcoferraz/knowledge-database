---
title:
type:         # declared in kb.config.json types (KB002)
status: tentative  # verified requires captured proof (KB004)
date:         # must equal filename date (KB001)
tags: []      # every tag declared in kb.config.json (KB002)
sources: []   # path:Lstart[-Lend][@rev], path must exist (KB003)
related: []   # other KB entries; REQUIRED if status is superseded (KB005)
---

<!-- Prefer `bin/kb new <type> <slug>` — it scaffolds a valid entry and regenerates INDEX.md.
     If copying this by hand: fill every list or use [], never leave a bare "-" (KB005). -->

## Summary

<!-- 1-2 sentences: the key takeaway -->



## Context / Question

<!-- What triggered this investigation/work? -->



## Findings / What We Did

<!--
The substance. REQUIREMENTS:
- Cite source file for EVERY claim (path:line-range)
- Unsourced claims = status must be tentative
- Write the conclusion, not the search journey
-->



<!-- ═══════════════════════════════════════════════════════════════════════════
     FOR errors/ ONLY — include ALL FOUR sections below (delete this comment):
     ═══════════════════════════════════════════════════════════════════════════

## Symptom

What error message / behavior was observed? Include exact error text.

## Root Cause

Why did it happen? (cite source files with path:line)

## Fix

What changes fixed it? (file paths + code snippets)

## Prevention

How to avoid this in the future? (checklist, lint rule, test, etc.)

-->



## Verification

<!--
REQUIRED for status: verified. Without this, status MUST be tentative.

Include ACTUAL PROOF — one or more of:
- Command run + output
- Test name + pass/fail result
- Row count / parity check
- Screenshot / log snippet
- Steps to reproduce + observed result

Example:
```bash
$ npm test -- --grep "auth middleware"
PASS src/middleware/auth.test.ts
  ✓ validates JWT token (12ms)
  ✓ rejects expired tokens (8ms)
```

If tentative: what's unproven + how to confirm
-->



## Lock-Step Check

<!--
Did this change require updating paired docs? Verify invariants:
- [ ] Schema change → schema doc updated
- [ ] API change → API doc updated
- [ ] Config change → deployment doc updated
- [ ] N/A (no lock-step invariants apply)

Delete this section if N/A.
-->



## Follow-ups / Open Questions

<!--
What remains unknown or should be investigated later?
Delete this section if none.
-->

