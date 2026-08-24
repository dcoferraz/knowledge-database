---
title: "Python 3 stdlib (not bash, not Node) for the kb enforcement CLI"
type: decision
status: verified
date: 2026-08-24
tags: [area:tooling, layer:cli, tech:python]
sources:
  - knowledge-db/bin/kb:1-40
  - knowledge-db/kb.config.json:1-36
related:
  - decisions/2026-08-20-bash-for-cli-tools.md
  - solutions/2026-08-24-kb-enforcement-tooling.md
---

## Summary

`bin/kb` is a single-file Python 3 stdlib script: no package manager, no lockfile, no YAML dependency (parses the flat front-matter schema directly). Node was the alternative for repos with a package.json; this repo has none, so Python 3 is the runtime every target machine already has.

## Context / Question

The 2026-08-20 decision chose bash for Phase 1 helpers (ingest/discover/lint). The enforcement CLI needs JSON config parsing, byte-exact text generation, and structured rule reporting — bash string handling was already the source of portability bugs (sed -i macOS/Linux) and cannot parse kb.config.json without jq (a dependency). Options: extend bash, Node single-file, Python 3 stdlib.

## Findings / What We Did

Python 3 stdlib: `json` module for config and `--json` reports, `re` for the source grammar, `subprocess` for git diff rules, no third-party imports (knowledge-db/bin/kb:22-28). The rule from the design: Node zero-dep if the repo has a package.json, else Python 3 stdlib — that is the only genuine per-repo choice. This does NOT supersede the bash decision: kb-ingest/kb-discover remain bash; kb-lint is deprecated in favor of `kb check`.

## Verification

Complete import list is stdlib-only (captured 2026-08-24):

```bash
$ sed -n '22,28p' knowledge-db/bin/kb
import argparse
import json
import re
import subprocess
import sys
from datetime import date, datetime, timedelta
from pathlib import Path
$ tests/run-kb-tests.sh
Results: 14 passed, 0 failed
All KB conformance tests passed
```
