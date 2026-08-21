---
title:
type:         # exploration | solution | error | decision
status:       # verified | tentative | superseded
date:
tags: []      # [area:<area>, layer:<layer>] - grep existing tags first
sources:      # REQUIRED: real files this is grounded in (path:line-range)
  -
related:      # other KB entries; REQUIRED if status is superseded
  -
---

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

