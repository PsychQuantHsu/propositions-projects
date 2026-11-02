# Article structure

The ledger (`main.jsonl`) says what each proposition claims and which earlier
propositions it rests on (`cites`). It does not say how the article is built:
what the article has promised the reader and where it keeps those promises,
what each section is for, and how each proposition connects to the one before
it. Two **sidecars** next to the ledger record that:

```
manuscript/propositions/
├── main.jsonl        # the ledger (unchanged by this format)
├── _meta.json
├── structure.json    # article level: thesis and section plan
└── discourse.jsonl   # one record per non-retired proposition
```

Adding, changing or removing the sidecars never changes `main.jsonl`, and
nothing in `validate-propositions.py` reads them. A ledger without sidecars
validates exactly as before. The sidecars have their own validator,
`validate-structure.py` (rules S1–S6), and a state query, `structure-state.py`;
both are introduced with this format (Spectra change
`add-article-construction-model`). The `propositions:construct` skill writes
the sidecars for an existing manuscript and reads them to propose the next
sentence of a draft.

## Three layers

What the next proposition should do is decided by three layers at once. Each
layer is recorded separately and has its own closed vocabulary.

| Layer | Question it answers | Recorded in |
|---|---|---|
| Commitments | What does the article still owe the reader? | `discourse.jsonl`: `opens`, `discharges` |
| Section roles | Which part of the plan is this, and what is that part for? | `structure.json`: `sections[].role` |
| Relations | How does this proposition connect to the previous one? | `discourse.jsonl`: `relation` |

The layers are independent. One proposition can open with "We now turn to"
(relation `shift`), sit in a `results` section, and discharge a `plan` item,
all at once.

**Why sidecars and not new ledger fields.** The ledger is a contract shared by
several skills; a new field would need a schema version and backward
compatibility across R1–R13. Structure labels are also more a matter of
judgement than extraction is, so keeping them apart lets them be redone
without touching the ledger. `verification.jsonl` set the same precedent
(see `VERIFICATION.md`).

**Why no fourth layer of rhetorical moves.** Paragraph-level moves in the
Swales sense ("establish the field, point out a gap, occupy the gap") are
already expressed by section role plus commitment kind: pointing out a gap
usually opens a `question`, and occupying it opens an `aim` or a `plan`. A
separate move layer would give the same fact two labels.

## Reading order and position

**Reading order** is the line order of `main.jsonl`, skipping retired
propositions. For a multi-file manuscript (schema v1.6+) the ledger follows the
flattened `\input` tree, so its line order is that flattened order.

**Position** is a proposition's 1-based place in reading order. Once S1 passes,
the records of `discourse.jsonl` are in the same order, so the n-th record (blank
lines are not records) belongs to the proposition at position n. The validator
and the state query report problems by position and id; a record whose
`prop_id` is not a non-retired ledger proposition has no position and is
reported by its line number instead.

The **previous proposition** is the one at the position just before. This holds
across every boundary: between two clause-level propositions split from one
sentence, from the end of one paragraph to the start of the next, and from the
last proposition of one section to the first of the next.

## `structure.json`

One JSON object for the whole article.

