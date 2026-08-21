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
kb-discover ./01-specs/ --output knowledge-db/explorations/

# Ingest a meeting transcript into a decision entry
cat 02-meetings/2026-08-15-kickoff.md | kb-ingest --bucket decisions

# Generate exploration from vendor documentation
kb-discover ./04-vendor-docs/stripe-api.md --output knowledge-db/explorations/

# Lint the entire workspace KB
kb-lint ./knowledge-db/
```

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
tags: [area:payments, stakeholder:product]
sources:
  - 02-meetings/2026-08-15-kickoff.md:42-58
  - 01-specs/product-requirements.md:120-135
decision_by: Sarah Chen (Product Lead)
participants: [John (Eng), Maria (Finance), Alex (CTO)]
---

## Context

Needed to choose payment processor for v2 launch.

## Options Considered

1. **Stripe** - Better API, higher fees (2.9%)
2. **PayPal** - Brand recognition, clunky integration
3. **Square** - Good for in-person, weak online

## Decision

Stripe. Developer velocity more valuable than 0.5% fee difference at our scale.

## Consequences

- Must handle Stripe webhooks (see solutions/2026-08-16-stripe-webhooks.md)
- Finance needs Stripe dashboard access
- Revisit at 10k transactions/month

## Verification

Decision recorded in kickoff meeting (02-meetings/2026-08-15-kickoff.md:55).
Approved by Alex (CTO) same day.
```

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

## Setting Up a Context Workspace

```bash
# Create the workspace structure
mkdir my-project-workspace
cd my-project-workspace

# Clone your actual repo into app/
git clone git@github.com:yourorg/yourapp.git app

# Initialize KB at workspace level
./path/to/scripts/init-knowledge-db.sh knowledge-db

# Create context folders
mkdir 01-specs 02-meetings 03-references 04-vendor-docs

# Create workspace-level CLAUDE.md
cat > CLAUDE.md << 'EOF'
# Project Workspace

## Structure
- app/           - The codebase (git repo)
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
cd my-project-workspace
claude  # or cursor, copilot, etc.
```

---

## The Mindset Shift

Stop thinking: "I have a repo with a knowledge folder."

Start thinking: "I have a project workspace where code is just one component of the full context my agent needs to do its job well."

The agent that only sees code is working with one hand tied behind its back. The agent that sees code + specs + meetings + references + decisions is operating at full capacity.

That is the difference between AI assistance and AI partnership.
