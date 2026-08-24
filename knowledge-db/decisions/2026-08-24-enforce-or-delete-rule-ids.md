---
title: "Enforce-or-delete: every hard rule gets an ID or leaves the README"
type: decision
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement]
sources:
  - knowledge-db/README.md:56-71
  - knowledge-db/README.md:107-115
related:
  - solutions/2026-08-24-kb-enforcement-tooling.md
---

## Summary

Every hard rule in knowledge-db/README.md is one of KB001-KB011 and cites its ID; anything unenforceable was deleted or moved to an explicitly labelled "Guidance (not checked)" section. No placeholder or aspirational tables remain.

## Context / Question

The old README and INDEX stated rules in prose that nothing checked (lock-step table shipped empty, "no bare paths" said once and never verified). Evaluator observation: an unenforced rule teaches every future reader that the document is decorative — the empty lock-step table trained agents to ignore it. Options: (A) keep aspirational rules and add tooling gradually, (B) delete or demote any rule without a rule ID.

## Findings / What We Did

Chose (B). Rules now live as IDs implemented in `kb check`, each with a conformance fixture; docs cite IDs instead of restating behavior, so prose cannot drift from enforcement. Judgment calls that cannot be mechanically checked (search-before-creating, one-entry-per-choice, source-of-truth hierarchy) moved under "## Guidance (not checked)" (knowledge-db/README.md:107-115) so their unenforced status is explicit rather than implied binding.

## Verification

Rule table rows at README lines 60-71, guidance section labelled (captured 2026-08-24):

```bash
$ grep -n "^| KB001\|^| KB011\|^## Guidance" knowledge-db/README.md
60:| KB001 | Every entry is `<bucket>/YYYY-MM-DD-<kebab-slug>.md` with front-matter keys `title`, `type`, `status`, `date`, `tags`, `sources`. `type` matches its directory. Filename date equals the `date` field. |
70:| KB011 | Write-back trigger: a diff touching `writeback.code` paths but no `knowledge-db/**` file fails, naming the bucket the entry probably belongs in. Diff mode only. |
107:## Guidance (not checked)
```
