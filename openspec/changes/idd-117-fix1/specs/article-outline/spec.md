## MODIFIED Requirements

### Requirement: Derive and draft build an outline without inventing content

The derive action SHALL read a finished manuscript and produce one section record for each of its sections and one paragraph record for each of its paragraphs and blocks. It reads the manuscript's main file by its real path, after confirming again that the file meets the conditions this capability sets for it. It SHALL follow the files that the manuscript includes, whose names end in `.tex` in any letter case, only when they are regular files inside the repository that git lists (tracked, or not tracked and not ignored) and whose path holds no line break and, below the root, no other character that a locator's `file` is not allowed to hold. Any other included file is named to the author and not read: one outside the repository, a symbolic link, a file reached through a directory that is a symbolic link, a file inside a `.git` directory in any letter case, a file git ignores, a file git gives no answer for (one in or under a directory laid out like a git repository), a file whose path holds such a character, or a missing file. An include whose name does not end in `.tex` in any letter case names the file with `.tex` added (`\input{fig.tikz}` names `fig.tikz.tex`): that file is read when it exists and is a file the skill reads, and is a missing file when it does not exist, the usual case for a figure, a table or a style file kept under its own name. A figure or a table that comes from an included file that was not read is still the one record that carries `carry` for the figure or the table, named in the file that includes it. Any other included file that was not read SHALL be recorded in `unread` on the section record of the section its include command stands in (the first section record when the command stands before the first section), one entry for each include command, and get nothing else in the outline: no paragraph record, no locator, no point and no `note`; the action names it and that section to the author. An include command `\input{x}` or `\include{x}` names the file `x` when `x` ends in `.tex` in any letter case, and `x.tex` otherwise, taken from the directory of the main file; it is read only when it is a file the skill reads, and the skill SHALL NOT look for it anywhere else. On a file system that ignores letter case the same file in another letter case is the same file. A command inside a LaTeX comment includes nothing. When the files the action read hold no paragraph and no block at all and no included file was left unread, the action SHALL stop, show no outline and write nothing to the repository; it SHALL stop before it asks the author for any section's `says`. When they hold none because the text is in included files that were not read, the action goes on: the section records carry those files in `unread`, and the paragraph file is empty. A paragraph counts when the action read any of its text; a block (a theorem-like statement, a proof, a figure, a table or a displayed formula) counts when the action read the environment or the delimiters that hold it, even when its content is in a file that was not read. When the action stops for this reason and the manuscript has headings and nothing under them, it also says that draft builds an outline from headings. When the action does not stop for this reason and all the text of a section is in included files that were not read, the action SHALL ask the author for the section's `says` and SHALL stop when the author gives none; when such a section ends with no paragraph record, of its own or of a section under it, the action tells the author that the premise check reports it for that reason. An abstract that has no heading of its own gets the `heading` "Abstract". Prose that comes before the first heading and is not the abstract gets one section record, whose `heading` is the title of the article; the skill tells the author that this section has no heading of its own in the manuscript, and asks what to put in `heading` when the manuscript gives no title. A theorem-like statement, a proof, a figure, a table, and a displayed formula or derivation that has a blank line before it and a blank line after it each become one record that carries `carry`, whose point is a complete sentence stating what the block states or shows. Any other displayed formula or derivation belongs to a paragraph's record: with no blank line on either side, the record of the paragraph it stands in; with a blank line on one side only, the record of the paragraph on the other side. Every paragraph record the action produces SHALL have `from` naming the passage it comes from, and every point SHALL state only what that passage states. A theorem-like statement, a figure or a table is named by its own label; the label of a section names the whole section and SHALL NOT be used for a record. The action writes no `lines` and no `commit`, and the `file` of every locator it writes is the name of the file from the root, as the first requirement defines it. Before it shows the outline, the action SHALL confirm for every locator it wrote that the locator resolves: the text of its `label` and its `starts`, whichever it has, each occur exactly once in the file it names. When a passage that has no label of its own has a text that, to its end, occurs a second time in the same file, as another passage that reads the same or inside a longer one, no locator names it: the action SHALL stop, tell the author which passages they are, show no outline and write nothing to the repository, and SHALL NOT take opening words from the passage that follows. It stops the same way when a file it read is not accepted as a locator's file. A manuscript that has paragraphs SHALL NOT give an empty paragraph file.

