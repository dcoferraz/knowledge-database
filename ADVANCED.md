# Advanced Usage: The Context Workspace

> **Prerequisites:** Read the [README](README.md) first to understand the basic KB pattern. This document builds on that foundation.

---

Here is where things get interesting.

The Quick Start shows you how to add a `knowledge-db/` folder inside your project. That works. But if you stop there, you are missing the bigger picture.

**The real power comes when you stop thinking of KB as "a folder in my repo" and start thinking of it as "the central nervous system of my entire project context."**

---

## The Problem With Embedding KB in Your Repo

When you put `knowledge-db/` inside your app folder, you create limitations:

1. **You must .gitignore it** - Or pollute your repo history with KB changes
2. **You cannot include private context** - Meeting notes, internal docs, client communications
3. **Your agent only sees code** - It misses specs, designs, decisions made in meetings
4. **Multiple repos cannot share knowledge** - Frontend and backend learn the same lessons separately

These are not small problems. They are the difference between an AI that helps and an AI that *understands your project*.

---

## The Context Workspace Pattern

Instead of embedding KB in your repo, create a parent folder that contains *everything* your agent needs to know:

```
my-project-workspace/                 <-- Agent runs from HERE
|
|-- app/                              <-- Your actual codebase (this is the git repo)
|   |-- src/
|   |-- package.json
|   +-- .git/
|
|-- knowledge-db/                     <-- KB lives OUTSIDE the repo
|   |-- INDEX.md
|   |-- explorations/
|   |-- solutions/
|   |-- errors/
|   +-- decisions/
|
|-- 01-specs/                         <-- PRDs, requirements, designs
|   |-- product-requirements.md
|   |-- technical-design.md
|   +-- api-contract.yaml
|
|-- 02-meetings/                      <-- Transcripts, decision records
|   |-- 2026-08-15-kickoff.md
|   |-- 2026-08-18-architecture-review.md
|   +-- 2026-08-20-client-feedback.md
|
|-- 03-references/                    <-- Related code, examples, prior art
|   |-- competitor-analysis/
|   |-- legacy-system-docs/
|   +-- sdk-examples/
|
|-- 04-vendor-docs/                   <-- API docs, SDK references
|   |-- stripe-api.md
|   |-- auth0-integration.md
|   +-- aws-services.md
|
+-- CLAUDE.md                         <-- Workspace-level instructions
```

Now your agent has access to *everything*. Not just code. Everything.

---

## Why This is Vastly Better

Let me be direct: **the embedded KB approach is a 10% solution. The context workspace is the 100% solution.**

Here is what changes:

```
+---------------------------------------------------------------------------------+
|                        EMBEDDED KB vs CONTEXT WORKSPACE                         |
+---------------------------------------------------------------------------------+
|                                                                                 |
|  EMBEDDED KB                          CONTEXT WORKSPACE                         |
|  -----------                          -----------------                         |
|  Agent sees: code                     Agent sees: code + specs + meetings +     |
|                                                   references + decisions        |
|                                                                                 |
|  KB pollutes repo history             KB is separate, clean repo stays clean    |
|                                                                                 |
|  Private docs excluded                Private docs welcome                      |
|                                                                                 |
|  One repo = one KB                    Multiple repos share one KB               |
|                                                                                 |
|  Agent asks "how does this work?"     Agent asks "does this match the spec?"    |
|                                                                                 |
|  Decisions reconstructed from code    Decisions traced to meeting + person      |
|                                                                                 |
+---------------------------------------------------------------------------------+
```

---

## The Numbered Prefix Convention

Notice the folder names: `01-specs/`, `02-meetings/`, `03-references/`.

This is intentional:

1. **Predictable sort order** - Folders always appear in priority order
2. **Scan order for agents** - Agent can process highest-priority context first
3. **Self-documenting structure** - Anyone can understand the hierarchy at a glance

Use whatever numbering makes sense for your project. The point is: impose order.

---

## Using KB Tools on Your Full Context

Here is where it gets powerful. The CLI tools work on *any* folder, not just code:

```bash
# Discover boundaries from specs (not just code)
knowledge-db/bin/kb discover ./01-specs/

# Ingest a meeting transcript into a decision entry
knowledge-db/bin/kb ingest --bucket decisions --input 02-meetings/2026-08-15-kickoff.md

# Same thing from a pipe, letting the bucket be detected
cat 04-vendor-docs/stripe-api.md | knowledge-db/bin/kb ingest

# Validate the entire workspace KB (rules KB001-KB015)
knowledge-db/bin/kb check
```

