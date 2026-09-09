---
title: "kb find's fallback note was read as a miss, and the KB got bypassed"
type: error
status: verified
date: 2026-09-09
tags: [area:tooling, layer:cli, severity:high]
sources:
  - knowledge-db/bin/kb:1431-1435
  - tests/run-kb-tests.sh:887-898
related:
  - 2026-09-08-indexed-lookup-fast-path
  - 2026-09-05-reuse-ends-the-task
---

## Summary

`kb find` printed `(deep scan: no title/tag/summary match)` alongside hits it had
just found. An agent read the negation as the result, treated the lookup as empty,
and went off to re-derive knowledge the KB already held — the one failure the tool
exists to prevent. The note is provenance, not a verdict, and is now worded that
way.

## Symptom

A body-only query returns entries *and* a line that reads like a refusal:

```
solutions/2026-09-05-lookup-path-and-purpose-v080.md  [verified]
  v0.8.0: cheap lookup path, reuse rule, and a README that states the purpose
  ...
knowledge-db/bin/kb show <entry>   # the fix, without the prose  (deep scan: no title/tag/summary match)
```

A consumer that reads the last line first concludes "no match" while two
`verified` hits sit directly above it.

## Root Cause

Introduced in v0.9.0 with the two-tier lookup (`bin/kb` `cmd_find`). The note was
written to explain *which tier answered* — index versus body scan — but phrased as
a negation of the index tier ("no title/tag/summary match"). Two things make that
dangerous rather than merely clumsy:

- It sits at the END of the output, after the hits, which is where a reader looks
  for a conclusion.
- Which tier answers is largely keyword luck. The same underlying question,
  phrased two ways, lands on different tiers — so the same KB, asked twice,
  emits the scary wording unpredictably.

No logic was wrong: the hits were correct, ranked, and complete. Only the label
was, and it was persuasive enough to override the data next to it.

## Fix

`knowledge-db/bin/kb:1431-1435` — state provenance, never a negative:

```diff
-    note = "" if tier == "index" else "  (deep scan: no title/tag/summary match)"
+    note = ("" if tier == "index" else
+            "  (full-text scan: matched entry bodies, not title/tag/summary)")
```

`tests/run-kb-tests.sh:887` and `:895` grepped the old string and moved with it;
`:896` now names the requirement ("says so, not implying zero hits") instead of
the mechanism.

## Prevention

- **A provenance note must never be phrased as a negation.** If output explains
  how an answer was found, it states what WAS matched, not what was not. The
  conformance case at `tests/run-kb-tests.sh:895` pins the wording, so reverting
  to a negative phrasing fails the suite.
- Assume the last line of tool output is read as the conclusion. Anything
  appended after a result list competes with it.
- When adding a tier, mode or fallback, write its label from the consumer's side:
  an agent acts on the sentence, not on the implementation detail behind it.

## Verification

```
$ # BEFORE (v0.9.0, same command, same KB)
$ knowledge-db/bin/kb find "banker" -n 1 | tail -1
knowledge-db/bin/kb show <entry>   # the fix, without the prose  (deep scan: no title/tag/summary match)

$ # AFTER
$ knowledge-db/bin/kb find "banker" -n 1 | tail -1
knowledge-db/bin/kb show <entry>   # the fix, without the prose  (full-text scan: matched entry bodies, not title/tag/summary)

$ # the index tier is unchanged and still prints no note
$ knowledge-db/bin/kb find "reuse ends the task" -n 1 | tail -1
knowledge-db/bin/kb show <entry>   # the fix, without the prose

$ bash tests/run-kb-tests.sh | tail -2
Results: 91 passed, 0 failed
All KB conformance tests passed
```
