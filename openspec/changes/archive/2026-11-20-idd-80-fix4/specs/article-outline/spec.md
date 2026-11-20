## MODIFIED Requirements

### Requirement: A paragraph record holds at least one point

Each line of `outline-paragraphs.jsonl` SHALL be a paragraph record with these keys.

| Key | Required | Value |
| --- | --- | --- |
| `id` | yes | A non-empty string, different from the `id` of every other paragraph record and of every point |
| `section` | yes | The `id` of a section record. A paragraph record whose `section` names no section record belongs to no section |
| `points` | yes | A list of one or more points |
| `from` | no | A list of one or more locators naming the passages this record comes from |
| `carry` | no | `true`: the record stands for a block that is moved from the passage its `from` names, unchanged apart from what `edits` lists and from cross-references that point elsewhere |
| `edits` | no | A non-empty string listing the changes made to the statement of a moved block. Only on a record that carries `carry` |
| `replaces` | no | A list of one or more locators naming the passages of the manuscript that this record takes the place of. They are not its source |
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

A record that carries `carry` SHALL carry `from`. Its points SHALL be complete sentences stating what the block states or shows, and the text of the block is not rewritten beyond the changes `edits` lists and cross-references that point elsewhere. "States Theorem 1." is not such a sentence. A block that is moved with changes to what it states is still a moved block: its record SHALL carry `carry` and `edits`, and its points state what the block states after the changes. A change that only redirects a cross-reference (where a reference points, a number) is not a change to the statement and needs no `edits`. `edits` SHALL NOT be on a record without `carry` and SHALL NOT be empty.

A paragraph written anew in place of a passage of the manuscript SHALL name that passage in `replaces`, not in `from`: the passages of `replaces` are not a source. A record can carry both; the same locator SHALL NOT be in both.

The write check SHALL report an `edits` that is not a non-empty string on a record that carries `carry`, and a locator that is in both the `from` and the `replaces` of a record, where two locators with the same `file` and the same `label`, or with no `label` and the same `starts`, are the same one; an object without a `file` that is a string is not compared. A `replaces` that is not a list names no passage, and the commands SHALL NOT read what it holds as locators.

The paragraph records SHALL be grouped by section: the records naming one section are on consecutive lines, and the groups come in the order of the section file. Inside a group, the order of the lines is the order of the paragraphs in the section. A paragraph record that carries `dropped` is not part of the article and keeps its line in its group. A section is allowed to have no paragraph record.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

#### Scenario: One point is the paragraph's topic sentence

- **WHEN** a paragraph record has one point
- **THEN** that point states what the whole paragraph says

#### Scenario: A theorem moved with one sentence removed

- **WHEN** the statement of a theorem is moved without its last sentence, which announced a later subsection
- **THEN** its record carries `carry`, `from` naming the theorem, and `edits` saying that the last sentence is removed, and its point states the theorem without that sentence

#### Scenario: A moved block whose reference points elsewhere

- **WHEN** a definition is moved unchanged except that a reference in it now points to an appendix
- **THEN** its record carries `carry` and no `edits`

#### Scenario: A new abstract in place of the old one

- **WHEN** the author plans a new abstract that does not draw on the old one
- **THEN** the record names the old abstract in `replaces` and has no `from`

#### Scenario: Three records the write check reports

- **WHEN** a paragraph file holds a record with `edits` and no `carry`, a record whose `edits` is an empty string, and a record with the same locator in `from` and in `replaces`
- **THEN** the write check reports each of the three by its line and prints no `ok` line

#### Scenario: A carried block needs a source

- **WHEN** a paragraph record carries `carry` and has no `from`
- **THEN** the record does not meet this requirement, because nothing says which block is moved

#### Scenario: The point of a carried theorem is a sentence

- **WHEN** a record that carries `carry` for Theorem 1 has the point "States Theorem 1."
- **THEN** the record does not meet this requirement, and a point such as "Theorem 1 states that the interval covers the true value at the nominal rate." does

