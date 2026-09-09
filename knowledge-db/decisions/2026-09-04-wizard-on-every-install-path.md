---
title: "Setup wizard lives in install.sh and runs on every install path"
type: decision
status: verified
date: 2026-09-04
tags: [area:tooling, layer:cli]
sources:
  - knowledge-db/install.sh:185-265
  - knowledge-db/install.sh:266
  - scripts/init-knowledge-db.sh:142-148
related:
  - 2026-09-04-audit-fixes-v070
---

## Summary

The setup wizard is part of `install.sh` (interactive when stdin and stderr are
TTYs), not a separate `kb setup` subcommand, and every documented install route
ends in it: `init-knowledge-db.sh` hands over by default, and the plugin's
`bootstrap.sh` calls the same installer.

## Context / Question

v0.6.0 installed one fixed set of layers with no questions asked, which is how
non-git workspaces got a half install and how `local`-style users got diff-time
gates that can never pass. Where should the wizard live, and which entry points
should reach it?

## Findings / What We Did

Options considered:

1. **Interactive `install.sh`** (chosen) — one entry point, already the thing
   every doc tells people to run, and already the code that knows about layers.
   `--yes` / `--mode` / `--no-*` flags keep CI and agents unattended.
2. `kb setup` subcommand — cleaner separation, but adds a second command to
   teach and leaves `install.sh` as a trap for anyone who runs it directly.
3. Standalone `scripts/kb-wizard` — not shipped inside a KB folder, so
   installed users could never run it. Same class of mistake as the
   never-installed `scripts/kb-discover`.

Decisive constraint: the wizard must be reachable from an INSTALLED KB, and
`install.sh` is the only script that ships inside `knowledge-db/`.

Interactivity is detected, never assumed: `install.sh:266` runs the wizard only
when `--wizard` is passed or both stdin and stderr are TTYs and `--yes` is not.
Prompts write to stderr so stdout stays the machine-readable report.

## Verification

```
$ printf '2\ny\ny\ny\ny\ny\n' | knowledge-db/install.sh --wizard 2>&1 | grep -E "choice|nested repo gate"
  choice [1] 2
CHANGED    nested repo gate installed in app/ (hooks/pre-commit)

$ knowledge-db/install.sh --yes >/dev/null 2>&1; echo $?
0

$ bash tests/run-tests.sh | tail -2
Results: 29/29 passed
All tests passed
```
