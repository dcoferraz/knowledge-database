---
title: "Update path: kb upgrade vendors tooling only, plus a passive notice"
type: decision
status: verified
date: 2026-09-04
tags: [area:tooling, area:release, layer:cli]
sources:
  - knowledge-db/bin/kb:1290-1330
  - knowledge-db/bin/kb:1395-1470
  - knowledge-database/bootstrap.sh:60-90
related:
  - 2026-09-04-audit-fixes-v070
  - 2026-08-24-downstream-upgrade-field-report
---

## Summary

End users get `kb upgrade` (self-update, tooling only, backup first) and a
passive "newer version available" notice from `kb version` and a warning-only
KB014 line. Sources resolve newest-first from local checkouts, falling back to a
shallow clone. `bootstrap.sh` became get-or-refresh so pre-v0.7.0 installs —
which have no `upgrade` subcommand — can still be updated.

## Context / Question

v0.6.0 had no update path at all. `UPGRADING.md` was a manual 8-step
walkthrough; `kb version` + KB014 compared the vendored tool against the local
config and so could never know upstream had shipped something newer;
`claude plugin update` refreshes the plugin payload (`SKILL.md`) while leaving
`knowledge-db/bin/kb` — where the tool actually lives — frozen; `bootstrap.sh`
scaffolded only when the KB was absent. Same shape as the audit's frozen
rule-block finding: drift with no signal.

## Findings / What We Did

Decisions taken:

1. **Self-update command, plus a notice** (over "command only" or "notice
   only"). A notice with no command leaves the manual copy in place; a command
   nobody knows to run leaves people on old versions indefinitely.
2. **Local sources, then network** (over local-only or an explicit `--source`
   only). A plugin install already has the marketplace clone and a developer
   usually has a checkout, so the common upgrade needs no network; the clone is
   a last resort and `--no-network` disables it.
3. **Tooling only, never the config or entries.** `TOOLING_FILES` is the whole
   copy list. Every trap in the downstream field report came from copying more
   than that: upstream's `kb.config.json` is a different closed vocabulary, its
   entries document the tool rather than your project, and `INDEX.*` is build
   output. New keys in the upstream default config are *reported*, never merged.
4. **`kb check` findings are a migration list, not an upgrade failure.** The
   upgrade succeeded; re-anchoring sources and re-verifying claims is human
   work. `--strict` exists for CI.

Three bugs found while building, each fixed and covered by a test:

- Source resolution took the FIRST candidate, so a marketplace clone pinned to
  an old commit shadowed a current checkout. Both the Python and the bash
  resolver now pick the newest, and the bash one refuses a source that is older
  than the install or predates `kb upgrade`.
- "installed" printed the RUNNING tool's version, which is wrong in the case
  that matters most: upgrading an old KB by running the new tool with
  `--kb-dir`. `installed_version()` reads the target KB's own `bin/kb`.
- `newer_upstream()` wrote its cache during `kb check`, making a validator
  mutate the KB it validates. The probe is now read-only; only
  `version --check` and `upgrade` refresh `.upgrade-cache.json`.

Everything after the vendor step runs through the NEW binary as a subprocess —
the running process is the old code, so calling its own `cmd_index` / `cmd_check`
would silently apply the old rules.

## Verification

```
$ knowledge-db/bin/kb --kb-dir /tmp/upg1/knowledge-db upgrade --source "$PWD"
source      /Users/.../01-app/knowledge-database (0.7.0)
installed   0.6.0
backup      /var/folders/.../kb.backup-fx_wm5ef/knowledge-db
vendored    bin/kb install.sh AGENT.md README.md
kept        entries, INDEX.*, kb.config.json vocabularies
bumped      kb_version 0.6.0 -> 0.7.0
reindexed   INDEX.md + INDEX.html
replanted   6 runtime file(s)
kb check    clean, 1 warning(s) to look at:
  WARN KB008 knowledge-db/explorations/2026-06-01-billing-flow.md: verified 95d ago (budget 90d)

$ cd /tmp/upg1 && python3 -c "
import json; d=json.load(open('knowledge-db/kb.config.json'))
print(d['tags']['area'], d['extra_root_files'], d['kb_version'])"
['billing', 'portal'] ['NOTES.md'] 0.7.0

$ bash tests/run-kb-tests.sh | tail -2
Results: 65 passed, 0 failed
All KB conformance tests passed
```
