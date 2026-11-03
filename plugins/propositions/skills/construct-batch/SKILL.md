---
name: construct-batch
description: >-
  Annotates the dependency tree of a long manuscript by splitting it into paragraph-safe batches,
  sending each to its own subagent, and merging the answers back into staged structure sidecars.
  Use when the user wants the article structure annotated and the ledger is too long for one pass
  (about 100 propositions or more: "整篇標註", "分批標註", "annotate the whole paper in batches"),
  when a ledger has to be put in reading order first ("帳冊順序不對", "reorder the ledger"),
  or when sidecars whose tree already exists need moves and paragraph types ("只標步驟", "label
  the moves only").
  It only drafts in staging; review and writing stay with /propositions:construct. Not for
  short manuscripts, the next-sentence question, or commitments, which /propositions:construct
  handles directly.
allowed-tools:
  - Read
  - Write
  - Bash
  - Agent
  - AskUserQuestion
---

# Construct in batches

`/propositions:construct` annotate mode holds the rules. This skill replaces only its step A3
for manuscripts too long to label well in one pass. Everything before A3 and after it stays
with that skill: preconditions, section and paragraph plan, validation, summary, confirmation.

Steps 1–7 annotate a manuscript from the start. Sidecars whose tree already exists go straight to
[Moves only](#moves-only-sidecars-whose-tree-already-exists).

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(ls -d "$HOME"/.claude/plugins/cache/propositions-projects/propositions/*/ 2>/dev/null | sort -V | tail -1)}"
SCRIPTS="$PLUGIN_ROOT/scripts"
```

## 1. Put the ledger in reading order

```bash
python3 "$SCRIPTS/reorder-ledger.py" --jsonl "$LEDGER/main.jsonl"
```

Exit 0: go on. Exit 1: lines would move. This is the one step here that changes the ledger, so
show the count and ask (AskUserQuestion) before running it again with `--write`. Line contents and ids do
not change. Then rerun `validate-propositions.py`; its results must not change. If the tool reports several propositions on one TeX line,
read those lines and check their order by hand.

## 2. Stage a skeleton

Run construct's A1 and A2. Draft `$STAGE/structure.json` (sections with `parent`, the paragraph plan)
and `$STAGE/discourse.jsonl` (one record per non-retired proposition, in ledger order, with only `prop_id`).
If 1.0 sidecars exist, `migrate-structure-v2.py` produces this skeleton instead.

## 3. Split

```bash
python3 "$SCRIPTS/structure-batch.py" split --jsonl "$LEDGER/main.jsonl" \
  --structure "$STAGE/structure.json" --discourse "$STAGE/discourse.jsonl" --out-dir "$STAGE/batches"
```

Batches hold whole paragraphs (at most 60 propositions unless a paragraph is longer; `--max-props`).

## 4. One subagent per batch

Dispatch in parallel, one per `input-NN.json`, pinned to a cheaper model when there are many. Give each one:

- the path of its input file and of `references/vocabulary.md` of the construct skill;
- the output path `output-NN.json` and the format in the `structure-batch.py` docstring;
- this instruction: choose heads for the tree as the text reads, and never move a head only to avoid a crossing. Keep a crossing and add a `note`.
- the instruction that `note` is only for close calls, written as `runner-up: <the other choice>; lost because <reason>`, and that most propositions have none. When you write the subagent's prompt, do not list `note` as a field every proposition fills, and do not show it on every entry of an example: a note on every record makes A5's list of close calls the whole article (#34).
- the instruction to report every place where the natural head would cross, naming both candidates. The summary needs that count: otherwise a low crossing rate says little.
- the instruction to label only the tree. Commitments, moves and paragraph types are not theirs.

A batch's first paragraph may hang on a paragraph of an earlier batch of the same section; `sections` and
paragraph ids in the input are enough to name it, but the subagent cannot read that paragraph, so have it
flag such choices for you to check.

## 5. Merge

```bash
python3 "$SCRIPTS/structure-batch.py" merge --jsonl "$LEDGER/main.jsonl" \
  --structure "$STAGE/structure.json" --discourse "$STAGE/discourse.jsonl" --out-dir "$STAGE/batches"
```

Exit 2 names the missing answers; nothing is written. Fix that batch and rerun.

## 6. Commitments

Read the manuscript in order and add `opens`, `discharges` and `thesis` to `$STAGE/batches/discourse.jsonl`
and `structure.json` yourself: a commitment often spans batches, so a batch cannot see both ends.
Check the flagged paragraph heads.

## 7. Moves and types, then back to construct

Set `TREE="$STAGE/batches"` and follow [Moves only](#moves-only-sidecars-whose-tree-already-exists) from
its split step. It ends at construct's A4. Report the crossings the subagents avoided or kept alongside
the S7 count.

## Moves only: sidecars whose tree already exists

This path labels `move` on every record and `type` on every paragraph. It does not draft or change the
tree. Coming straight here, run construct's A1 and stage a copy of the sidecars. Skip step 1 and construct's
A2: the ledger order and the paragraph plan stay as they are.

```bash
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/construct-XXXXXX")
TREE="$STAGE/tree"
mkdir "$TREE" && cp "$LEDGER/structure.json" "$LEDGER/discourse.jsonl" "$TREE/"
```

**Split.** Batches hold whole paragraphs, as in step 3. Each proposition in the input also has its head
position and relation.

```bash
python3 "$SCRIPTS/structure-batch.py" split --moves-only --jsonl "$LEDGER/main.jsonl" \
  --structure "$TREE/structure.json" --discourse "$TREE/discourse.jsonl" --out-dir "$TREE/moves"
```

**One subagent per batch.** Dispatch them as in step 4. Give each one:

- its input file `input-NN.json`;
- `catalog/vocabulary.yaml` of this plugin (`$PLUGIN_ROOT/catalog/vocabulary.yaml`);
- `references/vocabulary.md` of the construct skill, section "Moves and paragraph types";
- the output path `output-NN.json` and this format, with an entry for every proposition and paragraph of
  the batch:

  ```json
  {"propositions": {"<position>": {"move": "<move id>"}}, "paragraphs": {"<id>": {"type": "<paragraph type id>"}}}
  ```

- the instruction to label only moves and types. The head and relation are in the input to be read; the
  subagent does not change them and writes no other field. If one looks wrong, it reports the position.
- the instruction that a value missing from the vocabulary is a stop: leave that position or paragraph out
  of the output and report it with what it does. Never choose a near value.
- the instruction to report close calls in its reply, naming the position, the value chosen and the
  runner-up. The output format has no `note`.

**Merge.** Only `move` and `type` change; every other field of the staged sidecars stays as it is.

```bash
python3 "$SCRIPTS/structure-batch.py" merge --moves-only --jsonl "$LEDGER/main.jsonl" \
  --structure "$TREE/structure.json" --discourse "$TREE/discourse.jsonl" --out-dir "$TREE/moves"
```

Exit 2 names the missing answers, and no sidecar is written. If a subagent left an answer out because no
value fits, stop and report the position to the user; otherwise fix that batch and rerun.

**Back to construct.** Set `STAGE="$TREE/moves"` and continue at construct's A4, so that its commands use
the merged files. Show the close calls the subagents reported beside A5's list: they are not in `note`
fields.