#### Scenario: A record cannot use a later record

- **WHEN** the record on line 4 lists in `uses` the `id` of the record on line 9
- **THEN** the record on line 4 does not meet this requirement

### Requirement: A section stands as approved while it equals its latest approved copy

A section **stands as approved** when the last approval record that has an entry for it holds a `section` copy equal to the current section record and `paragraphs` copies equal, one for one and in the same order, to the current paragraph records naming that section. Two records are equal when they are the same JSON value: the order of keys does not count, `1` and `1.0` are the same number, and every key counts, defined by this capability or not. Two numbers that differ are different however long they are: the skill does not run with a tool that reads 9007199254740993 and 9007199254740992 as the same number. A section for which no approval record has an entry does not stand as approved.

The **order of sections stands as approved** when the ids of the section records, in file order, are the ids of the `sections` entries of the last approval record whose `whole` is `true`, in the same order. With no such record, the order of sections does not stand as approved. Approving the sections one at a time therefore does not make the order of sections stand as approved: that takes one approval record that covers every section.

The **outline stands as approved** when every section stands as approved, the order of sections stands as approved, and every paragraph record names a section record in `section`.

A paragraph record whose `section` names no section record belongs to no section. It is in no `paragraphs` copy, so no approval covers it, and it is never shown with a section. While the paragraph file holds one, the outline does not stand as approved, whatever the approval records say.

A section is compared with its own records only. When a point of another section that one of its records names in `uses` changes, the section still stands as approved: no tool follows `uses` (issue 78).

The status action SHALL report, for each section, whether it stands as approved, and for a section that does not, whether it was never approved or differs from its latest approved copy. It SHALL report whether the order of sections stands as approved, every section removed since its approval, every paragraph record whose `section` names no section record, the number of points that carry `pending` and the number of records that carry `dropped`. When every section stands as approved and the order of sections does not, it SHALL say that an approval of the whole outline is still needed. It SHALL decide equality on JSON values, not on the text of the lines. An approvals file that is empty or holds only blank lines holds no approval record. When the approvals file exists but cannot be read, or holds a line that is not empty and is not one JSON object written as JSON on its own (a record spread over several lines, two records on one line, a line of spaces, a value such as `nan`), it SHALL fail and say so, and SHALL NOT report a section as never approved. When the `sections` of an approval record is not a list of entries that each hold a `section` object and a `paragraphs` list of objects, it SHALL fail and say that the approvals file is at fault. Whenever it fails, nothing it printed is a status. Before it compares, the status action SHALL run the check of a write on the section file and the paragraph file and report no status when either fails, an empty paragraph file excepted: jq reads some values that are not written as JSON, such as `01`, as if they were. When it fails because the section file or the paragraph file is missing or is not a readable regular file, or holds a line that is not a record, the skill SHALL name the file, and the line when the check of a write finds it, and SHALL NOT correct or make the file in the status action: a file with such a line is corrected through revise, and a missing file is the author's to put back.

A section is **removed since its approval** when the order of sections does not stand as approved, the section is not in the section file, and its latest approved copy is in the last approval record whose `whole` is `true`, or in an approval record after that one; with no approval of the whole outline on record, any approved copy counts. Once an approval of the whole outline is recorded without the section, its removal is approved, and the section is no longer reported. When the order of sections stands as approved, the section file holds exactly the sections of the last approval of the whole outline, and no removal is waiting for an approval. A section that is put back after its removal was approved stands as approved when it equals its own latest approved copy, which an earlier record holds; the order of sections then does not stand as approved. The status action SHALL write nothing to the repository.

These conditions are what a later capability uses to decide whether text can be written from an outline (issue 51). This capability writes no text.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

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
- **THEN** it reports that `s-a` differs from its latest approved copy, that `s-b` stands as approved and that the order of sections stands as approved, and it writes no file in the repository

#### Scenario: A paragraph record that names no section

