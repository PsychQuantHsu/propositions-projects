# Annotating structure — how to choose each value

The definitions and boundary notes of every value live in
`plugins/propositions/docs/STRUCTURE.md`; that file is the reference. This file is
the decision procedure the construct skill follows when it labels a ledger. The
three tables below list the same values in the same order as the validator, and
a test keeps them identical.

Work proposition by proposition in reading order. For each one, answer four
questions in this order:

1. **Relation** — how does it connect to the proposition just before it? Ask the
   questions of the relation table in the **priority order** given under the
   table and take the first "yes", even when a later value also fits. `shift`
   comes last: use it only when none of the others holds.
2. **Opens** — does it promise the reader something that comes later? If so,
   give each promise an id and a kind from the commitment table.
3. **Discharges** — does it keep a promise opened earlier? List those ids.
4. **Section** — is it the first proposition of a section with its own text?
   If so, the section entry in `structure.json` starts here; pick its role from
   the role table.

A connective is evidence, not the answer. "Moreover," usually means `addition`,
but in a sentence that also says "mentioned in Section 1.2" the priority order
makes it `return`. Read what the proposition does to the previous one.

## Relations (12)

The rows are in the validator's order, which is not the order to ask them in
(see the priority order below the table). These are the only 12 values; do not
infer a new value from resemblance to a listed one.

| Value | Ask | Not this when |
|---|---|---|
| `start` | Is this the first record of the article? | Any other position — a new section is `shift` or a local relation, never `start` |
| `shift` | Asked last: no row below holds, and the proposition takes up the plan or an open commitment instead of the previous proposition | A local connective joins it to the previous proposition |
| `continue` | Does it go on with the same topic without a more specific relation? | A connective or the content makes one of the specific rows true |
| `restatement` | Does it say the same thing again in other words ("That is,", "In other words,")? | It adds detail the previous proposition did not have — `specification` |
| `specification` | Does it make the previous proposition more specific or detailed? | It is an example of it — `instance` |
| `instance` | Is it an example of the previous proposition ("To illustrate,", "e.g.")? | It is a further item of the same kind — `addition` |
| `addition` | Is it another item of the same kind ("Moreover,", "Furthermore,")? | It returns to an earlier thread — `return` outranks it |
| `contrast` | Does it oppose, concede to, or correct the previous proposition ("However,", "Rather,")? | It gives the cause of the previous proposition — `reason` |
| `reason` | Does it give the reason or cause of the previous proposition ("because")? | The cause comes first and this proposition is the effect — `consequence` |
| `consequence` | Does it follow from the previous proposition, including an interpretation drawn from evidence ("Therefore,", "Accordingly,", "These results suggest")? | It only says the same thing again — `restatement` |
| `sequence` | Is it the next step of a procedure or in time ("We then", "Next,")? | The steps are items of a list, not an order — `addition` |
| `return` | Does it come back to an earlier thread ("mentioned in Section 1.2", "Recall that")? Set `refers_to` to the proposition it returns to | It only continues the immediately previous proposition |

**Priority order** for annotation: `return` > `restatement` > `specification` > `instance` >
`contrast` > `reason` > `consequence` > `sequence` > `addition` > `continue`,
with `shift` only when none of these holds.

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
`future_work` is never discharged.

## Section roles (9)

These are the only 9 values; do not infer a new value from resemblance to a
listed one. A role says what the section does, not where it sits: a subsection
of the introduction that defines notation is `formal_setup`.

| Role | Ask | Not this when |
|---|---|---|
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

Add a `note` to a record whenever the choice was close (two rows of the relation
table both held, or a commitment could be read as two kinds). The note names the
runner-up and why it lost. Notes are what a reviewer reads to check the labels.
