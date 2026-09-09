---
title: "The roadmap told readers the enforcement did not exist"
type: error
status: verified
date: 2026-09-09
tags: [area:tooling, severity:medium]
sources:
  - roadmap/README.md:33-58
  - README.md:280-292
  - knowledge-db/bin/kb:50
related:
  - 2026-09-09-find-fallback-note-read-as-miss
  - 2026-09-08-indexed-lookup-fast-path
---

## Summary

A documentation audit against the tool's actual surface found `roadmap/README.md`
still advertising four shipped enforcement features as "not started" or
"documented only", and stating outright that the mechanisms in CLAUDE.md "are
currently **conventions** ... not enforced by hooks or CI gates yet". Every one of
those had shipped between v0.4.0 and v0.7.0.

## Symptom

A reader following the repo's own docs would conclude the product does not do the
thing it is built to do:

```
| Auto-append to agent configs    | Documented only | Phase 2 |
| Lock-step validation (automated)| Manual checklist| Phase 2 |
| Git hooks for KB suggestions    | Not started     | Phase 2 |
| GitHub Action for shared KB     | Not started     | Phase 3 |

The "Eight Enforcement Mechanisms" in CLAUDE.md are currently **conventions**
that agents follow by reading the file. They are not enforced by hooks or CI
gates yet.
```

Meanwhile `README.md`, `CLAUDE.md` and `ENFORCEMENT.md` all describe fifteen
enforced rules and six delivery layers. The docs contradicted each other, and the
most pessimistic one was the one a newcomer reaches from the roadmap link.

## Root Cause

Nothing keeps prose in step with the tool. The mechanised couplings only cover
some artefacts:

- KB007/KB012 pin `INDEX.md` and `INDEX.html` to the entries.
- KB014 pins the planted rule blocks to `kb rules --plant`, and `kb_version` to
  the tool version.
- KB009 pins declared lockstep pairs — in this repo, `bin/kb` to
  `knowledge-db/README.md`.

`roadmap/`, `README.md`, `ADVANCED.md` and `ENFORCEMENT.md` are in none of those,
so they drift silently. The roadmap drifted worst because nothing routes a reader
back to it during normal work: it is written once, at the start.

## Fix

Audited every doc mechanically against the tool rather than by reading, and
corrected what diverged:

- `roadmap/README.md:33-58` — status table rewritten with what shipped and in
  which version; the "conventions" paragraph replaced with the actual count
  (KB001-KB015) and the six delivery layers.
- `README.md` — repo tree was missing every supporting guide plus
  `knowledge-db/`, `tests/`, `demo/`, `images/`, `.githooks/`, `.github/`,
  `.cursor/` and `.windsurfrules`; the CLI block never taught `find -s`,
  `--deep`, `--full`, `-n` or `--lines`; a worked example was pinned to
  "upstream: 0.8.0 available"; four installer opt-out flags were undocumented.
- `ADVANCED.md` — the workspace CLI examples never mentioned the lookup path,
  which is where an agent most needs it.
- `knowledge-db/solutions/2026-09-08-indexed-lookup-fast-path.md:50` — described
  the v0.9.0 tier note as current output after v0.9.1 changed it; now carries a
  superseded-wording note and links forward.

## Prevention

The audit is four greps, and it is worth re-running before any release:

```bash
# 1. subcommands and flags the tool has, versus what the docs teach
knowledge-db/bin/kb --help
for c in find show new index check rules discover ingest stop-hook upgrade version; do
  knowledge-db/bin/kb $c --help; done

# 2. vocabulary the tool no longer uses, still in the prose
grep -rn "deep scan" --include="*.md" .

# 3. the README tree versus the real top level
python3 - <<'PY'
import pathlib, re
tree = re.search(r"knowledge-database/\n(.*?)```", pathlib.Path("README.md").read_text(), re.S).group(1)
print([p.name for p in pathlib.Path(".").iterdir()
       if not p.name.startswith(".git") and p.name not in (".DS_Store", "__pycache__")
       and p.name not in tree])
PY

# 4. the rule table versus the rules that exist
python3 -c "
import re, pathlib
tool = set(re.findall(r'KB0\\d\\d', pathlib.Path('knowledge-db/bin/kb').read_text()))
doc  = set(re.findall(r'^\\| (KB0\\d\\d)', pathlib.Path('knowledge-db/README.md').read_text(), re.M))
print('undocumented:', sorted(tool - doc), 'phantom:', sorted(doc - tool))"
```

Not adding a lockstep pair for `roadmap/` — a roadmap that must change whenever
`bin/kb` does would be noise, and KB009 fires on the diff, not on staleness.
The honest control is running the audit above at release time.

## Verification

```
$ grep -c 'are currently \*\*conventions\*\*' roadmap/README.md
0

$ for fl in '-s ' '--deep' '--full' '--lines' '-n '; do
>   printf '%-9s %s\n' "$fl" "$(grep -q -- "$fl" README.md && echo Y || echo n)"; done
-s        Y
--deep    Y
--full    Y
--lines   Y
-n        Y

$ python3 -c "
import pathlib, re
tree = re.search(r'knowledge-database/\n(.*?)\`\`\`', pathlib.Path('README.md').read_text(), re.S).group(1)
actual = {p.name for p in pathlib.Path('.').iterdir()
          if not p.name.startswith('.git') and p.name not in ('.DS_Store','__pycache__')}
print('tree missing:', [a for a in sorted(actual) if a not in tree] or 'none')"
tree missing: none

$ python3 -c "
import re, pathlib
tool = set(re.findall(r'KB0\d\d', pathlib.Path('knowledge-db/bin/kb').read_text()))
doc  = set(re.findall(r'^\| (KB0\d\d)', pathlib.Path('knowledge-db/README.md').read_text(), re.M))
print('implemented', len(tool), 'documented', len(doc))"
implemented 15 documented 15

$ bash tests/run-tests.sh | grep Results:
Results: 33/33 passed
$ bash tests/run-kb-tests.sh | tail -2
Results: 91 passed, 0 failed
All KB conformance tests passed
```
