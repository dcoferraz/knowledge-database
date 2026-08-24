---
title: "KB015: changelog animal art as a config-gated hard rule"
type: decision
status: verified
date: 2026-08-24
tags: [area:release, area:tooling, layer:enforcement]
sources:
  - knowledge-db/bin/kb:912-957
  - knowledge-db/kb.config.json:92-95
related:
  - solutions/2026-08-24-enforcement-guide.md
---

## Summary

The "small random animal SVG left of every changelog version title" practice is
a hard rule (KB015) — but config-gated: it enforces only when `changelog_art`
is declared in kb.config.json. Randomness stays convention; existence,
location, format, and uniqueness-per-version are the mechanical checks.

## Context / Question

User wanted the practice as a HARD RULE. Options: (A) agent convention in
CLAUDE.md only, (B) always-on rule for every KB, (C) config-gated rule.
Also: what part of "random animal" can a validator actually check?

## Findings / What We Did

Chose (C):

- (A) is exactly what this project's history says fails — conventions drift
  (the v0.4.0 lesson).
- (B) would force changelog illustration on every downstream KB — invasive
  default, violates the "extend config, never patch the CLI" principle the
  downstream field report validated.
- (C) matches existing precedent: KB009 lockstep and KB011/KB013 write-back
  are also config-driven.

Mechanical scope (knowledge-db/bin/kb:912-957): every `## [x.y.z]` heading in
the configured changelog must match
`## ![name](<dir>/....svg) [x.y.z]`; the SVG must exist, live under the
declared dir, and no two versions may share one file (uniqueness is the
checkable proxy for "random animal per release" — actual animal choice and
randomness are unverifiable and stay guidance in the rule table).

This repo enables it (knowledge-db/kb.config.json:92-95) and retroactively
illustrated all 12 prior releases with hand-drawn flat SVGs (~500B each,
28px, no external assets) plus a toucan for v0.6.0.

Extension (same day): all 13 GitHub release bodies also open with their
animal, embedded via raw URLs pinned to the v0.6.0 tag (release notes cannot
resolve relative repo paths). Release bodies are GitHub-side state `kb check`
cannot gate, so this half is convention, documented in the KB015 rule row.

## Verification

```
$ knowledge-db/bin/kb check; echo "exit: $?"
exit: 0    # 13 illustrated headings, all KB015 checks pass

$ knowledge-db/bin/kb --kb-dir tests/fixtures/fail/KB015/knowledge-db check 2>&1 | head -1
KB015 CHANGELOG.md:3: version [0.1.0] heading lacks SVG art left of the title — ...
```
