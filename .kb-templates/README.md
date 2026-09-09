# Knowledge Database

This folder is the project's **durable memory**: what is true, what we did, what
broke, and why we chose things — each claim tied to a source file and, when
marked `verified`, to captured proof.

## What it is for

**Your agents give the same answer twice, and can show their work.**

That is the claim this design actually supports. A worked example, measured:
three agents fixed the same money-rounding bug in the same codebase. The two
without the KB produced two *different* correct fixes — one exposed
`round_money(amount)`, the other `to_decimal` + `round_money(value)` +
`percent_of(amount, pct)`. The one with the KB reconstructed the recorded fix
from its spec: same API, same four call sites, same line numbers. All three were
correct; only one was *consistent with what the team already had*.

What you get, in order of how reliably it shows up:

| | What it does | Enforced by |
|---|---|---|
| **Convergence** | Agents and people reach the answer already agreed on, instead of a new equivalent one. Drift is the real cost of no memory | the entry itself |
| **Proof, not assertion** | `verified` demands a fenced block of real command output. Hypothetical markers are rejected, so a plausible-sounding claim cannot be filed as fact | KB004 |
| **Memory that audits the code** | Entries cite `path:line`. When the code they describe disappears or moves, the check says so — documentation that notices when it goes stale | KB003 |
| **The "why"** | Options considered and rejected, and who decided. Git records what changed; code records what is; neither records why | `decisions/` |
| **Prevention that outlives the entry** | An `errors/` entry must state Prevention — often a grep gate or a required test case, which keeps working after everyone forgets the incident | KB006 |
| **Continuity** | A new session recovers a long investigation from a few hundred tokens instead of a transcript that is gone, unsearchable, and unverified | `kb find` / `kb show` |

## Where it pays, and where it does not

Use it when knowledge is **expensive to acquire and cheap to state**, and when
**more than one reader** will need it:

- multi-day investigations, non-obvious traps, "why is it like this"
- teams, agent fleets, onboarding — value scales with *readers*, not writers
- long-lived repos where people leave and the reasoning leaves with them
- regulated or audited work, where a claim needs a receipt

Do not bother when:

- the fact is one grep away — recording it costs more than rediscovering it
- the project is solo and short-lived
- the code churns faster than entries can be re-verified; stale memory is worse
  than none, which is why KB003 warns and KB008 exists

**Token savings are a conditional benefit, not the pitch.** Reuse is cheap
(`kb find` + `kb show` is roughly 400-650 tokens against ~3,000 for scanning
`INDEX.md` and reading a full entry), but *writing* a good entry costs more than
one small lookup saves. It pays back when an answer is read many times, or when
the investigation behind it was expensive. `scripts/kb-benchmark` measures this
against your own KB rather than asking you to trust a number.

## What it costs

- ~240 tokens injected per prompt (the hard rules)
- one `kb find` per task, one `kb show` per answer used
- writing an entry when — and only when — the knowledge is new

Every hard rule below has a stable ID (KB001-KB015) and is enforced by `bin/kb check`.
A rule without an ID is not a rule — anything unenforceable lives in the
"Guidance (not checked)" section at the bottom. Vocabularies (buckets, statuses,
tags, staleness budgets, lockstep pairs) live in ONE place: `kb.config.json`.
To add a bucket, status, or tag, edit the config — never just create a folder or
type a new value into an entry (KB002).

## The Loop (Mandatory, Not Opt-In)

Every non-trivial task:

1. **LOOK UP FIRST** — one call: `kb find "<keywords>" -s`. Not `ls`, not `grep -r`,
   not a full read of INDEX.md. A `verified` entry is proven: apply it and STOP.
2. **DO THE WORK** — Explore or implement.
3. **WRITE BACK, OR REFRESH** — New knowledge gets an entry. Knowledge the KB
   already held gets the *existing* entry refreshed (bump `last_verified` with
   fresh proof, or add a reuse note) — never a duplicate. Enforced by KB011
   (production code) and KB013 (decision-bearing docs): a diff that touches those
   paths but no `knowledge-db/` file fails `kb check --staged` / `--diff-base`.
   Touching the entry you reused satisfies both.