```json
{
  "structure_version": "1.0",
  "thesis": ["019f3a10-0000-7000-8000-00000000000c"],
  "sections": [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first_prop": "019f3a10-0000-7000-8000-000000000001"},
    {"id": "sec-2", "heading": "Method",       "role": "method",       "first_prop": "019f3a10-0000-7000-8000-000000000005"},
    {"id": "sec-3", "heading": "Results",      "role": "results",      "first_prop": "019f3a10-0000-7000-8000-000000000008"},
    {"id": "sec-4", "heading": "Discussion",   "role": "discussion",   "first_prop": "019f3a10-0000-7000-8000-00000000000b"}
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `structure_version` | ✅ | Format version; currently `"1.0"` |
| `thesis` | ✅ | Non-empty list of full UUIDs of the propositions that state the article's main point |
| `sections` | ✅ | The section plan, a flat list in reading order |
| `sections[].id` | ✅ | Identifier unique within the file, e.g. `sec-1`, `sec-1-1` |
| `sections[].heading` | ✅ | The section heading |
| `sections[].role` | ✅ | One of the ten section roles below |
| `sections[].first_prop` | ✅ | Full UUID of the section's first non-retired proposition |

- The list is **flat**. A subsection such as 1.1 is an entry of its own, and its
  role may differ from the role of the section it belongs to.
- The first entry's `first_prop` is the first non-retired proposition in the
  ledger. Later `first_prop` values strictly increase in reading order.
- A section extends from its `first_prop` up to, not including, the next
  section's `first_prop`. The last section extends to the end of the ledger.
- Every entry needs a `first_prop` of its own, so a heading with no
  propositions of its own has no entry. In the reference manuscript,
  "2. Method" is followed directly by 2.1, so 2.1 and 2.2 are entries with role
  `method` and "2. Method" itself is not. An appendix that was not extracted
  has no entry either.

## `discourse.jsonl`

One JSON object per line: one record for each non-retired ledger proposition,
in the same order as `main.jsonl`.

```json
{"prop_id": "019f3a10-0000-7000-8000-000000000001", "relation": "start"}
{"prop_id": "019f3a10-0000-7000-8000-000000000002", "relation": "contrast", "opens": [{"id": "c-q-1", "kind": "question"}]}
{"prop_id": "019f3a10-0000-7000-8000-000000000003", "relation": "consequence", "opens": [{"id": "c-aim-1", "kind": "aim"}]}
{"prop_id": "019f3a10-0000-7000-8000-000000000004", "relation": "addition", "opens": [{"id": "c-ann-1", "kind": "announcement"}]}
{"prop_id": "019f3a10-0000-7000-8000-000000000005", "relation": "specification", "discharges": ["c-ann-1"]}
{"prop_id": "019f3a10-0000-7000-8000-00000000000b", "relation": "return", "refers_to": "019f3a10-0000-7000-8000-000000000002", "discharges": ["c-q-1"], "note": "answers the question raised in the introduction"}
```

(The example shows six of the records; a real file has one per proposition.)

| Field | Required | Meaning |
|---|---|---|
| `prop_id` | ✅ | Full UUID of the ledger proposition this record describes |
| `relation` | ✅ | One of the twelve relations below: how this proposition connects to the previous one |
| `refers_to` | ✅ when `relation` is `return`; otherwise absent | Full UUID of the earlier proposition whose line this one returns to |
| `opens` | — | Commitments this proposition opens; each is `{"id": ..., "kind": ...}` |
| `discharges` | — | Ids of commitments this proposition discharges |
| `note` | — | Free text |

### Relations

- Every record has a `relation`, including the first proposition of a
  paragraph or a section. If it has a local relation to the previous
  proposition, record that relation. When the last proposition of a section
  announces what comes next and the next section's first proposition delivers
  it, the relation is often `continue` or `specification`. With no local
  relation, use `shift`. Going back to an earlier line, use `return`.
- Clause-level propositions carry a relation too. When the ledger splits one
  sentence into two propositions, the second one is related to the first. The
  clearest connectives often sit inside a sentence ("…; rather, …",
  "That is, …"), so leaving them out would lose the strongest signal.

### Commitments

- A commitment id matches `^[a-z0-9][a-z0-9-]{0,63}$` and is unique in the
  file. Names such as `c-q-1`, `c-plan-2` or `c-ann-1` are a convention, not a
  rule.
- A commitment is discharged only by a strictly later proposition. A
  proposition cannot discharge a commitment it opens itself; it may open one
  commitment and discharge a different one.
- A commitment may be discharged more than once (an aim is often kept once in
  the results and again in the discussion). The state query counts the first
  discharge as the moment the commitment stops being open.
- A `future_work` commitment must never be discharged.

## Vocabulary

Values are lower-case and matched exactly. A value that resembles a listed one
(`Consequence`, `elaboration`, `literature`) is rejected, not mapped to it.

**Instances.** The instances come from the reference manuscript, the published
version of Cheng, Lay, Hsu, & Tsai (2021), *Methods in Psychology, 5*, Article
100081, https://doi.org/10.1016/j.metip.2021.100081 (CC BY-NC-ND 4.0; LS =
Likert scale, CJ = comparative judgment). The repository's
`docs/REFERENCE-MANUSCRIPTS.md` describes it. An instance quotes only the
connective or the heading, never the proposition, and only from the published
version. A connective is evidence for a label, not the label: the boundary
note and the priority order decide. Where the reference manuscript has no
instance, a short generic example is given and marked as such.

### Relations (12)

These are the only 12 values; do not infer a new value from resemblance to a
listed one. The skeleton is the sense hierarchy of the Penn Discourse Treebank 3
(PDTB-3), cut down to the senses an article needs, plus two structural values
(`shift`, `return`).

| Value | Use it when | Typical markers | Instance | PDTB-3 |
|---|---|---|---|---|
| `start` | The proposition is the first record; no other record may carry it | — | The first proposition of the abstract (no connective) | — |
| `shift` | A new line begins: no local relation to the previous proposition and no return to an earlier line; it follows the section plan or an open commitment instead | paragraph or section opening; We now turn to | "We now turn to comparing" | — |
| `continue` | The next statement on the same topic, when no more specific relation holds | no connective | (generic; no quotable instance in the reference manuscript, because `continue` has no connective) *The study list held 40 nouns.* → *The list was drawn from a published norm set.* | EntRel |
| `restatement` | Says what the previous proposition said, or its equivalent, in other words; adds no new claim | That is; In other words | "That is,"; "In other words," | Expansion.Equivalence |
| `specification` | Makes the previous proposition more specific or detailed; the same claim, made finer | Specifically; In particular | "Specifically," | Expansion.Level-of-detail |
| `instance` | Gives one example of what the previous proposition states in general | For example; To illustrate; e.g. | "To illustrate," | Expansion.Instantiation |
| `addition` | Adds another item of the same kind, at the same level as the previous proposition | Moreover; Furthermore; In addition | "Moreover,"; "Furthermore," | Expansion.Conjunction |
| `contrast` | Opposes the previous proposition, concedes against it, or corrects it by putting the right alternative in its place | However; Although; Rather | "However,"; "Rather," | Comparison.Contrast / Concession; Expansion.Substitution |
| `reason` | Gives the reason or cause of the previous proposition, which it follows | because; since; due to | "because" (mid-sentence, after the clause it explains) | Contingency.Cause.Reason |
| `consequence` | States a result or conclusion that follows from the previous proposition, including an interpretation drawn from evidence | Therefore; Thus; Accordingly; These results suggest | "Therefore,"; "Accordingly,"; "Consequently," | Contingency.Cause.Result (including +Belief) |
| `sequence` | Gives the next step of a procedure or the next event in time; the order is the point | Then; Next; First … Finally | "We then …" after "We first …" | Temporal.Asynchronous |
| `return` | Goes back to a line left earlier; `refers_to` names the earlier proposition | As mentioned in Section …; Recall that | "mentioned in Section 1.2" | — |

**Priority.** When two values fit, take the first in this order:

`return` > `restatement` > `specification` > `instance` > `contrast` >
`reason` > `consequence` > `sequence` > `addition` > `continue`

`shift` is used only when no value in this order applies: the proposition has
no local relation to the previous one and does not return to an earlier line.
`start` is fixed by position and never competes. In the reference manuscript,
the proposition marked "mentioned in Section 1.2" also opens with "Moreover,";
`return` outranks `addition`, so its relation is `return`.

**Close calls.**

- `restatement` or `specification`: the same content in other words, or the
  same claim in finer detail.
- `specification` or `instance`: a finer version of the claim, or one case of
  a general claim.
- `reason` or `consequence`: decided by direction. The proposition that gives
  the reason after the fact is `reason`. When the reason comes first
  ("Due to the fact that …, …") and the sentence is split, the clause after it
  is a `consequence` of the reason clause.
- `addition` or `sequence`: if swapping the two propositions changes the
  meaning, the order matters and it is `sequence`.
- `continue` or `shift`: still the same topic, or a new line taken from the
  plan or from an open commitment.

### Commitment kinds (7)

These are the only 7 kinds; do not infer a new kind from resemblance to a
listed one. A commitment is opened in `opens` and kept in `discharges`. The
last column is the S4 severity when a complete article never discharges it.

| Kind | What counts | Discharged by | Never discharged | Instance |
|---|---|---|---|---|
| `question` | A research question the article undertakes to answer, written as a question or as a "whether …" clause that poses it | A proposition that gives the answer | error | "whether the result of LS can accurately reflect" |
| `aim` | A declared purpose or task: "the main goal is to …", "we examined whether …" | A proposition that reports the result of doing it | error | "In summary, the main goal of this study is to examine" |
| `hypothesis` | A claim or explanation put forward in order to be tested | The result of the test, whether it supports or rejects the claim | error | "a possible explanation … is that" |
| `plan` | A declared organization of the article or of a section; each item opens its own commitment | The proposition that delivers that item | error | "This article is organized as follows. We first … We then … We wrap up …" (three items, three commitments; "We first" is kept by 1.1, "We wrap up" by 4) |
| `announcement` | A short-range promise that specific content comes next: "We now examine …", "which we now describe", "as follows:" | The content delivered right after it | error | "We now examine an alternative explanation." |
| `setup` | A concern, condition or consideration laid out for later use; ordinary definitions are excluded, because `cites` already records where a definition is used | The first later proposition that uses it | warning | The concerns about LS laid out in 1.2, used by the proposition marked "mentioned in Section 1.2" |
| `future_work` | A commitment to the research field that this article does not keep: further studies, extensions | Nothing; it must never be discharged | not applicable | "One direction of future work" |

Close calls:

- `question` or `aim`: a "whether" clause that states what is unknown is a
  `question`; one that is the object of the authors' task ("to examine
  whether …") is an `aim`.
- `plan` or `announcement`: a plan lays out several parts of the article or a
  section, one commitment per part; an announcement promises the single thing
  that comes next. S6 warns when an announcement is kept far away.
- `hypothesis` or `aim`: a hypothesis is a claim that the test can reject; an
  aim is a task that is done or not done.

### Section roles (10)

These are the only 10 values; do not infer a new value from resemblance to a
listed one. All profiles use the same ten roles. A role describes what the
section does, not where it sits.

| Role | What the section does | Instance |
|---|---|---|
| `abstract` | States the aims and findings in advance, before the introduction. Only the first section may have this role, and no proposition inside it opens a commitment: the body opens and keeps them, so the abstract's aims and findings are not counted twice. Its propositions still carry relations | The abstract of the reference manuscript (no heading) |
| `introduction` | Raises the problem, its importance and the gap; declares the aims and the plan | "1. Introduction" |
| `background` | Reviews literature or prior theory in a section of its own; a review inside the introduction stays `introduction` | (generic; no instance in the reference manuscript) "2. Related work" |
| `formal_setup` | Sets out notation, definitions and inference rules that the argument uses, even when placed under another section | "1.1. Congruence of choices inferred from LS and from CJ" (a subsection of the Introduction) |
| `method` | Describes the study's sample, instruments, procedure and analysis methods | "2. Method" |
| `results` | Reports results and their direct interpretation; in a mathematics manuscript, also the statements of the main theorems | "3. Results" |
| `proofs` | Gives the proofs of a mathematics manuscript in a section of their own | (generic; no instance in the reference manuscript) "5. Proofs of the main results" |
| `discussion` | Synthesizes the findings, draws implications, and states limitations and future work | "4. Discussion" |
| `conclusion` | Concludes in a section of its own; closing paragraphs inside the discussion stay `discussion` | (generic; no instance in the reference manuscript) "6. Conclusion" |
| `appendix` | Holds material placed in an appendix | "Appendix" |

## Validator

```bash
python3 plugins/propositions/scripts/validate-structure.py \
  --jsonl manuscript/propositions/main.jsonl
