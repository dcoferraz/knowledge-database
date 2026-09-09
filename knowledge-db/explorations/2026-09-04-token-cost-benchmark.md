---
title: "Token benchmark: what the KB costs vs what re-deriving costs"
type: exploration
status: verified
date: 2026-09-04
last_verified: 2026-09-05
tags: [area:tooling, area:test, layer:cli]
sources:
  - scripts/kb-benchmark:90-131
  - scripts/kb-benchmark:136-215
  - scripts/kb-benchmark:264-280
  - knowledge-db/bin/kb:1027-1050
related:
  - 2026-09-04-audit-fixes-v070
  - 2026-08-24-inject-rules-every-prompt
  - 2026-09-05-reuse-ends-the-task
---

## Summary

`scripts/kb-benchmark` measures the KB's token economics from real artifacts and
real Claude Code transcripts instead of asserting a saving. On this repo's KB (37
entries): the rules injection is 236 tokens per prompt, an entry averages 613
tokens, and the files an entry's citations point at average 17.2k tokens — a 28x
compression against re-reading them, 1.3x against the cited line ranges alone.
Break-even is one reused answer per session on the wide bound. The bigger effect
is amplification: measured at 43-112x across five real sessions, because every
token that enters context is re-read on every later turn.

## Context / Question

"Can we benchmark how much token usage the KB saves?" Nothing in the repo
measured this; the README's claims about never exploring twice were qualitative.

## Findings / What We Did

Built `scripts/kb-benchmark` (stdlib only, no network) with three separately
labelled measurements, because they have very different evidence quality:

1. **Cost of using the KB** — exact, from the artifacts: `kb rules` output
   (236 tokens, run for real, not estimated), INDEX.md (2.3k), AGENT.md (902),
   average entry (613). Fixed cost per session = injection x prompts + one
   INDEX scan (9.4k at 30 prompts); marginal cost per reused answer = 613.
2. **Cost of re-deriving it** — from each entry's own KB003 citations, as a
   bracket rather than a single number:
   - *narrow* 818 tokens/entry: only the cited line ranges. This assumes you
     already know which lines to open, and that knowledge IS the entry.
   - *wide* 17,216 tokens/entry: every cited file opened in full, which is what
     happens when you have to find the ranges yourself.
   Real exploration exceeds even the wide bound: it greps, lists directories,
   and opens files it discards.
3. **What real sessions spend** — from `~/.claude/projects/*/*.jsonl`: billed
   tokens per session, the read-only tool-result payload (apportioned by each
   session's read-vs-edit call mix), and **amplification** = billed / fresh
   input.

Amplification is the finding that reframes the whole question. Across the five
sessions that built this project and its workspace, billed tokens were 43-112x
fresh input (47x aggregate): a token read into context is paid once at full
price and then re-read on every subsequent turn. So the cost of exploration is
not the size of what you read, it is the size of what you read times how long
you carry it — which is exactly what a 613-token entry replacing a 17k-token
file sweep changes.

Two honest limits, stated because the numbers are otherwise easy to oversell:

- Token counts are characters / 4 unless a transcript supplies real usage;
  the divisor is printed so any figure can be rescaled.
- This is **not an A/B trial.** It compares the artifact against the citations
  the artifact itself declares. A true benchmark would run the same task twice,
  with and without the KB, and compare billed tokens. That has not been run.
- On the narrow bound the KB only breaks even after ~46 reuses per session,
  because the INDEX scan dominates. That number belongs in the record: the KB
  is not cheaper than a perfectly targeted read, only than searching for one.

## Live A/B: three agents, same bug, measured twice

Ran the real experiment the modelled numbers above could not settle: the same
half-cent rounding bug in two modules of one fixture, fixed by independent
subagents. Arm 1 (cold) fixed the invoice site with an empty KB and recorded it.
Arms 2 and 3 fixed the payout site — one seeded with arm 1's entries, one with
an empty KB. Round 2 repeated arms 2 and 3 after the v0.8.0 rule changes.

| metric | round 1 warm | round 1 control | round 2 warm | round 2 control |
|--------|-------------|-----------------|--------------|-----------------|
| harness subagent tokens | 70,563 | 66,862 | **55,980** | 63,771 |
| billed total | 3.62M | 2.46M | 2.21M | **1.77M** |
| fresh input | 129.3k | 131.6k | **116.7k** | 131.6k |
| context payload | 9.1k | 9.2k | **6.6k** | 10.0k |
| turns | 65 | 46 | 47 | **36** |
| new entries authored | 1 (+2 updated) | 2 | **0 (3 refreshed)** | 2 |
| suites green at the end | both | both | **both** | payout only |

Round 1 was a null result: the KB arm cost MORE. Two causes, both fixed in
v0.8.0 — the rules had no reuse path, so the agent re-authored knowledge it had
just consumed; and the seeded entries cited `app/money.py`, a file the fix
creates, so `kb check` opened with KB003 findings and the agent ran a regression
investigation the control never did.

Round 2, with the reuse rule and a clean seed, the warm arm authored **zero**
new entries (it refreshed the three it used, bumping `last_verified` and adding
a Reuse Log) and dropped from 70,563 to 55,980 harness tokens — 21% cheaper than
its own round-1 self, and 12% cheaper than the control.

**The verdict depends on the metric, and that is the honest finding.** The KB arm
wins on everything input-side: context payload -34%, fresh input -11%, harness
tokens -12%. It loses on billed total (+25%) because billed is dominated by
cache reads, which scale with turns, and it took 11 more turns — largely to
refresh three entries and re-verify. When comparing agents with different turn
counts, compare fresh input and payload; billed total mostly measures how long
the session ran.

The clearest result is not a token count at all: the warm arm fixed **all four**
money call sites and left both suites green, because the entry listed them. The
control fixed the one site it was asked about and left `tests/test_invoice.py`
failing — correctly logged as a follow-up, but still broken.

## Verification

```
$ scripts/kb-benchmark
1. COST OF USING THE KB (measured from the KB)
  rules injected per prompt           236 tokens
  INDEX.md (the scan)                2315 tokens
  average entry                       613 tokens
  -> fixed, once per session         9395 tokens (236 x 30 prompts + one INDEX scan)
  -> per answer reused                613 tokens (one entry)

2. COST OF RE-DERIVING IT (measured from each entry's citations, two bounds)
  entries                              37
  narrow: cited line ranges only      818 tokens per entry
  wide:   cited files, in full      17216 tokens per entry
  -> compression                     1.3x narrow, 28.1x wide

3. NET
  saved per reuse, narrow bound       205 tokens
  saved per reuse, wide bound       16603 tokens
  fixed cost to recover              9395 tokens per session
  -> break-even (narrow)               46 reused answer(s) per session
  -> break-even (wide  )                1 reused answer(s) per session

$ scripts/kb-benchmark --transcripts ~/.claude/projects/-Users-danielferraz-workspace-personal-knowledge-database
4. WHAT REAL SESSIONS SPENT (measured from Claude Code transcripts)
  session    prompts  discovery    edits  fresh in    billed  amplify
  16ace5d4        27      21.6k     7.0k    393.3k    20.40M    51.9x
  74973bd3        47      76.9k    45.1k     2.02M    86.79M    42.9x
  79a8f6e0         7      12.4k    12.2k    870.6k    49.84M    57.2x
  TOTAL           81     110.9k    64.4k     3.29M   157.02M    47.8x
  carried cost of that discovery payload: up to 5.29M billed tokens

$ bash tests/run-tests.sh | tail -2
Results: 33/33 passed
All tests passed
```
