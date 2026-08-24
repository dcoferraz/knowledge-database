---
title: "KB012 freshness via content fingerprint, not KB007-style byte check"
type: decision
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement]
sources:
  - knowledge-db/bin/kb:489-497
  - knowledge-db/bin/kb:875-886
related:
  - solutions/2026-08-24-index-html-evidence-browser.md
  - decisions/2026-08-24-derive-index-from-front-matter.md
---

## Summary

INDEX.html freshness is enforced by comparing an embedded SHA-256 fingerprint of the KB content (generated INDEX.md + entry file contents) against a recomputation — not by regenerating the page and byte-comparing like KB007 does for INDEX.md.

## Context / Question

INDEX.md derives only from entries + config, so byte-for-byte comparison (KB007) is exact and cheap. INDEX.html additionally embeds cited source lines read from files OUTSIDE the KB. A byte check would make `kb check` fail whenever any cited source file changes — every unrelated code edit would demand an INDEX.html regen, making the rule noisy enough that people bypass it. Options: (A) byte check including snippets, (B) fingerprint over KB content only, snippets excluded.

## Findings / What We Did

Chose (B). Fingerprint inputs: generated INDEX.md text + sorted (relpath, content) of every entry (knowledge-db/bin/kb:489-497). Check: knowledge-db/bin/kb:875-886. Consequences accepted and documented: embedded snippets are best-effort context captured at generation time and may lag the live code — the KB003 `@rev` warning is the mechanism for detecting cited-range rot, not KB012. Entry or INDEX changes are always caught (both are fingerprint inputs), which is the freshness that matters for readers.

## Verification

```bash
$ knowledge-db/bin/kb --kb-dir tests/fixtures/fail/KB012/knowledge-db check
KB012 knowledge-db/INDEX.html: stale (fingerprint mismatch with entries/INDEX) — run `kb index`
kb check: 1 finding(s)
$ tests/run-kb-tests.sh
Results: 16 passed, 0 failed
```
