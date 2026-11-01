---
name: construct
description: >-
  Answers "what should the next sentence or paragraph of this manuscript do?" and "does this
  manuscript keep what it promises?" using the propositions ledger. Use whenever the user is
  writing or revising a paper and asks what comes next ("下一句要寫什麼", "接下來那段要寫什麼才接得上",
  "已知 prop_t，prop_{t+1} 該寫什麼", "what should the next sentence do"), whether its promises
  are kept (research question answered, "organized as follows" followed, "we now examine"
  carried out, announced analyses done: "研究問題有沒有回答到", "論證的走向有沒有斷掉",
  "承諾有沒有兌現"), or wants the article structure annotated ("標註文章結構", "annotate the
  article structure", section roles, relations between consecutive propositions) — even if they
  never name this skill. Invoke it before opening the manuscript files: it finds the ledger and
  the files itself. It records commitments, section roles and adjacent relations in two sidecars
  beside the ledger (structure.json, discourse.jsonl), checks them (S1–S6), and reports what the
  article still owes the reader at any position. Not for splitting text into propositions
  (/propositions:extract), the R1–R13 validator (/propositions:propositions), the semantic walk
  (/propositions:proofread), or sentence-level clarity (/propositions:clarity-audit).
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Construct — the article as a whole

The ledger says what each proposition claims. This skill adds how the article is built, in
three layers that together decide what the next proposition should do (format and
vocabularies: `docs/STRUCTURE.md` in this plugin; decision procedure:
`references/vocabulary.md`):

| Layer | Question | Where it is recorded |
|---|---|---|
| Commitments | What has the article promised the reader, and has it kept it? | `discourse.jsonl`: `opens`, `discharges` |
| Section roles | What is the current section for? | `structure.json`: `sections[].role` |
| Relations | How does this proposition connect to the previous one? | `discourse.jsonl`: `relation` |

Labelling is a judgment task, so the model does it. Everything around the judgment is
mechanical:

| Risk | Gate |
|------|------|
| A sidecar skips, repeats or reorders propositions | S1 (`validate-structure.py`) |
| A label outside the closed vocabularies | S2, S3, S5 reject it; nothing is mapped to a near value |
| A promise kept before it was made, or never kept | S3, S4 |
| An announcement kept far from where it was made | S6 (warning) |
| A half-finished annotation lands in the ledger directory | all drafting happens in a staging directory; the ledger directory changes only after the validator passes and the user confirms |
| The skill alters the ledger | it never writes `main.jsonl`; its sha256 is compared before and after |

## Resolve scripts and paths

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(ls -d "$HOME"/.claude/plugins/cache/propositions-projects/propositions/*/ 2>/dev/null | sort -V | tail -1)}"
SCRIPTS="$PLUGIN_ROOT/scripts"
VALIDATOR="$SCRIPTS/validate-propositions.py"
COVERAGE="$SCRIPTS/check-extraction-coverage.py"
VSTRUCT="$SCRIPTS/validate-structure.py"
STATE="$SCRIPTS/structure-state.py"
for f in "$VALIDATOR" "$COVERAGE" "$VSTRUCT" "$STATE"; do [ -f "$f" ] || { echo "missing $f"; exit 2; }; done
```

Establish, from the request or by asking once (AskUserQuestion, all at once):

- `LEDGER` — the ledger directory (holds `main.jsonl` and `_meta.json`).
- `MAIN` — the manuscript's main `.tex` file.
- The mode: **annotate** (the manuscript is written; label its structure) or **next** (the user is
  writing; say what comes next). "下一句" / "what next" means next; "標註" / "check the
  structure" means annotate.

If `LEDGER/_meta.json` is missing, the manuscript has no ledger: point to Operation D of
`/propositions:propositions`, then `/propositions:extract`.

Record the ledger's fingerprint before doing anything else; every exit path compares it:

```bash
LEDGER_SHA=$(shasum -a 256 "$LEDGER/main.jsonl" | cut -d' ' -f1)
```

## Annotate mode

### A1 — Preconditions: a valid ledger that covers the text

```bash
python3 "$VALIDATOR" --jsonl "$LEDGER/main.jsonl" --meta "$LEDGER/_meta.json" --tex "$MAIN"
```

Then run `check-extraction-coverage.py` over every line range the ledger is meant to cover
(the body from the first to the last extracted line of each file; ranges the ledger's
`_meta.json` coverage marks as excluded, such as appendices and declarations, stay excluded):

```bash
python3 "$COVERAGE" --tex "$FILE" --lines "$A-$B" --jsonl "$LEDGER/main.jsonl" --main "$MAIN"
```

If the validator exits non-zero or any range reports uncovered text, **stop**: report the
failures and send the user to `/propositions:extract`. Structure laid over a ledger with gaps
would mislabel the propositions on both sides of each gap. Write nothing.

### A2 — Read

Read `references/vocabulary.md`. Then read the manuscript and the ledger together in reading
order (the `main.jsonl` line order, retired propositions skipped). Note every sentence that
promises something (a question, an aim, a hypothesis, "organized as follows", "We now …"),
every sentence that keeps one, and every heading that starts a section with its own text.

### A3 — Draft in staging

```bash
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/construct-XXXXXX")
```

Write `$STAGE/discourse.jsonl` — one record per non-retired proposition, in ledger order — and
`$STAGE/structure.json`. Follow the four questions of `references/vocabulary.md` for every
record. Put a `note` on every close call, naming the runner-up and why it lost. For a draft
that has not stated its thesis yet, `thesis` is `[]`.

If `LEDGER` already has sidecars, draft anyway; A5 shows the difference against them.

### A4 — Validate the staged files

```bash
python3 "$VSTRUCT" --jsonl "$LEDGER/main.jsonl" \
  --structure "$STAGE/structure.json" --discourse "$STAGE/discourse.jsonl"
```

Add `--partial` only when the manuscript is unfinished, and say so in the summary. Fix the
staged files and rerun until the exit code is 0. An S4 error means a promise the article
never keeps: check the manuscript before deciding — either a discharge was missed, or the
article really leaves it open (say so in the summary; do not delete the commitment to make
the validator pass). A needed value that is not in the vocabularies is a stop: report it to
the user; the vocabularies change only through a spec change.

### A5 — Summary for the user

```bash
python3 - "$LEDGER/main.jsonl" "$STAGE" <<'PY'
import collections, json, sys
from pathlib import Path
ledger, stage = Path(sys.argv[1]), Path(sys.argv[2])
live = [p["id"] for p in map(json.loads, filter(str.strip, ledger.read_text().splitlines())) if "retired" not in p]
pos = {pid: i for i, pid in enumerate(live, 1)}
recs = [json.loads(l) for l in (stage / "discourse.jsonl").read_text().splitlines() if l.strip()]
print("relations:", dict(collections.Counter(r["relation"] for r in recs).most_common()))
opened = {}
for r in recs:
    for c in r.get("opens", []):
        opened[c["id"]] = [c["kind"], pos[r["prop_id"]], []]
for r in recs:
    for cid in r.get("discharges", []):
        opened[cid][2].append(pos[r["prop_id"]])
print("commitments:")
for cid, (kind, at, kept) in opened.items():
    print(f"  {cid:28} {kind:13} opened #{at:<4} kept {['#%d' % k for k in kept] or 'never'}")
st = json.loads((stage / "structure.json").read_text())
print("sections:")
for s in st["sections"]:
    print(f"  #{pos[s['first_prop']]:<4} {s['role']:13} {s['heading']}")
print("thesis:", [f"#{pos[t]}" for t in st["thesis"]])
print("notes:", sum(1 for r in recs if r.get("note")))
PY
```

Show this output, the list of close calls (records with a `note`), and, when `LEDGER` already
has sidecars, `diff` against them. Say where the staged files are.

### A6 — Write only after confirmation

Ask (AskUserQuestion) whether to write the staged sidecars into `LEDGER`. If the user
declines, stop: nothing in `LEDGER` changes and the staged files stay in `$STAGE`. If the
user confirms:

```bash
cp "$STAGE/structure.json" "$STAGE/discourse.jsonl" "$LEDGER/"
python3 "$VSTRUCT" --jsonl "$LEDGER/main.jsonl"        # add --partial for a draft
[ "$(shasum -a 256 "$LEDGER/main.jsonl" | cut -d' ' -f1)" = "$LEDGER_SHA" ] || echo "main.jsonl CHANGED — stop and report"
```

## Next mode

### N1 — Preconditions: structure for the text written so far

The ledger must pass the validator and its sidecars must pass:

```bash
python3 "$VSTRUCT" --jsonl "$LEDGER/main.jsonl" --partial
```

If the sidecars are missing or fail, run annotate mode on the text written so far first
(with `--partial`), then come back. Fingerprint every file this mode must leave alone:

```bash
BEFORE=$(shasum -a 256 "$MAIN" "$LEDGER/main.jsonl" "$LEDGER/structure.json" "$LEDGER/discourse.jsonl")
```

### N2 — State at the end of the draft

```bash
python3 "$STATE" --jsonl "$LEDGER/main.jsonl" --at end --format json
```

It gives the current section and its role, the last relation, the open commitments in order
of urgency (announcement, hypothesis, plan, question, aim, setup; earliest first within a
kind), the future-work list, and whether the thesis has been stated. Read the last three to
five propositions of the draft as well.

### N3 — Say what the next proposition owes

Report, in this order: the current section and its role; the open commitments as the state
query ranks them; what the last proposition did (its relation and `claim_type`). Then the
default answer: the next proposition advances the first open commitment, unless the section's
role rules it out (a `discussion` does not open a new hypothesis except as `future_work`;
`method` does not interpret results).

### N4 — Propose at most three candidates

Each candidate states:

- **Advances**: the commitment id it opens, keeps or moves forward — or why a `shift` is due
  (the section's work is done and the plan's next item begins).
- **Joins by**: the relation to the last proposition and the connective that would show it.
- **Is**: the expected `claim_type` (and `evidence_class` for an empirical ledger).
- **Sentence**: one draft sentence, marked as a suggestion.

If an `announcement` is open, the first candidate keeps it — or, when keeping it needs facts the
draft has not stated yet, lays those facts down and says which announcement it prepares (the
worked example in `docs/REFERENCE-MANUSCRIPTS.md` keeps an announcement two propositions
later, after a factual setup). Never invent results, numbers or
citations in a draft sentence: write a placeholder such as `[result of the test]`.

### N5 — Leave every file untouched

```bash
AFTER=$(shasum -a 256 "$MAIN" "$LEDGER/main.jsonl" "$LEDGER/structure.json" "$LEDGER/discourse.jsonl")
[ "$BEFORE" = "$AFTER" ] || echo "a file changed in next mode — stop and report"
```

Next mode writes nothing: not the manuscript, not the ledger, not the sidecars. Adding the
chosen sentence to the manuscript is the author's act; afterwards `/propositions:extract`
and annotate mode bring the ledger and sidecars up to date.

## Report

- **Annotate**: validator results (propositions ledger and structure), the A5 summary, the
  close calls, where the sidecars were written (or that the user declined and where the
  staged files are), and the `main.jsonl` fingerprint check.
- **Next**: the state (section, role, open commitments), the candidates, and the fingerprint
  check.
