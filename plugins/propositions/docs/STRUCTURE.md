# Article structure

The ledger (`main.jsonl`) says what each proposition claims and which earlier
propositions it rests on (`cites`). It does not say how the article is built:
what the article has promised the reader and where it keeps those promises,
what each section is for, and how each proposition and each paragraph hangs on
the rest. Two **sidecars** next to the ledger record that:

```
manuscript/propositions/
├── main.jsonl        # the ledger (unchanged by this format)
├── _meta.json
├── structure.json    # article level: thesis, section plan, paragraph plan
└── discourse.jsonl   # one record per non-retired proposition
```

Adding, changing or removing the sidecars never changes `main.jsonl`, and
nothing in `validate-propositions.py` reads them. A ledger without sidecars
validates exactly as before. The sidecars have their own validator,
`validate-structure.py` (rules S1–S8), a state query, `structure-state.py`, and
a metrics report, `structure-metrics.py`. `derive-paragraphs.py` proposes the
paragraph plan from the TeX source, and `migrate-structure-v2.py` turns version
1.0 sidecars into the current version 2.0. The `propositions:construct` skill
writes the sidecars for an existing manuscript and reads them to propose the
next sentence of a draft. (Version 1.0 came with Spectra change
`add-article-construction-model`; version 2.0 with
`add-discourse-dependency-tree`.)

## Three layers

What the next proposition should do is decided by three layers at once. Each
layer is recorded separately and has its own closed vocabulary.

| Layer | Question it answers | Recorded in |
|---|---|---|
| Commitments | What does the article still owe the reader? | `discourse.jsonl`: `opens`, `discharges` |
| Section roles | Which part of the plan is this, and what is that part for? | `structure.json`: `sections[].role` |
| Dependency tree | What does this proposition hang on, and how? What does this paragraph hang on? | `discourse.jsonl`: `head`, `relation`, `also`; `structure.json`: `paragraphs`, `sections[].parent` |

The layers are independent. One proposition can be the root of a new paragraph,
sit in a `results` section, and discharge a `plan` item, all at once.

**Why sidecars and not new ledger fields.** The ledger is a contract shared by
several skills; a new field would need a schema version and backward
compatibility across R1–R13. Structure labels are also more a matter of
judgement than extraction is, so keeping them apart lets them be redone
without touching the ledger. `verification.jsonl` set the same precedent
(see `VERIFICATION.md`).

**Why a tree, in three levels.** A proposition rarely depends only on the one
before it: in the reference manuscript, of the 191 propositions whose ledger
entry cites another, only 65 cite the previous proposition alone. A clause such
as "Because …," belongs to the sentence after it, and a paragraph answers to
an earlier paragraph, not to its last sentence. So every proposition has one
**head** inside its paragraph, before or after it; every paragraph has one head
inside its section; and every section names its `parent`. Each choice is still
one head and one relation, so annotating costs about what one relation per
proposition did. The tree gives three things the earlier one-relation model
could not: scopes (paragraph, section), the **right frontier** (where the next
proposition can attach) and nesting for commitments. Long-range dependencies
that the tree does not carry are already in the ledger's `cites`; `also`
records any other relation worth keeping.

**Why not a constituency tree.** Rhetorical Structure Theory builds trees of
spans with nuclei and satellites. Drawing span boundaries and choosing nuclei
is harder and less consistent than choosing one head per unit, and the
paragraph and section levels already supply the spans that matter here.

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

**Paragraphs and sections are ranges.** A paragraph extends from its
`first_prop` up to, not including, the next paragraph's `first_prop`; a section
likewise. No paragraph crosses a section boundary.

## `structure.json`

One JSON object for the whole article.