"Non-trivial" = anything requiring search, reading multiple files, debugging, or making decisions.

## Tooling

```bash
knowledge-db/bin/kb find "<keywords>" -s   # search + the top hit's fix in ONE call — START HERE
knowledge-db/bin/kb find "<keywords>"      # hits only
knowledge-db/bin/kb find "<keywords>" --deep  # force a full-text scan of entry bodies
#                                             (automatic when the index misses; the hit
#                                             list then says which tier answered)
knowledge-db/bin/kb show <entry>        # one entry's actionable core (summary + fix + sources)
knowledge-db/bin/kb show <entry> --all  # the entry verbatim
knowledge-db/bin/kb new <type> <slug>   # scaffold a valid entry (status: tentative), regen INDEX
knowledge-db/bin/kb index               # regenerate INDEX.md + INDEX.html from entry front-matter
knowledge-db/bin/kb check               # validate; exits non-zero with "RULE_ID file: message"
knowledge-db/bin/kb check --staged      # + diff rules (KB009, KB011, KB013) against staged changes
knowledge-db/bin/kb check --staged --repo <path>   # diff a NESTED repo against this KB (workspace mode)
knowledge-db/bin/kb check --json        # machine-readable report
knowledge-db/bin/kb rules               # print agent hard-rules block (prompt-injection hooks)
knowledge-db/bin/kb rules --plant       # print the HARD RULE block install.sh plants (canonical text)
knowledge-db/bin/kb discover <dir>      # scan a directory into a tentative exploration entry
knowledge-db/bin/kb ingest              # turn a doc/transcript (file or stdin) into a draft entry
knowledge-db/bin/kb stop-hook           # loop-safe `check` for agent Stop/SubagentStop hooks
knowledge-db/bin/kb version             # tool version + config kb_version + any available update
knowledge-db/bin/kb version --check     # probe upstream for a newer version (may clone)
knowledge-db/bin/kb upgrade --dry-run   # what a tool upgrade would change
knowledge-db/bin/kb upgrade             # vendor a newer tool: TOOLING ONLY, entries untouched
```

Updating: `kb upgrade` backs the KB up, vendors `bin/kb`, `install.sh`,
`AGENT.md`, `README.md` and `_TEMPLATE.md` from the newest source it can find
(plugin marketplace clone, sibling checkout, then a shallow clone — `--no-network`
to stay offline), bumps `kb_version`, regenerates the index, reruns `install.sh`
(replanting stale rule blocks), and prints any `kb check` findings as a migration
list. It never copies upstream's entries, `kb.config.json` or `INDEX.*`. A KB
older than v0.7.0 has no `upgrade` subcommand — run the new tool against it with
`--kb-dir`, or use the plugin's `bootstrap.sh`. See UPGRADING.md.

Zero dependencies: Python 3 stdlib only.

`install.sh` wires enforcement and, run interactively, first asks how you want to
use the KB:

| Mode | KB lives | Git-time gates |
|------|----------|----------------|
| `in-repo` | committed inside this repo (default) | pre-commit + CI on this repo |
| `workspace` | above one or more nested app repos, next to specs/meetings | pre-commit planted INSIDE each nested repo, gated against this KB |
| `local` | gitignored personal memory | none — a gitignored KB never appears in a diff |

```bash
knowledge-db/install.sh            # wizard when interactive, default install when piped/CI
knowledge-db/install.sh --yes      # no questions, full default set
knowledge-db/install.sh --mode workspace
knowledge-db/install.sh --check    # assert it is still wired (and still current)
```

Layers: agent hooks in `.claude/settings.json` (Stop + SubagentStop run
`kb stop-hook`, UserPromptSubmit runs `kb rules`), the HARD RULE block planted in
the 6 runtime files the major agents auto-ingest, git pre-commit, and CI. The
planted text comes from `kb rules --plant`, so a block left over from an older
version is **replanted**, not skipped (KB014 warns about it too).

