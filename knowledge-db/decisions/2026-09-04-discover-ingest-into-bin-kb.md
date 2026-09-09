---
title: "kb-discover and kb-ingest folded into bin/kb instead of shipping scripts"
type: decision
status: verified
date: 2026-09-04
tags: [area:tooling, layer:cli]
sources:
  - knowledge-db/bin/kb:1340-1420
  - knowledge-db/bin/kb:1504-1580
  - knowledge-db/AGENT.md:18-27
related:
  - 2026-09-04-audit-fixes-v070
---

## Summary

Discovery and ingestion became `kb discover` / `kb ingest` inside the
zero-dependency CLI that ships in every KB folder. `scripts/kb-discover` and
`scripts/kb-ingest` remain as forwarding shims.

## Context / Question

AGENT.md — the portable hard-rules file planted into every runtime — told agents
to bootstrap an empty KB with `scripts/kb-discover` and `scripts/kb-ingest`.
`init-knowledge-db.sh` only ever copied `bin/kb` and `install.sh`, so no
installed KB had those scripts. The rules pointed at tools that did not exist.
Fix by shipping the scripts, or by folding them into the CLI?

## Findings / What We Did

Options considered:

1. **Fold into `bin/kb`** (chosen) — one file to vendor, one file to version,
   and the tools exist wherever the KB does. Also let the generators reuse the
   checker's own vocabulary handling.
2. Copy `scripts/` into `knowledge-db/bin/` at init — keeps 900 lines of bash
   heuristics as-is, but adds three more files to vendor on every upgrade and
   two more languages to the install surface.
3. Delete the references from AGENT.md — smallest change, but the empty-KB rule
   then has no concrete bootstrap path, which is the one moment a new KB most
   needs one.

A second defect drove the rewrite rather than a port: both scripts emitted
entries that FAILED `kb check` — `tags: [area:architecture, layer:overview]`
(undeclared, KB002), bare directory paths in `sources:` (KB003), and
`related:\n  - # TODO` template residue (KB005). A generator that produces
invalid entries teaches the opposite of the rules. The new implementations
filter tags against the declared vocabulary, cite `path:line` only for files
that exist, and are covered by tests asserting `kb check` passes on their
output.

## Verification

```
$ bash tests/run-kb-tests.sh 2>&1 | grep -A4 "kb discover and kb ingest"
Testing kb discover and kb ingest write valid entries
  kb discover --summary reports a scan... PASS
  kb discover output passes kb check... PASS
  kb ingest auto-detects the errors bucket... PASS
  kb ingest output passes kb check... PASS

$ bash tests/run-tests.sh 2>&1 | grep shim
  kb-discover shim forwards to bin/kb discover... PASS
  kb-ingest shim forwards to bin/kb ingest... PASS
```
