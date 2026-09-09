#!/usr/bin/env python3
"""measure.py — turn the demo's three arms into one comparison table.

Each arm runs as a Claude Code subagent, and Claude Code writes that agent's
full turn-by-turn transcript to a task output file. This reads those files and
reports what each arm actually cost: billed tokens, output tokens, tool calls,
and the payload the agent pulled into context.

It only ever prints aggregates — never transcript content — so it is safe to
run inside another agent session.

Usage:
  ./measure.py cold=<file> warm=<file> control=<file>
  ./measure.py --json cold=<file> warm=<file> control=<file>

Find the files under: <session scratch>/tasks/<agent-id>.output
(the path is printed when each agent is launched).
"""

import json
import sys
from pathlib import Path

CHARS_PER_TOKEN = 4.0
# Bash gets its own column on purpose: agents use it to read AND to write
# (heredocs, sed), so folding it into either bucket misreports the split.
READ_TOOLS = {"Read", "Grep", "Glob", "Explore", "WebFetch", "WebSearch"}
WRITE_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}


def measure(path):
    billed = {"input": 0, "cache_creation": 0, "cache_read": 0, "output": 0}
    tools = {}
    payload = 0
    turns = 0
    thinking = 0
    for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg = rec.get("message") if isinstance(rec, dict) else None
        if not isinstance(msg, dict):
            continue
        usage = msg.get("usage")
        if isinstance(usage, dict):
            turns += 1
            billed["input"] += usage.get("input_tokens") or 0
            billed["cache_creation"] += usage.get("cache_creation_input_tokens") or 0
            billed["cache_read"] += usage.get("cache_read_input_tokens") or 0
            billed["output"] += usage.get("output_tokens") or 0
            details = usage.get("output_tokens_details") or {}
            thinking += details.get("thinking_tokens") or 0
        content = msg.get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use":
                name = block.get("name", "?")
                tools[name] = tools.get(name, 0) + 1
            elif block.get("type") == "tool_result":
                body = block.get("content")
                if isinstance(body, list):
                    body = "".join(b.get("text", "") for b in body if isinstance(b, dict))
                if not isinstance(body, str):
                    body = str(body or "")
                payload += int(len(body) / CHARS_PER_TOKEN)
    reads = sum(n for k, n in tools.items() if k in READ_TOOLS)
    writes = sum(n for k, n in tools.items() if k in WRITE_TOOLS)
    shell = tools.get("Bash", 0)
    return {
        "turns": turns,
        "billed_total": sum(billed.values()),
        "fresh_input": billed["input"] + billed["cache_creation"],
        "cache_read": billed["cache_read"],
        "output": billed["output"],
        "thinking": thinking,
        "tool_payload": payload,
        "tool_calls": sum(tools.values()),
        "read_calls": reads,
        "write_calls": writes,
        "shell_calls": shell,
        "by_tool": tools,
    }


def human(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}k"
    return str(n)


def main():
    args = [a for a in sys.argv[1:] if a != "--json"]
    as_json = "--json" in sys.argv[1:]
    arms = {}
    for arg in args:
        if "=" not in arg:
            print(f"measure.py: expected label=file, got {arg!r}", file=sys.stderr)
            return 2
        label, path = arg.split("=", 1)
        if not Path(path).is_file():
            print(f"measure.py: no such file: {path}", file=sys.stderr)
            return 2
        arms[label] = measure(path)
    if not arms:
        print(__doc__)
        return 2

    if as_json:
        print(json.dumps(arms, indent=2))
        return 0

    print("Same bug, twice: what each arm cost")
    print()
    print(f"  {'arm':<10}{'turns':>7}{'tools':>7}{'shell':>7}{'reads':>7}{'edits':>7}"
          f"{'payload':>10}{'output':>9}{'fresh in':>10}{'billed':>10}")
    for label, m in arms.items():
        print(f"  {label:<10}{m['turns']:>7}{m['tool_calls']:>7}{m['shell_calls']:>7}"
              f"{m['read_calls']:>7}{m['write_calls']:>7}{human(m['tool_payload']):>10}"
              f"{human(m['output']):>9}{human(m['fresh_input']):>10}"
              f"{human(m['billed_total']):>10}")

    # The saving is control - warm: same task, same rules, only memory differs.
    if "warm" in arms and "control" in arms:
        warm, control = arms["warm"], arms["control"]
        print()
        print("  Same task (fix tests/test_payout.py), same rules, only memory differs:")
        for field, name in (("billed_total", "billed tokens"), ("fresh_input", "fresh input"),
                            ("output", "output tokens"), ("turns", "turns"),
                            ("tool_calls", "tool calls"), ("tool_payload", "context payload")):
            c, w = control[field], warm[field]
            if not c:
                continue
            delta = c - w
            pct = 100 * delta / c
            print(f"    {name:<17} control {human(c):>8}  warm {human(w):>8}  "
                  f"saved {human(delta):>8}  ({pct:+.0f}%)")
        if "cold" in arms:
            cold = arms["cold"]
            print()
            print(f"  Paid once to learn it (arm cold, includes writing the entries): "
                  f"{human(cold['billed_total'])} billed")
            if control["billed_total"] > warm["billed_total"]:
                per = control["billed_total"] - warm["billed_total"]
                n = -(-cold["billed_total"] // per)
                print(f"  Recovered after {n} reuse(s) of that knowledge "
                      f"({human(per)} saved each)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
