## Purpose

The article outline holds what an article is planned to say before it is written: one sentence for each section and at least one sentence for each paragraph, together with the record of the author's approval. This capability defines the three outline files beside a manuscript's ledger and the skill that writes them.

## ADDED Requirements

### Requirement: The outline is three files beside the ledger

The outline SHALL consist of three files in the directory that holds, or would hold, the manuscript's ledger: `outline-sections.jsonl`, `outline-paragraphs.jsonl` and `outline-approvals.jsonl`. In each file every line that is not empty SHALL be one JSON object.

The outline SHALL NOT depend on a ledger: the directory can hold the three files without a `main.jsonl`. Adding, changing or removing the outline files SHALL NOT change the ledger, its metadata, the structure sidecars or the verification records. The ledger's schema version does not cover the outline files.

A section record, a paragraph record, a point and a locator are allowed to carry keys that this capability does not define. An approval record SHALL carry no key other than the four this capability defines for it.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: A manuscript without a ledger has an outline

- **WHEN** a directory holds the three outline files and no `main.jsonl`
- **THEN** the three files are an outline, and nothing in this capability asks for a ledger

#### Scenario: An undefined key is allowed in a paragraph record

- **WHEN** a paragraph record carries a key `length_target`, which this capability does not define
- **THEN** the record is a paragraph record like any other, and the key is part of its content

### Requirement: A section record says in one sentence what the section says

Each line of `outline-sections.jsonl` SHALL be a section record with these keys.

| Key | Required | Value |
| --- | --- | --- |
| `id` | yes | A non-empty string, different from the `id` of every other section record |
| `heading` | yes | The heading of the section, a non-empty string |
| `says` | yes | One complete sentence stating what the section says |
| `role` | no | One of `abstract`, `introduction`, `background`, `formal_setup`, `method`, `results`, `proofs`, `discussion`, `conclusion`, `appendix` |
| `parent` | no | The `id` of a section record on an earlier line |
| `dropped` | no | A non-empty string giving the reason the section is left out of the article |

The order of the lines SHALL be the order of the sections in the article. A heading, a label or a list of topics is not a sentence stating what the section says.

A section record that carries `dropped` is not part of the article. It stays in the file so that the paragraph records naming it, and their sources, stay on record. Every paragraph record naming a section that carries `dropped` SHALL carry `dropped` too.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: A heading is not what the section says

- **WHEN** a section record has `heading` "Simulation study" and `says` "Simulation study"
- **THEN** the record does not meet this requirement, because `says` repeats the heading and states nothing

#### Scenario: A dropped section keeps its paragraph records

- **WHEN** the author leaves a whole section out of the article and its three paragraph records have `from`
- **THEN** the section record carries `dropped` with the reason, and each of the three paragraph records carries `dropped` too and still names that section

### Requirement: A paragraph record holds at least one point

Each line of `outline-paragraphs.jsonl` SHALL be a paragraph record with these keys.

| Key | Required | Value |
| --- | --- | --- |
| `id` | yes | A non-empty string, different from the `id` of every other paragraph record and of every point |
| `section` | yes | The `id` of a section record |
| `points` | yes | A list of one or more points |
| `from` | no | A list of one or more locators naming the passages this record comes from |
| `carry` | no | `true`: the record stands for a block that is moved unchanged from the passage its `from` names |
| `uses` | no | A list of ids, each the `id` of a paragraph record on an earlier line or of a point of such a record |
| `dropped` | no | A non-empty string giving the reason the paragraph is left out of the article |
| `note` | no | A string for the author |

A point SHALL be an object with these keys.

| Key | Required | Value |
| --- | --- | --- |
| `id` | yes | A non-empty string, different from the `id` of every other point and of every paragraph record |
| `text` | yes | One complete sentence stating one key point of the paragraph |
| `basis` | no | A list of one or more locators naming what supports the point |
| `pending` | no | A non-empty string naming what the author still has to supply before the point can be written |

A record with one point states, in that point, what the whole paragraph says. A record with several points states one key point of the paragraph in each, in the order the paragraph makes them.

A record that carries `carry` SHALL carry `from`. Its points say what the block is, and the text of the block is not rewritten.

The paragraph records SHALL be grouped by section: the records naming one section are on consecutive lines, and the groups come in the order of the section file. Inside a group, the order of the lines is the order of the paragraphs in the section. A paragraph record that carries `dropped` is not part of the article and keeps its line in its group.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: One point is the paragraph's topic sentence

- **WHEN** a paragraph record has one point
- **THEN** that point states what the whole paragraph says

#### Scenario: A carried block needs a source

