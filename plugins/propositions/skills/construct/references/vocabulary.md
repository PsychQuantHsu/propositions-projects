# Annotating structure — how to choose each value

The definitions and boundary notes of every value live in
`plugins/propositions/docs/STRUCTURE.md`; that file is the reference. This file is
the decision procedure the construct skill follows when it labels a ledger
(format 2.0: a dependency tree in three levels). The three tables below list the
same values in the same order as the validator, and a test keeps them identical.

Start from the paragraph plan that `derive-paragraphs.py` proposes, and change it
only where a TeX paragraph makes two arguments or two TeX paragraphs make one.
Then work paragraph by paragraph in reading order.

**For each paragraph**, before its propositions:

1. **Root.** Which proposition does everything else in the paragraph hang on,
   directly or through others? Usually the paragraph's main claim. It gets no
   `head` and no `relation`.

**For each proposition**, answer five questions in this order:

1. **Head.** If it is not the root: which proposition of the same paragraph
   does it hang on? It is often the previous one, but take the one it actually
   explains, restates, gives a reason for or draws a conclusion from. The head
   may come later: a fronted clause ("Because …,", "Since …,",
   "Under such circumstances,") hangs on the sentence after it.
2. **Relation.** What is this proposition's role relative to its head? Ask the
   questions of the relation table in the **priority order** given under the
   table and take the first "yes", even when a later value also fits.
3. **Opens** — does it promise the reader something that comes later? If so,
   give each promise an id and a kind from the commitment table.
4. **Discharges** — does it keep a promise opened earlier? List those ids.
5. **Also** — does it stand in another relation that neither its head nor the
   ledger's `cites` records (a contrast with a proposition three paragraphs
   back, say)? Add `{"to": …, "relation": …}`. Do not repeat the head, and do
   not copy every `cites` entry: `cites` is already recorded.

**For each paragraph after the first in its section**: which earlier or later
paragraph of the same section does it hang on, and how (a relation from the
same table)? The section's main paragraph is its root paragraph.

**For each section**: does it sit under another section (a subsection)? Set
`parent` to that section's id. A subsection whose parent heading has no entry
of its own (a heading with no propositions of its own) stays top-level.

A connective is evidence, not the answer. "Moreover," usually means `addition`,
but its head may be a proposition several sentences back. Read what the
proposition does to its head.

**Drafts.** A clause at the very end of a draft whose head has not been written
yet gets `"head": "pending"` (and no relation). Only the last paragraph may
have pending records, and only under `--partial`.

## Relations (10)

The rows are in the validator's order, which is not the order to ask them in
(see the priority order below the table). These are the only 10 values; do not
infer a new value from resemblance to a listed one. Each value is this
proposition's (or paragraph's) role relative to its head or `also` target.

| Value | Ask | Not this when |
|---|---|---|
| `continue` | Does it go on with the same topic as its head without a more specific relation? | A connective or the content makes one of the specific rows true |
| `restatement` | Does it say what its head says again in other words ("That is,", "In other words,")? | It adds detail the head did not have — `specification` |
| `specification` | Does it make its head more specific or detailed? | It is an example of it — `instance` |
| `instance` | Is it an example of what its head states in general ("To illustrate,", "e.g.")? | It is a further item of the same kind — `addition` |
| `addition` | Is it another item of the same kind as its head ("Moreover,", "Furthermore,")? | The order of the items is the point — `sequence` |
| `contrast` | Does it oppose, concede to, or correct its head ("However,", "Rather,")? | It gives the cause of its head — `reason` |
| `reason` | Does it give the reason or cause of its head, before it ("Because …,") or after it ("…, because …")? | It follows from its head — `consequence` |
| `consequence` | Does it follow from its head, including an interpretation drawn from evidence ("Therefore,", "Accordingly,", "These results suggest")? | It only says the same thing again — `restatement` |
| `sequence` | Is it the next step of a procedure or in time after its head ("We then", "Next,")? | The steps are items of a list, not an order — `addition` |
| `basis` | Does its head (or target) supply a definition, result, axiom or case that this proposition uses, and nothing more specific holds? This proposition should cite the target in `main.jsonl` | A rhetorical relation also holds — that relation wins. Never the other way round: the target is the supplier, this proposition the user |