Both commands ship inside `knowledge-db/bin/kb`, so they exist in every install,
and both write entries that already pass `kb check` (tentative, tags filtered to
the declared vocabulary, sources cited as `path:line`).

Think about what this means:

- **Meeting transcript** becomes a decision entry with WHO made the decision and WHY
- **Spec document** becomes boundaries the agent checks against when implementing
- **Vendor docs** become explorations the agent reads before integrating

Your agent is not just coding anymore. Your agent is *project-aware*.

---

## Decision Tracking: Who and Why

The `decisions/` bucket becomes dramatically more valuable in a context workspace. Now you can capture:

```yaml
---
title: Use Stripe over PayPal for payments
type: decision
status: verified
date: 2026-08-15
tags: [area:payments]
sources:
  - 02-meetings/2026-08-15-kickoff.md:42-58
  - 01-specs/product-requirements.md:120-135
decision_by: Sarah Chen (Product Lead)
---

## Summary

Stripe for v2 payments: developer velocity beats the 0.5% fee difference at our
scale. Decided by Sarah Chen (Product) in the kickoff; John (Eng), Maria
(Finance) and Alex (CTO) in the room.

## Context / Question

Needed to choose a payment processor for the v2 launch.

## Findings / What We Did

Options considered:

1. **Stripe** - better API, higher fees (2.9%)
2. **PayPal** - brand recognition, clunky integration
3. **Square** - good for in-person, weak online

Consequences: we must handle Stripe webhooks, Finance needs dashboard access,
and the choice is revisited at 10k transactions/month.

## Verification

```
$ sed -n '55p' 02-meetings/2026-08-15-kickoff.md
Sarah: going with Stripe for v2 — Alex signed off, revisit at 10k/mo.
```
```

Two things that entry does deliberately, because `kb check` enforces them:
`stakeholder:product` and a `participants:` key are NOT used (tags come from the
closed vocabulary in `kb.config.json` — KB002 — and unknown front-matter keys
warn; put the names in the body, or declare a `stakeholder` dimension in the
config first), and the Verification section carries a **fenced block with real
captured output** rather than a prose claim (KB004). `decision_by:` is a
declared optional key, so it stays.

Now when someone asks "why are we using Stripe?", the agent does not guess. The agent cites Sarah Chen, the kickoff meeting, and the exact reasoning.

**This is project management, not just code memory.**

---

## For Project Managers and Team Leads

If you are a PM or lead reading this, understand what the context workspace enables:

1. **Decision traceability** - Every architectural choice traced to a person, meeting, and rationale
2. **Spec compliance** - Agent checks implementations against actual requirements
3. **Onboarding acceleration** - New team members (human or AI) get full context instantly
4. **Institutional memory** - When people leave, their decisions stay documented
5. **Audit trail** - For regulated industries, you have a knowledge trail

You are not just helping developers code faster. You are building a **project brain** that persists across people, sessions, and time.

---

## The Human Window: INDEX.html

Everything above assumes someone comfortable in a repo. Most stakeholders are not.
`kb index` generates `INDEX.html` alongside `INDEX.md` for exactly that audience:
a self-contained knowledge browser that needs **no server, no dependencies, no
tooling — double-click the file and it opens in any browser**.

What a non-technical reader gets:

