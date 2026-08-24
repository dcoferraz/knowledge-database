---
title: "INDEX.html: self-contained evidence browser for non-technical readers"
type: solution
status: verified
date: 2026-08-24
tags: [area:tooling, area:ui, layer:cli]
sources:
  - knowledge-db/bin/kb:685-810
  - knowledge-db/bin/kb:592-610
  - knowledge-db/bin/kb:875-886
  - knowledge-db/README.md:71
  - ADVANCED.md:211-240
related:
  - decisions/2026-08-24-build-time-embed-vs-runtime-fetch.md
  - decisions/2026-08-24-kb012-fingerprint-vs-byte-check.md
  - solutions/2026-08-24-kb-enforcement-tooling.md
---

## Summary

Documented for non-technical audiences in ADVANCED.md ("The Human Window",
ADVANCED.md:211-240) since 2026-08-24, linked from the README guides section.

`kb index` now generates `INDEX.html` alongside INDEX.md: a single self-contained file a non-technical reader double-clicks to browse every entry, its Verification proof, and the actual source lines each claim is grounded in. Freshness enforced by KB012.

## Context / Question

Product-facing users need to read the KB without git, markdown, or a server. Requirement: navigate the proof — the grounding of each statement (cited source lines), all decisions with who/why, supersession chains.

## Findings / What We Did

- Generator: knowledge-db/bin/kb:685-810 (`generate_html`) — inlines all entries, sidebar nav by bucket with plain-language labels, client-side search + status filter, no external assets (offline-safe, shareable as one file).
- Proof navigation: each `sources:` item is an expandable block showing the cited lines, read at build time (knowledge-db/bin/kb:592-610, `_source_snippet`, capped at 60 lines); Verification sections render in a highlighted "Proof" box; superseded entries get a "replaced by" banner; decisions show `decided by:`.
- Freshness rule KB012: knowledge-db/bin/kb:875-886, rule table row knowledge-db/README.md:71. Fixture `tests/fixtures/fail/KB012/` (tampered fingerprint).
- Markdown renderer is a ~100-line subset (headings, fences, tables, lists, bold, code, links) — we control the entry format, so full CommonMark is unnecessary; all content HTML-escaped.

## Verification

```bash
$ knowledge-db/bin/kb index
regenerated .../knowledge-db/INDEX.md and INDEX.html
$ knowledge-db/bin/kb check; echo CHECK=$?
CHECK=0
$ tests/run-kb-tests.sh
Results: 16 passed, 0 failed
```

Structural check of generated page (2026-08-24): fingerprint present, 18 entry articles, 56 expandable source snippets, 18 proof boxes, 1 superseded banner, 0 external URL references (fully self-contained). All key tags balanced (article/details/section/table/pre/ul). KB012 fixture: `kb check` exits 1 naming KB012.