- **WHEN** every section of an outline and the order of sections stand as approved, and a paragraph record whose `section` is `s-typo` is then added, while no section record has that `id`
- **THEN** every section and the order of sections still stand as approved, the outline does not, and the status action lists that paragraph record

#### Scenario: An approval record spread over several lines

- **WHEN** a valid approval record in `outline-approvals.jsonl` has been rewritten by hand over several lines
- **THEN** the status action fails and says so, although the lines together are one JSON value

#### Scenario: An approvals file that cannot be read

- **WHEN** `outline-approvals.jsonl` exists and cannot be read
- **THEN** the status action fails and says so, and reports no section as never approved

#### Scenario: A section removed after the whole outline was approved

- **WHEN** an outline of the sections `s-a`, `s-b` and `s-c` has one approval record with `whole` true, and the section record `s-b` and its paragraph records are then deleted
- **THEN** the status action reports that `s-a` and `s-c` stand as approved, that the order of sections does not, and that `s-b` was removed since its approval; after the author approves the whole outline without `s-b`, it reports `s-b` no longer

#### Scenario: A section that was removed and put back

- **WHEN** the whole outline was approved with the sections `s-a` and `s-b`, `s-b` and its paragraph records were deleted, the whole outline was approved again without `s-b`, and `s-b` and its paragraph records were then put back as they were
- **THEN** the status action reports that `s-b` stands as approved and that the order of sections does not

#### Scenario: A line of the section file is a number

- **WHEN** the status action runs and one line of the section file holds the JSON value `5`
- **THEN** the skill reports no status, runs the check of a write on the section file and the paragraph file, reports the section file and that line, and changes no file

#### Scenario: The paragraph file is missing

- **WHEN** the status action runs, the section file exists and the paragraph file does not
- **THEN** the skill says that the paragraph file is not there, reports no status, and does not make the file

#### Scenario: A long number changed by one

- **WHEN** an approved section record carries an undefined key with the value 9007199254740993, and the value is then changed to 9007199254740992
- **THEN** the section does not stand as approved

#### Scenario: An approval record of the wrong shape

- **WHEN** a line of `outline-approvals.jsonl` is a JSON object whose `sections` is a list that holds a number
- **THEN** the status action fails, says that the approvals file is at fault, and reports no section

#### Scenario: Sections approved one at a time

- **WHEN** an outline of three sections has three approval records, each with an entry for one of the sections and none with `whole`, and nothing has changed since
- **THEN** each of the three sections stands as approved, the order of sections does not, the outline does not, and the status action says that an approval of the whole outline is still needed

### Requirement: A premise check runs before an outline is shown for approval

Each time before the approve action shows sections for approval, the skill SHALL have those sections checked. The check SHALL begin with the checks the skill runs after a write, on the section file and the paragraph file it examines: a file that was changed by hand can hold a line that is not a record. When one of them fails, the skill reports the file and the lines, counts nothing and starts no agent. A paragraph file with no record is not reported as passing and does not stop the check: an outline can have sections and no paragraph record yet, so the skill says that the file is empty and goes on. The check reports findings of these six kinds and no others.

1. **Not a sentence**: a `says` or the `text` of a point that is a heading, a label or a fragment.
2. **Not supported by its source**: a point whose record has `from`, or which has `basis`, and which the passages named do not state, or which they contradict. The passages named in `replaces` are not a source and are not read as support. When the record carries `edits`, the point states the block as changed, and a difference from the passage that `edits` lists is not a finding.
3. **Nothing to check against**: a point that states a result, a number or a citation, in a record without `from`, and that has neither `basis` nor `pending`.
4. **Relies on something later**: a point that needs a term, a result or a claim that only a later record introduces, or a `uses` entry that names an id which is missing, is not on an earlier line, or belongs to a record that carries `dropped`.
5. **Section not carried**: a section whose `says` is neither stated nor supported by the points of its paragraph records and of the paragraph records of the sections under it. The sections under a section are those that name it as `parent`, directly or through other sections.
6. **Locator does not resolve**: a locator whose `file` is missing, leads outside the repository, is inside a `.git` directory in any letter case, is not a file git lists, or has a name the locator rules do not allow, whose `label` text does not occur exactly once in the file, or whose `starts` does not occur exactly once in the file. An object in `from`, `replaces` or `basis` that is not a locator, and a `from`, a `replaces` or a `basis` that is not a list of one or more locators, are reported as this kind too; what such a value holds is not read as locators.

