---
title: "Consent only for superseding verified entries"
type: decision
status: verified
date: 2026-08-21
tags: [area:tooling, layer:enforcement]
sources:
  - CLAUDE.md:141-148
  - knowledge-database/SKILL.md:103-108
related:
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

CLAUDE.md:141-148 and SKILL.md:103-108 updated. Consent mechanism explicitly scoped to superseding verified entries only.
