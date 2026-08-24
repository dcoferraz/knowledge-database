---
title: "Consent only for superseding verified entries"
type: decision
status: superseded
date: 2026-08-21
tags: [area:tooling, layer:enforcement]
sources:
  - CLAUDE.md:155-163
  - knowledge-database/SKILL.md:128-134
related:
  - decisions/2026-08-24-autonomous-superseding-no-prompts.md
  - decisions/2026-08-21-mandatory-vs-optional-auto-capture.md
---

## Summary

User consent is ONLY required before marking a VERIFIED entry as SUPERSEDED. No consent needed for creating entries or updating tentative entries.

## Context / Question

Original v0.2.0 design prompted for tentative entries too:
- "Create KB entry?" prompt for all new entries
- User feedback: "I don't like the CONSENT part. it should only request if we're supersede"

## Options Considered

**Option A: Consent for all entry creation**
- Always ask before creating entries
- Risk: Slows down workflow, users may decline
- Conflicts with mandatory auto-capture

**Option B: Consent only for superseding verified (chosen)**
- Creating entries = automatic (mandatory capture)
- Updating tentative = automatic
- Superseding verified = requires explicit consent
- Verified entries represent proven knowledge

## Decision

**Option B: Consent only for superseding verified**

Rationale:
- Verified entries are "proven knowledge" - destructive to lose them
- Creating new entries should be frictionless (compounds value)
- Tentative entries are "best guess" - safe to update without ceremony
- Only superseding verified = changing proven truth = needs consent

Prompt format:
> "Entry '[title]' is verified. Mark as superseded because [reason]? [Y/N]"

## Verification

Both docs state the consent rule, scoped to superseding verified entries only (captured 2026-08-24):

```bash
$ sed -n '155p;157p' CLAUDE.md
### 9. Consent Before Superseding Verified
**Before marking a VERIFIED entry as SUPERSEDED**, ask user:
$ sed -n '128p;133p' knowledge-database/SKILL.md
### Consent Before Superseding
Never change verified entry status without explicit user consent.
```
