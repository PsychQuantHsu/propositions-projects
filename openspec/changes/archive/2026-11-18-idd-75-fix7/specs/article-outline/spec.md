## MODIFIED Requirements

### Requirement: Derive and draft build an outline without inventing content

The derive action SHALL read a finished manuscript and produce one section record for each of its sections and one paragraph record for each of its paragraphs and blocks. It reads the manuscript's main file by its real path, after confirming again that the file meets the conditions this capability sets for it. It SHALL follow the `.tex` files that the manuscript includes only when they are regular files inside the repository that git lists (tracked, or not tracked and not ignored) and whose path holds no line break and, below the root, no other character that a locator's `file` is not allowed to hold. Any other included file is named to the author and not read: one outside the repository, a symbolic link, a file reached through a directory that is a symbolic link, a file inside a `.git` directory in any letter case, a file git ignores, a file git gives no answer for (one in or under a directory laid out like a git repository), a missing file, a file whose path holds such a character, or a file that is not `.tex`. A figure or a table that comes from an included file that was not read is still the one record that carries `carry` for the figure or the table, named in the file that includes it. Any other included file that was not read SHALL get nothing in the outline: no record, no locator, no point and no `note`; the action names it to the author, and the outline does not show the gap (whether it should is open, issue 51). An include command `\input{x}` or `\include{x}` names the file `x.tex`, or, for `\input`, `x` itself when no `x.tex` is found. Since LaTeX looks for it from the directory it is run in, which the skill does not know, the skill looks in this order: `x.tex` from the directory of the main file, then (for `\input`) `x` from it, then the same two from the root; the first that exists is the included file, read only when it is a file the skill reads, and on a file system that ignores letter case the same name in another letter case counts. A command inside a LaTeX comment includes nothing. When all the text of a section is in included files that were not read, the action SHALL ask the author for the section's `says` and SHALL stop when the author gives none. When the files the action read hold no paragraph and no block at all, so that the paragraph file would be empty, the action SHALL stop, say which included files were not read, show no outline and write nothing to the repository. Prose that comes before the first heading and is not the abstract gets one section record, whose `heading` is the title of the article; the skill tells the author that this section has no heading of its own in the manuscript, and asks what to put in `heading` when the manuscript gives no title. A theorem-like statement, a proof, a figure, a table, and a displayed formula or derivation that has a blank line before it and a blank line after it each become one record that carries `carry`, whose point is a complete sentence stating what the block states or shows. Any other displayed formula or derivation belongs to a paragraph's record: with no blank line on either side, the record of the paragraph it stands in; with a blank line on one side only, the record of the paragraph on the other side. Every paragraph record the action produces SHALL have `from` naming the passage it comes from, and every point SHALL state only what that passage states. A theorem-like statement, a figure or a table is named by its own label; the label of a section names the whole section and SHALL NOT be used for a record. The action writes no `lines` and no `commit`, and the `file` of every locator it writes is the name of the file from the root, as the first requirement defines it. Before it shows the outline, the action SHALL confirm for every locator it wrote that the locator resolves: the text of its `label` and its `starts`, whichever it has, each occur exactly once in the file it names. When a passage that has no label of its own has a text that, to its end, occurs a second time in the same file, as another passage that reads the same or inside a longer one, no locator names it: the action SHALL stop, tell the author which passages they are, show no outline and write nothing to the repository, and SHALL NOT take opening words from the passage that follows. It stops the same way when a file it read is not accepted as a locator's file. A manuscript that has paragraphs SHALL NOT give an empty paragraph file.

The draft action SHALL produce section and paragraph records from a title and ideas, or from an outline the author supplies. It needs no manuscript. A file the author points to, or an outline the author supplies as a file, SHALL be read only after the check the skill runs on the manuscript's main file accepts it, and by the path that check gives; that run concerns that file only and does not change which file is the manuscript's main file; when the check refuses it, the skill asks the author to paste the text. When a locator the author asked for does not resolve, the action SHALL NOT rewrite it: it says which and why, and asks the author whether to correct it or to leave it out of the record. A point that would report a result, a number or a citation the author has not supplied SHALL say what will be reported without stating it, and SHALL carry `pending`. When the outline the author supplies has sections and no paragraph yet, the action writes no paragraph record, and the paragraph file is empty.

