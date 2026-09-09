# Changelog

All notable changes to Knowledge Database will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## ![lynx](images/changelog/v0.9.0-lynx.svg) [0.9.0] - 2026-09-08

v0.8.0 gave agents `kb find`, but it never consulted the index it ships: every
search opened every entry, twice (`read_text` plus `parse_entry`) — 80 file reads
for 40 entries. Profiling then showed the reads were not even the problem: ~55ms
of a 58ms lookup was interpreter startup. Both are fixed, and the fast path is
now the documented one.

### Added
- **`.search-index.json`** — a generated search index (title, tags, slug, status,
  summary, cited paths) written by `kb index`. `kb find` reads that ONE file
  instead of N entries. Dot-prefixed, so KB002 ignores it. Fingerprinted by
  entry stats: a hand-edited or newly cloned KB rebuilds it automatically rather
  than serving a stale answer.
- **`kb find --deep`** — force a body scan. It also happens automatically when
  the index yields nothing, and the output says so, so recall never drops
  silently: a term living only in a body section is still found.
- **`kb find -s` / `--show`** — hits plus the top hit's actionable core in one
  invocation. Measured: `find` then `show` cost 105ms; `find -s` costs 55ms,
  because each `kb` call pays ~55ms of Python startup.

### Changed
- **Lazy imports.** `shutil`, `subprocess`, `tempfile`, `io` and `contextlib`
  now load inside the functions that need them (upgrade, git access, the stop
  hook). The lookup path imports none of them.
- **`parse_text()`** split out of `parse_entry()`, so a caller holding the file
  contents no longer re-reads the file. `find` and `show` are single-read.
- The rules now name the one-call path — `kb find "<keywords>" -s` — and rule out
  `ls`, `grep -r` and full INDEX.md reads explicitly. The injected block got
  *smaller* doing it: 238 tokens, against 241 in v0.8.0.

### Measured

| | 40-entry KB | 1,000-entry KB |
|---|---|---|
| startup floor (`kb version`) | 53ms | 56ms |
| `kb find`, index hit | 54ms (1 read) | 59ms (1 read) |
| `kb find --deep` | 62ms | 108ms (1,000 reads) |
| body-only term (auto fallback) | — | 86ms, found |
| `find` + `show` as two calls | 105ms | — |
| `find -s`, one call | 55ms | — |

At 1,000 entries the index cuts search work from ~52ms to ~3ms. At 40 entries it
saves ~4ms and startup dominates — which is why `-s` and the lazy imports matter
more than the index for a small KB, and the index matters more as it grows.

## ![heron](images/changelog/v0.8.0-heron.svg) [0.8.0] - 2026-09-05

A three-arm experiment (same bug twice, with and without the KB, plus a control)
measured what reuse actually costs. The KB-equipped agent cost MORE than the
control, and the trace showed why: nothing in the rules told an agent what
"done" looks like when the KB already had the answer, so it re-authored one; and
the documented lookup path was "read INDEX.md", which is thousands of tokens
before you reach the answer. Both are fixed here.

### Added
- **`kb find "<keywords>"`** — searches titles, tags, slugs and bodies and prints
  only the hits (entry, status, title, summary, sources). Measured against this
  repo's KB: 134-360 tokens versus 2,360 to read `INDEX.md`.
- **`kb show <entry>`** — prints an entry's actionable core (summary, fix,
  prevention, sources) rather than the whole file: 279 tokens versus 709.
  `--all` for the verbatim entry, `--lines N` to cap each section.
  Together: **a reuse costs ~400-650 tokens instead of ~3,000 (79-87% less).**
- **Rule 2, REUSE ENDS IT** — if an entry already answered the task, it is
  finished by refreshing THAT entry (bump `last_verified` with fresh proof, or
  add a one-line reuse note), never by authoring a duplicate. Touching the
  reused entry already satisfies KB011/KB013; nothing had ever said so.

### Changed
- The injected rules now lead with `kb find` / `kb show` and explicitly forbid
  opening `ls`, `find` or all of `INDEX.md` first — the waste seen in the trace.
  Rewritten to stay the same size: 241 tokens per prompt, against 236 before.
- `AGENT.md` gains "LOOK UP FIRST (and cheaply)" with the measured costs, a
  "REUSE ENDS THE TASK" section, and the instruction to state a fix as a diff or
  `file:line` list so the next agent need not reopen the modules.
