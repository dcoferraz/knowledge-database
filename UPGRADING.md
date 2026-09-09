# Upgrading an Installed KB

> This guide is for a project that already has a `knowledge-db/` and wants to
> move to a newer upstream version. It is distilled from a real downstream
> upgrade (an older minimal copy to v0.5.2) — every trap below was actually hit.

The one-sentence rule: **an upgrade is not a file copy.** Upstream ships its own
config, its own KB entries (documenting this tool, not your project), and a
generated INDEX. Copying the tree verbatim silently invalidates your entries.

Treat it as three separate moves: **vendor the tooling, adapt the config,
migrate the entries.**

---

## The Short Way (v0.7.0+)

`kb upgrade` does the three moves for you and leaves the judgment calls to you:

```bash
knowledge-db/bin/kb upgrade --dry-run   # what would change, changes nothing
knowledge-db/bin/kb upgrade             # do it
```

```
source      ~/.claude/plugins/marketplaces/knowledge-database (0.8.0)
installed   0.7.0
backup      /tmp/kb.backup-xxxx/knowledge-db
vendored    bin/kb install.sh AGENT.md README.md _TEMPLATE.md
kept        entries, INDEX.*, kb.config.json vocabularies
bumped      kb_version 0.7.0 -> 0.8.0
reindexed   INDEX.md + INDEX.html
replanted   6 runtime file(s)
kb check    2 finding(s), 0 warning(s) — a migration list, not an upgrade failure:
  KB003 explorations/2026-01-02-auth.md: source path not found: src/old.ts
  KB004 solutions/2026-02-11-cache.md: Verification must contain a fenced block
```

What it guarantees:

- **Tooling only.** `bin/kb`, `install.sh`, `AGENT.md`, `README.md`,
  `_TEMPLATE.md` — never upstream's entries, never its `kb.config.json`, never
  its `INDEX.*`. Your vocabulary, `extra_root_files` and entries are untouched.
- **Backup first**, path printed, before anything is written.
- `kb_version` bumped to match, so KB014 goes quiet.
- The index is regenerated and `install.sh` is rerun, which replants stale rule
  blocks and migrates hooks — the two things a hand upgrade always forgot.
- `kb check` findings are printed as a **migration list**. They do not fail the
  upgrade (`--strict` if you want them to in CI): they are your work queue, and
  the Traps section below is how to clear them honestly.

Where the new version comes from, best first: `$CLAUDE_PLUGIN_ROOT/..`, the
plugin marketplace clone in `~/.claude/plugins/marketplaces/`, a sibling
checkout, then `git clone --depth 1` from GitHub. The **newest** candidate wins,
not the first found. `--no-network` stays local; `--source <path>` pins it.

### Finding out an update exists

```bash
knowledge-db/bin/kb version           # prints "upstream: X available" from local checkouts
knowledge-db/bin/kb version --check   # probe upstream (may clone), cache the answer
```

`kb check` also emits a warning-only `KB014` line when a newer tool is visible,
so the notice reaches you through the pre-commit hook and CI without ever
failing them. Plain `kb version` and `kb check` never touch the network, and
`kb check` never writes (the cache lives in `knowledge-db/.upgrade-cache.json`
and is only refreshed by `version --check` / `upgrade`).

### If your KB predates v0.7.0

An old install cannot update itself — its `bin/kb` has no `upgrade` subcommand.
Run the NEW tool against the OLD folder instead, which is exactly what the
plugin's bootstrap script does when it finds a KB already there:

```bash
~/.claude/plugins/marketplaces/knowledge-database/knowledge-database/bootstrap.sh
# or, from any checkout of this repo:
<checkout>/knowledge-db/bin/kb --kb-dir knowledge-db upgrade --source <checkout>
```

Everything below is what that command automates, and remains the manual
fallback when you have no checkout at all.

---

## The Order

1. **Back the whole KB up first.**
   ```bash
   cp -r knowledge-db /tmp/kb.backup-$(date +%s)
   ```
   Every later step is then reversible.

2. **Pin the version you are moving to.** Read upstream `CHANGELOG.md`, record
   the version and commit. Since v0.5.3 the tooling records itself:
   `kb version` prints the tool version and the `kb_version` your config
   declares, and `kb check` emits a `WARN KB014` when they diverge — so finish
   the upgrade by bumping `kb_version` in `kb.config.json`.

3. **Vendor only the tooling.** Copy from upstream:
   - `knowledge-db/bin/kb`
   - `knowledge-db/install.sh`
   - `knowledge-db/AGENT.md`
   - `knowledge-db/README.md`
   - `knowledge-db/_TEMPLATE.md`

   Do NOT copy:
   - upstream's `explorations/ solutions/ errors/ decisions/` — those document
     the KB tool itself, not your project
   - upstream's `INDEX.md` / `INDEX.html` — generated artifacts
   - upstream's `kb.config.json` — see next step

