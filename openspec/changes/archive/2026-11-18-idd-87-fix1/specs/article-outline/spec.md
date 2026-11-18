## MODIFIED Requirements

### Requirement: The outline is three files beside the ledger

The outline SHALL consist of three files in the directory that holds, or would hold, the manuscript's ledger: `outline-sections.jsonl`, `outline-paragraphs.jsonl` and `outline-approvals.jsonl`. In each file every line that is not empty SHALL be one JSON object.

The repository is the git repository that holds the manuscript, or, when that repository is checked out as a submodule of another (as git reports it, from the index of the outer repository), the outermost repository it is checked out in, however many levels of submodules lie between; this has no cap yet because the maintainer has not decided whether to stop past some number of levels (issue 75). When the manuscript is in no git repository, the skill SHALL stop and say why, and SHALL NOT take the boundary of the repository from an answer of the author. For a draft with no manuscript yet, the directory where the author says the manuscript will be stands in for it when the repository is found; when that directory does not exist yet, the nearest directory above it that does is used in its place, and the skill SHALL then tell the author which repository it found and ask whether the manuscript will be in it, and stop when it will not. A repository whose root is the root of the file system is not supported: the skill stops after its first command, which has already made its temporary directory inside it. That directory is not the directory of the outline files unless the author says so, and no ledger names a manuscript that does not exist yet. A repository that sits inside another without being its submodule is a repository of its own; a ledger of the outer repository is then outside the repository, does not name the manuscript, and cannot have the outline beside it. A directory under the repository's root counts as inside it even when it holds a git repository of its own. Wherever this capability says inside the repository, it means inside this one, and every path a locator gives is relative to its root; an outline kept inside a submodule therefore does not resolve in a checkout of the submodule alone.

The manuscript's main file SHALL be a regular file inside the repository that is not itself a symbolic link, is not inside a `.git` directory in any letter case, and that git lists: a file git tracks, or one git does not track and does not ignore (the requirement on locators says which repositories are asked). Its path from the root SHALL hold no character that a locator's `file` is not allowed to hold. When it is not such a file, the skill SHALL stop, say why, and not read it. A symbolic link in the path of the directory that holds it is a different case: it is resolved, and from then on the skill reads the manuscript by its real path.

Directories are compared by the name the system itself gives them, not by the way a path was written: a path through a symbolic link, in another letter case on a file system that ignores case, or through another name of the same volume leads to the same name. A file is named the same way: by its real path, with its directory named as the system names it, and only when that name and the path it was reached by are the same file. For the manuscript's main file and for a file a locator names, the last part of the name is the one the directory itself gives: `main.tex`, written for a file the disk has as `Main.tex`, is named `Main.tex`. When the directory holds two names for that file, the last part stays as it was resolved, which differs between the `realpath` macOS ships (the name the disk has) and GNU's (the name as typed). When git does not have that name, the whole path ignores letter case, and git tracks a path that differs from it only in letter case, the file counts as tracked and keeps the name it has by the rule above (its last part as the directory gives it), not the name git has; the `.tex` files the derive action follows are treated the same way. One such file is still refused: one whose name the outermost repository ignores, because it is asked about that name and answers so; a file in a submodule is not refused that way, because the outermost repository gives no answer for it. The directory is looked into for the name only once the file is known to be inside the repository and outside `.git`. Wherever this capability says that a directory or a file is inside or outside the repository, it means by that name.

The outline SHALL NOT depend on a ledger: the directory can hold the three files without a `main.jsonl`. The skill SHALL use a directory without asking only when every `_meta.json` it lists in the repository was read as one ledger and compared with the manuscript, exactly one of those ledgers names this manuscript, and the author's request names no other directory; it then uses that ledger's directory.