Both actions SHALL show the outline to the author before any file is written in the repository, and SHALL write the files there only after the author agrees. Agreeing to have the files written is not an approval of the outline, and neither action appends an approval record. Neither action SHALL overwrite or add to existing outline files: when `outline-sections.jsonl` or `outline-paragraphs.jsonl` exists, the action stops and says that revise is the action to use. When only `outline-approvals.jsonl` exists, the action SHALL stop too: a new outline is not started beside the approvals of an earlier one, and what to do with that file is the author's decision.

No executable check: this change adds no test target; the examples and tests of this requirement are deferred to issue 78, which follows the Swift package (issue 46).

#### Scenario: A proof becomes one carried record

- **WHEN** the derive action reads a manuscript in which a proof of twelve lines follows a theorem labelled `thm:main`
- **THEN** the outline has one paragraph record for the proof that carries `carry`, has a point that is a complete sentence stating that it proves that theorem, and has `from` naming the proof

#### Scenario: A result the author has not supplied is pending

- **WHEN** the draft action works from ideas that mention a simulation whose numbers do not exist yet
- **THEN** the point about the simulation says that its results will be reported, states no number, and carries `pending`

#### Scenario: Existing outline files are not overwritten

- **WHEN** the derive action is asked to run and `outline-paragraphs.jsonl` exists
- **THEN** the action writes nothing and says that revise is the action to use

#### Scenario: Approvals of an earlier outline are in the directory

- **WHEN** the derive action is asked to run and the outline directory holds `outline-approvals.jsonl` and neither of the other two files
- **THEN** the action writes nothing, says that approvals of an earlier outline are in the directory, and leaves what to do with that file to the author

#### Scenario: A section that has a label

- **WHEN** the derive action reads a section that has the label `sec:data` and opens with a paragraph of prose
- **THEN** the paragraph record for that paragraph names it by its opening words, not by `sec:data`

#### Scenario: A file included from outside the repository

- **WHEN** the manuscript includes a file by a path that leads outside the repository
- **THEN** the derive action does not read that file, tells the author which file it is, writes nothing for it in the outline, and goes on with the rest of the manuscript

#### Scenario: Two proofs that read the same

- **WHEN** the derive action reads a file in which two proofs, neither with a label, both consist of the sentence "The proof is immediate."
- **THEN** the action stops, tells the author that the two proofs cannot be named apart, shows no outline and writes nothing to the repository

#### Scenario: An introduction without a heading

- **WHEN** the derive action reads a manuscript in which three paragraphs of prose stand between the abstract and the first section heading
- **THEN** the outline has one section record for that prose, placed where the prose stands, whose `heading` is the title of the article, and the skill tells the author that the section has no heading of its own

#### Scenario: A generated table that git ignores

- **WHEN** the manuscript includes `tables/results.tex`, a file inside the repository that git ignores
- **THEN** the derive action does not read that file, tells the author which file it is, and writes one record that carries `carry` for the table, named in the file that includes it

#### Scenario: An included section that git ignores

- **WHEN** the manuscript includes `sections/generated.tex`, a file inside the repository that git ignores, by a command that stands between two paragraphs of prose and occurs once
- **THEN** the outline holds nothing for the command or the file, and the derive action names `sections/generated.tex` to the author as a file that was not read

#### Scenario: The same unread file included twice

- **WHEN** the manuscript writes `We surveyed \input{stats/N} adults.` in one paragraph and `Participants were \input{stats/N} adults.` in another, and `stats/` is ignored by git
- **THEN** the derive action does not stop: it writes the two paragraph records, nothing for `stats/N`, and names `stats/N` to the author as a file that was not read

#### Scenario: Every section's text is in files that were not read