## Folder Structure

```
knowledge-db/
  README.md        <- You are here (rules, each with an ID)
  AGENT.md         <- Portable agent hard rules (read-first, empty-KB, never-prompt)
  INDEX.md         <- GENERATED by `kb index` — hand-edit only inside kb:manual regions (KB007)
  INDEX.html       <- GENERATED human-facing view: entries + proof + cited source lines (KB012)
  kb.config.json   <- Single source of truth for all vocabularies (KB002)
  .install.json    <- What install.sh was asked to wire (mode + layers); commit it
                      so the team's --check audits the same set
  .upgrade-cache.json <- Last known upstream version (cache; safe to delete or ignore)
  .search-index.json  <- GENERATED search index for `kb find` (one file read instead of N;
                         rebuilt by `kb index`, and automatically when entries change)
  _TEMPLATE.md     <- Reference layout; prefer `kb new` which scaffolds valid entries
  bin/kb           <- Zero-dependency CLI: new / index / check / rules / discover / ingest
  install.sh       <- Idempotent enforcement installer
  explorations/    <- "what is true"
  solutions/       <- "what we did"
  errors/          <- "what broke + the fix"
  decisions/       <- "why we chose X"
```

Bucket set is closed (KB002): an undeclared directory under `knowledge-db/` fails `kb check`.

## The Rules

| ID | Rule |
|----|------|
| KB001 | Every entry is `<bucket>/YYYY-MM-DD-<kebab-slug>.md` with front-matter keys `title`, `type`, `status`, `date`, `tags`, `sources`. `type` matches its directory. Filename date equals the `date` field. |
| KB002 | `type`, `status`, and every tag are values declared in `kb.config.json`. Unknown bucket directory or unknown root file = failure. |
| KB003 | Every `sources:` item matches `path:Lstart[-Lend][@rev]` and the path exists. Bare paths and directories are rejected. A `verified` entry cites at least one source. With `@rev`, `kb check` warns when the file changed since that rev (line ranges rot loudly, not silently) — the rev is resolved in the repository that owns the file, so sources inside a nested repo are checked too. |
| KB004 | `status: verified` requires a `## Verification` section containing a fenced block with captured output. Hypothetical markers (`# should`, `# todo`, `# expected`, `# works`) and empty blocks are rejected. |
| KB005 | `status: superseded` requires a non-empty `related:` linking the replacement. No template residue (bare `-` under any list key) anywhere. |
| KB006 | Buckets listed in `required_sections` have all their sections. For `errors/`: Symptom, Root Cause, Fix, Prevention. |
| KB007 | `INDEX.md` matches `kb index` output byte-for-byte. INDEX is build output; hand-edits go only inside `kb:manual` fenced regions. |
| KB008 | Staleness, **opt-in**: with no `staleness_days.verified` in `kb.config.json` nothing ever expires. Declare a budget and a `verified` entry older than it **warns** (re-verify by bumping `last_verified` with fresh proof, or downgrade to `tentative`); add `"mode": "error"` to make it a gate. Never a silent repo-wide gate — an expiring KB would otherwise block every commit and every agent Stop hook at once. |
| KB009 | For each `lockstep` pair in the config: if the source-side path changed in the diff, the doc-side path must have changed too. Diff mode only (`--staged` / `--diff-base`). |
| KB010 | One trap per error entry. An error entry with duplicate Symptom / Root Cause / Fix / Prevention sections fails — split it so symptom-grep lands on one file. |
| KB011 | Write-back trigger: a diff touching `writeback.code` paths but no `knowledge-db/**` file fails, naming the bucket the entry probably belongs in. Diff mode only. With `--repo <nested>` (workspace mode) the KB cannot appear in that repo's diff, so the evidence is pending KB changes in the workspace, or a KB commit inside `writeback.grace_hours` (default 24). |
| KB012 | `INDEX.html` (self-contained human-facing view) is fresh: its embedded fingerprint matches the KB content (generated INDEX.md + entry files). Embedded source snippets are best-effort context and deliberately outside the fingerprint. |
| KB013 | Doc write-back trigger: a diff touching `writeback.docs` paths (decision-bearing docs: CLAUDE.md, AGENTS.md, ADRs, docs/) but no `knowledge-db/**` file fails — a doc edit that states a rule, constraint, or choice is a decision and belongs in `decisions/` too. Diff mode only. |
| KB014 | Drift (warning-only), two kinds: `kb.config.json` records the tool version that wrote it (`kb_version`), and a missing or mismatched value warns so independently-upgraded tooling and config are visible (`kb version` prints both); and a planted HARD RULE block that no longer matches `kb rules --plant` warns, because a marker-guarded block otherwise stays frozen at whatever an old installer wrote. Rerun `install.sh` to replant. Never fails the check — see UPGRADING.md. |
| KB015 | Changelog art (config-gated by `changelog_art` in `kb.config.json`): every released version heading in the changelog starts with a small SVG artwork at the LEFT of the title (`## ![name](<dir>/vX.Y.Z-<animal>.svg) [X.Y.Z] - date`). The SVG must exist, live under the declared dir, and be unique per version. Convention: a small random animal per release; the GitHub release body opens with the same SVG via a tag-pinned raw URL (`<img src="https://raw.githubusercontent.com/<org>/<repo>/<tag>/<dir>/vX.Y.Z-<animal>.svg" width="72" />`) — release bodies are external state the check cannot gate, so that half stays convention. Off unless configured. |