A ledger names one file at most. `docs/SCHEMA.md` writes a ledger's `source.file` from the "manuscript repo root"; when the git repository that holds the ledger is a submodule of another, some ledgers read that as the submodule's root and others as the root of the outermost repository. The skill reads `source.file` both ways, in this order: as a path from the root of the git repository that holds the ledger (for a ledger inside a submodule, the submodule's root), and then as a path from the root of the repository. The first reading that leads to a regular file under the root of the ledger's own git repository decides which file the ledger names, and a file in a directory under that root counts also when the directory is a submodule or holds a git repository of its own; a reading that leads to no file, or to a file outside the ledger's own git repository, is not taken. The ledger names this manuscript when the file it names is the manuscript's main file, both resolved to real paths. The ledger of another paper, kept in a submodule or in a git repository of its own under the root, therefore does not name a manuscript of the outer repository. For the same reason a ledger that is kept in a git repository of its own, apart from its manuscript, names no file, and the skill asks. A `source.file` that holds a control character names no file.

A `_meta.json` that is a symbolic link, that is inside a `.git` directory in any letter case, or whose path holds a line break is not listed, is not read and does not count as a ledger; one whose path holds, below the root, another character that a locator's `file` is not allowed to hold is not listed, is not read and does not count as a ledger either, and the part of the path down to the root is not tested. Whether git ignores a `_meta.json`, or the directory of the outline files, is not asked: only the sources (the manuscript, the files it includes and the files a locator names) are held to what git lists. A listed `_meta.json` is read as one ledger when it holds exactly one JSON value, that value is an object, and the file passes the test of written JSON that the write check applies to an outline file: outside its strings it holds only `true`, `false`, `null` and numbers written as JSON writes them. A file that fails this test SHALL NOT be read as one ledger, although the tool reading it accepts it; it is such a file when it holds `nan`, `Infinity`, or a number such as `01` or `.5` outside a string, or begins with a byte-order mark. As in the write check, a byte that is not UTF-8 is read as a replacement character and is not reported.

In every other case the skill SHALL NOT choose a directory itself. These are the cases, and the list is closed: no ledger names the manuscript; more than one does; there is no manuscript yet; a listed `_meta.json` could not be read as one ledger, or its comparison with the manuscript did not run to its end, in which case the skill also tells the author which one; or one ledger names the manuscript and the request names another directory. When the request names the directory of the outline files, every listed `_meta.json` was read as one ledger and compared, and no ledger names the manuscript or there is no manuscript yet, the request is the author's answer and the skill uses that directory. Otherwise it SHALL ask the author which directory to use. Outline files elsewhere in the repository are then offered, not taken, because they can belong to another manuscript; when there is nothing to offer, the skill proposes a directory `propositions` beside the manuscript, where a ledger is put by convention. When the command that lists the ledgers fails, the skill stops. Adding, changing or removing the outline files SHALL NOT change the ledger, its metadata, the structure sidecars or the verification records. The ledger's schema version does not cover the outline files, and neither does the rule that keeps the ledger in step with the manuscript (`rules/manuscript-jsonl-sync.md` of this plugin): a change to the manuscript obliges no change to the outline files.

A section record, a paragraph record, a point and a locator are allowed to carry keys that this capability does not define. An approval record SHALL carry no key other than the four this capability defines for it.

No string in a section record or a paragraph record, the name of a key included, SHALL contain a control character (U+0000 to U+001F), a line break included. Where the text has a line break, the string has a space.

No executable check: this change adds no test target; the examples and tests of this requirement are deferred to issue 78, which follows the Swift package (issue 46).

#### Scenario: A manuscript without a ledger has an outline

- **WHEN** a directory holds the three outline files and no `main.jsonl`
- **THEN** the three files are an outline, and nothing in this capability asks for a ledger

#### Scenario: An undefined key is allowed in a paragraph record

- **WHEN** a paragraph record carries a key `length_target`, which this capability does not define
- **THEN** the record is a paragraph record like any other, and the key is part of its content

#### Scenario: Neither a ledger nor an outline exists yet

- **WHEN** the author asks for an outline of a manuscript that has no ledger and no outline files, and the request names no directory for the outline
- **THEN** the skill asks which directory the outline files go in before it writes them

#### Scenario: Outline files of another manuscript in the same repository

- **WHEN** no ledger in the repository names this manuscript, the repository holds outline files in a directory that has no ledger, and the author asks for an outline of this manuscript
- **THEN** the skill offers that directory to the author and asks which directory to use, and does not read or write the outline files there before the author answers

#### Scenario: A manuscript in a submodule, with its ledger in the outer repository

- **WHEN** the manuscript's repository is checked out as a submodule of another repository, and the ledger that names the manuscript is in the outer repository
- **THEN** the repository is the outer one: the directory beside that ledger is inside it, and every `file` of a locator is a path relative to the outer repository's root

#### Scenario: A ledger inside a submodule names the manuscript

- **WHEN** the manuscript's repository is checked out as a submodule, holds the only ledger that names the manuscript, and that ledger's `source.file` is `main.tex`, a path from the submodule's root
- **THEN** the ledger names this manuscript, and the skill uses its directory without asking

#### Scenario: A repository inside another that is not its submodule

- **WHEN** the manuscript is in a git repository that sits inside another repository's directory without being registered as its submodule, no ledger of the inner repository names the manuscript, and the request names no directory for the outline
- **THEN** the repository is the inner one, a file of the outer repository is outside it, and a ledger of the outer repository is not used: the skill asks the author which directory of the inner repository to use

#### Scenario: A manuscript in no git repository

- **WHEN** the directory that holds the manuscript is in no git repository
- **THEN** the skill stops, says that it works only on a manuscript inside a git repository, and reads and writes no outline file

#### Scenario: A ledger written from the outer root

- **WHEN** the manuscript's repository is checked out as a submodule `paper/manuscript` of the repository, and the only ledger that names the manuscript sits inside the submodule with `source.file` `paper/manuscript/main.tex`, a path from the repository's root
- **THEN** the ledger names this manuscript, and the skill uses its directory without asking

#### Scenario: A ledger kept in a repository of its own

- **WHEN** the directory `manuscript/propositions` is a submodule that holds only the ledger, with `source.file` `manuscript/main.tex`, and the manuscript `manuscript/main.tex` is in the outer repository
- **THEN** the ledger names no file, because the file is outside the ledger's own git repository, and the skill asks the author which directory to use

#### Scenario: A ledger whose directory git cannot answer for

- **WHEN** two ledgers have a `source.file` that leads to the manuscript, and the comparison of one of them fails because git gives no answer for its directory
- **THEN** the skill does not count the other as the only ledger that names the manuscript: it tells the author which comparison failed and asks which directory to use

#### Scenario: The ledger of another paper in a submodule

- **WHEN** the repository's own manuscript is `main.tex` at its root and has no ledger, and a submodule of the repository holds another paper with a ledger whose `source.file` is `main.tex`
- **THEN** that ledger does not name the repository's manuscript, and the skill asks the author which directory to use

#### Scenario: A source.file that both readings find

- **WHEN** a ledger inside the submodule `sub` has `source.file` `sub/main.tex`, and both `sub/sub/main.tex` and `sub/main.tex` exist
- **THEN** the ledger names `sub/sub/main.tex`, the file the reading from the submodule's root leads to, and does not name `sub/main.tex`

#### Scenario: A draft with no manuscript in a repository that has a ledger

- **WHEN** the author asks for a draft, there is no manuscript yet, the request names no directory, and the repository holds the ledger of another manuscript
- **THEN** the skill does not stop: no ledger names a manuscript that does not exist, and it asks the author which directory to use

#### Scenario: A _meta.json that cannot be read

- **WHEN** one ledger names the manuscript and another `_meta.json` in the repository holds two JSON values
- **THEN** the skill tells the author which `_meta.json` could not be read as one ledger and asks which directory to use

#### Scenario: The request names another directory than the ledger's

- **WHEN** exactly one ledger names the manuscript and the author's request names a different directory for the outline
- **THEN** the skill says where that ledger is and asks which of the two directories to use

#### Scenario: A manuscript that is a symbolic link

- **WHEN** the path given as the manuscript's main file is a symbolic link to a file outside the repository
- **THEN** the skill stops, says why, and does not read the file

#### Scenario: A manuscript three submodules deep

- **WHEN** the manuscript's repository is checked out as a submodule of a submodule of a submodule of another repository
- **THEN** the repository is that outermost one, and the skill does not stop for the number of levels

#### Scenario: The directory for a manuscript does not exist yet

- **WHEN** the author asks for a draft, there is no manuscript yet, and the directory where the author says the manuscript will be does not exist
- **THEN** the nearest directory above it that exists is used to find the repository, the skill does not stop because the directory is missing, and it asks the author whether the repository it found is the one the manuscript will be in

#### Scenario: A manuscript written in another letter case

- **WHEN** the file system ignores letter case, the disk has `paper/Main.tex`, git tracks it, and the author gives the manuscript as `paper/main.tex`
- **THEN** the skill reads the file, and the name it uses for it in every locator is `paper/Main.tex`

#### Scenario: A tracked file renamed on the disk in letter case only

- **WHEN** the file system ignores letter case, git tracks `part.tex`, the file was renamed on the disk to `Part.tex` without telling git, and the manuscript includes it
- **THEN** the file counts as tracked: the derive action reads it, under the name the disk has, `Part.tex`, when the directory holds no other name for that file

#### Scenario: A file system that tells letter case apart

- **WHEN** the file system tells letter case apart, git tracks `main.tex`, and `Main.tex` is another file, which git ignores
- **THEN** `Main.tex` is not a file git lists: that git tracks a path differing only in letter case does not vouch for it

#### Scenario: A ledger in a directory git ignores

- **WHEN** the only ledger that names the manuscript is in a directory that git ignores, and the request names no other directory
- **THEN** the ledger is listed and compared like any other, and the skill uses its directory without asking

#### Scenario: A backslash that was written as a JSON escape

- **WHEN** the `text` of a point was meant to hold the LaTeX command for the Greek letter beta and its backslash was written into the file once, so that the string holds a backspace character
- **THEN** the record does not meet this requirement

#### Scenario: A ledger file that is not written as JSON

- **WHEN** the only `_meta.json` in the repository holds `{"source":{"file":"main.tex"},"extra":01}`
- **THEN** the skill does not read it as one ledger, tells the author which `_meta.json` could not be read, and asks where the outline files go

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

### Requirement: Derive and draft build an outline without inventing content

The derive action SHALL read a finished manuscript and produce one section record for each of its sections and one paragraph record for each of its paragraphs and blocks. It reads the manuscript's main file by its real path, after confirming again that the file meets the conditions this capability sets for it. It SHALL follow the files that the manuscript includes, whose names end in `.tex` in any letter case, only when they are regular files inside the repository that git lists (tracked, or not tracked and not ignored) and whose path holds no line break and, below the root, no other character that a locator's `file` is not allowed to hold. Any other included file is named to the author and not read: one outside the repository, a symbolic link, a file reached through a directory that is a symbolic link, a file inside a `.git` directory in any letter case, a file git ignores, a file git gives no answer for (one in or under a directory laid out like a git repository), a file whose path holds such a character, or a missing file. An include of a file that is not `.tex` names a file that is missing (`\input{fig.tikz}` names `fig.tikz.tex`). A figure or a table that comes from an included file that was not read is still the one record that carries `carry` for the figure or the table, named in the file that includes it. Any other included file that was not read SHALL get nothing in the outline: no record, no locator, no point and no `note`; the action names it to the author, and the outline does not show the gap (whether it should is open, issue 51). An include command `\input{x}` or `\include{x}` names the file `x` when `x` ends in `.tex` in any letter case, and `x.tex` otherwise, taken from the directory of the main file; it is read only when it is a file the skill reads, and the skill SHALL NOT look for it anywhere else. On a file system that ignores letter case the same file in another letter case is the same file. A command inside a LaTeX comment includes nothing. When the files the action read hold no paragraph and no block at all, so that the paragraph file would be empty, the action SHALL stop, say which included files were not read, show no outline and write nothing to the repository; it SHALL stop before it asks the author for any section's `says`. This holds when every section's text is in included files that were not read, when the manuscript has headings and nothing else (the action then says that draft builds an outline from headings), and when some sections are the one and some the other; it does not hold when the main file has a figure or a table whose content is in a file that was not read, since that is still a block. Otherwise, when all the text of a section is in included files that were not read, the action SHALL ask the author for the section's `says` and SHALL stop when the author gives none; when such a section ends with no paragraph record, of its own or of a section under it, the action tells the author that the premise check reports it for that reason. An abstract that has no heading of its own gets the `heading` "Abstract". Prose that comes before the first heading and is not the abstract gets one section record, whose `heading` is the title of the article; the skill tells the author that this section has no heading of its own in the manuscript, and asks what to put in `heading` when the manuscript gives no title. A theorem-like statement, a proof, a figure, a table, and a displayed formula or derivation that has a blank line before it and a blank line after it each become one record that carries `carry`, whose point is a complete sentence stating what the block states or shows. Any other displayed formula or derivation belongs to a paragraph's record: with no blank line on either side, the record of the paragraph it stands in; with a blank line on one side only, the record of the paragraph on the other side. Every paragraph record the action produces SHALL have `from` naming the passage it comes from, and every point SHALL state only what that passage states. A theorem-like statement, a figure or a table is named by its own label; the label of a section names the whole section and SHALL NOT be used for a record. The action writes no `lines` and no `commit`, and the `file` of every locator it writes is the name of the file from the root, as the first requirement defines it. Before it shows the outline, the action SHALL confirm for every locator it wrote that the locator resolves: the text of its `label` and its `starts`, whichever it has, each occur exactly once in the file it names. When a passage that has no label of its own has a text that, to its end, occurs a second time in the same file, as another passage that reads the same or inside a longer one, no locator names it: the action SHALL stop, tell the author which passages they are, show no outline and write nothing to the repository, and SHALL NOT take opening words from the passage that follows. It stops the same way when a file it read is not accepted as a locator's file. A manuscript that has paragraphs SHALL NOT give an empty paragraph file.

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
- **THEN** the derive action does not stop: it writes the two paragraph records, nothing for `stats/N.tex`, and names `stats/N.tex` to the author as a file that was not read

#### Scenario: Every section's text is in files that were not read

- **WHEN** the main file holds `\section{Introduction}` followed by `\input{sections/intro}` and `\section{Method}` followed by `\input{sections/method}`, and `sections/` is ignored by git
- **THEN** the derive action stops, names the two files as not read, shows no outline and writes nothing to the repository

#### Scenario: A file name with a dot

- **WHEN** the manuscript writes `\input{ch1.final}` and `ch1.final.tex` is a file git tracks in the directory of the main file
- **THEN** the derive action reads `ch1.final.tex`

#### Scenario: An include command that names its extension in capitals

- **WHEN** the manuscript writes `\input{Intro.TEX}` and `Intro.TEX` is a file git tracks in the directory of the main file
- **THEN** the derive action reads `Intro.TEX`

#### Scenario: Every section is in files that were not read and the author is not asked

- **WHEN** the text of every section of the manuscript is in included files that git ignores, and the main file holds no figure, table or other block
- **THEN** the derive action stops without asking the author for any section's `says`

#### Scenario: One section is a bare heading and the other is in a file that was not read

- **WHEN** one section of the manuscript is a heading with nothing under it and the text of the other is all in an included file that git ignores
- **THEN** the derive action stops without asking the author for either section's `says`

#### Scenario: A table whose content was not read keeps derive going

- **WHEN** the only section of the manuscript holds `\begin{table}\input{tables/results}\label{tab:results}\end{table}` and `tables/` is ignored by git
- **THEN** the derive action does not stop for an empty paragraph file: the table is one record that carries `carry`, and the action asks the author for the section's `says`

#### Scenario: An include command that names its extension

- **WHEN** the manuscript writes `\include{chapters/ch1.tex}` and `chapters/ch1.tex` is a file git tracks under the directory of the main file
- **THEN** the derive action reads `chapters/ch1.tex`

#### Scenario: A displayed formula inside a paragraph

- **WHEN** the derive action reads a paragraph whose third sentence is interrupted by a displayed, labelled equation, with no blank line before or after the equation, and goes on after it
- **THEN** the outline has one paragraph record for the paragraph, without `carry`, whose `from` names the paragraph by its opening words and not by the label of the equation