4. **Write the config, don't copy it.** `kb.config.json` is a closed
   vocabulary (KB002): upstream's tag allowlist fits upstream's repo, so your
   entries would fail against it. Derive yours from what your entries actually
   use:
   ```bash
   grep -rh "^tags:" knowledge-db/*/*.md | tr -d '[]' | tr ',' '\n' | sort -u
   ```
   Also declare in the config:
   - any bucket upstream lacks (custom buckets are config-driven — the CLI
     never needs patching for them)
   - any project-specific file at the KB root via `extra_root_files`
     (e.g. `"extra_root_files": ["RELEASES.md"]`) — KB002 accepts declared
     files; never patch `KNOWN_ROOT_FILES` in the vendored CLI
   - `kb_version` matching the version you pinned in step 2

5. **Run `kb check` and read the findings as a migration list**, not as
   failures to suppress. Typical items and the honest fix for each are in the
   Traps section below.

6. **Replant the rule blocks.** From v0.7.0 the HARD RULE block is generated by
   the tool, so an installer rerun refreshes the text in every runtime file
   instead of skipping it because a marker is present:
   ```bash
   knowledge-db/install.sh          # replants stale blocks in place
   knowledge-db/install.sh --check  # names any file still missing or stale
   ```
   `kb check` also warns (`WARN KB014 CLAUDE.md: planted HARD RULE block is
   stale`) so the drift is visible without running the installer. Upgrading from
   <= v0.6.0 also migrates the agent hooks: the Stop hook moves from `kb check`
   to `kb stop-hook`, and a `SubagentStop` hook is added.

7. **Regenerate last.**
   ```bash
   knowledge-db/bin/kb index
   ```
   Then re-seed the `kb:manual` regions (`ready-answers`, `external-docs`) —
   the only parts of INDEX.md that survive regeneration.

8. **Verify.** `knowledge-db/bin/kb check` exits 0 and `kb version` shows
   matching versions.

---

## Traps (all field-verified)

**INDEX.md is generated.** Hand-written content outside the
`<!-- kb:manual:{name}:start -->` regions is destroyed by `kb index`. Only
`ready-answers` and `external-docs` exist. Anything else worth keeping belongs
in the config or in an entry. Lock-step invariants are generated from the
config's `lockstep` — encode them there, never by hand.

**`sources:` grammar is strict.** `path:Lstart[-Lend][@rev]` only; bare paths
and directories are rejected (KB003). Pre-rule entries almost always fail this.
When re-anchoring, open the file and confirm the range still holds the claim —
line numbers rot. (The field upgrade found a file had grown 52 to 512 lines;
every pointer into it was dead.)

**`verified` requires captured proof.** KB004 wants a `## Verification` section
with a fenced block of real output. For entries describing a past state you
cannot reproduce, downgrade to `tentative` and say what is unproven — never
manufacture output.

**Statuses are a closed set.** `verified | tentative | superseded`. Map any
homegrown status (`resolved`, `done`, ...) to the nearest real one rather than
widening the vocabulary — a new status would bypass the proof requirement.

**Passing `kb check` does not mean entries are TRUE.** The field upgrade found
entries verified hours earlier still claiming a bug was open after it was
fixed. Mechanical checks catch shape and sources — not recent-but-false claims.
On every upgrade, re-read each `verified` entry against HEAD and supersede what
changed, linking the replacement.

**Staleness no longer expires anything by default (v0.7.0).** KB008 used to be a
hard failure at 90 days, which meant a KB written on one day started failing
every commit and every agent Stop hook on the same later day, all at once. It is
now opt-in: no `staleness_days.verified` in your config means nothing expires;
declaring a budget warns; `"mode": "error"` restores the gate. If you are
upgrading and want the old behaviour, write:
```json
"staleness_days": { "verified": 90, "mode": "error" }
```

---

## `install.sh` Is a Separate, Deliberate Step

Vendoring the CLI is safe and local. `install.sh` is invasive by design: it
plants rule blocks into six runtime files (CLAUDE.md, AGENTS.md, both Copilot
instruction files, Cursor `.mdc`, `.windsurfrules`), merges hooks into
`.claude/settings.json`, sets `git core.hooksPath`, writes a pre-commit hook
and a CI job, and activates KB011/KB013 — which fail any commit touching
`writeback.code`/`writeback.docs` paths without a matching `knowledge-db/**`
change.

Run interactively it asks first (layout, agent wiring, git-time gates) and
records the answers in `knowledge-db/.install.json`. On an upgrade that is
the moment to pick `workspace` mode if your KB sits above a nested app repo —
that mode also plants a hook inside the nested repo so code commits there are
gated against this KB. `--yes` keeps the old unattended behaviour.

If your `.claude/settings.json` already carries other hooks, the installer
merges without clobbering — but review the result. Audit first, change nothing:

```bash
knowledge-db/install.sh --check
```

Full details: [ENFORCEMENT.md](ENFORCEMENT.md).
