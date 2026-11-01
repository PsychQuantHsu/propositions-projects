---
name: extract
description: >-
  Split a paragraph, section, or theorem of a LaTeX manuscript into propositions — verbatim,
  line-addressed ledger entries — and merge them into the manuscript's propositions ledger
  (main.jsonl) behind two mechanical gates: the R1-R13 validator (nothing fabricated) and a
  per-character coverage check (nothing left out). Use whenever the user wants text of a
  manuscript turned into propositions: "拆成 propositions", "把這段拆成命題", "抽 prop",
  "extract propositions", "decompose this paragraph", "add this section to the ledger", or a
  rewritten passage that needs re-extraction — even if they never name this skill. Works for
  mathematical manuscripts and for empirical (e.g. psychology) manuscripts via the ledger's
  profile. Not for validating an existing ledger (/propositions:propositions), the semantic
  walk (/propositions:proofread), or prose clarity (/propositions:clarity-audit).
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Extract — manuscript text → propositions

A proposition is one declarative unit of the manuscript, stored as one JSONL line with its
verbatim `text`, its `location` (file and line range), what it `asserts`, its `claim_type`,
its `evidence_class`, and the earlier propositions it `cites`. Extraction is a judgment task
— where to split, what each unit claims — so the model does it. Everything around the
judgment is mechanical, and this skill runs those mechanical gates so a wrong judgment
surfaces before it reaches the ledger:

| Risk | Gate |
|------|------|
| Text was paraphrased or invented | validator R1 (`prop.text` must occur in the source) |
| A sentence or clause was left out | `check-extraction-coverage.py` (every character in the range is covered or deliberately excluded) |
| The model invents, duplicates or mistypes UUIDs | temporary ids `tmp:<label>`, replaced by `assign-prop-ids.py` |
| New props collide with the ledger (duplicate ids, cite cycles) | the validator runs on a merged *copy* before anything is written |
| A half-finished extraction lands in the ledger | all work happens in a staging directory outside the ledger; the ledger changes only after the user confirms the diff |

R1 alone cannot see omissions: it checks that every prop's text is in the source, not that
every piece of source text is in some prop. That gap is why the coverage check exists.