```json
{
  "structure_version": "2.0",
  "thesis": ["019a3c5e-7a00-7000-8000-000000000009"],
  "sections": [
    {"id": "sec-introduction", "heading": "Introduction", "role": "introduction", "first_prop": "019a3c5e-7a00-7000-8000-000000000001"},
    {"id": "sec-results", "heading": "Results", "role": "results", "first_prop": "019a3c5e-7a00-7000-8000-000000000008"},
    {"id": "sec-alternative", "heading": "An alternative explanation", "role": "results", "first_prop": "019a3c5e-7a00-7000-8000-00000000000a", "parent": "sec-results"}
  ],
  "paragraphs": [
    {"id": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-000000000001"},
    {"id": "p-3", "first_prop": "019a3c5e-7a00-7000-8000-000000000008"},
    {"id": "p-4", "first_prop": "019a3c5e-7a00-7000-8000-00000000000a"},
    {"id": "p-6", "first_prop": "019a3c5e-7a00-7000-8000-00000000000c", "head": "p-5", "relation": "addition"}
  ]
}
```

(The example shows some entries of the synthetic fixture in `tests/fixtures/structure/`.)

| Field | Required | Meaning |
|---|---|---|
| `structure_version` | ✅ | Format version; `"2.0"`. Anything else is refused with exit `2`; version 1.0 sidecars are converted with `migrate-structure-v2.py` |
| `thesis` | ✅ | Non-empty list of full UUIDs of the propositions that state the article's main point |
| `sections` | ✅ | The section plan, a flat list in reading order |
| `sections[].id` | ✅ | Identifier unique within the file, e.g. `sec-1`, `sec-1-1` |
| `sections[].heading` | ✅ | The section heading |
| `sections[].role` | ✅ | One of the ten section roles below |
| `sections[].first_prop` | ✅ | Full UUID of the section's first non-retired proposition |
| `sections[].parent` | — | The id of an earlier section this one sits under; absent for a top-level section |
| `paragraphs` | ✅ | The paragraph plan, a flat list in reading order |
| `paragraphs[].id` | ✅ | Identifier unique within the file, e.g. `p-1` |
| `paragraphs[].first_prop` | ✅ | Full UUID of the paragraph's first non-retired proposition |
| `paragraphs[].head` | — | The id of another paragraph in the same section; absent for the section's root paragraph |
| `paragraphs[].relation` | with `head` | One of the ten relations: this paragraph's role relative to its head paragraph |

- The section list is **flat**. A subsection such as 1.1 is an entry of its own,
  with `parent` naming the section it sits under; its role may differ from its
  parent's role.
- The first entry's `first_prop` is the first non-retired proposition in the
  ledger, for sections and for paragraphs alike. Later `first_prop` values
  strictly increase in reading order.
- Every section's `first_prop` is also some paragraph's `first_prop`.
- Every entry needs a `first_prop` of its own, so a heading with no
  propositions of its own has no entry. In the reference manuscript,
  "2. Method" is followed directly by 2.1, so 2.1 and 2.2 are entries with role
  `method` and "2. Method" itself is not; 2.1 and 2.2 then have no `parent`.
  An appendix that was not extracted has no entry either.
- **The default paragraph plan comes from the TeX source.**
  `derive-paragraphs.py` treats each run of non-blank lines as a paragraph and
  splits it where a section starts. The plan in `structure.json` is what counts:
  merge two TeX paragraphs that make one argument, or split one that makes two,
  by editing the list.

## `discourse.jsonl`

One JSON object per line: one record for each non-retired ledger proposition,
in the same order as `main.jsonl`.

```json
{"prop_id": "019a3c5e-7a00-7000-8000-000000000001", "head": "019a3c5e-7a00-7000-8000-000000000002", "relation": "reason", "opens": [{"id": "c-setup-study-time", "kind": "setup"}]}
{"prop_id": "019a3c5e-7a00-7000-8000-000000000002", "opens": [{"id": "c-q-spacing", "kind": "question"}]}
{"prop_id": "019a3c5e-7a00-7000-8000-000000000003", "head": "019a3c5e-7a00-7000-8000-000000000002", "relation": "restatement", "opens": [{"id": "c-aim-compare", "kind": "aim"}]}
{"prop_id": "019a3c5e-7a00-7000-8000-00000000000b", "also": [{"to": "019a3c5e-7a00-7000-8000-000000000001", "relation": "contrast"}, {"to": "019a3c5e-7a00-7000-8000-000000000007", "relation": "basis"}], "discharges": ["c-setup-study-time", "c-ann-study-time", "c-plan-discussion"]}
```

