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

6. **Regenerate last.**
   ```bash
   knowledge-db/bin/kb index
   ```
   Then re-seed the `kb:manual` regions (`ready-answers`, `external-docs`) —
   the only parts of INDEX.md that survive regeneration.

7. **Verify.** `knowledge-db/bin/kb check` exits 0 and `kb version` shows
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
fixed. Mechanical checks catch shape, sources, and staleness (KB008 is
time-based) — not recent-but-false claims. On every upgrade, re-read each
`verified` entry against HEAD and supersede what changed, linking the
replacement.

---

## `install.sh` Is a Separate, Deliberate Step

Vendoring the CLI is safe and local. `install.sh` is invasive by design: it
plants rule blocks into six runtime files (CLAUDE.md, AGENTS.md, both Copilot
instruction files, Cursor `.mdc`, `.windsurfrules`), merges hooks into
`.claude/settings.json`, sets `git core.hooksPath`, writes a pre-commit hook
and a CI job, and activates KB011/KB013 — which fail any commit touching
`writeback.code`/`writeback.docs` paths without a matching `knowledge-db/**`
change.

If your `.claude/settings.json` already carries other hooks, the installer
merges without clobbering — but review the result. Audit first, change nothing:

```bash
knowledge-db/install.sh --check
```

Full details: [ENFORCEMENT.md](ENFORCEMENT.md).
