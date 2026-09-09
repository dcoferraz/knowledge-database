---
title: "Workspace write-back gate: plant a hook inside each nested repo"
type: decision
status: verified
date: 2026-09-04
last_verified: 2026-09-09
tags: [area:tooling, layer:enforcement]
sources:
  - knowledge-db/install.sh:455-500
  - knowledge-db/bin/kb:897-930
  - ADVANCED.md:300-330
related:
  - 2026-09-04-audit-fixes-v070
---

## Summary

In workspace mode `install.sh` plants a pre-commit hook inside each nested app
repo that runs the workspace KB's `kb check --staged --repo <that repo>`.
Write-back evidence there is pending KB changes in the workspace, or a KB commit
inside `writeback.grace_hours` (default 24).

## Context / Question

ADVANCED.md sells the context workspace as "the 100% solution": KB in the parent
folder, app in a nested repo the workspace gitignores. In that layout KB011 and
KB013 can never fire — a commit inside the app repo has no KB in its diff, and
the workspace diff never contains app code. The flagship pattern had no
write-back enforcement at all. How far should the fix go?

## Findings / What We Did

Options considered:

1. **Nested-repo hook** (chosen, user's call) — restores the gate exactly where
   code commits happen, with no new config surface.
2. Document the gap loudly — honest, but leaves the recommended pattern weaker
   than the one it is recommended over.
3. Full multi-repo support (`repos:` list in the config, diffs walked per repo)
   — most capable, but a much larger change and more config to keep true.

Design points that fell out of implementation:

- Evidence cannot be "the KB is in this diff", so `kb_evidence` looks for
  pending changes under the KB dir, then for a KB commit inside a grace window;
  with no git at all it falls back to entry mtimes. Consequence, documented in
  AGENT.md: record the entry BEFORE committing code.
- The hook goes to the nested repo's configured hooks path, and references the
  KB by a path relative to that repo — an absolute path would be one machine's
  layout, and when `core.hooksPath` points into the worktree the line is
  tracked and shared.
- Non-interactive `--mode workspace` wires every nested repo it can see: asking
  is impossible there, and an ungated app repo is the exact failure this mode
  exists to fix.

## Reuse log — two traps found building a demo workspace (2026-09-09)

Standing up `02-demo-app` as a real context workspace surfaced two things that
make the nested gate silently permissive. Neither is a code defect; both are
configuration semantics nobody had written down.

**1. `writeback.code` globs are relative to the diff's repo, not the workspace.**
A nested diff reports `meridian/dunning.py`, not `app/meridian/dunning.py`, so
the natural workspace-relative glob `app/**` never matches and KB011 never
fires. The demo config lists `meridian/**` and `tests/**` instead. Anyone wiring
workspace mode will hit this, and the failure mode is silence — the gate reports
success.

**2. `grace_hours` defaults to 24, which is very permissive in practice.**
Any KB commit in the last day counts as write-back evidence for *any* code
commit in a nested repo. Reasonable for daily use — it stops blocking the
natural "record the entry, commit the KB, then commit the code" order — but it
means the gate will not fire during a demo, or for a developer who touched the
KB that morning for unrelated reasons. The demo sets `grace_hours: 0` so the
mechanism is observable; that setting requires PENDING KB changes at commit time.

Both verified by running the gate in both directions in the demo workspace. Not
changing the defaults: 24h is the right trade-off for real use, and the fix is
documentation plus a louder mention in ADVANCED.md.

## Verification

```
$ "$TMP/knowledge-db/install.sh" --mode workspace --yes | grep nested
CHANGED    nested repo gate installed in app/ (hooks/pre-commit)

$ cd app && git commit -m "feat: log twice"
KB011 src/index.js: code changed but no knowledge-db/ entry touched in /tmp/w1/knowledge-db
      — record the work (likely bucket: solutions/ for features, errors/ for fixes; ...)
kb check: 1 finding(s)
$ git rev-list --count HEAD
1

$ cd .. && knowledge-db/bin/kb new solution log-twice >/dev/null && cd app
$ git commit -m "feat: log twice" | tail -1
 1 file changed, 1 insertion(+)
$ git rev-list --count HEAD
2
```