(Four records of the fixture: position 1 has its head after it, position 2 is
a paragraph root, position 11 is a root with two `also` entries.)

| Field | Required | Meaning |
|---|---|---|
| `prop_id` | ✅ | Full UUID of the ledger proposition this record describes |
| `head` | ✅ except on a paragraph root | Full UUID of another proposition in the same paragraph, before or after this one; or `"pending"` in a draft (below). A paragraph root has no `head` |
| `relation` | ✅ with a proposition `head` | One of the ten relations: this proposition's role relative to its head. A root has none; with `head: "pending"` it may be left out |
| `also` | — | `[{"to": UUID, "relation": ...}]`: other relations worth recording that neither the tree nor `cites` carries; `to` is any other non-retired proposition except the head |
| `opens` | — | Commitments this proposition opens; each is `{"id": ..., "kind": ...}` |
| `discharges` | — | Ids of commitments this proposition discharges |
| `note` | — | Free text |

### Heads

- **Choose the head the proposition hangs on**, inside its paragraph: the one it
  explains, restates, gives a reason for, draws a consequence from, gives an
  example of. It is often the previous proposition, but it need not be.
- **A head can come later.** A fronted clause ("Because …,", "Since …,",
  "Under such circumstances,") hangs on the sentence after it. The relation is
  recorded on the dependent, so an edge has one spelling only.
- **The paragraph root** is the proposition everything else in the paragraph
  hangs on, directly or through others: usually its main claim. It has no head.
- Clause-level propositions have heads too. When the ledger splits one sentence
  into two propositions, one is the head of the other; the clearest connectives
  often sit inside a sentence ("…; rather, …", "That is, …").
- **Derived labels.** Three things the earlier format labelled are now read off
  the tree: the **start** is the root of the first paragraph; a **shift** is a
  paragraph root (it hangs on nothing in its paragraph); a **return** is a
  proposition whose head is earlier in the paragraph but is not the previous
  proposition — it goes back up the right frontier to an earlier line.

### Drafts: `head: "pending"`

A draft may end with a clause whose head has not been written yet. Its record
carries `"head": "pending"`. This is allowed only with `--partial` and only in
the last paragraph; the state query lists such records, and the next
proposition is usually their head. In the last paragraph of a draft, the root
may not exist yet either: every chain of heads then ends at a pending record.

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
- A commitment's **scope** is the paragraph and section of the proposition that
  opened it. A promise that reaches the next paragraph or a later section
  ("We now examine …" at the end of a paragraph, the article plan in the
  introduction) is recorded as a commitment; how far it reaches is read off
  where it is opened and where it is kept.

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

### Relations (10)

These are the only 10 values; do not infer a new value from resemblance to a
listed one. Each value states the role of the proposition (or paragraph)
relative to its head, or to the `to` of an `also` entry. The first nine follow
the sense hierarchy of the Penn Discourse Treebank 3 (PDTB-3), cut down to the
senses an article needs; `basis` records the dependency the ledger's `cites`
records, when it is the relation that holds. The values `start`, `shift` and
`return` of version 1.0 are no longer labels; they are derived (see Heads).

| Value | Use it when | Typical markers | Instance | PDTB-3 |
|---|---|---|---|---|
| `continue` | The next statement on the same topic, when no more specific relation holds | no connective | (generic; no quotable instance in the reference manuscript, because `continue` has no connective) *The study list held 40 nouns.* → *The list was drawn from a published norm set.* | EntRel |
| `restatement` | Says what the head says, or its equivalent, in other words; adds no new claim | That is; In other words | "That is,"; "In other words," | Expansion.Equivalence |
| `specification` | Makes the head more specific or detailed; the same claim, made finer | Specifically; In particular | "Specifically," | Expansion.Level-of-detail |
| `instance` | Gives one example of what the head states in general | For example; To illustrate; e.g. | "To illustrate," | Expansion.Instantiation |
| `addition` | Adds another item of the same kind, at the same level as the head | Moreover; Furthermore; In addition | "Moreover,"; "Furthermore," | Expansion.Conjunction |
| `contrast` | Opposes the head, concedes against it, or corrects it by putting the right alternative in its place | However; Although; Rather | "However,"; "Rather," | Comparison.Contrast / Concession; Expansion.Substitution |
| `reason` | Gives the reason or cause of the head, before or after it | because; since; due to | "because" (after the clause it explains); "Because …," (before it) | Contingency.Cause.Reason |
| `consequence` | States a result or conclusion that follows from the head, including an interpretation drawn from evidence | Therefore; Thus; Accordingly; These results suggest | "Therefore,"; "Accordingly,"; "Consequently," | Contingency.Cause.Result (including +Belief) |
| `sequence` | Gives the next step of a procedure or the next event in time after the head; the order is the point | Then; Next; First … Finally | "We then …" after "We first …" | Temporal.Asynchronous |
| `basis` | The head (or the `also` target) supplies a definition, result, axiom or case that this proposition uses; the direction is the same as `cites`: this proposition should cite its target in `main.jsonl` (S8) | as defined in; by Lemma …; using (1) | (generic) *By Lemma 2, the map is monotone.* → `basis` to Lemma 2 | — |