```

`--structure` and `--discourse` default to `structure.json` and
`discourse.jsonl` in the ledger's directory. `--partial` is for unfinished
drafts (below). `--format text|json` selects the output format.

| Rule | Severity | Checks |
|---|---|---|
| S1 | error | `discourse.jsonl` has exactly one record per non-retired ledger proposition, in ledger order. Missing, extra, duplicate and out-of-order records are listed separately |
| S2 | error | `relation` is one of the 12 values. The first record is `start` and no other record is. A `return` carries `refers_to` naming an earlier proposition; no other record carries `refers_to` |
| S3 | error | Commitment ids match the pattern and are unique; `kind` is one of the 7. Every discharged id was opened by a strictly earlier record. No `future_work` is discharged |
| S4 | error / warning | Every `question`, `aim`, `hypothesis`, `plan` and `announcement` is discharged at least once (error). An undischarged `setup` is a warning. `future_work` is not reported |
| S5 | error | `structure.json` has the required fields; each `role` is one of the 10; an `abstract` section is only the first entry and no proposition inside it opens a commitment; section ids are unique; every `first_prop` names a non-retired proposition, the values strictly increase in ledger order, and the first section starts at the first non-retired proposition; `thesis` is non-empty and every entry names a non-retired proposition |
| S6 | warning | An `announcement` is first discharged neither in the section where it was opened nor in the next section |

The output has one summary line per rule, marked `[PASS]`, `[FAIL]` or
`[WARN]`, followed by each problem with the proposition's position and id.
Exit code: `0` no errors (warnings allowed), `1` at least one error, `2` input
error: a file is missing, unreadable or not valid JSON (the message names the
file, or the line of `discourse.jsonl`). Both sidecars are required; a missing
one is exit `2`.

**Unfinished drafts.** A draft in progress always has open commitments, and it
often has not stated its thesis yet. With `--partial`, S4 lists undischarged
commitments, `setup` included, as information instead of errors or warnings,
and S5 reports an empty `thesis` as information, so the draft can pass. Every
other check applies unchanged.

An error in `thesis` or `structure_version` fails S5 but does not stop S6 or the
state query from using a section list that is itself valid; only an invalid
section list does that (S6 then says it was not evaluated).

## State query

```bash
python3 plugins/propositions/scripts/structure-state.py \
  --jsonl manuscript/propositions/main.jsonl --at end