- **WHEN** the main file holds `\section{Introduction}` followed by `\input{sections/intro}` and `\section{Method}` followed by `\input{sections/method}`, and `sections/` is ignored by git
- **THEN** the derive action stops, names the two files as not read, shows no outline and writes nothing to the repository

#### Scenario: A file name with a dot

- **WHEN** the manuscript writes `\input{ch1.final}` and `ch1.final.tex` is a file git tracks in the directory of the main file
- **THEN** the derive action reads `ch1.final.tex`

#### Scenario: A displayed formula inside a paragraph

- **WHEN** the derive action reads a paragraph whose third sentence is interrupted by a displayed, labelled equation, with no blank line before or after the equation, and goes on after it
- **THEN** the outline has one paragraph record for the paragraph, without `carry`, whose `from` names the paragraph by its opening words and not by the label of the equation

### Requirement: A paragraph record holds at least one point

Each line of `outline-paragraphs.jsonl` SHALL be a paragraph record with these keys.

| Key | Required | Value |
| --- | --- | --- |
| `id` | yes | A non-empty string, different from the `id` of every other paragraph record and of every point |
| `section` | yes | The `id` of a section record. A paragraph record whose `section` names no section record belongs to no section |
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

A record that carries `carry` SHALL carry `from`. Its points SHALL be complete sentences stating what the block states or shows, and the text of the block is not rewritten. "States Theorem 1." is not such a sentence.

The paragraph records SHALL be grouped by section: the records naming one section are on consecutive lines, and the groups come in the order of the section file. Inside a group, the order of the lines is the order of the paragraphs in the section. A paragraph record that carries `dropped` is not part of the article and keeps its line in its group. A section is allowed to have no paragraph record.

No executable check: this change adds no test target; the examples and tests of this requirement are deferred to issue 78, which follows the Swift package (issue 46).

#### Scenario: One point is the paragraph's topic sentence

- **WHEN** a paragraph record has one point
- **THEN** that point states what the whole paragraph says

#### Scenario: A carried block needs a source

- **WHEN** a paragraph record carries `carry` and has no `from`
- **THEN** the record does not meet this requirement, because nothing says which block is moved

#### Scenario: The point of a carried theorem is a sentence

- **WHEN** a record that carries `carry` for Theorem 1 has the point "States Theorem 1."
- **THEN** the record does not meet this requirement, and a point such as "Theorem 1 states that the interval covers the true value at the nominal rate." does

#### Scenario: A record cannot use a later record

- **WHEN** the record on line 4 lists in `uses` the `id` of the record on line 9
- **THEN** the record on line 4 does not meet this requirement

### Requirement: Revising keeps ids stable and never loses a source

The revise action SHALL change the outline files only as the author instructs.

A record and a point SHALL keep their `id` when their content changes and when they move. Merging and splitting replace records: the records that are merged, and the record that is split, leave the file, and the records that replace them are new. A new record or point, a replacement included, SHALL get an `id` that appears in neither outline file and in no approval record, as the `id` of a record or a point or as a value of `section`, `parent` or `uses`. The list of ids in use that the skill prints can hold more than these, taken from other objects in the files; that only rules out more ids. A replacement SHALL NOT take the `id` of a record it replaces.

Merging, splitting and leaving a paragraph out SHALL keep every source on record.

- The `from` of the record that replaces merged records holds every locator of the records it replaces.
- When a record that has `from` is split, each record that replaces it has in its `from` at least one locator of the original, and each locator of the original is in the `from` of at least one of them.
- When a point moves to another paragraph record and the record it leaves has `from`, each locator of that `from` is added to the point's `basis`, so that the point keeps its source; a locator the point already has is not added again. A record is not left with no point: when the point that moves is the last one of its record, the skill asks the author whether that record is given a new point or is left out. Left out, a record without `from` is deleted once the point has moved. A record with `from` can be neither deleted nor left without a point: the point moves with its `id`, and the record keeps a copy of the point's text as a point with a new `id` and is given `dropped` with the reason.
- When the author leaves a paragraph out of the article and its record has `from`, the record is not deleted: it is given `dropped` with the reason. A record without `from` that the author leaves out is deleted from the file.