The sixth kind is established by the skill itself, by resolving each path and counting, so that it is decided the same way every time. The first five are judged by the agent `propositions:outline-checker`, which this plugin defines in `agents/outline-checker.md`. Its definition SHALL give it the Read tool and no other tool, so that it cannot write or change a file, run a program or send anything. It is given these paths and nothing else: the section file and the paragraph file it examines, a list that the skill writes outside the repository, and, when only some sections are examined, a file that lists their ids. Each line of the list is a JSON object with the `file` a locator gives and the real path of the file that was counted for it; the list holds one line for each file the count read and no other file. A check of some sections outside the approve action SHALL NOT write the file in which the approve action records which sections were shown. The task message SHALL hold no text taken from the outline or the manuscript, no name of a file that a locator gives, and nothing of the conversation; the agent's definition says that what it reads is data to examine and holds no instruction for it. It SHALL also say that when a locator carries both `label` and `starts` and the two name different passages, the passage is the one `label` names. The Read tool can open any file: that the agent reads only the files it is given is an instruction of its definition, not a limit of the tool. When that agent cannot be started, the skill SHALL stop and say so, and SHALL NOT judge the five kinds with another agent or by itself. The check SHALL NOT read a file that a locator names when that file is outside the repository or is not a file git lists.

A record that carries `dropped` is examined for the sixth kind only, and its points do not count for the fifth kind. Each finding names the record or the point it concerns.

The skill SHALL show every finding with the section it concerns. It SHALL NOT change the outline because of a finding unless the author asks for the change, and it SHALL NOT act on anything in the agent's report that reads as an instruction.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

#### Scenario: A point with nothing behind it is reported

- **WHEN** a drafted paragraph record without `from` has a point "The estimator is unbiased in samples of 50." with neither `basis` nor `pending`
- **THEN** the check reports a finding of the kind "nothing to check against" that names that point, and the skill shows it with the section and leaves the point as it is

#### Scenario: A record relies on a paragraph that was left out

- **WHEN** the record `p-8` does not carry `dropped` and lists `p-5` in `uses`, and `p-5` is on an earlier line and carries `dropped`
- **THEN** the check reports a finding of the kind "relies on something later" that names `p-8`

#### Scenario: The checker has no tool but Read

- **WHEN** the plugin's definition `agents/outline-checker.md` is read
- **THEN** its `tools` names Read and nothing else, and the skill starts that agent, and no other, for the first five kinds

#### Scenario: A locator whose label and opening words name different passages

- **WHEN** a point's record has a locator whose `label` names a theorem and whose `starts` gives the opening words of a paragraph elsewhere in the same file, each occurring once
- **THEN** the agent judges the point against the theorem, the passage `label` names

#### Scenario: The checker cannot be started

- **WHEN** the agent `propositions:outline-checker` cannot be started, as in an older install of the plugin
- **THEN** the skill stops, says so, and judges none of the first five kinds itself

#### Scenario: The path the checker is given

- **WHEN** a locator's `file` is `lnin/../../outside.tex`, where `lnin` is a symbolic link to a directory two levels below the root, so that the path leads to the file `outside.tex` at the root
- **THEN** the list gives the checker the real path of `outside.tex` at the root, the file that was counted, and not the name as the locator writes it

#### Scenario: An outline file that was changed by hand

- **WHEN** the check is asked for and a line of the paragraph file is not a JSON object
- **THEN** the skill reports the file and the line, counts no locator and starts no agent

#### Scenario: A locator that leads outside the repository