**Priority order** for annotation: `restatement` > `specification` > `instance` >
`contrast` > `reason` > `consequence` > `sequence` > `basis` > `addition` >
`continue`.

`basis`, the right way round: *By Lemma 2, the map is monotone.* has `basis`
to Lemma 2 (and cites it). Lemma 2 does not get `basis` to the sentence that
uses it.

## Commitment kinds (7)

These are the only 7 kinds; do not infer a new kind from resemblance to a listed
one. Ids are lower-case, start with a letter or digit and use hyphens
(`c-aim-1`, `c-plan-method`).

| Kind | Ask | Not this when |
|---|---|---|
| `question` | Does the article pose something it will answer, as a question or as "whether …"? | It states a goal to carry out — `aim` |
| `aim` | Does it state a goal or task of the study ("the main goal of this study is to examine")? | It is a claim that a test could reject — `hypothesis` |
| `hypothesis` | Does it put forward a claim or explanation to be tested ("a possible explanation … is that")? | The claim is asserted as established — no commitment |
| `plan` | Does it announce the organisation of the article or a section ("We first …, We then …, We wrap up …")? Open one commitment per announced item | It promises only the very next passage — `announcement` |
| `announcement` | Does it promise what comes immediately ("We now examine …", "which we now describe", "as follows:")? | The promised content is a whole later section — `plan` |
| `setup` | Does it raise a concern, condition or consideration so that a later passage can use it? | It is an ordinary definition — its uses are recorded by `cites`, not here |
| `future_work` | Does it point beyond this article ("One direction of future work")? | The article itself goes on to do it — use the kind that matches |

Discharge a commitment at the proposition that keeps it: the answer to the
question, the report that the aim was carried out, the test result (support or
rejection both count), the first proposition of the announced part, the first
use of the setup. A proposition never discharges a commitment it opens itself.
`future_work` is never discharged. A promise made at the end of a paragraph and
kept in the next one is an `announcement`; keep it with the proposition that
delivers it, not with the first sentence of the next paragraph by default.

## Section roles (10)

These are the only 10 values; do not infer a new value from resemblance to a
listed one. A role says what the section does, not where it sits: a subsection
of the introduction that defines notation is `formal_setup`.

| Role | Ask | Not this when |
|---|---|---|
| `abstract` | Does it summarise the aims and findings in advance, before the introduction? Then it is the first section, and its propositions open no commitments (the body opens and keeps them) | It is the opening of the introduction proper — `introduction` |
| `introduction` | Does it pose the problem, argue its importance and the gap, and announce the aims or plan? | It is a standalone review of prior work — `background` |
| `background` | Is it a standalone section on prior literature and theory? | The review is part of the introduction's argument for the gap |
| `formal_setup` | Does it fix notation, definitions or inference rules? | It describes the sample, instruments or procedure — `method` |
| `method` | Does it describe the sample, instruments, procedure or analysis? | It reports what the analysis found — `results` |
| `results` | Does it report findings and their immediate interpretation, or state the main theorems? | It synthesises the findings with limitations and outlook — `discussion` |
| `proofs` | Does it prove theorems stated elsewhere? | It states them — `results` |
| `discussion` | Does it synthesise, interpret, state limitations and future work? | It is a short standalone closing section — `conclusion` |
| `conclusion` | Is it a standalone closing section after the discussion? | The closing paragraph sits inside the discussion |
| `appendix` | Is it material appended after the main text? | — |

Back matter that carries no argument (declarations of competing interest,
author-contribution statements, the questionnaire items of an appendix) is not
extracted into the ledger, so it needs no section entry.

## Recording the decision

Add a `note` to a record whenever the choice was close (two heads were
plausible, two rows of the relation table both held, or a commitment could be
read as two kinds). The note names the runner-up and why it lost. Notes are
what a reviewer reads to check the labels. When S7 reports a crossing, look at
both arcs first: a crossing is often a head chosen one sentence too far; keep
it only when the text really is not tree-shaped, and say so in a note.