Leaving a section out and moving a section SHALL leave every `parent` naming a section record on an earlier line.

- When the author leaves a section out, three things happen in this order. First, the sections under it are settled: each is left out with it, or is given another `parent` or none, as the author says; the skill asks when the author has not said. Second, each paragraph record naming the section is left out by the rule above. Third, the skill looks at what still names the section: when no paragraph record and no section record names it any more, the section record is deleted from the file; otherwise it stays and is given `dropped` with the reason.
- A section that is moved takes the sections under it along, so that they stay on later lines than it. A section is not moved to a line before its own `parent`: it is given another `parent`, or none, first, as the author says. The skill asks when the author has not said.

A record's `note` stays with it when it changes, moves or is given `dropped`; a record that replaces merged records holds their notes, and each record that replaces a split record holds its note. A file the author points to during a revision is read under the same rule as in draft.

When a revision leaves a `uses` entry that names a later line, a record that is no longer in the file or a record that carries `dropped`, the skill tells the author and SHALL NOT delete the entry itself.

After a revision the skill SHALL say which sections no longer stand as approved, and which sections were removed since their approval.

No executable check: this change adds no test target; the examples and tests of this requirement are deferred to issue 78, which follows the Swift package (issue 46).

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

When writing the record into the approvals file fails, the record may have been appended in whole, in part or not at all: the skill SHALL show the author the check of the approvals file, the status and the last line of the approvals file, say that the approval may or may not be on record, and SHALL NOT append again. The skill SHALL append the record as a line of its own: when the last line of the approvals file is not ended by a line break, the skill ends that line first. The line break that ends a line is not part of its content, and the skill SHALL NOT change the content of an earlier line. What the skill writes down for one approval, the author's words and the sections approved, SHALL NOT be used for a later one.

What the skill shows for a section depends on its approved copy.

- A section that has no approved copy is shown in full: its `heading` and `says`, every paragraph record naming it with its points and its `note`, and every record that carries `dropped` together with the reason.
- A section that differs from its approved copy is shown by its differences: for each record that was changed, added, removed or moved, the approved content and the current content. The skill says that the rest of the section is as it was approved, and shows the section in full when the author asks.
- A section that equals its approved copy is shown as unchanged since its approval.

The findings of the premise check on a section are shown with it in all three cases.

Whenever the sections shown are all the sections of the section file, the skill SHALL show three more things first, because an approval of all of them is an approval of the whole outline and approves all three. When the order of sections does not stand as approved, it shows the sections in the order they are in now, and beside it their order in the last approval of the whole outline when one is on record. And it shows every section removed since its approval, with its heading, its `says` and the points of its paragraph records as they were last approved. And it shows in full every section of the file that the last approval of the whole outline does not hold, when one is on record, also when that section equals its latest approved copy: a section that was taken out, approved as gone with the whole outline, and put back unchanged would otherwise return without being seen. When fewer than all the sections are shown, and the order of sections does not stand as approved or a section was removed since its approval, the skill says that the order of the sections, with the sections added to it, or the removal of a section, is not part of this approval: it takes an approval of the whole outline.

No executable check: this change adds no test target; the examples and tests of this requirement are deferred to issue 78, which follows the Swift package (issue 46).

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

### Requirement: Text from the manuscript and the author never becomes part of a command