Every rule has a fixture: `tests/fixtures/pass/` must exit 0; each
`tests/fixtures/fail/KBxxx/` must exit non-zero naming that ID (`tests/run-kb-tests.sh`).

## Entry Format

Created by `kb new <type> <slug>`; the flat schema `bin/kb` parses:

```yaml
---
title: Short human title
type: exploration          # declared in kb.config.json types (KB002)
status: tentative          # verified | tentative | superseded (KB002); new entries start tentative
date: 2026-08-24           # equals filename date (KB001)
tags: [area:tooling]       # every tag declared in kb.config.json (KB002)
sources:
  - path/to/file.py:42-56  # path:Lstart[-Lend][@rev] (KB003)
related:
  - solutions/other.md     # REQUIRED if superseded (KB005)
last_verified: 2026-08-24  # optional; resets the KB008 staleness clock (opt-in rule)
---
```

## Status Rules

| Status | Meaning | Enforced by |
|--------|---------|-------------|
| `tentative` | Best understanding, unproven. The default — `kb new` writes it. | KB004 (cannot claim verified without proof) |
| `verified` | Proven true: Verification section with captured command output. | KB003, KB004, KB008 |
| `superseded` | Outdated; `related:` links the replacement. | KB005 |

**Superseding is autonomous**: never ask permission — supersede a VERIFIED entry the
moment evidence invalidates it, with reason stated and replacement linked in `related:`
(KB005 enforces the link). See AGENT.md ("Never prompt, never withhold").

Opt-out: `"supersede_with_consent": true` in `kb.config.json` restores
ask-before-superseding. It is a real switch, not a note — `kb rules` then injects
the consent wording into every prompt, so the agent sees it. Not recommended: it
blocks autonomous agents on a question the user usually cannot answer.

## Guidance (not checked)

These improve the KB but have no rule ID because they cannot be mechanically enforced:

- **Search before creating**: update a near-duplicate instead of adding a new entry.
- **One entry per CHOICE** in `decisions/`: if you would search for it separately, split it.
- **Write conclusions, not search journeys**: the entry is for the next reader.
- **Source-of-truth hierarchy** when sources disagree: real code > generated definitions > outbound feeds > docs. Note the stale one.
- **Ready-Answer Table**: when an entry becomes the canonical answer for a topic, add a row (inside the `kb:manual` region of INDEX.md).