The draft action SHALL produce section and paragraph records from a title and ideas, or from an outline the author supplies. It needs no manuscript. A file the author points to, or an outline the author supplies as a file, SHALL be read only after the check the skill runs on the manuscript's main file accepts it, and by the path that check gives; that run concerns that file only and does not change which file is the manuscript's main file; when the check refuses it, the skill asks the author to paste the text. When a locator the author asked for does not resolve, the action SHALL NOT rewrite it: it says which and why, and asks the author whether to correct it or to leave it out of the record. A point that would report a result, a number or a citation the author has not supplied SHALL say what will be reported without stating it, and SHALL carry `pending`. When the outline the author supplies has sections and no paragraph yet, the action writes no paragraph record, and the paragraph file is empty.

Both actions SHALL show the outline to the author before any file is written in the repository, and SHALL write the files there only after the author agrees. Agreeing to have the files written is not an approval of the outline, and neither action appends an approval record. Neither action SHALL overwrite or add to existing outline files: when `outline-sections.jsonl` or `outline-paragraphs.jsonl` exists, the action stops and says that revise is the action to use. When only `outline-approvals.jsonl` exists, the action SHALL stop too: a new outline is not started beside the approvals of an earlier one, and what to do with that file is the author's decision.

No executable check: this requirement is about what the skill does in a conversation or what a document says, which no command of this repository decides; the commands the skill runs are checked by an acceptance run outside the repository.

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
- **THEN** the derive action does not read that file, tells the author which file it is, records it in `unread` of the section record its include command stands in and writes nothing else for it, and goes on with the rest of the manuscript

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
- **THEN** the section record of that section carries `sections/generated` in `unread`, the outline holds no paragraph record for the command or the file, and the derive action names `sections/generated.tex` to the author as a file that was not read

#### Scenario: The same unread file included twice

- **WHEN** the manuscript writes `We surveyed \input{stats/N} adults.` in one paragraph and `Participants were \input{stats/N} adults.` in another, and `stats/` is ignored by git
- **THEN** the derive action does not stop: it writes the two paragraph records, two `unread` entries for `stats/N` on the section record (one for each include command), and names `stats/N.tex` to the author as a file that was not read

#### Scenario: Every section's text is in files that were not read

- **WHEN** the body of the main file holds only `\section{Introduction}` followed by `\input{sections/intro}` and `\section{Method}` followed by `\input{sections/method}`, and `sections/` is ignored by git
- **THEN** the derive action does not stop: it asks the author for the `says` of each section, writes two section records that each carry their file in `unread`, leaves the paragraph file empty, and names the two files as not read

#### Scenario: A file name with a dot

- **WHEN** the manuscript writes `\input{ch1.final}` and `ch1.final.tex` is a file git tracks in the directory of the main file
- **THEN** the derive action reads `ch1.final.tex`

#### Scenario: An include command that names its extension in capitals

- **WHEN** the manuscript writes `\input{Intro.TEX}` and `Intro.TEX` is a file git tracks in the directory of the main file
- **THEN** the derive action reads `Intro.TEX`

#### Scenario: Every section is in files that were not read and the author gives no sentence

- **WHEN** the text of every section of the manuscript is in included files that git ignores, the files the action read hold no paragraph and no block, and the author gives no `says` for a section
- **THEN** the derive action stops, names the files, shows no outline and writes nothing to the repository

#### Scenario: An abstract in the main file keeps derive going

