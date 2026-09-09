---
title: "Wizard answers live in .install.json, not in kb.config.json"
type: decision
status: verified
date: 2026-09-04
tags: [area:tooling, layer:enforcement]
sources:
  - knowledge-db/install.sh:44-52
  - knowledge-db/install.sh:113-155
  - knowledge-db/bin/kb:210-213
related:
  - 2026-09-04-wizard-on-every-install-path
  - 2026-09-04-audit-fixes-v070
---

## Summary

`install.sh` records the chosen mode and layers in `knowledge-db/.install.json`.
The first implementation wrote them into `kb.config.json` under an `install`
key; that was wrong and a test caught it.

## Context / Question

`--check` must audit the layers a project actually asked for, so the answers
need to persist somewhere. `kb.config.json` was the obvious home — it is
already the single source of truth for vocabularies.

## Findings / What We Did

The workspace conformance test failed with:

```
KB009 knowledge-db/kb.config.json: changed, but lockstep pair 'knowledge-db/INDEX.md' untouched in this diff
```

This repo declares a lockstep pair between `kb.config.json` and `INDEX.md`
(KB009), so an installer that rewrites the config trips that rule on every run —
and any downstream project with a similar pair would hit the same wall. The
config is a *vocabulary* that projects deliberately constrain; install state is
machine bookkeeping. Different lifetimes, different files.

`.install.json` is dot-prefixed, so `collect_entries` skips it and it needs no
`extra_root_files` declaration (`bin/kb:210-213` skips names starting with `.`).
It is meant to be committed: the team's `--check` should audit the same set.

## Verification

```
$ cat knowledge-db/.install.json
{
  "mode": "in-repo",
  "layers": {
    "agent_hooks": true,
    "git_hooks": true,
    "ci": true,
    "rule_files": true
  },
  "nested_repos": []
}

$ python3 -c "
import json; print('install' in json.load(open('knowledge-db/kb.config.json')))"
False

$ knowledge-db/bin/kb check; echo "exit=$?"
exit=0
```