- **WHEN** a paragraph record carries `carry` and has no `from`
- **THEN** the record does not meet this requirement, because nothing says which block is moved

#### Scenario: A record cannot use a later record

- **WHEN** the record on line 4 lists in `uses` the `id` of the record on line 9
- **THEN** the record on line 4 does not meet this requirement

### Requirement: A locator names a passage by a label or by its opening words

A locator SHALL be an object with these keys.

| Key | Required | Value |
| --- | --- | --- |
| `file` | yes | The path of a file, relative to the root of the repository that holds the manuscript |
| `label` | one of `label` and `starts` | A LaTeX label defined in that file |
| `starts` | one of `label` and `starts` | The opening words of the passage, copied exactly, enough of them to occur once in the file |
| `lines` | no | A list of two line numbers, the first and the last line of the passage |
| `commit` | when `lines` is present | The commit at which those line numbers hold |

A locator SHALL carry `label`, `starts` or both. `lines` SHALL NOT appear without `commit`. When `label` and `starts` are both present and name different passages, `label` decides.

The file a locator names is allowed to be outside the manuscript, such as a note in the same repository.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: Four locators

- **WHEN** these four objects are read as locators

  | Object | Is a locator |
  | --- | --- |
  | `{"file": "main.tex", "label": "thm:main"}` | yes |
  | `{"file": "notes/proof-sketch.md", "starts": "The bound follows from"}` | yes |
  | `{"file": "main.tex", "lines": [120, 131], "commit": "3f2c1ab"}` | no: neither `label` nor `starts` |
  | `{"file": "main.tex", "label": "sec:intro", "lines": [10, 42]}` | no: `lines` without `commit` |

- **THEN** the first two are locators and the last two are not, for the reasons in the table

### Requirement: An approval record stores what the author approved

Each line of `outline-approvals.jsonl` SHALL be an approval record with these keys and no others.

| Key | Required | Value |
| --- | --- | --- |
| `approved_at` | yes | The time of the approval, with its offset from UTC |
| `statement` | yes | The author's approving words, copied exactly |
| `sections` | yes | A list of one or more entries, described below |
| `whole` | no | `true` when `sections` has an entry for every section record of the section file as it was, in file order |

An entry of `sections` SHALL be an object with two keys: `section`, a copy of a section record as it was when the author approved, and `paragraphs`, copies of all the paragraph records naming that section as they were, in file order, those that carry `dropped` included.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: An approval of one section

- **WHEN** the author approves the section `s-model`, which has four paragraph records, one of them carrying `dropped`
- **THEN** the approval record has one entry in `sections`, whose `section` is a copy of the record `s-model` and whose `paragraphs` holds copies of all four paragraph records in file order, and the record has no `whole`

### Requirement: A section stands as approved while it equals its latest approved copy

A section **stands as approved** when the last approval record that has an entry for it holds a `section` copy equal to the current section record and `paragraphs` copies equal, one for one and in the same order, to the current paragraph records naming that section. Two records are equal when they are the same JSON value: the order of keys does not count, and every key counts, defined by this capability or not. A section for which no approval record has an entry does not stand as approved.

The **order of sections stands as approved** when the ids of the section records, in file order, are the ids of the `sections` entries of the last approval record whose `whole` is `true`, in the same order. With no such record, the order of sections does not stand as approved.

The **outline stands as approved** when every section stands as approved and the order of sections stands as approved.

The status action SHALL report, for each section, whether it stands as approved, and for a section that does not, whether it was never approved or differs from its latest approved copy. It SHALL report whether the order of sections stands as approved, the number of points that carry `pending` and the number of records that carry `dropped`. It SHALL write nothing.

These three conditions are what a later capability uses to decide whether text can be written from an outline (issue 51). This capability writes no text.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: What one change does to the three conditions

- **WHEN** an outline has the sections `s-a` (paragraph records `p-1`, `p-2`) and `s-b` (paragraph record `p-3`), one approval record with `whole` true that covers both, and then exactly one of these changes is made

  | Change | `s-a` stands | `s-b` stands | Order of sections stands |
  | --- | --- | --- | --- |
  | The text of a point of `p-2` is reworded | no | yes | yes |
  | The lines of `p-1` and `p-2` are swapped | no | yes | yes |
  | `p-2` is moved to `s-b` | no | no | yes |
  | `p-3` is given `dropped` | yes | no | yes |
  | An undefined key `length_target` is added to `p-3` | yes | no | yes |
  | `p-1` is written again with its keys in another order and the same values | yes | yes | yes |
  | A section `s-c` with one paragraph record is added | yes | yes | no |
  | The lines of `s-a` and `s-b` are swapped, with their groups of paragraph records | yes | yes | no |