The skill SHALL NOT write text taken from the manuscript, from an outline file or from the author into the text of a command. Such text (the opening words of a passage, a sentence, an `id`, the name of a file a locator gives, the author's approving words) SHALL reach a command only from a file that the command reads. A command that hands such a value on to a tool SHALL hand it on so that the shell interprets no character of it. A path the skill does write in a command SHALL be written so that the shell interprets no character of it. The paths the skill writes in its commands are the root, the outline directory, the stage directory, the directory that holds the manuscript, the manuscript's main file, and a file the author points to in draft or revise (a source, or an outline of the author's own), which the skill checks the way it checks the main file before it reads it. Each SHALL begin with `/`: a path among them that is empty or not written out in full stops the skill, and so does a path that holds a single quote. The one exception is the manuscript's main file in the command that compares a ledger with it: left empty there, it means that there is no manuscript yet. The paths of the ledgers' `_meta.json` files SHALL reach a command only from a list in the stage directory, not written into the command. The task message the skill gives to the agent of the premise check is held to the same rule: it holds paths the skill made, and none of that text.

A check of the skill counts as passed only when its command reports success in words. A check whose command prints nothing, fails, or cannot run SHALL be treated as failed. When a tool that the skill's commands need (`jq`, `realpath`, `git`) is not installed, the skill SHALL stop and say which tool is missing. It SHALL stop too when its `jq` reads two long numbers that differ as the same number, as versions before 1.7 do; when its `git` is older than 2.38, the first version that knows the setting `safe.bareRepository`; and when the system's `pwd` is in neither `/usr/bin` nor `/bin`: the names of directories rest on it, and the skill looks for it nowhere else. The other tools are found through `PATH`. A variable named `TOOLS` or `ROOT` in the author's environment SHALL NOT change what the first command does. When the first command finds no git repository for the directory, or git cannot say whether that repository is checked out inside another, it says so in a line of its own that begins with `STOP`.

Every git command of the skill that reads a repository SHALL be run with the settings `safe.bareRepository=explicit` and `core.fsmonitor=false`. With the first, git takes a directory for a repository only when a `.git` is in it or above it: files of the working tree that are laid out like a repository (a `HEAD`, an `objects`, a `refs` and a `config`, which a commit can carry like any other files) are not taken for one, and that `config` is not read. Git does not pass such a directory by: asked in it, or in a directory under it, git refuses to answer, so a source there is not read: the derive action does not follow a `.tex` file there, a locator that names a file there does not resolve, and a manuscript there stops the skill at its first command, where git's own error gives the reason. A `_meta.json` there is still listed, because the listing does not ask git; when there is a manuscript, its comparison with the manuscript does not run to its end, and the skill asks; when there is no manuscript yet, the comparison runs no git and the file counts as compared. With the second, git starts no file-watching program that a configuration names. A linked worktree, and a repository whose `.git` is a file, are found as before.

No executable check: this change adds no test target; the examples and tests of this requirement are deferred to issue 78, which follows the Swift package (issue 46).

#### Scenario: A passage that opens with inline mathematics

- **WHEN** the derive action reads a passage whose opening words contain a dollar sign followed by a parenthesis, a backquote and a backslash
- **THEN** the opening words reach the counting command only inside the staged paragraph file, they are counted as they are written in the manuscript, and no part of them is run or rewritten by the shell

#### Scenario: A jq that does not keep long numbers

- **WHEN** the installed `jq` reads 9007199254740993 and 9007199254740992 as the same number
- **THEN** the skill stops before it resolves any path and says what is missing

#### Scenario: Files laid out like a repository

- **WHEN** a directory of the repository holds a `HEAD`, an `objects`, a `refs` and a `config` that names a program for `core.fsmonitor`, with a `.tex` file beside them, all of them committed
- **THEN** no command of the skill runs that program, and that `.tex` file is not listed as a file to read, because git gives no answer for that directory

#### Scenario: A git older than 2.38

- **WHEN** the installed `git` reports version 2.30
- **THEN** the skill stops before it resolves any path and says what is missing

#### Scenario: A manuscript in a linked worktree

- **WHEN** the directory that holds the manuscript is a linked worktree of a repository, or a worktree of a bare repository
- **THEN** the root is that worktree, and the files git tracks there are read as in any other checkout

#### Scenario: A variable of the environment named ROOT

- **WHEN** the author's environment has a variable `ROOT`, and the directory given to the first command is in no git repository
- **THEN** the first command stops and makes no stage directory

#### Scenario: The tool the checks use is missing

- **WHEN** the tool that the skill's checks use is not installed
- **THEN** the skill stops, says which tool is missing, and reports no write as done
