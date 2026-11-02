---
name: construct-batch
description: >-
  Annotates the dependency tree of a long manuscript by splitting it into paragraph-safe batches,
  sending each to its own subagent, and merging the answers back into staged structure sidecars.
  Use when the user wants the article structure annotated and the ledger is too long for one pass
  (about 100 propositions or more: "整篇標註", "分批標註", "annotate the whole paper in batches"),
  or when a ledger has to be put in reading order first ("帳冊順序不對", "reorder the ledger").
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
- the instruction to report every place where the natural head would cross, naming both candidates. The summary needs that count: otherwise a low crossing rate says little.
- the instruction to label only the tree. Commitments are not theirs.

A batch's first paragraph may hang on a paragraph of an earlier batch of the same section; `sections` and
paragraph ids in the input are enough to name it, but the subagent cannot read that paragraph, so have it
flag such choices for you to check.

## 5. Merge

```bash
python3 "$SCRIPTS/structure-batch.py" merge --jsonl "$LEDGER/main.jsonl" \
  --structure "$STAGE/structure.json" --discourse "$STAGE/discourse.jsonl" --out-dir "$STAGE/batches"
```

Exit 2 names the missing answers; nothing is written. Fix that batch and rerun.

## 6. Commitments, then back to construct

Read the manuscript in order and add `opens`, `discharges` and `thesis` to `$STAGE/batches/discourse.jsonl`
and `structure.json` yourself: a commitment often spans batches, so a batch cannot see both ends.
Check the flagged paragraph heads. Then continue at construct's A4 with those two files as the staged
sidecars. Report the crossings the subagents avoided or kept alongside the S7 count.