**Priority.** When two values fit, take the first in this order:

`restatement` > `specification` > `instance` > `contrast` > `reason` >
`consequence` > `sequence` > `basis` > `addition` > `continue`

**Close calls.**

- `restatement` or `specification`: the same content in other words, or the
  same claim in finer detail.
- `specification` or `instance`: a finer version of the claim, or one case of
  a general claim.
- `reason` or `consequence`: decided by direction. The proposition that gives
  the reason is `reason`, whether it comes before its head ("Because …, …") or
  after it ("…, because …"); the proposition that follows from its head is
  `consequence`.
- `addition` or `sequence`: if swapping the two propositions changes the
  meaning, the order matters and it is `sequence`.
- `basis` or a rhetorical relation: if a rhetorical relation also holds
  (`consequence`, `instance` …), it wins; `basis` is for a proposition that
  uses what its target established and does nothing more specific with it. Do
  not invert it: `basis` points from the user to the supplier, never the other
  way.

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
| `abstract` | States the aims and findings in advance, before the introduction. Only the first section may have this role, and no proposition inside it opens a commitment: the body opens and keeps them, so the abstract's aims and findings are not counted twice. Its propositions still have heads | The abstract of the reference manuscript (no heading) |
| `introduction` | Raises the problem, its importance and the gap; declares the aims and the plan | "1. Introduction" |
| `background` | Reviews literature or prior theory in a section of its own; a review inside the introduction stays `introduction` | (generic; no instance in the reference manuscript) "2. Related work" |
| `formal_setup` | Sets out notation, definitions and inference rules that the argument uses, even when placed under another section | "1.1. Congruence of choices inferred from LS and from CJ" (a subsection of the Introduction) |
| `method` | Describes the study's sample, instruments, procedure and analysis methods | "2. Method" |
| `results` | Reports results and their direct interpretation; in a mathematics manuscript, also the statements of the main theorems | "3. Results" |
| `proofs` | Gives the proofs of a mathematics manuscript in a section of their own | (generic; no instance in the reference manuscript) "5. Proofs of the main results" |
| `discussion` | Synthesizes the findings, draws implications, and states limitations and future work | "4. Discussion" |
| `conclusion` | Concludes in a section of its own; closing paragraphs inside the discussion stay `discussion` | (generic; no instance in the reference manuscript) "6. Conclusion" |
| `appendix` | Holds material placed in an appendix | "Appendix" |

## A worked example: §3.3 of the reference manuscript

Positions are those of the reference manuscript's ledger (see
`docs/REFERENCE-MANUSCRIPTS.md`); only connectives are quoted. Three TeX
paragraphs, each a subtree:

