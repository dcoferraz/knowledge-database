# Enforcement Guide: The Six Layers

> **Prerequisites:** Read the [README](README.md) first for the basic KB pattern.
> This document explains how the enforcement machinery works, why each layer
> exists, and how to tune it. For the context-workspace pattern, see
> [ADVANCED.md](ADVANCED.md).

---

Rules that live only in an agent's goodwill fail silently. The KB learned this
in the field twice:

1. Conventions "enforced by agent behavior" drifted — tag typos, prose claimed
   as proof, hand-edited indexes (fixed in v0.4.0 by rules KB001-KB013).
2. A decision recorded only in CLAUDE.md produced no KB entry despite full
   enforcement being installed — the rules had never entered the running
   agent's context, and no gate covered doc-only changes (fixed in v0.5.0).

The answer both times: move the guarantee out of the model and into machinery.
`knowledge-db/install.sh` wires six layers; `install.sh --check` audits all of
them and exits non-zero if any is missing.

| # | Layer | Mechanism | Catches |
|---|-------|-----------|---------|
| 1 | KB scaffold | `knowledge-db/` with config, CLI, buckets | Nothing to enforce against otherwise |
| 2 | Stop hook | `.claude/settings.json` runs `kb check` when the agent stops | Invalid entries left behind in a session |
| 3 | Per-prompt rules injection | `.claude/settings.json` UserPromptSubmit hook runs `kb rules` | Rules falling out of context mid-session |
| 4 | Planted rule files | HARD RULE block in 6 runtime files agents auto-ingest | Any agent runtime starting a session blind |
| 5 | Git pre-commit | `.githooks/pre-commit` runs `kb check --staged` | Invalid entries and write-back gaps at commit time |
| 6 | CI | `.github/workflows/kb-check.yml` | `--no-verify` bypasses; drift on PRs |

The layers are deliberately redundant. Each one has a blind spot; together the
blind spots do not overlap.

---

## Layer 3: Per-Prompt Rules Injection

`kb rules` prints a compact hard-rules block:

```
$ knowledge-db/bin/kb rules
<kb-hard-rules source="knowledge-db/AGENT.md">
Durable memory lives in knowledge-db/ (buckets: explorations/, solutions/, errors/, decisions/). ...
1. READ FIRST ...
2. EMPTY KB ...
3. NEVER PROMPT, NEVER WITHHOLD ...
4. WRITE BACK AT THE MOMENT OF INSIGHT ...
</kb-hard-rules>
```

`install.sh` merges a UserPromptSubmit hook running it into the committed
`.claude/settings.json`. Claude Code appends the hook's stdout to the agent's
context on EVERY prompt. Consequences:

- **Mid-session installs work.** CLAUDE.md is read once at session start; a
  rule appended mid-session is invisible until restart. The hook is live from
  the very next prompt.
- **Context loss is survivable.** Long sessions compact old context; the rules
  re-arrive with each prompt.
- **Cost is bounded.** The block is ~200 tokens (bucket names are derived from
  `kb.config.json` at runtime; the full prose stays in `AGENT.md`, which the
  block references).

This layer is Claude Code-specific. Other runtimes have no hook equivalent —
for them, layer 4 is the ceiling.

## Layer 4: Multi-Runtime Rule Planting

One agent runtime seeing the rules is not enough: repos are worked on by
whatever agent the contributor happens to run. `install.sh` plants the same
marker-guarded HARD RULE block into every runtime file the major agents
auto-ingest:

| File | Runtime | Notes |
|------|---------|-------|
| `CLAUDE.md` | Claude Code | Plus layers 2-3 hooks |
| `AGENTS.md` | Codex and agents-md runtimes | |
| `.github/copilot-instructions.md` | GitHub Copilot | Repo-wide instructions |
| `.github/instructions/kb.instructions.md` | GitHub Copilot | Created with `applyTo: '**'` frontmatter so the rule fires on every task/file |
| `.cursor/rules/knowledge-db.mdc` | Cursor | Created with `alwaysApply: true` frontmatter |
| `.windsurfrules` | Windsurf | |

Semantics:

- **Create-or-merge.** A missing file is created (frontmatter included where
  the runtime needs it); an existing file gets the block appended. Nothing is
  ever clobbered.
- **Marker-guarded.** The block sits between `<!-- kb:agent-rules:start -->`
  and `<!-- kb:agent-rules:end -->`; reruns detect the marker and change
  nothing (idempotent).
- **Audited.** `install.sh --check` fails naming exactly the files that lost
  the block.
- **Path-bound.** The rule text references the KB folder by the exact name the
  installer sees (`$KB_NAME`), so a renamed KB never leaves dangling references.

To restrict the target set, delete rows from the `RULE_TARGETS` array in
`install.sh` — the audit mirrors the array, so `--check` stays consistent.

## Layers 5-6: Write-Back Gates (KB011 and KB013)

The write-back rule — non-trivial work ends with a KB entry — is enforced on
diffs, not on trust:

- **KB011 (code):** a staged/PR diff touching `writeback.code` paths without
  touching `knowledge-db/**` fails, naming the likely bucket.
- **KB013 (docs):** the same trigger for `writeback.docs` paths. A doc edit
  that states a rule, constraint, or choice IS a decision — it belongs in
  `decisions/` too. This closes the gap where decisions recorded only in
  CLAUDE.md or an ADR left no KB trace.

Both are configured in `kb.config.json`:

```json
"writeback": {
  "code":   ["src/**", "lib/**", "app/**"],
  "docs":   ["CLAUDE.md", "AGENTS.md", "docs/**", "adr/**"],
  "exempt": []
}
```

Tuning guidance:

- `code`: your production source globs. Generated files and vendored code go
  in `exempt`.
- `docs`: every file where decisions get written down. Add `README.md` if your
  README carries policy; leave it out if README churn is mechanical.
- The gates run in `kb check --staged` (pre-commit) and
  `kb check --diff-base <ref>` (CI on PRs). A plain `kb check` skips them —
  diff rules need a diff.

## Auditing and Repair

```bash
knowledge-db/install.sh --check   # non-zero + MISSING lines if any layer drifted
knowledge-db/install.sh           # repairs exactly what is missing, touches nothing else
```

CI runs `install.sh --check` on every push, so deleting a planted file or
unhooking a setting fails the build — enforcement of the enforcement.

## Timing Caveats

- Planted rule files load at each agent's NEXT session start.
- The UserPromptSubmit hook covers the CURRENT Claude Code session from the
  next prompt.
- The Stop hook validates entry QUALITY; it cannot detect that work happened
  without an entry. That detection is exactly what KB011/KB013 do at diff
  time — the one behavioral gap left is uncommitted work in a runtime without
  prompt injection, which layer 4 covers by keeping the rules in front of the
  agent.

## Bash Portability Note

The enforcement scripts are bash + Python 3 stdlib + git, nothing else. One
hard-won rule for contributors (see
`knowledge-db/errors/2026-08-24-errexit-arithmetic-increment-ci-failure.md`):
under `set -e`, never write `((VAR++))` — from zero it returns status 1 and
bash >= 4.1 kills the script, while macOS bash 3.2 tolerates it. Use
`VAR=$((VAR + 1))`.