```

`--at` takes a proposition's full UUID or `end`; `--format text|json` and the
sidecar paths work as in the validator. The query first applies S1–S3 and
exits `1` if any fails: fix the structure before asking about it.

For position t, counting t itself, it reports t's position and the total
count; the section containing t (id, heading, role); t's relation; the open
commitments; the `future_work` commitments opened so far, in a separate list;
and whether any `thesis` proposition has appeared. A commitment is **open** at
t if it was opened at or before t and not discharged at or before t. Each open
commitment is listed with its id, its kind, the position and id of the
proposition that opened it, and the number of propositions since then.

Open commitments are ordered by kind, from most to least pressing:

`announcement` → `hypothesis` → `plan` → `question` → `aim` → `setup`

and within a kind by the position that opened them, earliest first.
`future_work` takes no part in the ordering. An open announcement almost always
has to be kept by the very next proposition, which is why it comes first. This
ordering is the mechanical answer to "what should the next proposition
advance?": the first open commitment in the list. The `propositions:construct`
skill starts from that answer and adds judgement from the section's role and
the previous relation.

Example: in a ledger of 10 propositions, position 1 opens `c-q-1` (question),
position 2 opens `c-plan-1` and `c-plan-2` (plan), position 4 discharges
`c-plan-1`, and position 6 opens `c-ann-1` (announcement) and `c-fw-1`
(future_work). At position 6:

| Order | Commitment | Kind | Opened at | Since |
|---|---|---|---|---|
| 1 | `c-ann-1` | announcement | 6 | 0 |
| 2 | `c-plan-2` | plan | 2 | 4 |
| 3 | `c-q-1` | question | 1 | 5 |

`c-fw-1` appears only in the future-work list.

Exit code: `0` success, `1` the sidecars fail S1–S3, `2` input error or an
`--at` id that is not a non-retired ledger proposition (the message names the
id).

## What is not checked

The validator checks that the annotation is structurally consistent, not that
it is right. Whether `consequence` was the right relation, or whether a
proposition really answers the question it claims to discharge, is a matter
for a human reader, in the same way that `validate-propositions.py` checks the
ledger's form and `propositions:proofread` checks its meaning. When the ledger
gains or loses propositions, the sidecars are not updated automatically; S1
reports every record that no longer matches.