```
paragraph A  (#210-#213)    root #210 ("We noticed that …")
  #212 -consequence-> #210            ("… cannot be overlooked")
    #211 -addition-> #212             ("In addition to considering …,"; head after it)
    #213 -consequence-> #212          ("We now examine an alternative explanation.") opens an announcement
paragraph B  (#214-#223)    root #216 ("a possible explanation … is that")    B -specification-> A
  #214 -continue-> #216               (the counts the explanation is about; head after it)
  #215 -reason-> #216                 ("Because …,"; head after it)
  #217 -restatement-> #216            ("That is,")
  #218 -restatement-> #216            ("In other words,")
    #219 -contrast-> #218             ("Rather,")
  #222 -consequence-> #216            (the prediction drawn from the explanation)
    #220 -continue-> #222             ("Under such circumstances,"; head after it)
    #221 -reason-> #222               ("since …,"; head after it)
    #223 -contrast-> #222             (the test rejects the prediction)
paragraph C  (#224-…)       root #224 ("The above results indicated")       C -consequence-> B
```

No arcs cross. #216 discharges the announcement opened by #213, one paragraph
later; #223 discharges the hypothesis #216 opened and a plan item opened at the
start of §3. At #221 the right frontier is #221, #216; #220 and #221 are
pending, so the next proposition (#222) is their head and hangs on #216.

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
| S2 | error | A record with a proposition `head` has a `relation` among the 10; a root has neither; no record carries `refers_to`. Each head names another proposition of the same paragraph. Each paragraph has exactly one root, and heads form no cycle. `head: "pending"` only with `--partial` and only in the last paragraph. `also` entries name another proposition, not the head, with a relation among the 10 |
| S3 | error | Commitment ids match the pattern and are unique; `kind` is one of the 7. Every discharged id was opened by a strictly earlier record. No `future_work` is discharged |
| S4 | error / warning | Every `question`, `aim`, `hypothesis`, `plan` and `announcement` is discharged at least once (error). An undischarged `setup` is a warning. `future_work` is not reported |
| S5 | error | `thesis` is non-empty and names non-retired propositions. Sections: required fields, each `role` one of the 10, unique ids, `first_prop` strictly increasing from the first proposition, `parent` naming an earlier section, an `abstract` only as the first entry and opening no commitment. Paragraphs: unique ids, `first_prop` strictly increasing from the first proposition, every section starting at a paragraph's start, one root paragraph per section, paragraph heads inside the section with a relation among the 10, no cycle |
| S6 | warning | An `announcement` is first discharged neither in the section where it was opened nor in the next section |
| S7 | warning | Two arcs of one paragraph (record to head), or two paragraph arcs of one section, cross: with endpoints sorted, a1 < a2 < b1 < b2. Counted, never an error |
| S8 | warning | A `basis` edge (tree or `also`) whose target the proposition does not cite in `main.jsonl`. Fix the ledger's `cites`, not the relation |

The output has one summary line per rule, marked `[PASS]`, `[FAIL]` or
`[WARN]`, followed by each problem with the proposition's position and id.
Exit code: `0` no errors (warnings allowed), `1` at least one error, `2` input
error: a file is missing, unreadable or not valid JSON (the message names the
file, or the line of `discourse.jsonl`), or `structure_version` is not `"2.0"`
(the message names `migrate-structure-v2.py`). Both sidecars are required; a
missing one is exit `2`.

**Unfinished drafts.** A draft in progress always has open commitments, it
often has not stated its thesis yet, and its last clause may be waiting for its
head. With `--partial`, S4 lists undischarged commitments, `setup` included, as
information instead of errors or warnings; S5 reports an empty `thesis` as
information; and S2 accepts `head: "pending"` in the last paragraph. Every
other check applies unchanged.

An error in `thesis` fails S5 but does not stop S6 or the state query from
using a section list that is itself valid; only an invalid section or
paragraph plan does that.

## State query

```bash
python3 plugins/propositions/scripts/structure-state.py \
  --jsonl manuscript/propositions/main.jsonl --at end
```

`--at` takes a proposition's full UUID or `end`; `--order kind|scope` chooses
the ordering of open commitments (default `kind`); `--format text|json` and the
sidecar paths work as in the validator. The query first applies S1–S3 and the
section and paragraph plan of S5, accepting `head: "pending"` as `--partial`
does, and exits `1` if they fail: fix the structure before asking about it.

For position t, counting t itself, it reports:

- t's position and the total count;
- the section containing t (id, heading, role);
- the paragraph containing t, with the position and id of its root, or null
  when the root has not appeared yet;
- t's relation, or `root` for a paragraph root;
- the **right frontier**: t and each ancestor of t, reached by following heads,
  whose position is at most t (an ancestor that comes after t is passed
  through, not listed), ending at the paragraph root once it has appeared; then
  the paragraph and its ancestor paragraphs up to the section's root paragraph;
  then the section and its ancestor sections;
- the **pending** records: those at or before t whose head is `"pending"` or
  comes after t;
- the open commitments, each with its id, kind, the position and id of the
  proposition that opened it, the number of propositions since then, and its
  scope (paragraph and section of the opening proposition);
- the `future_work` commitments opened so far, in a separate list;
- whether any `thesis` proposition has appeared, and the ordering used.

In a tree without crossing arcs, a proposition that hangs on an earlier one
hangs on a sentence node of the right frontier. That is the mechanical answer
to "where can the next proposition attach?". When records are pending, the next
proposition is usually their head.

**Ordering.** With `kind` (the default), open commitments are ordered by kind,
from most to least pressing:

`announcement` → `hypothesis` → `plan` → `question` → `aim` → `setup`

and within a kind by the position that opened them, earliest first. With
`scope`, the kind order stays, and within a kind the commitments whose opening
section shares the deepest section with t come first (a section contains its
own range and every section under it; the depth of a top-level section is 1,
and 0 means no shared section), then earliest first. `scope` puts a plan opened
at the start of the current section before a plan item left over from the
introduction. `future_work` takes no part in the ordering. The first open
commitment in the list is the mechanical answer to "what should the next
proposition advance?"; the `propositions:construct` skill starts from that
answer and adds judgement from the section's role and the frontier.

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

Exit code: `0` success, `1` the sidecars fail the checks above, `2` input error
or an `--at` id that is not a non-retired ledger proposition (the message names
the id).

## Metrics

```bash
python3 plugins/propositions/scripts/structure-metrics.py \
  --jsonl manuscript/propositions/main.jsonl
```

The validator says whether the format is right; the metrics say whether the
model fits the article. Same inputs and exit codes as the state query. Reported:

- **arcs**: sentence arcs and paragraph arcs, how many take part in at least one
  crossing, and that proportion. A proportion above 5% of sentence arcs means
  the article is not tree-like enough and the model needs another look;
- **frontier**: the length of the sentence part of the right frontier at every
  position, as median, mean and maximum — how many places the next proposition
  can attach to;
- **heads**: records whose head comes before them, after them, pending, and roots;
- **relations**: the count of each relation on records with a head, and the
  number of `also` entries;
- **S8 warnings**;
- **ordering**: for `kind` and `scope`, how many positions were evaluated and how
  many were hits. Position t is evaluated when a commitment open at t is
  discharged after t; it is a hit when the first commitment in the ordering is
  among those first discharged at the earliest such position.

## Tools for getting there

- `derive-paragraphs.py --jsonl main.jsonl --tex main.tex [--structure structure.json]`
  prints the default `paragraphs` list. A location must lie in the main file
  (`main.tex:` or no prefix); multi-file manuscripts are refused with exit `2`,
  and their paragraphs are listed by hand.
- `migrate-structure-v2.py --jsonl main.jsonl --tex main.tex --out-dir DIR`
  reads version 1.0 sidecars beside the ledger and writes version 2.0 sidecars
  and `migration-review.json` into `DIR`. It never writes the ledger or the 1.0
  files, refuses `DIR` when it is the ledger's directory or already holds
  sidecars, and lists for review every former `start`, `shift` and `return`,
  every paragraph relation replaced by `continue`, every relation dropped at a
  section's first paragraph, and every section whose `parent` could not be
  read off the TeX headings. Its output is a mechanical starting point (chains
  inside paragraphs), not a finished annotation.

## What is not checked

The validator checks that the annotation is structurally consistent, not that
it is right. Whether `consequence` was the right relation, whether a
proposition really hangs on the head it names, or whether it really answers the
question it claims to discharge, is a matter for a human reader, in the same
way that `validate-propositions.py` checks the ledger's form and
`propositions:proofread` checks its meaning. When the ledger gains or loses
propositions, the sidecars are not updated automatically; S1 reports every
record that no longer matches.