## Resolve scripts and paths

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(ls -d "$HOME"/.claude/plugins/cache/propositions-projects/propositions/*/ 2>/dev/null | sort -V | tail -1)}"
SCRIPTS="$PLUGIN_ROOT/scripts"
VALIDATOR="$SCRIPTS/validate-propositions.py"
ASSIGN="$SCRIPTS/assign-prop-ids.py"
COVERAGE="$SCRIPTS/check-extraction-coverage.py"
for f in "$VALIDATOR" "$ASSIGN" "$COVERAGE"; do [ -f "$f" ] || { echo "missing $f"; exit 2; }; done
```

Then establish, from the user's request or by asking once (AskUserQuestion, all at once):

- `LEDGER` — the ledger directory holding `main.jsonl` and `_meta.json` (conventionally `manuscript/propositions/`).
- `MAIN` — the manuscript's main `.tex` file.
- `FILE`, `A`, `B` — the file that holds the passage and its inclusive line range (set the
  shell variables `A` and `B` to the first and last line). For a single-file manuscript
  `FILE` is `MAIN`. If the user names a section or theorem instead of
  lines, find the lines with `grep -n` and state the range you will use.

If `LEDGER` has no `_meta.json`, the manuscript has not been onboarded: stop and point to
Operation D in `/propositions:propositions`, which scaffolds the ledger.

## Step 1 — Read the profile, load exactly one reference

```bash
PROFILE=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('profile','default'))" "$LEDGER/_meta.json")
```

- `default` (or no `profile` field) → read [`references/math.md`](references/math.md).
- `empirical` → read [`references/empirical.md`](references/empirical.md).

Load only the one that matches. Each holds the vocabulary that ledger's validator accepts and
the splitting conventions of that kind of manuscript; mixing them invites values the validator
will reject (R11/R12). The ledger also carries its own pinned `EXTRACTION-PROMPT.md` and
`SCHEMA.md`; when they disagree with the reference, the ledger's pinned copies win, because
they describe the schema version that ledger is on.

## Step 2 — Stop if the range is already extracted

Extracting over existing propositions would leave two props for the same text. Check first:

```bash
python3 - "$LEDGER/main.jsonl" "$FILE" "$MAIN" "$A" "$B" "$SCRIPTS" <<'PY'
import json, sys
from pathlib import Path
ledger, file, main, a, b, scripts = sys.argv[1:]
sys.path.insert(0, scripts)
from _lib.latex_env_parser import parse_location_v16
target, mainp = Path(file).resolve(), Path(main).resolve()
hits = []
for line in open(ledger, encoding="utf-8"):
    if not line.strip() or line.lstrip().startswith("//"):
        continue
    p = json.loads(line); loc = parse_location_v16(p.get("location", ""))
    if not loc or "retired" in p:  # retired props no longer describe the paper
        continue
    rel, s, e = loc
    named = mainp if rel is None else (mainp.parent / rel).resolve()
    if named == target and s <= int(b) and e >= int(a):
        hits.append(f"{p['id']}  {p['location']}  {p.get('text','')[:60]}")
print("\n".join(hits) if hits else "range is free")
PY
```

If anything is listed, stop and show the list. Re-extracting a passage means marking those
props `retired` first (see the PLAYBOOK and the ledger's `SCHEMA.md` §retired) — retired props
are skipped here and by the coverage check — and retiring is the user's call, not this skill's.

## Step 3 — Pick the granularity

- **Existing ledger**: match what it already uses — read `coverage.phase` in `_meta.json` and
  a few existing props. A ledger that mixes granularities becomes hard to audit.
- **New ledger**: ask the user once, with the two modes from the reference: `heterogeneous`
  (one prop per declarative sentence) or `clause-level` (split at clause boundaries, with
  `connective` / `reference` / `scope_qualifier` props).

## Step 4 — Pin environment boundaries (theorem-like passages)

If the range lies inside a `theorem` / `lemma` / `definition` / `proof` (or any environment the
manuscript declares with `\newtheorem`), get the real `\begin` / `\end` lines with `grep -n`
before extracting. The statement ends at the physical `\end{...}` token, not where the prose
feels finished; the math reference explains the failure this prevents. Empirical manuscripts
usually have none — skip this step when grep finds nothing.

## Step 5 — Extract into staging with temporary ids

```bash
STAGE=$(mktemp -d)/extract && mkdir -p "$STAGE"
sed -n "${A},${B}p" "$FILE" > "$STAGE/source.txt"   # copy text from here, never retype it
```

Write `$STAGE/new.jsonl`, one proposition per line, in reading order:

- `text` — copied character for character from the source, LaTeX included (`\%`, `\citep{...}`,
  `$...$`). Retyping is how paraphrase creeps in; R1 will catch it, but copying avoids the loop.
- `location` — `L<a>` or `L<a>-L<b>` for the main file; `<relpath>.tex:L<a>[-L<b>]` for a file
  under the main file's directory (schema v1.6+). Use the line where the unit starts.
- `id` — `tmp:<label>` (letters, digits, `_`, `-`), unique within the batch.
- `cites` — `tmp:<label>` for props in this batch, the existing UUID for props already in the
  ledger.
- `claim_type`, `evidence_class`, `asserts`, `containing_block`, and the other fields — from the
  loaded reference and the ledger's pinned `EXTRACTION-PROMPT.md`. Use only values in the
  profile's vocabulary.

## Step 6 — Assign ids

```bash
python3 "$ASSIGN" "$STAGE/new.jsonl" --out "$STAGE/new.ids.jsonl"
```

Exit 1 names the problem (a cite to an undefined `tmp:` label, a duplicate label, a malformed
`tmp:` value, bad JSON). Fix `new.jsonl` and rerun with a fresh `--out` path; the script never
overwrites a file.

## Step 7 — Coverage

```bash
python3 "$COVERAGE" --tex "$FILE" --lines "$A-$B" --jsonl "$STAGE/new.ids.jsonl" --main "$MAIN"
```

- `UNCOVERED Lx-Ly: …` — text no prop covers. Either it is a unit you missed (go back to
  step 5) or the user accepts leaving it out (step 8). Do not accept on the user's behalf.
- `WARNING <id>: text not found …` — that prop's text is not verbatim, or only part of it lies
  in the range. Fix the text or the range.
- `WARNING <id>: … equally near …` — the same text occurs twice; give the prop the `location`
  of the occurrence it means.
- `excluded table/figure Lx-Ly` — floats are not extracted by this skill; say so in the report.

Exactly five structures are excluded and never reported: comments, `\label{...}`, sectioning
commands with their titles, `\begin`/`\end` markers, and table/figure floats. Anything else
that is uncovered is either extracted or explicitly accepted.

## Step 8 — Curation with the user

Show the staged props as a compact table (location, claim_type, evidence_class, first words of
the text) together with any uncovered runs, and walk the curation checklist in the reference.
Ask the user (AskUserQuestion) to accept, or to say what to change. Record each uncovered run
the user accepts — it goes into the completion report.

## Step 9 — Validate a merged copy

Insert the new lines into a copy of the ledger at their reading-order position: before the
first existing prop that starts after the range. "After" means in the order a reader meets the
text — the `\input` tree is expanded at the line of each `\input`, so a part's lines come
between the main-file lines around its `\input`, not after the whole main file.

```bash
python3 - "$LEDGER/main.jsonl" "$STAGE/new.ids.jsonl" "$STAGE/merged.jsonl" "$FILE" "$MAIN" "$A" "$SCRIPTS" <<'PY'
import json, re, sys
from pathlib import Path
ledger, new, out, file, main, a, scripts = sys.argv[1:]
sys.path.insert(0, scripts)
from _lib.latex_env_parser import parse_location_v16
mainp = Path(main).resolve()
INPUT = re.compile(r"\\(?:input|include)\s*\{([^}]+)\}")
def uncommented(line):  # drop text from a % preceded by an even number of backslashes
    out, slashes = [], 0
    for ch in line:
        if ch == "%" and slashes % 2 == 0:
            break
        slashes = slashes + 1 if ch == "\\" else 0
        out.append(ch)
    return "".join(out)
def walk(f, seq, depth=0):  # reading order: expand each \input where it occurs
    for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        seq.append((f, n))
        for m in INPUT.finditer(uncommented(line)) if depth < 3 else ():
            name = m.group(1).strip()
            child = (mainp.parent / (name if name.endswith(".tex") else name + ".tex")).resolve()
            if child.is_file():
                walk(child, seq, depth + 1)
seq = []; walk(mainp, seq); rank = {k: i for i, k in enumerate(seq)}
def key(loc):
    parsed = parse_location_v16(loc)
    if not parsed:
        return None
    rel, s, _ = parsed
    f = mainp if rel is None else (mainp.parent / rel).resolve()
    return rank.get((f, s))
start = rank[(Path(file).resolve(), int(a))]
lines = open(ledger, encoding="utf-8").read().splitlines(keepends=True)
at = len(lines)
for i, raw in enumerate(lines):
    if raw.strip() and not raw.lstrip().startswith("//"):
        k = key(json.loads(raw).get("location", ""))
        if k is not None and k > start:
            at = i; break
block = open(new, encoding="utf-8").read()
block = block if block.endswith("\n") else block + "\n"
Path(out).write_text("".join(lines[:at]) + block + "".join(lines[at:]), encoding="utf-8")
print(f"insert before ledger line {at + 1} of {len(lines)}")
PY
python3 "$VALIDATOR" --jsonl "$STAGE/merged.jsonl" --meta "$LEDGER/_meta.json" --tex "$MAIN"
```

The validator must exit 0 on the copy. If it exits 1, show the failing rules and go back to
the step they point at; do not offer the merge. Warnings (R9, R13, R1.5 informational) do not
block, but mention any that concern the new props.

## Step 10 — Show the diff, merge only on confirmation

```bash
diff -u "$LEDGER/main.jsonl" "$STAGE/merged.jsonl" | head -80
```

Show the insertion point, the number of new props, and the diff, then ask the user to confirm
writing the ledger. The ledger lives in the user's repository; writing it without a yes is
exactly what the plugin's hard rule forbids. On yes: `cp "$STAGE/merged.jsonl" "$LEDGER/main.jsonl"`.
On no: leave the ledger untouched and say where the staged files are.

## Step 11 — Final gate and report

Run the validator once more on `$LEDGER/main.jsonl`; it must exit 0, as the copy did. The
extraction is complete only when that holds **and** the coverage check exited 0 or every
uncovered run was accepted by the user. Report:

- props added, by `claim_type`, and where they were inserted;
- the coverage result, with every accepted uncovered run and its lines;
- excluded floats in the range;
- next step: `/propositions:proofread` walks whether each prop's claim and cites hold.

Updating `_meta.json` `coverage.sections_extracted` is a separate write; offer it, do not do it
silently.