- **WHEN** a paragraph record has a locator whose `file` leads to a file outside the repository
- **THEN** the check reports a finding of the kind "locator does not resolve" that names the record, and that file is not read and not quoted

### Requirement: Revising keeps ids stable and never loses a source

The revise action SHALL change the outline files only as the author instructs.

A record and a point SHALL keep their `id` when their content changes and when they move. Merging and splitting replace records: the records that are merged, and the record that is split, leave the file, and the records that replace them are new. A new record or point, a replacement included, SHALL get an `id` that appears in neither outline file and in no approval record, as the `id` of a record or a point or as a value of `section`, `parent` or `uses`. The list of ids in use that the skill prints can hold more than these, taken from other objects in the files; that only rules out more ids. A replacement SHALL NOT take the `id` of a record it replaces.

Merging, splitting and leaving a paragraph out SHALL keep every source on record.

- The `from` of the record that replaces merged records holds every locator of the records it replaces, and its `replaces` every locator of their `replaces`. When a record that has `replaces` is split, each locator of it is in the `replaces` of at least one of the records that replace it. A record that has `replaces` and that the author leaves out is not deleted: it is given `dropped` with the reason; wherever this requirement keeps a record because it has `from`, a record that has `replaces` is kept the same way, also when its last point moves away. Records SHALL NOT be merged when a locator is in the `from` of one and the `replaces` of another until the author has said which of the two the passage is for the merged paragraph; the locator is then taken out of the other list before the merge, and when the author wants both, the records are not merged. In every revision that makes another record stand for a moved block (a merge, a split, or the block's point moving to another record), the record that stands for the block afterwards SHALL carry `carry`, the `from` of the block and the `edits` that apply to it; when the changes cannot be divided between the records, or no record stands for the block any more, the skill asks the author. Before a revision moves a moved block to a record whose `replaces` holds a locator of the block's `from`, the skill asks the author as for a merge.
- When a record that has `from` is split, each record that replaces it has in its `from` at least one locator of the original, and each locator of the original is in the `from` of at least one of them.
- When a point moves to another paragraph record and the record it leaves has `from`, each locator of that `from` is added to the point's `basis`, so that the point keeps its source; a locator the point already has is not added again. A record is not left with no point: when the point that moves is the last one of its record, the skill asks the author whether that record is given a new point or is left out. Left out, a record with neither `from` nor `replaces` is deleted once the point has moved. A record with `from` or `replaces` can be neither deleted nor left without a point: the point moves with its `id`, and the record keeps a copy of the point's text as a point with a new `id` and is given `dropped` with the reason.
- When the author leaves a paragraph out of the article and its record has `from` or `replaces`, the record is not deleted: it is given `dropped` with the reason. A record with neither that the author leaves out is deleted from the file.

Leaving a section out and moving a section SHALL leave every `parent` naming a section record on an earlier line.

- When the author leaves a section out, three things happen in this order. First, the sections under it are settled: each is left out with it, or is given another `parent` or none, as the author says; the skill asks when the author has not said. Second, each paragraph record naming the section is left out by the rule above. Third, the skill looks at what still names the section: when no paragraph record and no section record names it any more, the section record is deleted from the file; otherwise it stays and is given `dropped` with the reason.
- A section that is moved takes the sections under it along, so that they stay on later lines than it. A section is not moved to a line before its own `parent`: it is given another `parent`, or none, first, as the author says. The skill asks when the author has not said.

A record's `note` stays with it when it changes, moves or is given `dropped`; a record that replaces merged records holds their notes, and each record that replaces a split record holds its note. A file the author points to during a revision is read under the same rule as in draft.

When a revision leaves a `uses` entry that names a later line, a record that is no longer in the file or a record that carries `dropped`, the skill tells the author and SHALL NOT delete the entry itself.

After a revision the skill SHALL say which sections no longer stand as approved, and which sections were removed since their approval.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

#### Scenario: A merge keeps both sources

- **WHEN** the author has `p-3`, whose `from` names the passage labelled `sec:data`, merged with `p-4`, whose `from` names the passage that starts "We collected"
- **THEN** one new record replaces them: its `id` appears in neither outline file and in no approval record, its `from` holds both locators, and `p-3` and `p-4` are no longer in the file

#### Scenario: A point moves to a record without a source

- **WHEN** the author moves the point `p-3.2`, whose record `p-3` has `from` naming the passage that starts "We collected", into `p-12`, a record without `from`
- **THEN** the point `p-3.2` carries in its `basis` the locator of the passage that starts "We collected"

#### Scenario: The last point of a record is moved

- **WHEN** the author moves the only point of `p-3`, a record that has `from`, into `p-12`
- **THEN** the skill asks whether `p-3` gets a new point or is left out, and does not leave `p-3` in the file with an empty list of points

#### Scenario: The record that lost its last point is left out and has a source

- **WHEN** the author moves `p-3.1`, the only point of `p-3`, into `p-12`, `p-3` has `from` naming the passage that starts "We collected", and the author has `p-3` left out
- **THEN** `p-12` holds the point `p-3.1` with that locator in its `basis`; `p-3` stays in the file with its `from`, with one point that has a new `id` and the text of `p-3.1`, and with `dropped` set to the author's reason

#### Scenario: The record that lost its last point is left out and has no source

- **WHEN** the author moves the only point of `p-7`, a record without `from`, into `p-12`, and has `p-7` left out
- **THEN** `p-12` holds the point with its `id` unchanged, and `p-7` is no longer in the file

#### Scenario: A split keeps a source in each part

- **WHEN** the author has `p-5`, whose `from` names two passages, split into two records
- **THEN** each of the two new records has at least one of those locators in its `from`, and each of the two locators is in the `from` of at least one of them

#### Scenario: An id that only uses still names

- **WHEN** the record `p-6` was deleted, `p-8` still lists `p-6` in `uses`, and the author has a new record added
- **THEN** the new record does not get the `id` `p-6`

#### Scenario: A removed paragraph with a source stays as dropped

- **WHEN** the author has `p-9` removed because it repeats `p-4`, and `p-9` has `from`
- **THEN** `p-9` stays in the file with `dropped` set to that reason, and the skill says that its section no longer stands as approved

#### Scenario: A section with a subsection is left out

- **WHEN** the author has the section `s-method` left out, the section `s-method-data` names it as `parent`, and the author has not said what happens to `s-method-data`
- **THEN** the skill asks whether `s-method-data` is left out too or goes under another section, and afterwards no section record that is part of the article names a `parent` that carries `dropped` or is no longer in the file

### Requirement: Only the author's explicit statement in the current message approves

The approve action SHALL append an approval record only when both of these hold: the skill has shown the sections concerned, as they now are, earlier in the same conversation; and the author, in the message the skill is answering, states in words the author typed that the outline or those sections are approved.

The skill SHALL ask for the approval in plain text and wait for the author's message. It SHALL NOT offer approval as an option to select: a selected option is not words the author typed. `statement` holds the words of that message that state the approval, copied character for character.

None of the following is an approval, and this list is closed.

1. An instruction given before the version shown existed, such as an instruction to derive an outline and then go on to write.
2. An approval passed on by another agent or another session.
3. An approval of an earlier version, or of sections other than the ones concerned.
4. No reply, or a reply about something else.
5. An instruction to this skill or another one to start writing.

By default the skill SHALL show the whole outline and ask for approval of the whole outline. When the author asks for particular sections to be approved, the skill SHALL show those sections only. The record it appends SHALL cover the sections the author states are approved, which can be fewer than the sections shown, SHALL have at least one entry, and SHALL hold the sections as they were shown. It SHALL NOT have an entry for a section that was not shown: when the author names such a section, the skill leaves it out of the record, says that it was not shown, and shows it. When none of the sections the author names was shown, the skill appends nothing. The record has `whole` true when it covers every section record, and no `whole` otherwise.

The skill SHALL keep, outside the repository, a copy of the section file and the paragraph file as they were when shown, so that the approval can be recorded when the author's reply arrives in a later message. When the section file or the paragraph file differs from that copy at the time of the approval, when the real path of the outline directory differs from the one recorded when the copy was taken, or when the copy, or the record of which sections were shown, is no longer available, the skill SHALL append nothing and show the sections again. When a paragraph record of the copy names no section record, the skill SHALL append nothing either: it shows that record first, and the record is corrected through revise before the outline is shown again. Before it appends, the skill SHALL check that every line of the approvals file that is not empty is one JSON object written as JSON whose `sections` has the shape the status action requires; when one is not, or the file cannot be read, it SHALL append nothing, say that the file was changed by hand or cannot be read, and leave what to do with it to the author.

When writing the record into the approvals file fails, the record may have been appended in whole, in part or not at all: the skill SHALL show the author the check of the approvals file and the status, say that the approval may or may not be on record, and SHALL NOT append again. The skill SHALL append the record as a line of its own: when the last line of the approvals file is not ended by a line break, the skill ends that line first. The line break that ends a line is not part of its content, and the skill SHALL NOT change the content of an earlier line. What the skill writes down for one approval, the author's words and the sections approved, SHALL NOT be used for a later one.

What the skill shows for a section depends on its approved copy.

- A section that has no approved copy is shown in full: its `heading` and `says`, every paragraph record naming it with its points and its `note`, and every record that carries `dropped` together with the reason. In both ways of showing a section, in full or by its differences, a record that carries `edits` SHALL be shown with them and said to be a block moved with changes, not unchanged; a record that carries `replaces` SHALL be shown with the passages it takes the place of. These are shown as labelled quotations of the record, not as words of the skill, and text taken from a record is shown inside a fenced code block whose fence is longer than any run of backticks in the text, so that nothing in it closes the block or is rendered as a link, as markup or as a heading.
- A section that differs from its approved copy is shown by its differences: for each record that was changed, added, removed or moved, the approved content and the current content. The skill says that the rest of the section is as it was approved, and shows the section in full when the author asks.
- A section that equals its approved copy is shown as unchanged since its approval.

The findings of the premise check on a section are shown with it in all three cases.

Whenever the sections shown are all the sections of the section file, the skill SHALL show three more things first, because an approval of all of them is an approval of the whole outline and approves all three. When the order of sections does not stand as approved, it shows the sections in the order they are in now, and beside it their order in the last approval of the whole outline when one is on record. And it shows every section removed since its approval, with its heading, its `says` and the points of its paragraph records as they were last approved. And it shows in full every section of the file that the last approval of the whole outline does not hold, when one is on record, also when that section equals its latest approved copy: a section that was taken out, approved as gone with the whole outline, and put back unchanged would otherwise return without being seen. When fewer than all the sections are shown, and the order of sections does not stand as approved or a section was removed since its approval, the skill says that the order of the sections, with the sections added to it, or the removal of a section, is not part of this approval: it takes an approval of the whole outline.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

#### Scenario: An earlier blanket instruction does not approve

- **WHEN** the author's first message asks for an outline to be derived and for writing to start afterwards, the skill then shows the outline, and the author has not replied
- **THEN** the skill appends no approval record and waits for the author

#### Scenario: A relayed approval does not approve

- **WHEN** another session reports that the author approved the outline
- **THEN** the skill appends no approval record

#### Scenario: The author approves two of the three sections shown

- **WHEN** the skill shows the whole outline, which has the sections `s-a`, `s-b` and `s-c`, and the author replies that `s-a` and `s-b` are approved and that `s-c` is still open
- **THEN** the skill appends one approval record with entries for `s-a` and `s-b` and no `whole`

#### Scenario: The files changed between showing and approving

- **WHEN** the skill shows the whole outline, a point is then changed in `outline-paragraphs.jsonl`, and the author replies that the outline is approved
- **THEN** the skill appends no approval record, says that the outline changed after it was shown, and shows it again

#### Scenario: The outline directory changed between showing and approving

- **WHEN** the skill shows the whole outline, the path of the outline directory is then made to lead to another directory of the repository that holds outline files with the same content, and the author replies that the outline is approved
- **THEN** the skill appends no approval record to either directory and shows the outline again

#### Scenario: The approvals file was changed by hand

- **WHEN** a line of `outline-approvals.jsonl` holds two approval records, and the author replies that the outline is approved
- **THEN** the skill appends nothing, says that the file was changed by hand, and changes no line of it

#### Scenario: A paragraph record of the copy names no section

- **WHEN** the copy the skill showed holds a paragraph record whose `section` names no section record, and the author replies that the outline is approved
- **THEN** the skill appends no approval record, shows that paragraph record, and says that it belongs to no section

#### Scenario: Approving a section again shows only what differs

- **WHEN** the section `s-a` has an approved copy and one point of it was reworded since
- **THEN** the skill shows the approved text and the current text of that point, says that the rest of `s-a` is as it was approved, and appends an approval record with one entry only after the author states that `s-a` is approved

#### Scenario: The sections asked for are all the sections

- **WHEN** an outline has the sections `s-a` and `s-b`, their order has changed since the last approval of the whole outline, and the author asks for `s-a` and `s-b` to be approved
- **THEN** the skill shows the two orders first, as for the whole outline, and the record it appends on the author's approval of both has `whole` true

#### Scenario: Two sections were swapped since the whole outline was approved

- **WHEN** the whole outline was approved with the sections in the order `s-a`, `s-b`, the two section records and their groups of paragraph records were then swapped, and the author asks to approve the outline
- **THEN** the skill shows the approved order and the current order before it asks, although each of the two sections equals its approved copy

#### Scenario: A section was removed since the whole outline was approved

- **WHEN** the whole outline was approved with the sections `s-a` and `s-b`, the section `s-b` and its paragraph records were then deleted, and the author asks to approve the outline
- **THEN** the skill shows `s-b` as it was approved and says that it is no longer in the outline, before it asks

#### Scenario: A section that was removed is back

- **WHEN** the whole outline was approved with the sections `s-a` and `s-b`, `s-b` was deleted, the whole outline was approved again without it, `s-b` was then put back as it was, and the author asks to approve the outline
- **THEN** the skill shows `s-b` in full and says that it was not in the outline as last approved as a whole, before it asks, although `s-b` equals its latest approved copy

#### Scenario: The record of what was shown is gone

- **WHEN** the skill has shown the whole outline, the file in which it recorded which sections were shown no longer exists, and the author replies that the outline is approved
- **THEN** the skill appends nothing, says that what was shown is no longer on record, and shows the outline again

#### Scenario: The author replies in a later message

- **WHEN** the skill shows the whole outline and ends its message with the question, and the author's next message states that the outline is approved
- **THEN** the skill builds the approval record from the copy it kept when it showed the outline, and appends it

#### Scenario: The approvals file does not end with a line break

- **WHEN** the last record of `outline-approvals.jsonl` is not followed by a line break and the skill appends an approval record
- **THEN** the new record is on a line of its own and the content of the earlier line is unchanged

#### Scenario: The approving message names no section that was shown

- **WHEN** the skill has shown the sections `s-a` and `s-b` only, and the author's message states that `s-c` is approved
- **THEN** the skill appends no approval record, says that `s-c` was not shown, and shows it

#### Scenario: One of the sections named was not shown

- **WHEN** the skill has shown the sections `s-a` and `s-b` only, and the author's message states that `s-a`, `s-b` and `s-c` are approved
- **THEN** the skill appends one approval record with entries for `s-a` and `s-b`, says that `s-c` was not shown, and shows it

#### Scenario: Words left from an earlier approval

- **WHEN** the skill recorded an approval of `s-a` an hour ago, has now shown `s-b`, and the author has not replied
- **THEN** nothing the skill wrote down for the approval of `s-a` can be appended as an approval of `s-b`
