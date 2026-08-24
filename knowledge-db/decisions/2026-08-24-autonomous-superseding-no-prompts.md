---
title: "Never prompt: autonomous superseding with audit trail replaces consent"
type: decision
status: verified
date: 2026-08-24
tags: [area:tooling, layer:enforcement]
sources:
  - CLAUDE.md:155-163
  - knowledge-db/AGENT.md:28-40
  - knowledge-database/SKILL.md:135-147
related:
  - decisions/2026-08-21-consent-only-for-superseding.md
  - solutions/2026-08-24-agent-rules-forwarding.md
decision_by: Project maintainer (explicit directive, 2026-08-24)
---

## Summary

Agents never prompt the user about KB operations — create, update, and supersede autonomously. Superseding a verified entry requires an audit trail (reason stated, replacement linked in `related:`, enforced by KB005), not permission. Supersedes the 2026-08-21 consent-before-superseding decision.

## Context / Question

Mechanism 9 (v0.2.x-0.4.0) required a Y/N prompt before superseding verified entries. Maintainer directive on 2026-08-24: "It should never prompt the user in any way, and never keep from saving important information from the KB." A consent gate stalls autonomous agents (headless sessions have nobody to answer) and risks losing corrections — exactly the memory-loss failure mode Mechanism 10 exists to prevent. Options: (A) keep consent, (B) autonomous superseding with mandatory audit trail, opt-in flag to restore prompting.

## Findings / What We Did

Chose (B). The safety consent provided (protecting proven knowledge from silent overwrites) is preserved structurally: the old entry is never deleted, `status: superseded` + `related:` link are enforced (KB005), and the agent reports what it superseded in the task summary — informing, not asking. Changed: CLAUDE.md:155-163 (Mechanism 9 rewritten), knowledge-db/AGENT.md:28-40 (portable rule 3), knowledge-database/SKILL.md:135-147 ("Never Prompt, Never Withhold"), plus the HARD RULE block install.sh forwards. Opt-in `supersede_with_consent: true` restores the old behavior.

## Verification

Both docs now state the no-prompt rule (captured 2026-08-24):

```bash
$ sed -n '155p;157p' CLAUDE.md
### 9. Autonomous Superseding with Audit Trail
**Never prompt the user** to create, update, or supersede entries — capture must not stall on permission,
$ grep -n "NEVER PROMPT" knowledge-db/AGENT.md
28:## 3. NEVER PROMPT, NEVER WITHHOLD
$ grep -n "NEVER PROMPT" CLAUDE.md
287:3. **NEVER PROMPT, NEVER WITHHOLD** — create, update, and supersede KB entries autonomously,
```

Applied in the same change set: 2026-08-21-consent-only-for-superseding.md marked superseded with this entry linked (user consent for that supersede given explicitly in the 2026-08-24 directive).
