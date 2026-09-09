---
title: "Reuse ends the task, and lookup goes through kb find/show"
type: decision
status: verified
date: 2026-09-05
tags: [area:tooling, layer:enforcement, layer:cli]
sources:
  - knowledge-db/bin/kb:1027-1044
  - knowledge-db/bin/kb:1290-1420
  - knowledge-db/AGENT.md:16-40
related:
  - 2026-09-04-token-cost-benchmark
  - 2026-09-05-lookup-path-and-purpose-v080
---

## Summary

Two rule changes and two commands, all from one measured failure: a KB-equipped
agent cost MORE than a control agent solving the same bug. Reuse now explicitly
ends a task (refresh the entry you used; never duplicate it), and lookup goes
through `kb find` / `kb show` instead of reading `INDEX.md` end-to-end.

## Context / Question

The three-arm demo (same bug twice, plus a control with no KB) measured the warm
arm at 3.62M billed tokens against the control's 2.46M — 47% worse. The trace
showed the agent had obeyed every rule: it read the KB first, applied the
recorded fix, and then did what the rules demanded of "non-trivial work" — wrote
a new entry, updated two, regenerated the index. It also opened all four modules
the entry had already named, and read `kb.config.json` and `_TEMPLATE.md` to
learn how to author.

So the question was not "why did the agent ignore the KB" — it did not. It was
"what do the rules tell an agent to do when the KB already has the answer?"
Nothing. There was no reuse path, and the documented lookup path was a full read
of the catalog.

## Findings / What We Did

Decisions:

1. **Reuse is a terminal state.** Refreshing the entry you used (bump
   `last_verified` with fresh proof, or a one-line reuse note) is the complete
   write-back for a reuse. Rejected: keeping "all non-trivial work gets an
   entry", which is what produced the regression — it charges the full authoring
   cost on every reuse and splits one answer into two that later disagree.
   No code change was needed for the gate: KB011/KB013 only require the diff to
   touch `knowledge-db/`, and touching the reused entry does that. The rules had
   simply never said so.
2. **Lookup is a query, not a scan.** `kb find "<keywords>"` prints hits only;
   `kb show <entry>` prints the actionable core. Rejected: telling agents to
   grep the folder (unranked, returns whole files) and shrinking `INDEX.md`
   (it is a human artifact and a build output — KB007 — so it cannot also be a
   token-efficient agent interface).
3. **The rules must not get more expensive.** They are injected on every prompt,
   so the rewrite was constrained to the existing budget: 241 tokens against 236
   before, +150 per 30-prompt session, buying both new behaviours.
4. **Entries must hand over an applicable change.** AGENT.md now asks for the
   fix as a diff or `file:line` list, because the warm arm re-read modules the
   entry had already cited.

## Verification

```
$ python3 - <<'PY'
import subprocess
def toks(cmd):
    out = subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout
    return int(len(out)/4)
kb = "knowledge-db/bin/kb"
print("cat INDEX.md          ", toks("cat knowledge-db/INDEX.md"))
print("kb find (1 hit)       ", toks(f'{kb} find "workspace nested repo write-back" -n 1'))
print("cat entry             ", toks("cat knowledge-db/decisions/2026-09-04-workspace-gate-via-nested-hooks.md"))
print("kb show               ", toks(f"{kb} show workspace-gate --lines 8"))
PY
cat INDEX.md           2360
kb find (1 hit)         134
cat entry               709
kb show                 279

old lookup path (INDEX + entry) = 3069 tokens
new lookup path (find + show)   =  413 tokens   (87% less)

$ knowledge-db/bin/kb rules | wc -c
974          # 241 tokens, was 236 before this change

$ bash tests/run-kb-tests.sh | tail -2
Results: 76 passed, 0 failed
All KB conformance tests passed
```
