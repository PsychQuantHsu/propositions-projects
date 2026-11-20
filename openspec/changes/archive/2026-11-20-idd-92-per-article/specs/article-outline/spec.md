## MODIFIED Requirements

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
| `moved_to` | no | A non-empty string naming where a section that is left out goes: another article, or a part that has no outline here. Only on a record that carries `dropped` |
| `part` | no | One of `main`, `appendix`, `supplement`: the part of the article the section is in. Without it the section is in the main text |

The order of the lines SHALL be the order of the sections in the article. A heading, a label or a list of topics is not a sentence stating what the section says.

A section record that carries `dropped` is not part of the article. It stays in the file so that the records naming it, and their sources, stay on record. Every paragraph record naming a section that carries `dropped` SHALL carry `dropped` too, and so SHALL every section record that names it as `parent`.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

`part` says where the section is printed and `role` what it does in the argument; `part` SHALL NOT change the order of the sections or what the premise check does. The write check SHALL report a `part` that is not one of the three values and a `moved_to` that is not a non-empty string on a record that carries `dropped`.

#### Scenario: An appendix of proofs

- **WHEN** the author says the section of proofs is in the appendix
- **THEN** its section record carries `part` `appendix` and can carry `role` `proofs`

#### Scenario: A section that goes to the second paper

- **WHEN** a manuscript is cut into two articles and its section on extensions goes to the second one
- **THEN** in the first article's outline the section record carries `dropped` with the reason and `moved_to` naming the second article, and it is not deleted

#### Scenario: A part the format does not know

- **WHEN** a section record carries `part` `online`
- **THEN** the write check reports the line and prints no `ok` line

#### Scenario: A heading is not what the section says

- **WHEN** a section record has `heading` "Simulation study" and `says` "Simulation study"
- **THEN** the record does not meet this requirement, because `says` repeats the heading and states nothing

#### Scenario: A dropped section keeps its paragraph records

- **WHEN** the author leaves a whole section out of the article and its three paragraph records have `from`
- **THEN** the section record carries `dropped` with the reason, and each of the three paragraph records carries `dropped` too and still names that section

#### Scenario: A section under a dropped section

- **WHEN** the section record `s-method` carries `dropped`, and the section record `s-method-data` names `s-method` as `parent` and does not carry `dropped`
- **THEN** `s-method-data` does not meet this requirement

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
| `uses` | no | A list whose entries are ids, each the `id` of a paragraph record on an earlier line or of a point of such a record, or references to another outline |
| `dropped` | no | A non-empty string giving the reason the paragraph is left out of the article |
| `moved_to` | no | A non-empty string naming where a paragraph that is left out goes. Only on a record that carries `dropped` |
| `note` | no | A string for the author |

A point SHALL be an object with these keys.

| Key | Required | Value |
| --- | --- | --- |
| `id` | yes | A non-empty string, different from the `id` of every other point and of every paragraph record |
| `text` | yes | One complete sentence stating one key point of the paragraph |
| `basis` | no | A list of one or more entries naming what supports the point: locators, or references to another outline |
| `pending` | no | A non-empty string naming what the author still has to supply before the point can be written |

A record with one point states, in that point, what the whole paragraph says. A record with several points states one key point of the paragraph in each, in the order the paragraph makes them.

A record that carries `carry` SHALL carry `from`. Its points SHALL be complete sentences stating what the block states or shows, and the text of the block is not rewritten beyond the changes `edits` lists and cross-references that point elsewhere. "States Theorem 1." is not such a sentence. A block that is moved with changes to what it states is still a moved block: its record SHALL carry `carry` and `edits`, and its points state what the block states after the changes. A change that only redirects a cross-reference (where a reference points, a number) is not a change to the statement and needs no `edits`. `edits` SHALL NOT be on a record without `carry` and SHALL NOT be empty.

A paragraph written anew in place of a passage of the manuscript SHALL name that passage in `replaces`, not in `from`: the passages of `replaces` are not a source. A record can carry both; the same locator SHALL NOT be in both.

The write check SHALL report an `edits` that is not a non-empty string on a record that carries `carry`, and a locator that is in both the `from` and the `replaces` of a record, where two locators with the same `file` and the same `label`, or with no `label` and the same `starts`, are the same one; an object that is not a locator (no `file` that is a string, a `label` or a `starts` that is not a string, neither `label` nor `starts`, `lines` without `commit`) is not compared and is left to the locator check. A `replaces` that is not a list names no passage, and the commands SHALL NOT read what it holds as locators.

The paragraph records SHALL be grouped by section: the records naming one section are on consecutive lines, and the groups come in the order of the section file. Inside a group, the order of the lines is the order of the paragraphs in the section. A paragraph record that carries `dropped` is not part of the article and keeps its line in its group. A section is allowed to have no paragraph record.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

An outline is one article. When a manuscript is cut into several articles, each article SHALL have its own outline directory. A reference to another outline is an object with `outline`, the path of that outline's directory from the repository's root, and `id`, the `id` of a paragraph record or of a point in its paragraph file; it has no `file`. The other outline SHALL be in the same repository and SHALL NOT be this outline. The skill SHALL confirm that the directory is inside the repository and outside `.git`, that its paragraph file is a regular file that is not a symbolic link and is JSON, and that the `id` is in it; a reference that fails one of these does not resolve and is reported as a finding of the sixth kind of the premise check. Nothing else is checked: the skill does not read what the other record says, whether it carries `dropped`, or whether the other article comes first, and the premise check does not judge a point against it. A point whose `basis` holds such a reference has a `basis`. A reference to another outline is not a locator and is not resolved as one.

#### Scenario: A point that rests on a result of the first paper

- **WHEN** a point of the second article's outline has in its `basis` `{"outline": "paper-a/propositions", "id": "p-12.1"}`, and the paragraph file in that directory has a point with that `id`
- **THEN** the reference resolves, and the premise check reports nothing about it

#### Scenario: Six references that do not resolve

- **WHEN** references name an `id` that is not in the other outline, a directory outside the repository, a directory inside `.git`, a directory with no paragraph file, this outline's own directory, and an object with `outline` and no `id`
- **THEN** each is reported with the record that names it, as a reference that does not resolve

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