- **WHEN** the main file holds an abstract whose one paragraph is written out in the main file, and the text of every section is in included files that git ignores
- **THEN** the derive action does not stop for an empty paragraph file, and asks the author for the `says` of each section

#### Scenario: An abstract in an included file that was read keeps derive going

- **WHEN** the main file holds `\input{abstract}` before the first heading, `abstract.tex` is a file git tracks that holds one paragraph, and the text of every section is in included files that git ignores
- **THEN** the derive action does not stop for an empty paragraph file, and asks the author for the `says` of each section

#### Scenario: An abstract whose text was not read is recorded like a section

- **WHEN** the main file holds `\begin{abstract}\input{gen/abstract}\end{abstract}`, the text of every section is in included files under `gen/`, `gen/` is ignored by git, and the files the action read hold no paragraph and no block
- **THEN** the derive action does not stop: it asks the author for the `says` of the abstract and of each section, and each section record carries its file in `unread`

#### Scenario: An include without the extension names the file with it

- **WHEN** the main file holds `\input{fig.tikz}` and the repository tracks `fig.tikz.tex` beside it
- **THEN** the derive action reads `fig.tikz.tex` and does not name it to the author as a missing file

#### Scenario: One section is a bare heading and the other is in a file that was not read

- **WHEN** one section of the manuscript is a heading with nothing under it, the text of the other is all in an included file that git ignores, and the files the action read hold no paragraph and no block
- **THEN** the derive action does not stop: it asks the author for the `says` of the section whose text was not read and records the file in `unread` of its section record; the bare heading gets its section record as any section does

#### Scenario: A table whose content was not read keeps derive going

- **WHEN** the only section of the manuscript holds `\begin{table}\input{tables/results}\label{tab:results}\end{table}` and `tables/` is ignored by git
- **THEN** the derive action does not stop for an empty paragraph file: the table is one record that carries `carry`, and the action asks the author for the section's `says`

#### Scenario: An include command that names its extension

- **WHEN** the manuscript writes `\include{chapters/ch1.tex}` and `chapters/ch1.tex` is a file git tracks under the directory of the main file
- **THEN** the derive action reads `chapters/ch1.tex`

#### Scenario: A displayed formula inside a paragraph

- **WHEN** the derive action reads a paragraph whose third sentence is interrupted by a displayed, labelled equation, with no blank line before or after the equation, and goes on after it
- **THEN** the outline has one paragraph record for the paragraph, without `carry`, whose `from` names the paragraph by its opening words and not by the label of the equation


<!-- @trace
source: idd-78-outline-checks
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---

### Requirement: The explanatory document describes the outline

`plugins/propositions/docs/OUTLINE.md` SHALL describe what the repository is, the three files and every key of their records, the locator, the three conditions (a section stands as approved, the order of sections stands as approved, the outline stands as approved) and what a paragraph record that names no section does to the last of them, what counts as an approval and the five things that do not, the six kinds of finding of the premise check and the agent that judges five of them, and the six actions of the skill.

It SHALL state that this capability writes no manuscript text and that text is written from an outline by the construct skill, that no validator of the outline files exists until issue 78, and which checks the skill runs until then. It SHALL state what an approval record does not establish: it does not say who approved, and anyone who can write to the repository can add one. It SHALL state that the tools the skill is allowed to use without a prompt are not limited by that allowance: that the skill writes only the three files and starts no agent other than the checker is kept by its commands and its rules. It SHALL state the three things the skill keeps and list the limits known today, saying for each which of the three it can make fail. It SHALL list the design questions this version leaves open.

No executable check: this requirement is about what the skill does in a conversation or what a document says, which no command of this repository decides; the commands the skill runs are checked by an acceptance run outside the repository.

#### Scenario: A reader decides from the document alone

- **WHEN** a reader who has only the document is given the three files of an outline
- **THEN** the reader can say for each section whether it stands as approved, and whether the order of sections and the outline stand as approved


<!-- @trace
source: idd-78-outline-checks
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
