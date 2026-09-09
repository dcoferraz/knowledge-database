---
title: "v0.9.0: indexed lookup — one file read, one process, never stale"
type: solution
status: verified
date: 2026-09-08
last_verified: 2026-09-09
tags: [area:tooling, layer:cli, area:test]
sources:
  - knowledge-db/bin/kb:1291-1360
  - knowledge-db/bin/kb:1395-1470
  - knowledge-db/bin/kb:24-40
related:
  - 2026-09-09-find-fallback-note-read-as-miss
  - 2026-09-05-reuse-ends-the-task
  - 2026-09-05-lookup-path-and-purpose-v080
---

## Summary

`kb find` shipped in v0.8.0 without consulting any index: it opened every entry
twice (80 reads for 40 entries). Fixed by a generated `.search-index.json` read
once per search, an automatic deep-scan fallback so recall never drops, and
`find -s` to fuse find+show into one process. Profiling showed startup, not
reads, dominates a small KB — so lazy imports and the fused call matter there,
and the index matters as the KB grows.

## Context / Question

"Are we checking the INDEX file first before grepping the whole KB? This must be
consistent and as fast as possible."

Answer was no, on both counts: `cmd_find` never mentioned INDEX, and it called
`path.read_text()` *and* `parse_entry(path)` for every entry — the latter opening
the file again.

## Findings / What We Did

**The index tier.** `kb index` now writes `.search-index.json`: one row per
entry with title, bucket, status, date, tags, cited sources, and the first of
Summary/Fix/Symptom trimmed to 400 chars. `kb find` reads that single file and
ranks title (8), tags (4), slug (3), summary (2 per hit, capped), sources (1).
Dot-prefixed so KB002 skips it, like `.install.json`.

**Never stale.** The digest carries a fingerprint over every entry's
`(path, mtime_ns, size)` — stats only, no reads. If it does not match, `find`
rebuilds before answering. So a hand-edited entry, a fresh clone, or a deleted
digest all self-heal instead of returning a wrong answer.

**Recall kept.** Bodies are not in the digest (that would be a second copy of
the KB). If the index tier scores nothing, `find` automatically scans bodies and
prints a note naming the tier that answered. Deep scores are index scores plus
body counts, so the tiers can never disagree on ordering. `--deep` forces it.

**Superseded wording (v0.9.1).** That note originally read
`(deep scan: no title/tag/summary match)`, which an agent read as "no results"
while hits were on screen. It is now
`(full-text scan: matched entry bodies, not title/tag/summary)` — see
[[2026-09-09-find-fallback-note-read-as-miss]].

**What actually cost the time.** Profiling first, optimising second:

| | 40 entries | 1,000 entries |
|---|---|---|
| `python3 -c pass` | 18ms | 18ms |
| startup + imports (`kb version`) | 53ms | 56ms |
| `kb find`, index hit | 54ms | 59ms |
| `kb find --deep` | 62ms | 108ms |
| body-only term, auto fallback | — | 86ms |

At 40 entries the search itself is ~2.4ms: **95% of a lookup was process
startup**, so the digest saved ~4ms and was nearly pointless on its own. Two
changes attack the real cost: `find -s` prints the top hit's core in the same
process (105ms for two calls versus 55ms for one), and `shutil`, `subprocess`,
`tempfile`, `io`, `contextlib` moved to function-level imports (~8ms of import
time the lookup path never needed). At 1,000 entries the index earns its keep on
its own: search work drops from ~52ms to ~3ms.

**Rules follow the fast path**, or agents will not use it: the injected block and
the planted block now say `kb find "<keywords>" -s` and rule out `ls`, `grep -r`
and full `INDEX.md` reads. The injection got smaller: 238 tokens versus 241.

## Hardening added after the first measurement (same release)

Three follow-ups, one of which corrected a claim I had made without measuring:

**The suites were never slow.** I had reported that the conformance suite
"exceeds a 600s timeout" and offered to parallelise it. Measured: `run-tests.sh`
5.5-6.3s, `run-kb-tests.sh` 13.7-14.6s, ~20s together. The 600s timeout came
from one compound shell invocation that stalled for reasons I could not
reproduce, and I attributed it to the suites without timing them. No
parallelisation was needed, and none was done.

**A perf/offline canary now guards the hot path**, because those commands run on
every agent Stop, every commit and every CI job: `check`, `rules`, `version` and
`find` must each finish inside 5s (they take 0.07-0.08s), and `check` plus `find`
must still work with `git` replaced by a stub that exits 127. That last
assertion failed on first run — and the failure was in the test, not the tool:
it queried "money", which matches nothing in the pass fixture, and `kb find`
exits 1 on no match by design. Verified the tool separately: `kb check` exits 0
with git entirely absent from PATH.

**`timeout-minutes: 10`** added to the CI job and to the generator in
`install.sh`, so a future hang fails a build instead of burning a runner.

**SKILL.md can no longer drift from the tool.** Invoking the skill surfaced that
its sample HARD RULE block was still the pre-v0.7.0 four-rule text — it told
agents to "search knowledge-db/ (start with INDEX.md)", the exact behaviour
v0.9.0 exists to replace. Regenerated from `kb rules --plant`, and a conformance
test now compares the two (whitespace-insensitive) so the sample fails the suite
the moment it ages. Note the test itself needed rewriting: a quoted heredoc
containing triple backticks inside `$()` is mis-parsed by bash 3.2, which broke
the whole suite file until the backticks were removed.

**Still uncovered, deliberately:** `kb upgrade` vendors `TOOLING_FILES` only, so
it never refreshes an installed *skill* copy. Checked on this machine: the
plugin marketplace clone's `SKILL.md` has drifted from canonical, while the
workspace's `.claude/skills/knowledge-database` is a symlink and therefore
always current. A copied skill goes stale silently; `claude plugin update`
refreshes it, `kb upgrade` does not.

## Verification

```
$ knowledge-db/bin/kb find "reuse duplicate entry" -n 1 -s --lines 6 | head -3
decisions/2026-09-05-reuse-ends-the-task.md  [verified]
  Reuse ends the task, and lookup goes through kb find/show

$ bash tests/run-kb-tests.sh 2>&1 | sed -n '/search index/,/one call/p'
Testing the search index (one file read, never stale, deep fallback)
  kb index writes the search index... PASS
  the search index does not trip KB002 (dot-prefixed)... PASS
  a title hit is served from the index, no body scan... PASS
  a body-only term falls back to a deep scan and reports it... PASS
  --deep forces the body scan explicitly... PASS
  a hand-edited KB rebuilds the index instead of serving a stale one... PASS
  a missing index is rebuilt on the next find... PASS
  kb find -s returns the hit and the fix in one call... PASS

$ bash tests/run-kb-tests.sh | tail -2
Results: 91 passed, 0 failed
All KB conformance tests passed

$ python3 -c "import subprocess,time
for s in ('tests/run-tests.sh','tests/run-kb-tests.sh'):
    t=time.perf_counter(); subprocess.run(['bash',s],capture_output=True); print(s, round(time.perf_counter()-t,1))"
tests/run-tests.sh 6.3
tests/run-kb-tests.sh 14.6

$ env PATH=/usr/bin:/bin knowledge-db/bin/kb --kb-dir /tmp/x/knowledge-db check; echo "exit=$?"
exit=0        # git absent from PATH entirely

$ knowledge-db/bin/kb version
kb tool version: 0.9.0
kb.config.json kb_version: 0.9.0

$ knowledge-db/bin/kb check; echo "exit=$?"
exit=0
```