1. **Plain-language navigation** - Buckets labeled in human terms ("what broke and
   how we fixed it", not `errors/`), with a search box and a status filter
   (verified / tentative / superseded).
2. **Proof, not claims** - Every verified entry shows its Verification evidence,
   and every source citation expands to the actual cited lines, embedded at build
   time. A skeptical stakeholder can check the receipts without opening an editor.
3. **Decision accountability** - Decision entries show who decided; superseded
   entries carry a banner linking their replacement, so nobody acts on stale
   knowledge.
4. **It travels** - One file, no external assets. It survives email, Slack, and a
   shared drive intact. Send it to a client, an auditor, or an exec before a
   review meeting.

Freshness is enforced, not hoped for: rule KB012 embeds a fingerprint of the KB
content in the file, and `kb check` (pre-commit and CI) fails when INDEX.html no
longer matches the entries. The copy in the repo is never silently stale — a
forwarded copy is a snapshot, so regenerate with `kb index` before sharing.

For PMs: this is the artifact you show in the meeting. The KB stops being "a
thing the developers do" and becomes the project's shared source of truth.

---

## Setting Up a Context Workspace

```bash
# Create the workspace structure
mkdir my-project-workspace
cd my-project-workspace

# Make the WORKSPACE a git repo of its own. Do not skip this: the KB's history
# is what makes decisions auditable, and the write-back gate needs a diff.
git init

# Clone your actual repo into app/ and keep it out of the workspace history
git clone git@github.com:yourorg/yourapp.git app
echo "app/" >> .gitignore

# Create context folders
mkdir 01-specs 02-meetings 03-references 04-vendor-docs

# Initialize the KB at workspace level, then let the wizard wire it.
# Pick [2] workspace, and say yes when it offers to gate app/.
./path/to/scripts/init-knowledge-db.sh knowledge-db
```

The wizard prints something like:

```
  1) How do you want to use the knowledge base?
     [1] in-repo    KB committed inside this repo, shared with the team (default)
     [2] workspace  KB lives above one or more nested app repos, alongside
                    specs/meetings/references (the context-workspace pattern)
     [3] local      personal memory, gitignored, never committed
  choice [1] 2
  ...
  4) Nested repos to gate (code commits there require a KB entry here)
     wire app/? (y/n) [y] y

CHANGED    nested repo gate installed in app/ (hooks/pre-commit)
```

Then add the workspace-level instructions (the installer plants the HARD RULE
block into `CLAUDE.md` for you; this is the project-specific half):

```bash
cat >> CLAUDE.md << 'EOF'

# Project Workspace

## Structure
- app/           - The codebase (its own git repo, gitignored here)
- knowledge-db/  - Project memory (KB)
- 01-specs/      - Requirements and designs (read-only reference)
- 02-meetings/   - Meeting notes and transcripts
- 03-references/ - Related code and prior art
- 04-vendor-docs/- External API documentation

## Rules
- Always run agent from this workspace root
- Check knowledge-db/ before exploring
- Validate implementations against 01-specs/
- Record decisions with WHO and WHY
- Meeting transcripts are source of truth for verbal decisions
EOF

# Now always run your agent from my-project-workspace/
claude  # or cursor, copilot, etc.
```

## What Enforcement Looks Like in a Workspace

Workspace mode is not just a folder layout — it changes where the gates live,
because the code and the memory are in different repositories.

| Gate | In-repo mode | Workspace mode |
|------|--------------|----------------|
| Hard rules injected into the agent | `.claude/settings.json` UserPromptSubmit hook | same (workspace root) |
| KB validity on session end | Stop + SubagentStop hooks | same |
| Write-back on code commits | pre-commit in the same repo | pre-commit planted **inside each nested repo**, running the workspace KB's `kb check --staged --repo <nested>` |
| Evidence of write-back | the KB shows up in the same diff | pending KB changes in the workspace, or a KB commit inside `writeback.grace_hours` (default 24) |
| CI | `.github/workflows/kb-check.yml` on the repo | on the workspace repo; the app repo's own CI does not see this KB |

Practical consequences:

- **Record the entry before you commit code.** The nested hook looks for KB
  movement in the workspace, so writing the entry after the commit is too late
  for that commit.
- **The nested hook is local.** It lives in that repo's `.git/hooks/`, which is
  not committed, so each clone runs `install.sh --wizard` once. It is also
  bypassable with `--no-verify`, exactly like any pre-commit hook.
- **Cite nested sources with the nested path** (`app/src/thing.ts:12-40`). If you
  pin `@rev`, the rev must exist in the repo that owns the file — `kb check`
  resolves it there.
- **If you never wire a nested repo**, workspace mode still gives you the agent
  hooks and the planted rules, but nothing gates a `git commit` inside `app/`.
  The installer says so rather than pretending otherwise.

---

## The Mindset Shift

Stop thinking: "I have a repo with a knowledge folder."

Start thinking: "I have a project workspace where code is just one component of the full context my agent needs to do its job well."

The agent that only sees code is working with one hand tied behind its back. The agent that sees code + specs + meetings + references + decisions is operating at full capacity.

That is the difference between AI assistance and AI partnership.