- **THEN** each condition holds or fails as the table says, and after the change in the seventh row `s-c` does not stand as approved because no approval record has an entry for it

#### Scenario: Status after a change

- **WHEN** the status action runs on that outline after the text of a point of `p-2` was reworded
- **THEN** it reports that `s-a` differs from its latest approved copy, that `s-b` stands as approved and that the order of sections stands as approved, and it writes no file

### Requirement: Only the author's explicit statement in the current message approves

The approve action SHALL append an approval record only when both of these hold: the skill has shown the sections concerned, as they now are, earlier in the same conversation; and the author, in the message the skill is answering, states that the outline or those sections are approved.

None of the following is an approval, and this list is closed.

1. An instruction given before the version shown existed, such as an instruction to derive an outline and then go on to write.
2. An approval passed on by another agent or another session.
3. An approval of an earlier version, or of sections other than the ones concerned.
4. No reply, or a reply about something else.
5. An instruction to this skill or another one to start writing.

By default the skill SHALL show the whole outline and ask for approval of the whole outline. When the author asks for particular sections to be approved, the skill SHALL show those sections only. The record it appends SHALL cover exactly the sections the author states are approved, which can be fewer than the sections shown. The record has `whole` true when it covers every section record, and no `whole` otherwise.

What the skill shows for a section SHALL include its `says`, every paragraph record naming it with its points, every record that carries `dropped` together with the reason, and the findings of the premise check on the section. For a section that has an approved copy, the skill SHALL show what differs from that copy.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: An earlier blanket instruction does not approve

- **WHEN** the author's first message asks for an outline to be derived and for writing to start afterwards, the skill then shows the outline, and the author has not replied
- **THEN** the skill appends no approval record and waits for the author

#### Scenario: A relayed approval does not approve

- **WHEN** another session reports that the author approved the outline
- **THEN** the skill appends no approval record

#### Scenario: The author approves two of the three sections shown

- **WHEN** the skill shows the whole outline, which has the sections `s-a`, `s-b` and `s-c`, and the author replies that `s-a` and `s-b` are approved and that `s-c` is still open
- **THEN** the skill appends one approval record with entries for `s-a` and `s-b` and no `whole`

#### Scenario: Approving a section again shows only what differs

- **WHEN** the section `s-a` has an approved copy and one point of it was reworded since
- **THEN** the skill shows the section with the old and the new text of that point marked as the difference, and appends an approval record with one entry only after the author states that `s-a` is approved

### Requirement: A premise check runs before an outline is shown for approval

Before the approve action shows sections for approval, the skill SHALL have those sections examined by an agent that is given the section file, the paragraph file and the files their locators name, and nothing of the conversation.

The check reports findings of these six kinds and no others.

1. **Not a sentence**: a `says` or the `text` of a point that is a heading, a label or a fragment.
2. **Not supported by its source**: a point whose record has `from`, or which has `basis`, and which the passages named do not state, or which they contradict.
3. **Nothing to check against**: a point that states a result, a number or a citation, in a record without `from`, and that has neither `basis` nor `pending`.
4. **Relies on something later**: a point that needs a term, a result or a claim that only a later record introduces, or a `uses` entry that names an id which is missing or is not on an earlier line.
5. **Section not carried**: a section whose `says` the points of its paragraph records neither state nor support.
6. **Locator does not resolve**: a locator whose file is missing, whose `label` is not defined in the file, or whose `starts` does not occur exactly once in the file.

A record that carries `dropped` is examined for the sixth kind only. Each finding names the record or the point it concerns.

The skill SHALL show every finding with the section it concerns. It SHALL NOT change the outline because of a finding unless the author asks for the change.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: A point with nothing behind it is reported

- **WHEN** a drafted paragraph record without `from` has a point "The estimator is unbiased in samples of 50." with neither `basis` nor `pending`
- **THEN** the check reports a finding of the kind "nothing to check against" that names that point, and the skill shows it with the section and leaves the point as it is

### Requirement: Derive and draft build an outline without inventing content

The derive action SHALL read a finished manuscript and produce one section record for each of its sections and one paragraph record for each of its paragraphs and blocks. A theorem-like statement, a proof, a figure, a table and a displayed derivation each become one record that carries `carry`. Every paragraph record the action produces SHALL have `from` naming the passage it comes from, and every point SHALL state only what that passage states.

The draft action SHALL produce section and paragraph records from a title and ideas, or from an outline the author supplies. A point that would report a result, a number or a citation the author has not supplied SHALL say what will be reported without stating it, and SHALL carry `pending`.