- **The KB README now says what the thing is FOR** — convergence, proof,
  citations that audit the code, the "why", prevention, continuity — plus where
  it does *not* pay (facts one grep away, solo short projects, fast-churning
  code) and what it costs. The old header claim ("never investigate the same
  thing twice") promised token savings the measurements do not support at small
  scale; the honest version is that agents converge on one answer and can show
  the proof, with token savings as a conditional benefit.

## ![otter](images/changelog/v0.7.0-otter.svg) [0.7.0] - 2026-09-04

An end-to-end audit of v0.6.0 against Claude Code — installing it fresh, in a
non-git workspace, through the plugin, and reading the docs as a new user —
turned up thirteen findings. Everything mechanically enforced worked; everything
at the edges did not. This release fixes all of them, and the installer now asks
how you want to use the KB instead of assuming.

### Added
- **Setup wizard.** `install.sh` run in a terminal asks three questions —
  layout (`in-repo` / `workspace` / `local`), agent wiring, git-time gates — and
  installs exactly that. Answers are recorded in `knowledge-db/.install.json`
  (not in `kb.config.json`, which projects put under lockstep rules), so
  `install.sh --check` audits what the project asked for instead of a fixed
  ideal. Piped, in CI, or with `--yes` it asks nothing and
  installs the default set. Flags: `--mode`, `--wizard`, `--yes`, `--no-ci`,
  `--no-git-hooks`, `--no-agent-hooks`, `--no-rule-files`.
  Every install path (`init-knowledge-db.sh`, the plugin's `bootstrap.sh`,
  a bare `install.sh`) now ends in the same wizard, so there is no half-wired
  install.
- **`kb discover <dir>` and `kb ingest`** are part of the CLI that ships inside
  every KB folder. AGENT.md had told agents to run `scripts/kb-discover` and
  `scripts/kb-ingest` since v0.2.0, but no install ever copied those scripts —
  the rules pointed at tools that were not there. Both now also emit entries
  that pass `kb check` unchanged (tags filtered to the declared vocabulary,
  sources cited as `path:line`, no template residue); the old scripts remain as
  forwarding shims.
- **`kb stop-hook`**: the loop-safe wrapper the Stop hook runs. Exit 2 makes
  Claude Code hand the findings back to the model and keep working, but the hook
  payload's `stop_hook_active` is honored, so a finding the model cannot fix
  reports once instead of looping forever.
- **`SubagentStop` hook**: work delegated to a subagent is held to the same
  standard as work in the main thread. Only `Stop` was wired before.
- **Workspace-mode write-back gate.** In the context-workspace pattern the app
  lives in a nested repo the workspace ignores, so the KB could never appear in
  that repo's diff and KB011/KB013 silently passed forever. `install.sh --mode
  workspace` now plants a hook inside each nested repo running
  `kb check --staged --repo <that repo>`; evidence of write-back is pending KB
  changes in the workspace, or a KB commit inside `writeback.grace_hours`
  (default 24).
- **`kb upgrade` + an update notice — an actual update path.** Until now the
  only way to move an installed KB to a newer version was the manual 8-step
  walkthrough in UPGRADING.md, and nothing ever told you a new version existed:
  `kb version`/KB014 only compared the vendored tool against your own config,
  and `claude plugin update` refreshes the plugin payload while leaving the
  `knowledge-db/` folder — where the tool actually lives — untouched.
  `kb upgrade` backs the KB up, vendors tooling only (`bin/kb`, `install.sh`,
  `AGENT.md`, `README.md`, `_TEMPLATE.md`), bumps `kb_version`, regenerates the
  index, reruns `install.sh` (so stale rule blocks are replanted and hooks
  migrated), and prints `kb check` findings as a migration list instead of
  failing. `--dry-run`, `--source`, `--no-network`, `--no-install`, `--force`
  and `--strict` are all supported. Sources are resolved newest-first (plugin
  marketplace clone, sibling checkout, then a shallow clone), never
  first-found. `kb version` now reports an available update from local
  checkouts, `kb version --check` probes upstream, and `kb check` carries the
  same notice as a warning-only KB014 line — neither ever blocks, and `check`
  stays read-only.
- **`bootstrap.sh` is get-or-refresh.** With no KB it scaffolds and runs the
  wizard; with a KB present it upgrades the tooling in place. That is the only
  way to update an install from before v0.7.0, whose `bin/kb` has no `upgrade`
  subcommand and so cannot update itself.
- **`kb rules --plant` / `--targets`**: the canonical HARD RULE block and the
  runtime-file list, generated by the tool.
- **`knowledge-database/bootstrap.sh`** in the plugin payload. The published
  plugin ships the skill only, so the skill's old instruction ("copy the FULL
  knowledge-db/ skeleton", including the 1000-line CLI) had no source to copy
  from. The script finds one — the plugin's marketplace clone, a sibling
  checkout, else a shallow clone — and hands over to the wizard.

### Changed
- **Planted rule blocks are refreshed, not frozen.** The marker guard that made
  planting idempotent also froze the text: a repo upgraded across versions kept
  whatever an old installer wrote, while `install.sh --check` reported "IN
  PLACE". The block now comes from `kb rules --plant` and a stale region is
  replanted in place; `--check` names stale files, and KB014 warns about them.
- **KB008 (staleness) is opt-in and warns by default.** It used to fail hard at
  90 days, so a KB written on one day began blocking every commit and every
  agent Stop hook on the same later day, all at once. No `staleness_days.verified`
  in the config means nothing expires; a declared budget warns; `"mode": "error"`
  restores the gate. Shipped configs declare no budget.
- **KB003 resolves `@rev` in the repo that owns the file.** A pinned source
  inside a nested repo used to produce no drift warning ever, because the
  workspace-level `git diff` returns empty for untracked nested paths.
- **`install.sh` survives a non-git project.** It used to die at
  `git config core.hooksPath` with `fatal: not in a git directory` (exit 128)
  under `set -e`, half-installed, with the CI and rule-planting layers never
  reached and the report never printed — and every rerun died at the same line,
  so those layers could never be repaired. This is exactly the shape ADVANCED.md
  recommends for a context workspace. Git-time layers are now skipped with a
  reason, and the report prints from an EXIT trap.
- **`supersede_with_consent` is a real switch.** It was documented in CLAUDE.md
  and implemented nowhere; it now lives in `kb.config.json` and `kb rules`
  injects the consent wording into every prompt when set.
- Documentation: ADVANCED.md's workspace recipe now creates a git repo and runs
  the wizard (it previously produced a workspace with zero enforcement layers),
  and its example decision entry passes `kb check` (it failed KB002 and KB004);
  the upgrade guide covers replanting and the KB008 change; stale `KB001-KB011`
  / `KB001-KB013` rule ranges are corrected, and the planted range is generated
  from the tool so it cannot drift again.

### Removed
- `hooks/kb-session-check.sh`: referenced by nothing, depended on `jq` against
  the project's zero-dependency claim, and emitted
  `hookSpecificOutput.additionalContext` for the Stop event, which is not a
  Stop-hook field. `kb stop-hook` replaces the idea properly.

## ![toucan](images/changelog/v0.6.0-toucan.svg) [0.6.0] - 2026-08-24

### Added
- **KB015 — changelog art (config-gated)**: declare `changelog_art` in
  `kb.config.json` and every released version heading in the changelog must
  start with a small SVG artwork at the left of the title. The SVG must exist,
  live under the declared dir, and be unique per version; the convention is a
  small random animal per release. Off unless configured. Conformance fixture
  included.
- Thirteen hand-drawn flat animal SVGs under `images/changelog/` (fox, owl,
  cat, rabbit, whale, hedgehog, penguin, bee, turtle, frog, koala, octopus,
  toucan) — every release since v0.1.0 retroactively illustrated, headings
  rewritten to the enforced format.

### Changed
- This repo's `kb.config.json` enables `changelog_art`, so the rule now gates
  its own releases.

## ![octopus](images/changelog/v0.5.3-octopus.svg) [0.5.3] - 2026-08-24

Response to the first real downstream upgrade (field report from a project
moving an older minimal KB copy to v0.5.2): the upgrade worked but was fully
manual, version drift was invisible, and a project-specific root file had no
config escape.

### Added
- **`kb version` + KB014 (warning-only)**: `kb.config.json` now records the
  tool version that wrote it (`kb_version`); `kb check` warns on a missing or
  mismatched value so independently-upgraded tooling and config are visible.
  `kb version` prints both.
- **`extra_root_files` config key**: project-specific files at the KB root
  (e.g. `RELEASES.md`) can be declared instead of failing KB002 — extend the
  config, never patch `KNOWN_ROOT_FILES` in the vendored CLI.
- **UPGRADING.md**: field-verified upgrade guide — vendor the tooling, adapt
  the config, migrate the entries; the trap list (generated INDEX, strict
  sources grammar, honest KB004 downgrades, closed statuses, recent-but-false
  verified entries) and the audit-first note for `install.sh`.
- Conformance tests: `kb version` output, KB014 drift warning, KB002
  root-file escape (suite now 27 tests).

## ![koala](images/changelog/v0.5.2-koala.svg) [0.5.2] - 2026-08-24

### Added
- **ENFORCEMENT.md**: dedicated guide for the six-layer enforcement machinery —
  layer table with what each catches, per-prompt rules injection mechanics,
  multi-runtime rule planting semantics and `RULE_TARGETS` tuning, KB011/KB013
  write-back gate configuration, drift audit/repair, timing caveats, and the
  bash errexit portability rule. Linked from the README guides section.
- **ADVANCED.md "The Human Window"**: INDEX.html section for non-technical
  stakeholders — zero-tooling browsing, plain-language navigation, proof
  navigation down to cited source lines, decision attribution, single-file
  sharing, KB012 freshness guarantee.

## ![frog](images/changelog/v0.5.1-frog.svg) [0.5.1] - 2026-08-24

### Fixed
- CI-only failure of the legacy kb-lint suite: `set -e` + `((VAR++))` from zero
  kills the script on bash >= 4.1 (ubuntu CI) while macOS bash 3.2 tolerates it.
  All counter increments in `scripts/kb-lint` and `scripts/kb-ingest` rewritten
  as errexit-safe `VAR=$((VAR + 1))` assignments. Red since v0.4.1.

## ![turtle](images/changelog/v0.5.0-turtle.svg) [0.5.0] - 2026-08-24

Response to field failure and external parity feedback: enforcement content
existed, but the delivery mechanism auto-loaded for only one agent runtime and
only from session start. v0.5.0 makes the rules reach every major agent runtime
with zero human steps, and closes the doc-only-decision write-back gap.

### Added
- **Per-prompt rules injection**: new `kb rules` subcommand prints a compact
  `<kb-hard-rules>` block; `install.sh` merges a UserPromptSubmit hook running it
  into `.claude/settings.json`. Rules enter agent context on EVERY prompt —
  active immediately after a mid-session install, immune to context loss.
- **Multi-runtime rule planting**: `install.sh` now plants the HARD RULE block
  into every runtime file the major agents auto-ingest — `CLAUDE.md`,
  `AGENTS.md`, `.github/copilot-instructions.md`,
  `.github/instructions/kb.instructions.md` (with `applyTo: '**'` frontmatter),
  `.cursor/rules/knowledge-db.mdc` (with `alwaysApply: true`), `.windsurfrules`.
  Marker-guarded create-or-merge, idempotent; `--check` fails if any target
  loses the block. Replaces the single-host-file behavior.
- **KB013 — doc write-back trigger**: a staged/PR diff touching
  `writeback.docs` paths (default: CLAUDE.md, AGENTS.md, `docs/**`, `adr/**`)
  without touching `knowledge-db/**` fails — a doc edit that states a rule,
  constraint, or choice is a decision and belongs in `decisions/` too.
  Conformance fixture included.
- Installer conformance tests: all-6-files planted, frontmatter shapes,
  idempotent rerun, drift detection (suite now 23 tests).

### Changed
- `install.sh` output notes that planted rule files load at each agent's next
  session start while the UserPromptSubmit hook covers the current Claude Code
  session from the next prompt.
- `kb.config.json` `writeback` gains a `docs` glob list alongside `code`.

## ![bee](images/changelog/v0.4.1-bee.svg) [0.4.1] - 2026-08-24

### Added
- **`INDEX.html` — self-contained human-facing KB browser** for non-technical readers, generated by `kb index` alongside INDEX.md. Double-click to open; zero dependencies, no server, no external assets, works offline and survives email/Slack as a single file.
  - Every entry inlined with plain-language bucket labels, search box, status filter
  - **Proof navigation**: Verification evidence rendered per entry; every `sources:` citation expandable to the actual cited source lines (embedded at build time)
  - Decisions show `decided by:` attribution; superseded entries carry a "replaced by" banner linking the replacement; related entries cross-link as in-page anchors
- **KB012**: `INDEX.html` freshness enforced via embedded fingerprint of KB content (generated INDEX.md + entry files). Embedded source snippets are deliberately outside the fingerprint — a KB007-style byte check would fail on every unrelated code edit. Conformance fixture included (suite now 16 tests).

## ![penguin](images/changelog/v0.4.0-penguin.svg) [0.4.0] - 2026-08-24

Response to external evaluator feedback: conventions that were "enforced by
agent behavior" drifted in practice (INDEX tag drift, prose-only "verified"
proof, hypothetical output as evidence). v0.4.0 makes every hard rule
mechanically enforced or explicitly labelled guidance.

### Added
- **`knowledge-db/bin/kb`**: zero-dependency CLI (Python 3 stdlib) — `new` (scaffold valid entries, status tentative), `index` (INDEX.md is now GENERATED from front-matter), `check` (rules KB001-KB011, `--json`, `--staged`/`--diff-base` diff modes)
- **`knowledge-db/kb.config.json`**: single source of truth for buckets, statuses, tag vocabulary, staleness budgets, lockstep pairs, write-back paths — closed enums (KB002)
- **Rule IDs KB001-KB011**, each with a conformance fixture (`tests/fixtures/`, `tests/run-kb-tests.sh`: pass/ exits 0, each fail/KBxxx exits non-zero naming its ID)
- **`knowledge-db/install.sh`**: idempotent, merging installer for three enforcement layers — agent Stop hook in committed `.claude/settings.json`, `.githooks/pre-commit` + `core.hooksPath`, CI workflow; `--check` audits without changing anything
- **Staleness budget (KB008)**: `verified` older than 90 days fails until re-verified (`last_verified` field) or downgraded
- **Write-back trigger (KB011)**: replaces the end-of-task checklist as the hard gate — a diff touching production code but no `knowledge-db/**` file fails
- **Source rev pinning (KB003)**: `path:Lstart-Lend@rev` warns when the file changed since the rev

### Changed
- INDEX.md is build output (KB007: byte-for-byte match); hand-edits only inside `kb:manual` fenced regions
- knowledge-db/README.md rewritten enforce-or-delete: every hard rule cites its ID; unenforceable items moved to an explicit "Guidance (not checked)" section
- `.claude/settings.json` is now committed (personal overrides stay in gitignored `settings.local.json`)

### Fixed
- Tag drift between entry front-matter and INDEX rows (3 rows); undeclared `area:release` tag now declared in config
- Four decision entries claimed `verified` with prose-only Verification; now carry captured command output (KB004)
- Hypothetical marker `# Works without any dependency installation` used as proof in bash-for-cli-tools decision; replaced with real evidence

### Added (agent-rules forwarding)
- **`knowledge-db/AGENT.md`**: portable agent hard rules that travel with the KB folder — ALWAYS read first, EMPTY KB (suggest exploration or manual document/context input, then continue), NEVER PROMPT / NEVER WITHHOLD, write back
- **install.sh layer 5**: appends a marker-guarded HARD RULE block to the host instructions file (CLAUDE.md / AGENTS.md / copilot-instructions.md; creates CLAUDE.md if none); `--check` asserts it
- `scripts/init-knowledge-db.sh` now ships the full enforcement (AGENT.md, kb.config.json, bin/kb, install.sh) and generates INDEX.md via `kb index`

### Changed (behavior)
- **Mechanism 9 flipped**: autonomous superseding with audit trail replaces consent prompts. Agents never prompt about KB operations; superseding a verified entry requires reason + `related:` link (KB005), not permission. Opt-in `supersede_with_consent: true` restores prompting.
- **KB tracked by default**: `init-knowledge-db.sh` no longer gitignores the KB (`--local` opts in) — a gitignored KB breaks KB011 diff enforcement and loses knowledge across clones

### Deprecated
- `scripts/kb-lint` — superseded by `bin/kb check` (kept for compatibility)

## ![hedgehog](images/changelog/v0.3.1-hedgehog.svg) [0.3.1] - 2026-08-21

### Fixed
- **Security**: Command injection via unsanitized directory path in kb-discover
- **Security**: Path traversal in kb-ingest --kb-dir flag
- **Security**: Temp file race condition in kb-lint (now uses mktemp)
- **Portability**: sed -i.bak macOS-only syntax now works on Linux
- **DoS prevention**: Added 1MB input size limit to kb-ingest

### Changed
- Mechanism 6 (SCOPES) clarified: repo/session only, user-scope moved to Phase 2
- Removed generic trigger phrases ("start of task") from SKILL.md
- Added archival guidance for INDEX.md at scale (100+ entries)
- Added "when to split" heuristic for entry granularity

## ![whale](images/changelog/v0.3.0-whale.svg) [0.3.0] - 2026-08-21

### Added
- **Incremental Capture** (Mechanism 10): Record findings as they occur, not batched at session end
- **Entry Granularity guidance**: decisions/ = one entry per choice, not per session
- **Session Resilience section**: Explicit guidance on protecting against session loss

### Changed
- Upgraded from 9 to 10 enforcement mechanisms
- WRITE loop renamed "as insights occur" instead of "end of task"
- HARD-RULE block now includes INCREMENTAL line

### Fixed
- Pattern violation where multiple decisions consolidated into single entry

## ![rabbit](images/changelog/v0.2.2-rabbit.svg) [0.2.2] - 2026-08-21

### Added
- Clear auto-capture trigger table (what records, what doesn't)
- Priority guidance (errors > investigations > decisions > solutions)
- "Rename with reasoning" now triggers recording (it's a decision)

### Changed
- Rule of thumb: "If there was reasoning, record it. Future you will ask why?"

## ![cat](images/changelog/v0.2.1-cat.svg) [0.2.1] - 2026-08-21

### Changed
- Auto-capture is now mandatory, not an optional prompt
- Non-trivial work automatically creates KB entry
- User reviews entry content, not whether to create it

## ![owl](images/changelog/v0.2.0-owl.svg) [0.2.0] - 2026-08-21

### Added
- **Auto-capture enforcement** (Mechanism 8): Always prompt user at task end to create KB entry
- **Consent for superseding** (Mechanism 9): Ask before marking verified entries as superseded
- **Test suite**: 23 tests covering all CLI tools (init, lint, ingest, discover)
- **Security**: Input sanitization for YAML and sed injection prevention
- **.gitignore handling**: init script auto-adds knowledge-db/ to .gitignore
- **Worked examples**: Real KB entries demonstrating the pattern

### Changed
- Upgraded from 8 to 9 enforcement mechanisms
- kb-lint --fix now uses awk instead of sed for safer INDEX.md updates
- Phase 1 milestones updated to reflect completion status

### Fixed
- YAML injection vulnerability in kb-ingest (title/tags)
- sed injection vulnerability in kb-lint --fix
- Template tags no longer flagged as typos in kb-lint

## ![fox](images/changelog/v0.1.0-fox.svg) [0.1.0] - 2026-08-20

### Added
- Initial release
- Four-bucket structure (explorations, solutions, errors, decisions)
- Eight enforcement mechanisms
- CLI tools: init-knowledge-db.sh, kb-ingest, kb-discover, kb-lint
- CLAUDE.md with HARD RULE pattern
- Advanced Usage guide (Context Workspace pattern)
- Roadmap for Phase 2 (git hooks) and Phase 3 (GitHub Action)

[0.6.0]: https://github.com/dcoferraz/knowledge-database/compare/v0.5.3...v0.6.0
[0.5.3]: https://github.com/dcoferraz/knowledge-database/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/dcoferraz/knowledge-database/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/dcoferraz/knowledge-database/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/dcoferraz/knowledge-database/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/dcoferraz/knowledge-database/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/dcoferraz/knowledge-database/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/dcoferraz/knowledge-database/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/dcoferraz/knowledge-database/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/dcoferraz/knowledge-database/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/dcoferraz/knowledge-database/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/dcoferraz/knowledge-database/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dcoferraz/knowledge-database/releases/tag/v0.1.0
