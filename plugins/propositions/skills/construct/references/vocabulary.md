# Annotating structure — how to choose each value

The definitions and boundary notes of every value live in
`plugins/propositions/docs/STRUCTURE.md`; that file is the reference. This file is
the decision procedure the construct skill follows when it labels a ledger
(format 2.0: a dependency tree in three levels). The three tables below list the
same values in the same order as the validator, and a test keeps them identical.
Moves and paragraph types are the exception: their values and definitions live in
`plugins/propositions/catalog/vocabulary.yaml`.

Start from the paragraph plan that `derive-paragraphs.py` proposes, and change it
only where a TeX paragraph makes two arguments or two TeX paragraphs make one.
Then work paragraph by paragraph in reading order.

**For each paragraph**, before its propositions:

1. **Root.** The first proposition of the paragraph that does not hang on a
   later one: usually simply the first proposition; a fronted clause or a
   framing fragment that opens the paragraph hangs on the sentence after it,
   and the root is that sentence. The root gets no `head` and no `relation`.
   This is a convention, not a judgement of which claim matters most: when a
   paragraph lays down evidence and then concludes, the evidence is the root
   and the conclusion hangs on it as `consequence`; when it lays down a fact
   and then explains it, the fact is the root and the explanation hangs on it
   as `reason`. The convention makes two annotators choose the same root.

**For each proposition**, answer six questions in this order:

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
6. **Move** — what does it do for its paragraph? See "Moves and paragraph
   types" below.

**For each paragraph after the first in its section**: which earlier or later
paragraph of the same section does it hang on, and how (a relation from the
same table)? The section's main paragraph is its root paragraph.

**For each paragraph**, once its propositions are labelled: its `type`. See
"Moves and paragraph types" below.

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

Patterns settled in the pilot (only the ten values; there is no `condition`):

| Pattern | Head and relation |
|---|---|
| A scope or condition fragment ("Under such circumstances,", "In this case,") | the clause it qualifies, `specification` (it narrows where its head holds) |
| "Suppose X. Then Y." in a statement | X is the root (or hangs where it belongs); Y hangs on X, `consequence` |
| A list of assumptions ("Suppose further …", "Finally, suppose …") | each item hangs on the first, `addition` |
| A case split | the first case hangs on what is split, `specification`; each further case hangs on the first case, `addition` |
| A proof paragraph | the paragraph hangs on the statement's paragraph, `reason` |
| A fact, then its explanation | the fact is the root; the explanation hangs on it, `reason` |
| Evidence, then a conclusion | the evidence comes first; the conclusion hangs on it, `consequence` |

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

## Moves and paragraph types

The values are in `plugins/propositions/catalog/vocabulary.yaml`: the lists
`moves` and `paragraph_types`, where each entry has `does`, `zh` and sometimes
`not`. That file is the list. It is not copied here because it can still change.
It is closed: S9 rejects any other value, and a value that resembles a listed one
is not mapped to it.

A move says what the sentence does for its paragraph. Two other fields already
record other things, and a move that only restates one of them adds nothing:

| Field | What it records |
|---|---|
| `claim_type` (in the ledger) | What kind of claim the sentence is |
| `head`, `relation` | What the sentence hangs on, and how it connects |
| `move` | What the sentence does for its paragraph |

**For each proposition**, with the whole paragraph in view:

1. **Say what the paragraph needs this sentence for**, in your own words, before
   you look at the list. "It is a claim" and "it makes its head more specific"
   are not answers: the first is its `claim_type` and the second its relation.
2. **Find the value** whose `does` says the same thing.
3. **Read the `not` hints** of that value and of any value that came close. A
   `not` hint says when a sentence belongs to a neighbouring value; follow it.
4. **Check that the move is not a restatement.** A `claim` can point out what
   earlier work leaves open in one paragraph and say where the work should go
   next in another, and those are two moves. Two sentences joined to their heads
   by `specification` can also do different work: one says what the study
   compares, the other what a later study should try. If your only reason for a
   value is the `claim_type` or the relation, go back to question 1.
5. **Decide.** If one value fits, take it. If two fit, take the closer one and
   record the runner-up (see "Recording the decision"). If none fits, stop and
   report the sentence's position. Do not choose a near value: adding a value is
   a change to the vocabulary, not a labelling decision.

Label what each sentence does, even when the order looks unusual. No rule checks
the order of moves, and a link missing from `catalog/links.csv` is not a
problem, so never change a label to make a paragraph look like another one.

**For each paragraph**, after its propositions:

1. **Label the sentences first.** A type chosen first pulls the sentences towards
   it.
2. **Ask what the paragraph as a whole does**, reading its moves in order, and
   find the value in `paragraph_types` whose `does` says the same thing. Read its
   `not` hint if it has one.
3. **Keep it apart from the section's role.** A role says what the section does; a
   type says what this paragraph does. A paragraph in a results section may do
   something other than report results.
4. **Decide.** If none fits, stop and report the paragraph's id. If a paragraph
   seems to need two types, it may be making two arguments, which is a question
   for the paragraph plan.

`structure-metrics.py` reports Cramér's V between move and `claim_type` and
between move and relation. When moves line up almost one to one with either field,
the move layer adds nothing and the vocabulary needs another look.

Patterns settled in the pilot:

- **Consecutive sentences doing the same job share a move.** A sentence that says
  its head again more plainly keeps its head's move; `restatement` already records
  how it connects. There is no move for "says it again".
- **A fragment takes the move of the sentence it belongs to.** A condition, a scope
  phrase, a "because" clause or a display equation split off by the ledger is part
  of the job its sentence does, even when it is the head's `reason` or
  `specification`. `explain-why` is for a sentence that gives a reason as its own job.
- **A statement block:** each "Suppose ..." is `set-assumption` and the "Then ..."
  is `state-result`, although the relation says `consequence`. An opening sentence
  whose content is in the items after it ("Suppose ... Then one of the following
  holds") is `set-assumption`. In a statement that lists cases, a heading that only
  names the case is `open-case`, and one that gives the case's formula or conclusion
  is `state-result`.
- **Inside a proof** each step is `derive`, including a check that a lemma's conditions
  hold, and the sentence that starts a case is `open-case`. Introducing a symbol is
  `define` even there.
- **A footnote has its own job.** The fragment rule does not cover it.
- **A title or heading the ledger lists** is `set-context`.
- **A test's outcome:** `state-result` when the text only reports it, `rule-out`
  when the text uses it to set an explanation aside. The same `claim_type: result`
  takes either.
- **An explanation being considered** is `propose-explanation` until the text has
  tested it, however confidently it is worded.
- **A short paragraph still gets a type**, from what it does in its section. A
  one-sentence paragraph that finishes a statement or corrects a detail is `remark`.

## Recording the decision

A record gets a `note` only when the choice was close, and has none otherwise.
A choice is close in exactly these four cases: two heads were plausible, two
rows of the relation table both held, a commitment could be read as two kinds,
or two moves both fit. Write the note as
`runner-up: <the other choice>; lost because <reason>`. The evidence for a
label (the connective, "paragraph root", "no connective") is not a note: the
label already says it. In most paragraphs few records, if any, have a note.

A5 lists the records that have a note, so the reviewer knows which labels to
check first. A note on every record makes that list the whole article.

When S7 reports a crossing, look at both arcs first: a crossing is often a
head chosen one sentence too far. Keep it only when the text really is not
tree-shaped. A kept crossing is a close call: the runner-up in its note is the
head that would not cross.
