---
title: Bash for Phase 1 CLI tools
type: decision
status: verified
date: 2026-08-20
tags: [area:tooling, layer:cli]
sources:
  - roadmap/phases/phase-1-local-tooling.md:15-30
  - scripts/kb-ingest:1-5
  - scripts/kb-discover:1-5
  - scripts/kb-lint:1-5
related:
  - explorations/2026-08-20-cli-tool-architecture.md
decision_by: Project maintainer
---

## Summary

Chose bash scripting for Phase 1 CLI tools (kb-ingest, kb-discover, kb-lint) over compiled alternatives. Enables zero-dependency installation and rapid iteration at the cost of scalability.

## Context / Question

Need CLI tools for Knowledge Database. Options: bash, Python, Node.js, Go, Rust.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Bash** | Zero deps, universal, fast iteration | No types, hard to test, won't scale |
| Python | Readable, rich stdlib | Requires Python install, venv complexity |
| Node.js | Match JS-heavy agent ecosystem | Requires Node, npm complexity |
| Go | Single binary, fast, types | Compile step, slower iteration |
| Rust | Fastest, safest | Slowest iteration, overkill for Phase 1 |

## Decision

Bash for Phase 1. Reasoning:

1. **Zero-friction install**: `git clone` + `chmod +x` = working tools
2. **Universal availability**: bash exists on macOS, Linux, WSL
3. **Rapid iteration**: No compile step during active development
4. **Acceptable scope**: Phase 1 tools are simple text processors

## Consequences

### Accepted Trade-offs

- **No type safety**: Errors caught at runtime only
- **Testing complexity**: Bash testing requires temp directories, sed assertions
- **Scale ceiling**: At ~500 LOC per script, consider rewrite

### Migration Path (Phase 2+)

When any of these trigger, migrate to Go:
- Script exceeds 500 lines
- Need concurrent operations (parallel file processing)
- Need to distribute single binary
- Performance becomes bottleneck

See roadmap/phases/phase-2-git-hooks.md for planned migration.

## Verification

Tools work as documented:
```bash
$ ./tests/run-tests.sh
Results: 23/23 passed
All tests passed
```

Install friction minimal: `init-knowledge-db.sh` uses only bash + coreutils, and the test run above executed it with no dependency installation step.
