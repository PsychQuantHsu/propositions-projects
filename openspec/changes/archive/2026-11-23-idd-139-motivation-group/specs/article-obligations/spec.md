## MODIFIED Requirements

### Requirement: Obligations are grouped by principle

`groups` SHALL list exactly these eight groups, in this order: `dependence`, `motivation`, `commitment`, `support`, `consistency`, `truth`, `placement`, `completeness`. Each group SHALL have `id`, `zh` (a Traditional Chinese label) and `does` (one English sentence saying what the group protects). `axiom` is optional and, when present, SHALL name one axiom of the che-axiom-systems plugin as `<domain>/<axiom id>`. A group SHALL name at most one axiom. The group `dependence` SHALL name `academic-writing/A1_no_forward_dependence`, and the group `motivation` SHALL name `academic-writing/A2_motivated_by_prefix` (issue 139: every example, definition or result arrives after the text before it has raised the question it answers; a property of the sequence, which no other group covers). The file SHALL NOT restate the text of an axiom.

Every obligation entry SHALL name one of the eight groups in `group`. A precondition entry SHALL NOT have `group`.

#### Scenario: An obligation without a group is refused

- **WHEN** an entry has `class: obligation` and no `group`
- **THEN** the guard fails and its message names the entry id

#### Scenario: A ninth group is refused

- **WHEN** `groups` has an item with the id `style`
- **THEN** the guard fails and its message names `style`

##### Example: a ninth group

- **GIVEN** a table whose `groups` holds the eight groups and a ninth item with the id `style`
- **WHEN** the format check runs
- **THEN** it reports a problem that names `style`

### Requirement: The explanatory document describes the table without restating it

`plugins/propositions/docs/OBLIGATIONS.md` SHALL describe the keys of the data file, the two classes and how to tell them apart, the eight groups and their axioms (and why `motivation` is a group of its own rather than part of `placement`), how applicability is stated and the cases in which a value cannot be read, which checks count as implemented and why the excluded ones are excluded, what the fields of a gap mean, which entries need an external source and why that mark is a key of its own, the two values of `on_warning`, that `info` covers only the warning an entry was reviewed for and that a unit can pass one of the four `info` entries while its criterion does not hold, the four outcomes, the seven points that the outcome rules have to keep, the three outcomes that the table decides by itself, as rules of which the first that fits decides, and that the second of them holds also when a check printed something about the unit, which rules it leaves to issue 71, why no entry passes yet, soundness, the reasons no article is sound yet, and how to add or change an entry. It SHALL NOT list the entries: it SHALL mention at most two entry ids, as examples.

No executable check for this list beyond what the guard requirement names. A search for a phrase shows that a sentence is present and not that the document explains the thing, and no such search is written for the rest of the list. An independent reader decides cases about outcomes and about the scope of the table from the data file and the document alone; the cases, the reader's answers and the commit they were decided against are recorded on issue 47. What the list asks beyond those cases is checked by review only.

`plugins/propositions/docs/VERIFICATION.md` SHALL say that its description of a `supported` proofread record is of the derivation walk, that a record does not say which walk produced it, and that its rule of taking each method's latest record is for the disagreement warning only. For how a record counts toward an article being sound it SHALL point to `OBLIGATIONS.md` and state no rule of its own. It SHALL NOT change the record format. The guard checks for the three phrases that carry these statements: `derivation walk`, `for this warning only` and `OBLIGATIONS.md`.

#### Scenario: A copy of the table in the document is refused

- **WHEN** the document mentions three or more entry ids of the data file
- **THEN** the guard fails and its message gives the number found

##### Example: a document that names three entries

- **GIVEN** a table with three entries and a document whose text contains the ids of all three
- **WHEN** the document check runs
- **THEN** it reports a problem that gives the number 3

##### Example: a verification document without the pointer

- **GIVEN** the text of a verification document that names neither `OBLIGATIONS.md` nor the derivation walk
- **WHEN** the check on that document runs
- **THEN** it reports a problem for each missing phrase, and one of them names `OBLIGATIONS.md`

#### Scenario: The document says why a defined layer is a gap

- **WHEN** a reader looks up why the proofread layer E9 is a gap
- **THEN** the document says that the walk of the proofread skill does not list E8, E9 and E10, so a verdict does not show that they were read