Both actions SHALL show the outline to the author before any file is written and SHALL write the files only after the author agrees. Agreeing to have the files written is not an approval of the outline, and neither action appends an approval record. Neither action SHALL overwrite or add to existing outline files: when `outline-sections.jsonl` or `outline-paragraphs.jsonl` exists, the action stops and says that revise is the action to use.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: A proof becomes one carried record

- **WHEN** the derive action reads a manuscript in which a proof of twelve lines follows a theorem labelled `thm:main`
- **THEN** the outline has one paragraph record for the proof that carries `carry`, has a point saying that it is the proof of that theorem, and has `from` naming the proof

#### Scenario: A result the author has not supplied is pending

- **WHEN** the draft action works from ideas that mention a simulation whose numbers do not exist yet
- **THEN** the point about the simulation says that its results will be reported, states no number, and carries `pending`

#### Scenario: Existing outline files are not overwritten

- **WHEN** the derive action is asked to run and `outline-paragraphs.jsonl` exists
- **THEN** the action writes nothing and says that revise is the action to use

### Requirement: Revising keeps ids stable and never loses a source

The revise action SHALL change the outline files only as the author instructs.

A record and a point SHALL keep their `id` when their content changes and when they move. Merging and splitting replace records: the records that are merged, and the record that is split, leave the file, and the records that replace them are new. A new record or point, a replacement included, SHALL get an `id` that appears in neither outline file and in no approval record.

Merging, splitting and leaving a paragraph out SHALL keep every source on record.

- The `from` of the record that replaces merged records holds every locator of the records it replaces.
- When a record is split, each locator of the original is in the `from` of at least one of the records that replace it.
- When the author leaves a paragraph out of the article and its record has `from`, the record is not deleted: it is given `dropped` with the reason. A record without `from` that the author leaves out can be deleted from the file.
- A section record is deleted from the file only when no paragraph record names it. A section that the author leaves out while paragraph records name it is given `dropped`, and so is every paragraph record naming it.

After a revision the skill SHALL say which sections no longer stand as approved.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: A merge keeps both sources

- **WHEN** the author has `p-3`, whose `from` names the passage labelled `sec:data`, merged with `p-4`, whose `from` names the passage that starts "We collected"
- **THEN** one new record replaces them: it has an `id` that was never used, its `from` holds both locators, and `p-3` and `p-4` are no longer in the file

#### Scenario: A removed paragraph with a source stays as dropped

- **WHEN** the author has `p-9` removed because it repeats `p-4`, and `p-9` has `from`
- **THEN** `p-9` stays in the file with `dropped` set to that reason, and the skill says that its section no longer stands as approved

### Requirement: The outline skill writes only the three outline files

The skill `/propositions:outline` SHALL have six actions: derive, draft, revise, check, approve and status. It SHALL write no file other than the three outline files: not the manuscript, not the ledger, not the structure sidecars and not the verification records. It SHALL NOT change or remove a line of `outline-approvals.jsonl`. The check action and the status action SHALL write nothing.

After every write to an outline file the skill SHALL confirm that every line of that file that is not empty parses as a JSON object and that no `id` repeats among the section records or among the paragraph records and points. When either fails, it SHALL report the file and the line and SHALL NOT report the write as done. Its report SHALL say that no other check of the format exists until issue 78.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: The skill does not touch the manuscript

- **WHEN** the author, during a revision, asks the skill to rewrite a paragraph of the manuscript to match a point
- **THEN** the skill writes nothing to the manuscript and says that writing from an outline is not one of its actions

#### Scenario: A repeated id stops the report

- **WHEN** a write leaves two paragraph records with the `id` `p-7`
- **THEN** the skill reports the file and the two lines, and does not report the write as done

### Requirement: The explanatory document describes the outline

`plugins/propositions/docs/OUTLINE.md` SHALL describe the three files and every key of their records, the locator, the three conditions (a section stands as approved, the order of sections stands as approved, the outline stands as approved), what counts as an approval and the five things that do not, the six kinds of finding of the premise check, and the six actions of the skill.

It SHALL state that this capability writes no manuscript text and that writing from an outline belongs to issue 51, and that no mechanical check of the outline files exists until issue 78.

No executable check: a check of this requirement has to be a Swift test, and the repository has no Swift package yet (issue 46); issue 78 adds the examples and tests.

#### Scenario: A reader decides from the document alone

- **WHEN** a reader who has only the document is given the three files of an outline
- **THEN** the reader can say for each section whether it stands as approved, and whether the order of sections and the outline stand as approved
