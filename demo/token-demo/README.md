# Token demo: the same bug, twice

A live demo of what durable memory is worth, in tokens. It is a tiny billing
app with **the same latent bug in two unrelated modules**:

| Module | Function | Failing test |
|--------|----------|--------------|
| `app/billing/invoice.py` | `apply_discount` | `tests/test_invoice.py` |
| `app/reporting/payout.py` | `share_amount` | `tests/test_payout.py` |

Both compute money as `round(amount * pct / 100, 2)`. That is wrong twice over:
binary floats cannot hold a half-cent exactly, and Python's `round` breaks ties
to even rather than up the way money does. So a 50% share of `1000.05` pays out
`500.02` instead of `500.03` — a one-cent shortfall that only shows up on
half-cent boundaries.

The point of the demo is not the bug. It is that **fixing it the second time
should cost almost nothing**, because the first fix was written down.

## The three arms

Run each in a **fresh agent session**, in its own copy of this folder, and
record the tokens each one spends.

| Arm | Task | KB state | What it shows |
|-----|------|----------|---------------|
| **1. cold** | fix `tests/test_invoice.py` | empty | the real cost of discovery, plus the one-time cost of writing an entry |
| **2. warm** | fix `tests/test_payout.py` | contains arm 1's entry | reading the answer instead of re-deriving it |
| **3. control** | fix `tests/test_payout.py` | empty | the honest baseline: what arm 2 would have cost with no memory |

Arm 3 is what makes this a measurement instead of an anecdote. Without it,
"arm 2 was cheaper" could just mean the second bug was easier to find.
**The saving is arm 3 minus arm 2.** Arm 1 is what you pay, once, to get it.

## Runbook

```bash
# one copy per arm, so no arm can see another's edits
for arm in cold warm control; do cp -R demo/token-demo /tmp/demo-$arm; done

# run arm 1 (cold) first, on tests/test_invoice.py

# then seed arm 2 with arm 1's KNOWLEDGE ONLY - the entries and the INDEX,
# never the code it wrote:
cp /tmp/demo-cold/knowledge-db/*/*.md   /tmp/demo-warm/knowledge-db/<same buckets>/
cp /tmp/demo-cold/knowledge-db/INDEX.*  /tmp/demo-warm/knowledge-db/

# sanity-check the seed: both bugs must still be red in the warm copy
python3 /tmp/demo-warm/tests/test_payout.py    # exit 1
test -f /tmp/demo-warm/app/money.py            # must NOT exist

# arm 3 (control) starts with an empty KB - do not seed it
```

**Seed hygiene matters — the first run of this demo was ruined by skipping it.**
Arm 1's entries cite the file arm 1 created (`app/money.py:...`), which does not
exist in the warm copy. Left in place, `kb check` greets the warm agent with
three KB003 "source path not found" findings, it reasonably concludes *the fix
regressed*, and it runs a whole regression investigation plus writes a new entry
— work the control arm never does. Measured, that made the warm arm **47% more
expensive than the control**.

So when seeding: drop citations to files the fix has not created yet, and if
that leaves a `verified` entry with no sources (KB003), repoint it at an
existing call site. Then:

```bash
/tmp/demo-warm/knowledge-db/bin/kb index
/tmp/demo-warm/knowledge-db/bin/kb check    # MUST exit 0 before you run the arm
```

State any seed edit out loud when presenting. The warm arm must start from a
clean KB that simply *knows the answer* — not from an alarm.

Give each agent the same prompt, changing only the test name:

```
Work only inside <copy>. `python3 tests/test_payout.py` is failing.
Follow the rules in <copy>/CLAUDE.md. Fix it.
```

Then measure. Every agent's token usage is in the Claude Code transcript
(`~/.claude/projects/<project>/*.jsonl`, records with `isSidechain: true`);
`scripts/kb-benchmark --transcripts <dir>` reads the same fields.

## Measured results

Run twice: once before the v0.8.0 rule changes, once after. Both rounds used
independent subagents with no shared context.

| metric | R1 warm | R1 control | R2 warm | R2 control |
|--------|---------|------------|---------|------------|
| harness subagent tokens | 70,563 | 66,862 | **55,980** | 63,771 |
| billed total | 3.62M | 2.46M | 2.21M | **1.77M** |
| fresh input | 129.3k | 131.6k | **116.7k** | 131.6k |
| context payload | 9.1k | 9.2k | **6.6k** | 10.0k |
| turns | 65 | 46 | 47 | **36** |
| new entries authored | 1 (+2 updated) | 2 | **0 (3 refreshed)** | 2 |
| suites green at the end | both | both | **both** | payout only |

**Round 1 was a null result** — the KB arm cost *more*. Worth showing: it is the
honest half of the story, and it found two real defects. The rules had no reuse
path, so the agent re-authored knowledge it had just consumed; and the seed was
dirty (see above), so the agent ran a regression investigation the control never
did. Both fixed in v0.8.0.

**Round 2**: the warm arm authored **zero** new entries — it refreshed the three
it used — and fell from 70,563 to 55,980 tokens, 21% below its own round-1 self
and 12% below the control.

**The metric decides the verdict, and that is worth saying out loud.** The KB arm
wins on everything input-side (payload -34%, fresh input -11%, harness tokens
-12%) and loses on billed total (+25%), because billed is dominated by cache
reads that scale with turn count, and it took 11 more turns to refresh entries
and re-verify. When two agents take different numbers of turns, compare fresh
input and context payload; billed total mostly measures how long the session ran.

**The strongest result is not a token count.** The warm arm fixed **all four**
money call sites and left both suites green, because the entry listed them. The
control fixed only the site it was asked about and left `tests/test_invoice.py`
red — correctly logged as a follow-up, but still broken. Same task, same rules;
the arm with memory shipped the complete fix.

## What to watch on stage

- Arm 1 opens the test, then the module, then usually experiments in a REPL to
  understand why `round(6.175, 2)` is `6.17`. That is the expensive part, and
  it is *knowledge*, not typing.
- Arm 1 ends by writing an `errors/` entry: symptom, root cause, fix,
  prevention (the KB rules require all four).
- Arm 2 reads `knowledge-db/INDEX.md`, opens one entry, and goes straight to
  `share_amount`. No REPL, no rediscovery.
- Arm 3 repeats arm 1's investigation from scratch — the cost you keep paying
  forever without a KB.

## Verifying a fix

A fix is only real when both are true:

```bash
python3 tests/test_invoice.py   # exit 0
python3 tests/test_payout.py    # exit 0
```

The correct fix is `Decimal` with `ROUND_HALF_UP`, quantized to cents, built
from `str()` of the inputs (not from floats). Anything that special-cases the
test values is cheating, and the second test will catch it.
