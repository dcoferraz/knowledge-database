---
title: "KB v0.4.0: rule IDs KB001-KB011 enforced by zero-dependency kb CLI"
type: solution
status: verified
date: 2026-08-24
tags: [area:tooling, layer:cli, layer:enforcement, area:test]
sources:
  - knowledge-db/bin/kb:1-25
  - knowledge-db/kb.config.json:1-36
  - knowledge-db/install.sh:1-30
  - tests/run-kb-tests.sh:1-30
  - knowledge-db/README.md:55-69
  - CHANGELOG.md:8-40
related:
  - decisions/2026-08-24-derive-index-from-front-matter.md
  - decisions/2026-08-24-python-stdlib-for-kb-cli.md
  - decisions/2026-08-24-enforce-or-delete-rule-ids.md
  - decisions/2026-08-24-writeback-trigger-not-checklist.md
  - solutions/2026-08-21-kb-v2-improvements.md
---

## Summary

External evaluator feedback showed the prose-enforced conventions drifted in real use (tag drift, fake "verified" proof, undeclared vocabulary). Built `knowledge-db/bin/kb` (Python 3 stdlib, zero deps) enforcing every hard rule as KB001-KB011, plus an idempotent `install.sh` wiring agent hook, git pre-commit, and CI.

## Context / Question

An agent deploying this pattern reported violations our conventions could not stop: INDEX rows drifting from front-matter, `status: resolved` and `layer:process` invented values, `# Should pass with no errors` used as verification proof, undeclared buckets, three shipped waves with no KB entry. Confirmed in this repo: 3 INDEX rows with tag drift, undeclared `area:release` tag, `# Works without any dependency installation` as proof, and 4 decision entries `verified` with prose-only Verification.

## Findings / What We Did

- `knowledge-db/kb.config.json:1-36` — all vocabularies (buckets, types, statuses, tags, staleness, required sections, lockstep pairs, write-back paths) in one config.
- `knowledge-db/bin/kb:1-25` — CLI with `new` (scaffolds valid entries, status tentative), `index` (INDEX.md generated from front-matter, manual regions fenced), `check` (KB001-KB011, `--json`, `--staged`/`--diff-base`).
- `knowledge-db/install.sh:1-30` — idempotent merging installer: agent Stop hook into committed `.claude/settings.json`, `.githooks/pre-commit` + `core.hooksPath`, `.github/workflows/kb-check.yml`; `--check` audits.
- `tests/run-kb-tests.sh:1-30` — conformance suite: `tests/fixtures/pass/` must exit 0, each `tests/fixtures/fail/KBxxx/` must exit non-zero naming its ID; KB009/KB011 exercised in temp git repos with staged diffs.
- Rule table: `knowledge-db/README.md:55-69`.

## Verification

```bash
$ knowledge-db/bin/kb check
exit 0

$ tests/run-kb-tests.sh
Results: 14 passed, 0 failed
All KB conformance tests passed

$ tests/run-tests.sh
Results: 23/23 passed
All tests passed
```

install.sh run twice: second run reports all layers IN PLACE (no changes). Against a repo with pre-existing `.claude/settings.json` hooks and `.githooks/pre-commit`, both were preserved and the KB hook appended; a staged code change with no KB entry was blocked at commit (KB009 fired, commit exit 1).

## Follow-ups / Open Questions

- `scripts/kb-lint` is deprecated but still shipped; remove after one release.
- `.kb-templates/` (used by `scripts/init-knowledge-db.sh`) still scaffolds the pre-v0.4.0 layout without kb.config.json/bin; new installs should copy `knowledge-db/` + run `install.sh`.
