# Knowledge Database

This repo implements a **durable memory pattern** for AI coding agents. Never investigate the same thing twice. Never re-introduce a fixed bug.

## HARD RULE: Build the Knowledge Database on every task

This repo keeps durable memory in `knowledge-db/` so we never explore the same thing twice and never re-introduce a fixed bug. For EVERY non-trivial task (agent or human):

1. **READ FIRST** — Search `knowledge-db/` (start with INDEX.md); reuse a verified entry.
2. **DO THE WORK**.
3. **WRITE BACK** — Copy `_TEMPLATE.md` into explorations|solutions|errors|decisions, ground every claim in a real source file, set status, update INDEX.md.

`errors/` entries MUST record: Symptom -> Root cause -> Fix -> Prevention.

**Leaving a task without updating the knowledge database is incomplete work.**

---

## Quick Reference

### When to Write

"Non-trivial" = anything requiring search, reading multiple files, debugging, or decisions.
Skip only pure one-liners (rename var, fix typo).

### Which Bucket?

| Intent | Bucket |
|--------|--------|
| Understanding how something works | `explorations/` |
| Building/changing something | `solutions/` |
| Build/runtime/test failure | `errors/` |
| Choosing between options | `decisions/` |

### Entry Naming

`YYYY-MM-DD-short-kebab-slug.md`

### Status Values

- **verified** — Proven (tests pass, output confirmed)
- **tentative** — Best understanding, not yet proven
- **superseded** — Outdated, points to replacement

### Content Rules

1. Ground every claim in a source file (path:line-range)
2. Unsourced = tentative
3. Write the answer, not the journey
4. `errors/` must have all four: Symptom, Root cause, Fix, Prevention
5. Small + linked beats large + orphaned

---

## Setup (one time)

```bash
./scripts/init-knowledge-db.sh
```

Creates `knowledge-db/` with templates and empty buckets.

---

## READ Loop (start of task)

1. Open `knowledge-db/INDEX.md`
2. Scan for relevant entries by title/tags
3. `grep -r "keyword" knowledge-db/`
4. **verified** entry answers it? Use it, stop.
5. **tentative** exists? Build on it, upgrade when proven.

## WRITE Loop (end of task)

1. Pick bucket by intent
2. `cp knowledge-db/_TEMPLATE.md knowledge-db/<bucket>/YYYY-MM-DD-slug.md`
3. Fill front-matter (title, type, status, date, tags, sources, related)
4. Write sections
5. Add row to INDEX.md (newest on top)
6. Cross-link related entries
