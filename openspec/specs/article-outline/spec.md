# article-outline Specification

## Purpose

The article outline holds what an article is planned to say before it is written: one sentence for each section and at least one sentence for each paragraph, together with the record of the author's approval. This capability defines the three outline files beside a manuscript's ledger and the skill that writes them.

## Requirements

### Requirement: The outline is three files beside the ledger

The outline SHALL consist of three files in the directory that holds, or would hold, the manuscript's ledger, when that directory is in a repository that holds the manuscript: `outline-sections.jsonl`, `outline-paragraphs.jsonl` and `outline-approvals.jsonl`. In each file every line that is not empty SHALL be one JSON object.

The repository is the git repository that holds the directory of the outline files (issue 91). The skill SHALL find it in two steps. First it finds the outermost repository the manuscript is checked out in: the git repository that holds the manuscript, or, when that repository is checked out as a submodule of another (as git reports it, from the index of the outer repository), the outermost repository above it, however many levels of submodules lie between; it looks for ledgers and outline files there, and the directory of the outline files SHALL be inside it. Once that directory is known, the git repository that holds it (for a directory that does not exist yet, the one that holds the directory that is to hold it) is the repository from then on, and its submodules are inside it. That repository SHALL hold the manuscript, and for a draft with no manuscript yet the directory where the author says the manuscript will be (or the nearest one above it that exists); when it does not, the skill SHALL stop and ask for a directory of a repository that does. The root SHALL only move down, to a repository inside the outermost one, and the skill SHALL refuse an outline directory that it would refuse later before it changes the root; to choose an outline directory outside the root, the skill starts again. The lines that begin every command that is given the outline directory SHALL ask git which repository holds it and SHALL stop when it is not the root: after a new session whose first command found the outermost repository again, when the outline directory's repository is below that one, and when the outline directory was changed to a directory of another repository, until the root is set again. The skill SHALL stop too when the outline directory is, or is inside, a submodule that is not checked out, where files could not be tracked, and when git finds no repository for it, which includes a directory in or under one laid out like a git repository. An answer of the author can choose the outline directory, but the boundary is still the one the first command found, narrowed to a repository inside it. When the manuscript is in no git repository, the skill SHALL stop and say why, and SHALL NOT take the boundary of the repository from an answer of the author. For a draft with no manuscript yet, the directory where the author says the manuscript will be stands in for it when the repository is found; when that directory does not exist yet, the nearest directory above it that does is used in its place, and the skill SHALL then tell the author which repository it found and ask whether the manuscript will be in it, and stop when it will not. A repository whose root is the root of the file system is not supported: the skill stops after its first command, which has already made its temporary directory inside it. That directory is not the directory of the outline files unless the author says so, and no ledger names a manuscript that does not exist yet. A repository that sits inside another without being its submodule is a repository of its own; a ledger of the outer repository is then outside the repository, does not name the manuscript, and cannot have the outline beside it. A directory under the repository's root counts as inside it even when it holds a git repository of its own. Wherever this capability says inside the repository, it means inside this one, and every path a locator gives is relative to its root; an outline therefore resolves in every checkout of the repository that holds it, on its own or as a submodule of any other. An outline written before this rule gives every path from the outermost repository. The skill does not convert such an outline and does not try to recognise one. When the root is a repository below the outermost one, its locators do not resolve and the check reports each of them; the skill then says that such an outline names its files from the outermost repository and that the path from that repository down to this one can be removed from each path. Removing it changes the records, so the sections whose records change no longer stand as approved. A path outside the new root is reported too, and no locator can name it any more. One case is not reported and is left to the author: a path that by chance names another file under the new root that holds the same label or opening words. Such an outline in a repository that does not hold the manuscript is refused like any other outline directory there.

The manuscript's main file SHALL be a regular file inside the repository that is not itself a symbolic link, is not inside a `.git` directory in any letter case, and that git lists: a file git tracks, or one git does not track and does not ignore (the requirement on locators says which repositories are asked). Its path from the root SHALL hold no character that a locator's `file` is not allowed to hold. When it is not such a file, the skill SHALL stop, say why, and not read it. A symbolic link in the path of the directory that holds it is a different case: it is resolved, and from then on the skill reads the manuscript by its real path.

Directories are compared by the name the system itself gives them, not by the way a path was written: a path through a symbolic link, in another letter case on a file system that ignores case, or through another name of the same volume leads to the same name. A file is named the same way: by its real path, with its directory named as the system names it, and only when that name and the path it was reached by are the same file. For the manuscript's main file and for a file a locator names, the last part of the name is the one the directory itself gives: `main.tex`, written for a file the disk has as `Main.tex`, is named `Main.tex`. When the directory holds two names for that file, the last part stays as it was resolved, which differs between the `realpath` macOS ships (the name the disk has) and GNU's (the name as typed). When git does not have that name, the whole path ignores letter case, and git tracks a path that differs from it only in letter case, the file counts as tracked and keeps the name it has by the rule above (its last part as the directory gives it), not the name git has; the `.tex` files the derive action follows are treated the same way. One such file is still refused: one whose name the repository ignores at its root, because it is asked about that name and answers so; a file in a submodule is not refused that way, because the repository gives no answer for it. The directory is looked into for the name only once the file is known to be inside the repository and outside `.git`. Wherever this capability says that a directory or a file is inside or outside the repository, it means by that name.

The outline SHALL NOT depend on a ledger: the directory can hold the three files without a `main.jsonl`. The skill SHALL use a directory without asking only when every `_meta.json` it lists in the outermost repository was read as one ledger and compared with the manuscript, exactly one of those ledgers names this manuscript, and the author's request names no other directory; it then uses that ledger's directory.

A ledger names one file at most. `docs/SCHEMA.md` writes a ledger's `source.file` from the "manuscript repo root"; when the git repository that holds the ledger is a submodule of another, some ledgers read that as the submodule's root and others as the root of the outermost repository. The skill reads `source.file` both ways, in this order: as a path from the root of the git repository that holds the ledger (for a ledger inside a submodule, the submodule's root), and then as a path from the root of the outermost repository. The first reading that leads to a regular file under the root of the ledger's own git repository decides which file the ledger names, and a file in a directory under that root counts also when the directory is a submodule or holds a git repository of its own; a reading that leads to no file, or to a file outside the ledger's own git repository, is not taken. The ledger names this manuscript when the file it names is the manuscript's main file, both resolved to real paths. The ledger of another paper, kept in a submodule or in a git repository of its own under the root, therefore does not name a manuscript of the outer repository. For the same reason a ledger that is kept in a git repository of its own, apart from its manuscript, names no file, and the skill asks. A `source.file` that holds a control character names no file.

A `_meta.json` that is a symbolic link, that is inside a `.git` directory in any letter case, or whose path holds a line break is not listed, is not read and does not count as a ledger; one whose path holds, below the root, another character that a locator's `file` is not allowed to hold is not listed, is not read and does not count as a ledger either, and the part of the path down to the root is not tested. Whether git ignores a `_meta.json`, or the directory of the outline files, is not asked: only the sources (the manuscript, the files it includes and the files a locator names) are held to what git lists. A listed `_meta.json` is read as one ledger when it holds exactly one JSON value, that value is an object, and the file passes the test of written JSON that the write check applies to an outline file: outside its strings it holds only `true`, `false`, `null` and numbers written as JSON writes them. A file that fails this test SHALL NOT be read as one ledger, even when the tool reading it accepts it; it is such a file when it holds `nan`, `Infinity`, or a number such as `01` or `.5` outside a string, or begins with a byte-order mark. As in the write check, a byte that is not UTF-8 is read as a replacement character and is not reported.

In every other case the skill SHALL NOT choose a directory itself. These are the cases, and the list is closed: no ledger names the manuscript; more than one does; there is no manuscript yet; a listed `_meta.json` could not be read as one ledger, or its comparison with the manuscript did not run to its end, in which case the skill also tells the author which one; or one ledger names the manuscript and the request names another directory. When the request names the directory of the outline files, every listed `_meta.json` was read as one ledger and compared, and no ledger names the manuscript or there is no manuscript yet, the request is the author's answer and the skill uses that directory. Otherwise it SHALL ask the author which directory to use. Outline files elsewhere in the outermost repository are then offered, not taken, because they can belong to another manuscript; when there is nothing to offer, the skill proposes a directory `propositions` beside the manuscript, where a ledger is put by convention. When the command that lists the ledgers fails, the skill stops. Adding, changing or removing the outline files SHALL NOT change the ledger, its metadata, the structure sidecars or the verification records. The ledger's schema version does not cover the outline files, and neither does the rule that keeps the ledger in step with the manuscript (`rules/manuscript-jsonl-sync.md` of this plugin): a change to the manuscript obliges no change to the outline files.

A section record, a paragraph record, a point and a locator are allowed to carry keys that this capability does not define. An approval record SHALL carry no key other than the four this capability defines for it.

No string in a section record or a paragraph record, the name of a key included, SHALL contain a control character (U+0000 to U+001F), a line break included. Where the text has a line break, the string has a space.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

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

- **WHEN** no ledger in the outermost repository names this manuscript, that repository holds outline files in a directory that has no ledger, and the author asks for an outline of this manuscript
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

- **WHEN** the manuscript's repository is checked out as a submodule `paper/manuscript` of the repository, and the only ledger that names the manuscript sits inside the submodule with `source.file` `paper/manuscript/main.tex`, a path from the outermost repository's root
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

- **WHEN** one ledger names the manuscript and another `_meta.json` in the outermost repository holds two JSON values
- **THEN** the skill tells the author which `_meta.json` could not be read as one ledger and asks which directory to use

#### Scenario: The request names another directory than the ledger's

- **WHEN** exactly one ledger names the manuscript and the author's request names a different directory for the outline
- **THEN** the skill says where that ledger is and asks which of the two directories to use

#### Scenario: A manuscript that is a symbolic link

- **WHEN** the path given as the manuscript's main file is a symbolic link to a file outside the repository
- **THEN** the skill stops, says why, and does not read the file

#### Scenario: A manuscript three submodules deep

- **WHEN** the manuscript's repository is checked out as a submodule of a submodule of a submodule of another repository, and the directory of the outline files is in the outermost one
- **THEN** the repository is that outermost one, and the skill does not stop for the number of levels

#### Scenario: The outline in the article's repository

- **WHEN** the manuscript's repository is a submodule of an article repository, the article repository is a submodule of an outer repository, and the directory of the outline files is in the article repository
- **THEN** the repository is the article repository, every `file` of a locator is written from its root, and the same locators resolve in a checkout of the article repository on its own

#### Scenario: A draft whose outline is in a repository beside the manuscript's directory

- **WHEN** there is no manuscript yet, the author says it will be in a submodule `paper`, and the directory of the outline files is in another submodule `ledgers`
- **THEN** the skill stops and asks for a directory of a repository that holds `paper`

#### Scenario: The outline directory changes to another repository

- **WHEN** the root was set for an outline directory in the outermost repository, and a later command is given an outline directory in a submodule of it
- **THEN** that command stops until the root is set for the new directory

#### Scenario: An outline directory that is refused does not change the root

- **WHEN** the directory given as the outline directory is a file, is inside a `.git` directory, or holds an outline file that is a symbolic link
- **THEN** the skill stops and the root stays as it was

#### Scenario: An outline directory in a submodule that is not checked out

- **WHEN** the outline directory is in the directory of a submodule that was not checked out
- **THEN** the skill stops and asks the author to check the submodule out or to name another directory

#### Scenario: An outline written from the outermost repository

- **WHEN** the root is the article repository, the outline files exist, and their locators give every path from the outer repository, as `article/manuscript/main.tex`
- **THEN** the check reports each locator as not resolving, the skill says that an outline written before this rule names its files from the outermost repository, and it changes no record itself

#### Scenario: A session that resumes without setting the root

- **WHEN** the outline directory is in a repository below the outermost one, and a new session runs the first command again and then a command that reads the outline, without setting the root to the outline directory's repository
- **THEN** that command stops

#### Scenario: The outline in a repository that does not hold the manuscript

- **WHEN** the directory of the outline files is in a submodule that holds only ledgers, beside the submodule that holds the manuscript
- **THEN** the skill stops, says that the outline goes in a repository that holds the manuscript, and asks for another directory

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

- **WHEN** the only `_meta.json` in the outermost repository holds `{"source":{"file":"main.tex"},"extra":01}`
- **THEN** the skill does not read it as one ledger, tells the author which `_meta.json` could not be read, and asks where the outline files go


<!-- @trace
source: idd-91-fix3
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
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


<!-- @trace
source: idd-92-per-article
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
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

An outline is one article. When a manuscript is cut into several articles, each article SHALL have its own outline directory. A reference to another outline is an object with `outline`, the path of that outline's directory from the repository's root, and `id`, the `id` of a paragraph record or of a point in its paragraph file; it has no `file`. An object with `outline` is always such a reference and never a locator, however it is written. The other outline SHALL be in the same git repository, whose root directory counts and whose submodules and repositories of its own do not, and SHALL NOT be this outline. The skill SHALL confirm that the directory is in the repository and outside `.git`, that its paragraph file is a regular file that is not a symbolic link and is JSON, and that the `id` is in it; a reference that fails one of these does not resolve and is reported, with each record that names it, as a finding of the sixth kind of the premise check; so is a `uses` that is not a list, and an entry of it that is neither an id nor a reference. Derive, draft and revise SHALL go on only when no such finding is left. A record with `moved_to` SHALL NOT be deleted, whether or not it has `from` or `replaces`; when the author takes it back, `dropped` and `moved_to` are removed together. At approval, `moved_to`, `part` and a reference's directory and `id` are shown as text taken from a record, and each reference is said to have resolved, not resolved, or not been checked. Nothing else is checked: the skill does not read what the other record says, whether it carries `dropped`, or whether the other article comes first, and the premise check does not judge a point against it. A point whose `basis` holds such a reference has a `basis`. A reference to another outline is not a locator and is not resolved as one.

#### Scenario: A point that rests on a result of the first paper

- **WHEN** a point of the second article's outline has in its `basis` `{"outline": "paper-a/propositions", "id": "p-12.1"}`, and the paragraph file in that directory has a point with that `id`
- **THEN** the reference resolves, and the premise check reports nothing about it

#### Scenario: An outline in the repository's root directory

- **WHEN** this outline is in `paper-b/propositions`, the other outline's files are in the root directory of the repository, and a reference names the outline `.`
- **THEN** the reference resolves when the `id` is there

#### Scenario: Seven references that do not resolve

- **WHEN** references name an `id` that is not in the other outline, a directory outside the repository, a directory inside `.git`, a directory with no paragraph file, a directory in a repository of its own under the root, this outline's own directory, and an object with `outline` and no `id`
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


<!-- @trace
source: idd-92-fix1
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: A locator names a passage by a label or by its opening words

A locator SHALL be an object with these keys.

| Key | Required | Value |
| --- | --- | --- |
| `file` | yes | The path of a file inside the repository, relative to its root, not inside a `.git` directory in any letter case, and not ignored by git |
| `label` | one of `label` and `starts` | A LaTeX label whose text `\label{…}` occurs exactly once in that file. It names the section or the environment the label is attached to |
| `starts` | one of `label` and `starts` | The opening words of the passage, copied from the file, enough of them to occur exactly once in it |
| `lines` | no | A list of two line numbers, the first and the last line of the passage |
| `commit` | when `lines` is present | The commit at which those line numbers hold |

A locator SHALL carry `label`, `starts` or both. `lines` SHALL NOT appear without `commit`. When `label` and `starts` are both present and name different passages, `label` decides; both are counted, and each SHALL occur exactly once. The skill does not check the values of `lines` and `commit`.

Occurrences of `starts` are counted in the text of the file, not in its lines: words that occur twice on one line occur twice, and two occurrences that overlap count as two. In the comparison every run of spaces, tabs and line breaks, in the file and in `starts`, counts as one space, so the opening words can go on past the end of a line. White space at either end of `starts` is ignored.

The text of a label, `\label{` followed by the value of `label` and `}`, is counted in the text of the file the way `starts` is, every run of spaces, tabs and line breaks in the file and in `label` counting as one space: an occurrence in a LaTeX comment counts too, and a label written with a space between `\label` and its brace is not found.

A label inside a passage does not name the passage: a paragraph of prose that contains a labelled equation is named by `starts`. A passage that has no label of its own and whose whole text occurs a second time in the file, as another passage that reads the same or inside a longer one, cannot be named: this capability has no locator for it.

The file a locator names is allowed to be outside the manuscript, such as a note in the same repository. It SHALL be a file git lists: one git tracks, or one git does not track and does not ignore. Two repositories are asked. The first is the one that holds the file, asked in the directory of the file: a file inside a submodule, or inside a git repository of its own under the root, is judged by the rules of that repository. The second is the repository, asked at its root whether it ignores the path: when it does, the file SHALL NOT be a locator's file whatever the first said, so a repository of its own inside a directory that the repository ignores does not make its files readable. When the repository gives no answer for the path, as it gives none for a file inside a submodule, the answer of the first stands; any error of that second question counts as no answer. A repository between the two is not asked. A file git ignores, or one that the repository holding it gives no answer for, SHALL NOT be a locator's file: it is not read, and an object naming it is not a locator. It SHALL NOT be outside the repository: an object whose `file` leads outside it, by a leading `/`, by `..` or through a symbolic link, is not a locator; what counts is where the path leads, so a path whose `..` lead out and back into the repository is taken. A file inside a `.git` directory, in any letter case, or the `.git` file of a submodule, SHALL NOT be a locator's file either. The value of `file` SHALL NOT hold a character from U+007F to U+009F or one that breaks a line or turns the direction of text (U+2028 to U+202E, U+2066 to U+2069); an object whose `file` holds one is not a locator, and the skill does not print that name as it is.

`from`, `replaces` and `basis` SHALL be lists of one or more locators. A `from`, a `replaces` or a `basis` that is not such a list, an empty list included, names no passage, and what it holds SHALL NOT be read as locators. The members of a list are read one by one: a member that is not a locator is reported, and the other members are still resolved. The locators of `replaces` are resolved like those of `from` and `basis`.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

#### Scenario: Seven objects read as locators

- **WHEN** these seven objects are read as locators

  | Object | Is a locator |
  | --- | --- |
  | `{"file": "manuscript/main.tex", "label": "thm:main"}` | yes |
  | `{"file": "notes/proof-sketch.md", "starts": "The bound follows from"}` | yes |
  | `{"file": "manuscript/main.tex", "lines": [120, 131], "commit": "3f2c1ab"}` | no: neither `label` nor `starts` |
  | `{"file": "manuscript/main.tex", "label": "sec:intro", "lines": [10, 42]}` | no: `lines` without `commit` |
  | `{"file": "../other-paper/main.tex", "label": "thm:main"}` | no: the file is outside the repository |
  | `{"file": "/etc/hosts", "starts": "localhost"}` | no: the file is outside the repository |
  | `{"file": ".git/HEAD", "starts": "ref"}` | no: the file is inside a `.git` directory |

- **THEN** the first two are locators and the last five are not, for the reasons in the table

#### Scenario: A locator that names a file git ignores

- **WHEN** the repository's `.gitignore` lists `*.env`, and an object in `from` has the `file` `secret.env`, which exists and is not tracked
- **THEN** the object is not a locator, and the file is not read

#### Scenario: A file git does not track yet

- **WHEN** an object in `basis` names a note that was written today, which git neither tracks nor ignores, by opening words that occur once in it
- **THEN** the object is a locator like any other

#### Scenario: A repository of its own inside an ignored directory

- **WHEN** the repository ignores the directory `private`, that directory holds a git repository of its own which tracks `notes/creds.tex`, and an object in `from` has the `file` `private/notes/creds.tex`
- **THEN** the object is not a locator, and the file is not read

#### Scenario: A file inside a submodule

- **WHEN** an object in `from` names a file that a submodule of the repository tracks
- **THEN** the object is a locator: the repository gives no answer for a path inside a submodule, and the answer of the submodule stands

#### Scenario: A locator's file written in another letter case

- **WHEN** the file system ignores letter case, the disk has `paper/Main.tex`, git tracks it, and an object in `basis` has the `file` `paper/main.tex` and opening words that occur once in that file
- **THEN** the locator resolves, and the file is read by the name the disk has

#### Scenario: Two proofs that open alike

- **WHEN** a file has two proofs, each opening with a line that holds only the command that begins a proof, and the second goes on, on its next line, with the words "Let y be"
- **THEN** a `starts` made of that command, one space and "Let y be" names the second proof, because with the line break counted as one space those words occur exactly once in the file

#### Scenario: A label that also occurs in a comment

- **WHEN** a file holds the text `\label{thm:x}` once in a theorem and once more in a LaTeX comment
- **THEN** a locator whose `label` is `thm:x` does not meet this requirement, because the text of the label occurs twice

#### Scenario: Words that occur twice on one line

- **WHEN** the words "It repeats." occur twice on one line of the file and nowhere else
- **THEN** a locator whose `starts` is "It repeats." does not meet this requirement


<!-- @trace
source: idd-80-fix5
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: An approval record stores what the author approved

Each line of `outline-approvals.jsonl` SHALL be an approval record with these keys and no others.

| Key | Required | Value |
| --- | --- | --- |
| `approved_at` | yes | The time of the approval, with its offset from UTC, such as `2026-11-13T16:30:00+08:00` |
| `statement` | yes | Words the author typed that state the approval, copied character for character from the author's message |
| `sections` | yes | A list of one or more entries |
| `whole` | no | `true` when `sections` has an entry for every section record of the section file as it was, in file order |

An entry of `sections` SHALL be an object with two keys: `section`, a copy of a section record as it was when the author approved, and `paragraphs`, copies of all the paragraph records naming that section as they were, in file order, those that carry `dropped` included.

No executable check: this change adds no test target; the examples and tests of this requirement are deferred to issue 78, which follows the Swift package (issue 46).

#### Scenario: An approval of one section

- **WHEN** the author approves the section `s-model`, which has four paragraph records, one of them carrying `dropped`
- **THEN** the approval record has one entry in `sections`, whose `section` is a copy of the record `s-model` and whose `paragraphs` holds copies of all four paragraph records in file order, and the record has no `whole`


<!-- @trace
source: idd-75-fix1
updated: 2026-11-15
code:
  - propositions-projects.code-workspace
-->

---
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


<!-- @trace
source: idd-80-fix4
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
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

- A section that has no approved copy is shown in full: its `heading` and `says`, every paragraph record naming it with its points and its `note`, and every record that carries `dropped` together with the reason. In both ways of showing a section, in full or by its differences, and wherever else a paragraph record is shown for approval (the approved copy of a changed record, the records of a section removed since its approval), a record that carries `edits` SHALL be shown with them and said to be a block moved with changes, not unchanged; a record that carries `replaces` SHALL be shown with the passages it takes the place of. These are shown as labelled quotations of the record, not as words of the skill, and text taken from a record is shown inside a fenced code block whose fence is longer than any run of backticks in the text, so that nothing in it closes the block or is rendered as a link, as markup or as a heading, and a control character in it is written as its code point.
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


<!-- @trace
source: idd-80-fix6
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: A premise check runs before an outline is shown for approval

Each time before the approve action shows sections for approval, the skill SHALL have those sections checked. The check SHALL begin with the checks the skill runs after a write, on the section file and the paragraph file it examines: a file that was changed by hand can hold a line that is not a record. When one of them fails, the skill reports the file and the lines, counts nothing and starts no agent. A paragraph file with no record is not reported as passing and does not stop the check: an outline can have sections and no paragraph record yet, so the skill says that the file is empty and goes on. The check reports findings of these six kinds and no others.

1. **Not a sentence**: a `says` or the `text` of a point that is a heading, a label or a fragment.
2. **Not supported by its source**: a point whose record has `from`, or which has `basis`, and which the passages named do not state, or which they contradict. The passages named in `replaces` are not a source and are not read as support. For a record that carries `carry`, a difference between the point and the passage its `from` names is not a finding when the record's `edits` lists it, or when it only concerns where a cross-reference points or what number something has; this does not excuse a difference from a passage named in `basis`. The check looks up the passages of `from` and `basis` only and reports nothing about the passages of `replaces`. What a finding of any kind takes from the agent's report or from a record is shown inside a fenced code block, like record text at approval, with control characters written as code points.
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


<!-- @trace
source: idd-80-fix6
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Derive and draft build an outline without inventing content

The derive action SHALL read a finished manuscript and produce one section record for each of its sections and one paragraph record for each of its paragraphs and blocks. It reads the manuscript's main file by its real path, after confirming again that the file meets the conditions this capability sets for it. It SHALL follow the files that the manuscript includes, whose names end in `.tex` in any letter case, only when they are regular files inside the repository that git lists (tracked, or not tracked and not ignored) and whose path holds no line break and, below the root, no other character that a locator's `file` is not allowed to hold. Any other included file is named to the author and not read: one outside the repository, a symbolic link, a file reached through a directory that is a symbolic link, a file inside a `.git` directory in any letter case, a file git ignores, a file git gives no answer for (one in or under a directory laid out like a git repository), a file whose path holds such a character, or a missing file. An include whose name does not end in `.tex` in any letter case names the file with `.tex` added (`\input{fig.tikz}` names `fig.tikz.tex`): that file is read when it exists and is a file the skill reads, and is a missing file when it does not exist, the usual case for a figure, a table or a style file kept under its own name. A figure or a table that comes from an included file that was not read is still the one record that carries `carry` for the figure or the table, named in the file that includes it. Any other included file that was not read SHALL get nothing in the outline: no record, no locator, no point and no `note`; the action names it to the author, and the outline does not show the gap (whether it should is open, issue 51). An include command `\input{x}` or `\include{x}` names the file `x` when `x` ends in `.tex` in any letter case, and `x.tex` otherwise, taken from the directory of the main file; it is read only when it is a file the skill reads, and the skill SHALL NOT look for it anywhere else. On a file system that ignores letter case the same file in another letter case is the same file. A command inside a LaTeX comment includes nothing. When the files the action read hold no paragraph and no block at all, so that the paragraph file would be empty, the action SHALL stop, say which included files were not read, show no outline and write nothing to the repository; it SHALL stop before it asks the author for any section's `says`. A paragraph counts when the action read any of its text; a block (a theorem-like statement, a proof, a figure, a table or a displayed formula) counts when the action read the environment or the delimiters that hold it, even when its content is in a file that was not read. When the action stops for this reason and the manuscript has headings and nothing under them, it also says that draft builds an outline from headings. When the action does not stop for this reason and all the text of a section is in included files that were not read, the action SHALL ask the author for the section's `says` and SHALL stop when the author gives none; when such a section ends with no paragraph record, of its own or of a section under it, the action tells the author that the premise check reports it for that reason. An abstract that has no heading of its own gets the `heading` "Abstract". Prose that comes before the first heading and is not the abstract gets one section record, whose `heading` is the title of the article; the skill tells the author that this section has no heading of its own in the manuscript, and asks what to put in `heading` when the manuscript gives no title. A theorem-like statement, a proof, a figure, a table, and a displayed formula or derivation that has a blank line before it and a blank line after it each become one record that carries `carry`, whose point is a complete sentence stating what the block states or shows. Any other displayed formula or derivation belongs to a paragraph's record: with no blank line on either side, the record of the paragraph it stands in; with a blank line on one side only, the record of the paragraph on the other side. Every paragraph record the action produces SHALL have `from` naming the passage it comes from, and every point SHALL state only what that passage states. A theorem-like statement, a figure or a table is named by its own label; the label of a section names the whole section and SHALL NOT be used for a record. The action writes no `lines` and no `commit`, and the `file` of every locator it writes is the name of the file from the root, as the first requirement defines it. Before it shows the outline, the action SHALL confirm for every locator it wrote that the locator resolves: the text of its `label` and its `starts`, whichever it has, each occur exactly once in the file it names. When a passage that has no label of its own has a text that, to its end, occurs a second time in the same file, as another passage that reads the same or inside a longer one, no locator names it: the action SHALL stop, tell the author which passages they are, show no outline and write nothing to the repository, and SHALL NOT take opening words from the passage that follows. It stops the same way when a file it read is not accepted as a locator's file. A manuscript that has paragraphs SHALL NOT give an empty paragraph file.

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

- **WHEN** the body of the main file holds only `\section{Introduction}` followed by `\input{sections/intro}` and `\section{Method}` followed by `\input{sections/method}`, and `sections/` is ignored by git
- **THEN** the derive action stops, names the two files as not read, shows no outline and writes nothing to the repository

#### Scenario: A file name with a dot

- **WHEN** the manuscript writes `\input{ch1.final}` and `ch1.final.tex` is a file git tracks in the directory of the main file
- **THEN** the derive action reads `ch1.final.tex`

#### Scenario: An include command that names its extension in capitals

- **WHEN** the manuscript writes `\input{Intro.TEX}` and `Intro.TEX` is a file git tracks in the directory of the main file
- **THEN** the derive action reads `Intro.TEX`

#### Scenario: Every section is in files that were not read and the author is not asked

- **WHEN** the text of every section of the manuscript is in included files that git ignores, and the files the action read hold no paragraph and no block
- **THEN** the derive action stops without asking the author for any section's `says`

#### Scenario: An abstract in the main file keeps derive going

- **WHEN** the main file holds an abstract whose one paragraph is written out in the main file, and the text of every section is in included files that git ignores
- **THEN** the derive action does not stop for an empty paragraph file, and asks the author for the `says` of each section

#### Scenario: An abstract in an included file that was read keeps derive going

- **WHEN** the main file holds `\input{abstract}` before the first heading, `abstract.tex` is a file git tracks that holds one paragraph, and the text of every section is in included files that git ignores
- **THEN** the derive action does not stop for an empty paragraph file, and asks the author for the `says` of each section

#### Scenario: An abstract whose text was not read does not keep derive going

- **WHEN** the main file holds `\begin{abstract}\input{gen/abstract}\end{abstract}`, the text of every section is in included files under `gen/`, `gen/` is ignored by git, and the files the action read hold no paragraph and no block
- **THEN** the derive action stops without asking the author for any section's `says`

#### Scenario: An include without the extension names the file with it

- **WHEN** the main file holds `\input{fig.tikz}` and the repository tracks `fig.tikz.tex` beside it
- **THEN** the derive action reads `fig.tikz.tex` and does not name it to the author as a missing file

#### Scenario: One section is a bare heading and the other is in a file that was not read

- **WHEN** one section of the manuscript is a heading with nothing under it, the text of the other is all in an included file that git ignores, and the files the action read hold no paragraph and no block
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


<!-- @trace
source: idd-87-fix4
updated: 2026-11-19
code:
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/ReadingOrder.swiftconstvalues
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/pre-receive.sample
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsedValues.d
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/sys_types-3J4ZFA06I5V1P.pcm
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/XPC-T0ZXCAST7PE3.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Tree.o
  - .build/out/CompilationCache.noindex/generic/v1.1/index.v1.shared
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpGenerator.swiftconstvalues
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/03cd2f611fa53e83f3ed19a9ff7c5c8d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParserError.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandConfiguration.swiftconstvalues
  - .build/out/v5/records/3C/task_policy.h-3OV04BTXG853C
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Version.o
  - .build/out/v5/records/8N/SCSICommandDefinitions.h-38HI15DXQIP8N
  - .build/out/v5/records/K6/__stddef_wchar_t.h-3MNV84OUMYLK6
  - .build/out/SDKExplicitPrecompiledModules/sys_types-666LKS3HU1SBDV35HJT80EUGI.pcm
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_Builtin_limits-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/KJ/inet.h-11F05ZXC5T2KJ
  - .build/out/v5/records/NR/NSGarbageCollector.h-3HX6SD0W6OANR
  - .build/out/v5/records/BV/SecTrustedApplication.h-2T0ZNA8MMUQBV
  - .build/out/v5/units/_Builtin_float-8VRJETFKL8GBLX34WLQBKRTXU.pcm-2IQC4CA1PVZRV
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/69ecbe680c5b8a5f14502abeac2a5bf1
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/Dispatch-R76HXUP80TVL.pcm
  - .build/out/v5/records/F2/mach_voucher.h-3FX41Y9XG4EF2
  - .build/out/v5/records/5C/Script.h-390SFCO7CZ35C
  - .build/out/v5/units/ArgumentSet.o-BFKJ6YLDAS7E
  - .build/out/v5/records/RA/oidsbase.h-2Y5IWQ000FARA
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/OptionGroup.swiftconstvalues
  - .build/out/v5/records/6R/IOPMLib.h-NT6IIRE4GN6R
  - .build/out/v5/records/5B/wordexp.h-GWC8E4HYTG5B
  - .build/out/v5/records/DO/conf.h-317NT1SEZQEDO
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/CoreServices-39NCTJOEW7PQ2.pcm
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/ReadingOrder.dia
  - .build/out/v5/records/DM/clock.h-HFWTDB6NDVDM
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo-Swift.h
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/DiskArbitration-3LBJF5I58QD8.pcm
  - .build/out/v5/records/14/FoundationErrors.h-11V4MY3XAR114
  - .build/out/v5/records/81/NSFilePresenter.h-ZHEO6SFX2R81
  - .build/out/v5/records/DI/NSStream.h-11039A2NCF8DI
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/Dispatch-R76HXUP80TVL.pcm
  - .build/out/v5/records/ME/CompletionKind.swift-1LTFQ5F82DBME
  - .build/out/v5/records/SJ/port_obj.h-2WCZO5EPZB5SJ
  - .build/out/v5/records/RC/NSValue.h-3GSSKK8OMZQRC
  - .build/out/SDKExplicitPrecompiledModules/_Builtin_stdarg-DDTW7ZG77P0BLZ150JPHZOJRV.pcm
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/227b782cb6eaf03396d3c6fe8b65c221
  - .build/out/v5/records/6M/_ct_rune_t.h-31XIOF8OH9D6M
  - .build/out/v5/records/H5/CiteOrderTests.swift-7LE9MI8L6YH5
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/string_h-47SZ9A199RUD.pcm
  - .build/out/v5/records/3W/NSClassDescription.h-2U84N8T9B3W3W
  - .build/out/v5/records/0I/dispatch_swift_shims.h-23CZJ5IJFD30I
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit.LinkFileList
  - .build/out/v5/records/OF/AEDataModel.h-2C9CA4B5YROOF
  - .build/out/v5/records/Y1/posix_sem.h-3O9GAOBIRL9Y1
  - .build/out/v5/records/BG/processor_info.h-2LETAC7HAHNBG
  - .build/out/v5/records/MQ/user.h-1DH14OMA2G5MQ
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/4c4489b2d9c6962f0e11f113fabeda8d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser.swiftdoc
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/ObjectiveC-1G8H182PQX3QE.pcm
  - .build/out/v5/units/CiteOrderTests.o-3KUEXLASQNJM2
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/OptionGroup.o
  - .build/out/v5/records/66/NSBackgroundActivityScheduler.h-TO45HB5OKE66
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/description.msgpack
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_Builtin_float-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/P0/message.h-18EMHMAU0D1P0
  - .build/out/v5/records/U8/kern_event.h-1XV5DB78TNWU8
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/build-request.json
  - .build/out/v5/records/NE/msgbuf.h-2IF781P25YANE
  - .build/out/v5/records/CX/_stdio.h-3BQ2PABJXY3CX
  - .build/out/ModuleCache.noindex/V625515Z2F2L/_SwiftConcurrencyShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/6K/NSURLCredential.h-2XEZB5AUDYJ6K
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/b81a5715c5227ba32114342ae999a766
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/CFNetwork-1PNPO1ORVQZLS.pcm
  - .build/out/v5/records/FK/CFMessagePort.h-2QTSARUA6LVFK
  - .build/out/v5/records/I2/ipsec.h-18B6SOZ67BEI2
  - .build/out/v5/records/73/activity.h-2QPWNFG7LWS73
  - .build/out/SDKExplicitPrecompiledModules/ObjectiveC-C6G0RBBYZQZRXN0H3L0G84K7C.pcm
  - .build/out/v5/records/BL/PositionalArgumentsValidator.swift-3IHUZ93N3OXBL
  - .build/out/v5/records/8E/sockio.h-2MN1EG2TM2Y8E
  - .build/out/v5/records/1W/_OSByteOrder.h-22HWOXDCHH81W
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit.abi.json
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/9d470f0fe97cb62b8315c162b2f900cf
  - .build/out/v5/records/0R/CFTimeZone.h-248L8N0764U0R
  - .build/out/v5/records/3F/_u_int16_t.h-2DD3SJLX8QF3F
  - .build/out/v5/units/sys_types-666LKS3HU1SBDV35HJT80EUGI.pcm-F8722DEV14MA
  - .build/out/v5/records/N5/OSReturn.h-1QNX56UXB6MN5
  - .build/repositories/swift-argument-parser-54a11a8d/config
  - .build/out/v5/records/2Z/availability.h-1K10PYICPT12Z
  - .build/out/v5/records/NP/thread_state.h-RCK64T92QVNP
  - .build/out/v5/records/ZM/NSURL.h-1ROC0YYMYOSZM
  - .build/out/v5/records/2J/vm_statistics.h-1BAYW4ERSDP2J
  - .build/out/v5/records/KJ/resource.h-34OLESOFV4FKJ
  - .build/out/v5/records/EG/main.swift-3OYK6TSNDHUEG
  - .build/out/v5/records/4D/host_info.h-2GCQ0OMCGI24D
  - .build/out/v5/records/UF/_wchar_t.h-2D7TWI0JBA9UF
  - .build/out/v5/records/63/NSKeyValueCoding.h-15CVUS4ELVS63
  - .build/out/v5/units/SplitArguments.o-16I0LUF0L6JRM
  - .build/out/v5/records/Y1/CFNotificationCenter.h-388RU7NYVHXY1
  - .build/out/v5/records/HM/in6.h-27XK0PQQKQYHM
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Option.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NonsenseFlagsValidator.d
  - .build/out/v5/records/2E/in.h-3PCI9BX3JTD2E
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDiscussion.swiftconstvalues
  - .build/out/v5/records/1B/CFNumber.h-2GI3TR0JZGG1B
  - .build/out/v5/records/86/if_media.h-1P19KQF3U7086
  - .build/out/v5/records/9B/log.h-1PATALJV83Y9B
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/f26bec36a172fe818fae42bf57d98d44
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/6f60e95553fce434159e54d0b9d59770
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NonsenseFlagsValidator.swiftconstvalues
  - .build/out/v5/records/CP/AvailabilityVersions.h-ISVADLYSVSCP
  - .build/out/v5/records/VN/emmspi.h-1LHPI34FDSWVN
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/ptrcheck-2OQWMRBVRD4OJ.pcm
  - .build/repositories/swift-argument-parser-54a11a8d/objects/pack/pack-8e9c7dd1be2a2ad10f5b481e816a8504f35ddca9.idx
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CollectionExtensions.dia
  - .build/out/v5/units/CoreFoundation-6F2J2PC11ZNLNE00BYSN50Y9S.pcm-3H31LESC7A0OM
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-10
  - .build/out/v5/records/GT/IOATAStorageDefines.h-1PZ35E52MYXGT
  - .build/out/v5/records/CN/LedgerReader.swift-1BAJJJ33GDRCN
  - .build/out/v5/records/HJ/AppleEvents.h-1P18GY5FVJ3HJ
  - .build/out/v5/records/8P/NSEnergyFormatter.h-3PLK62MZBBU8P
  - .build/out/v5/records/K6/MachineExceptions.h-1V7C1Q7NLKGK6
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/os_object-2MV8OP7R98AN8.pcm
  - .build/out/v5/records/9S/audit_errno.h-2KEF3J00QY89S
  - .build/out/v5/records/PG/vm.h-1GG2706LNZOPG
  - .build/out/v5/records/OU/LSInfoDeprecated.h-2NIWOUIT1HROU
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableCommand.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit-primary-emit-module.d
  - .build/out/v5/records/WI/types.h-EDPX0HDHYBWI
  - .build/out/v5/records/WR/ethernet.h-M6FNGIMNTKWR
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UniqueNamesValidator.d
  - .build/out/v5/records/03/workgroup_interval.h-2B0SX7JOMGL03
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/target-graph.txt
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/39786d311dc44b904edc6f35d96e5c8a
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandGroup.swiftdeps
  - .build/out/v5/records/7E/SecProtocolTypes.h-2847XVHDRJI7E
  - .build/out/v5/records/UG/Availability.h-1I3UYFLVKXHUG
  - .build/out/CompilationCache.noindex/generic/v1.1/actions.v1.shared
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Tree.swiftdeps
  - .build/out/v5/records/QQ/KextManager.h-3KKQDSHMMRSQQ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Mutex.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/EnumerableFlag.swiftconstvalues
  - .build/out/v5/records/OT/CSCommon.h-CMD81G5ESHOT
  - .build/out/v5/records/HM/NSHTTPCookieStorage.h-1D3FEY534DVHM
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncParsableCommand.swiftdeps
  - .build/out/v5/records/T2/IOCDMediaBSDClient.h-2NTTMZJSF1IT2
  - .build/out/Products/Debug/libPropositionsKit.a
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CollectionExtensions.swiftdeps
  - .build/out/v5/records/KH/AEMach.h-21UXMM301ILKH
  - .build/out/v5/records/W2/IOSerialKeys.h-1TN8H410O6ZW2
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/fb4985d8c4b099a564da7b3f99d8a7de
  - .build/out/v5/records/3Q/_time.h-1X097TP7Y3I3Q
  - .build/out/v5/records/3J/reloc.h-RRP847M61Z3J
  - .build/out/v5/records/0S/SecBase.h-33R7LNU1AZ60S
  - .build/out/v5/records/LT/NSUserScriptTask.h-38SQX1SUBWKLT
  - .build/out/v5/records/8R/param.h-O9K52O68YF8R
  - .build/out/v5/records/6V/trace.h-BH2W2KQ2Z76V
  - .build/out/v5/records/NM/_timespec.h-27MEHSAP8CNNM
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Argument.swiftdeps
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/Support.d
  - .build/out/v5/records/R9/uuid.h-NGGNDAOU1UR9
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/StringExtensions.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-12
  - .build/out/v5/records/1N/NSUserActivity.h-17Q2LUME5631N
  - .build/out/v5/records/G8/fsgetpath.h-15Y9F097OMFG8
  - .build/out/v5/records/WW/NSLinguisticTagger.h-PL5G5S7JUHWW
  - .build/out/v5/records/X5/audit_kevents.h-1TPHN7I2SSX5
  - .build/out/v5/records/IA/NSFileHandle.h-BKLKOUDW8ZIA
  - .build/out/v5/records/X8/CiteOrderTests.swift-2VTOFA6MCQX8
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/StringExtensions.swiftconstvalues
  - .build/out/v5/records/F2/_structs.h-3FSW98T3MEBF2
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/CiteOrderTests.swiftdeps
  - .build/out/v5/records/9I/processor_info.h-3EIHFSB1K7P9I
  - .build/out/v5/records/JW/hfs_mount.h-3D2I40O494ZJW
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Errors.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-16
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Name.d
  - .build/out/v5/records/AJ/NSDictionary.h-14GF9AFBC74AJ
  - .build/out/v5/records/B2/_stdio.h-3KSUAY6F95VB2
  - .build/out/v5/records/T4/utmpx.h-3TOXZBRVRWHT4
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/PositionalArgumentsValidator.dia
  - .build/out/v5/records/3F/_u_short.h-1NO7YNEHO793F
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpCommand.dia
  - .build/out/v5/records/F9/menu.h-2LAIBWU4H0JF9
  - .build/out/v5/units/os_object-1E8JNT1TGYQ0K6UE4L00KSJ5J.pcm-3NZXWG18YZP2P
  - .build/out/v5/records/5J/dyld_kernel.h-3I2REXDMCW05J
  - .build/out/v5/records/HP/ncurses_dll.h-9VC29QYZSPHP
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/69ecbe680c5b8a5f14502abeac2a5bf1
  - .build/out/v5/records/8V/_nl_item.h-FETDID176N8V
  - .build/repositories/swift-argument-parser-54a11a8d/packed-refs
  - .build/out/v5/records/4V/IOHIDDevicePlugIn.h-ZW95TWHABY4V
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/401fad213a413d1b687a47f6e660d656
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/MachO-20RPYVQSX341K.pcm
  - .build/out/v5/records/5Q/AvailabilityInternal.h-31LUEL5CFJT5Q
  - .build/out/v5/records/GL/CFBase.h-IKFYA3WUWDGL
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDecoder.swiftconstvalues
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_Builtin_stdarg-2OQWMRBVRD4OJ.pcm
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/build-request.json
  - .build/out/v5/records/63/lctx.h-TTO4HW6FYK63
  - .build/out/v5/units/ZshCompletionsGenerator.o-1GZEPFMMTU89A
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/6a89d4677c25fa550ccc8d2b64f1f3b2
  - .build/out/v5/records/10/CFLocale.h-34KHAYNH73H10
  - .build/out/v5/records/61/NSExtensionRequestHandling.h-2F77VUSC5ES61
  - .build/out/v5/records/QV/LedgerReader.swift-3TEB7WEN9QWQV
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ExpressibleByArgument.dia
  - .build/out/v5/records/2O/_fd_def.h-36OKCH21XJ12O
  - .build/plugins/cache/GenerateDoccReference-state.json
  - .build/out/v5/records/EI/Resources.h-29OY8KUNJIYEI
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-29N9054ZUALKT
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SwiftExtensions.d
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/9d470f0fe97cb62b8315c162b2f900cf
  - .build/out/v5/records/8I/cssmcspi.h-1NQ3IUPVIT08I
  - .build/out/v5/records/3Q/if_mib.h-2B7344788R53Q
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandGroup.swiftconstvalues
  - .build/out/v5/records/TJ/NSURLHandle.h-3MGIE80IRTJTJ
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_DarwinFoundation1-2YSBQADOLX02V.pcm
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/libkern-2KQ0X67RTM1JF.pcm
  - .build/out/v5/records/DO/arm64e-apple-macos.swiftinterface-3AHXI4ZG6IXDO
  - .build/out/v5/records/K5/_int32_t.h-3MR7DZZIHJ4K5
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionsGenerator.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParserError.d
  - .build/out/v5/records/VN/NSDate.h-2CJAXEQS6VLVN
  - .build/out/v5/records/XA/NSValueTransformer.h-28K0HD40L6UXA
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UniqueNamesValidator.swiftconstvalues
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SwiftExtensions.swiftdeps
  - .build/out/v5/records/2Z/MacMemory.h-1X1CL0NFKC2Z
  - .build/out/v5/records/E2/socket.h-3J1Q8RZHP1EE2
  - .build/out/v5/records/PZ/NSArchiver.h-172GBDVDQKBPZ
  - .build/out/v5/records/13/IOStorage.h-BGSPOASNMO13
  - .build/out/v5/records/3V/NSFileVersion.h-37PNIF951AM3V
  - .build/out/v5/units/ArgumentDiscussion.o-R6D0VPXLFL0A
  - .build/out/v5/records/EK/_useconds_t.h-2Z8XR3FJX83EK
  - .build/out/v5/records/29/_int8_t.h-FJCH36X8E629
  - .build/out/v5/records/PU/assert.h-3Q5UWG6FV2DPU
  - .build/out/v5/records/RU/queue.h-12WEE3NHRL3RU
  - .build/out/v5/records/6M/arm64e-apple-macos.swiftinterface-3V2X65VHK7Z6M
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncCompletionsValidator.d
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/9a9c096c4ace5cbd1414691c8d9d4c23
  - .build/out/v5/records/8V/NSProcessInfo.h-3AL8HTHRXQL8V
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/CoreFoundation-16SA8WK3L6MQN.pcm
  - .build/out/v5/records/JJ/mach_host.h-R37HT1A67XJJ
  - .build/out/v5/records/KI/cssmkrspi.h-1QT1M6ZWOZLKI
  - .build/out/v5/records/OT/_int64_t.h-1C8PBLFOABIOT
  - .build/out/v5/records/UN/NSTermOfAddress.h-31WSG1ZSHDZUN
  - .build/out/v5/records/YQ/gethostuuid.h-2PN6OXCITWTYQ
  - .build/out/v5/records/XQ/_gid_t.h-3QLFYT8GCA5XQ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpGenerator.dia
  - .build/out/v5/records/9H/netdb.h-2653GAEVR0R9H
  - .build/out/v5/records/PN/_uintmax_t.h-1AH75M817EMPN
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema_check.swiftmodule
  - .build/out/v5/records/IP/trace.h-2YBDEBED4IQIP
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputKey.swiftdeps
  - .build/out/v5/records/Z4/hfs_unistr.h-30PY041J8IKZ4
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_Builtin_stdarg-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/GI/Components.h-1WNOAS22SNPGI
  - .build/out/v5/records/HL/audit_fcntl.h-9IM2W3606THL
  - .build/out/v5/records/Q3/_wctrans_t.h-3915B7EZBIZQ3
  - .build/out/v5/records/R4/IOHIDLib.h-2EC1LQX3I7WR4
  - .build/out/v5/records/LY/processor_set.h-CAN0N3YK1YLY
  - .build/out/v5/records/8E/signal.h-2F43SEKSS9Y8E
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_Builtin_float-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/FU/NSDistributedLock.h-5LX6UOZC8RFU
  - .build/out/v5/records/QO/IOStorageProtocolCharacteristics.h-TXWW9OGDEQO
  - .build/out/v5/records/AM/kernel_types.h-1FG78GBH6B2AM
  - .build/out/v5/records/FZ/nlist.h-1B4UDTW9VPLFZ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SplitArguments.o
  - .build/out/SDKExplicitPrecompiledModules/Security-CLVDOQ1QTUNWWYBPR0FEC8K3J.pcm
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/pre-push.sample
  - .build/out/v5/records/TX/NSPropertyList.h-DJ1YBJJLJXTX
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions-dependencies-1.json
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/ObjectiveC-1G8H182PQX3QE.pcm
  - .build/out/v5/records/QI/runtime.h-2M5SN6V5I8HQI
  - .build/out/v5/records/QW/NSHFSFileTypes.h-JVBT8WF97BQW
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Foundation.swiftconstvalues
  - .build/out/v5/records/A1/IOBDMedia.h-2YUF9X8AYETA1
  - .build/out/v5/records/BL/_endian.h-3VEJOS27HZWBL
  - .build/out/v5/records/80/SecStaticCode.h-2015KPJGM0180
  - .build/out/v5/records/UV/shm.h-W71B93UE2RUV
  - .build/out/v5/units/_Builtin_stdbool-1BZW2YIRGDSI04EXV7CLLG91F.pcm-251ZRS4MTOHW1
  - .build/out/v5/records/ZC/mig.h-3XDIEW4W8KZC
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Flag.swiftconstvalues
  - .build/out/v5/records/BG/IOBSD.h-1CLW1S1VTWBBG
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_DarwinFoundation3-2NSGASPTSNBVQ.pcm
  - .build/debug
  - .build/out/v5/records/HC/event_status_driver.h-1XWQBHLINH0HC
  - .build/out/v5/records/OE/_static_assert.h-3FMFFJN8XD2OE
  - .build/out/v5/records/H8/arm64e-apple-macos.swiftinterface-363OQONIAVTH8
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Platform.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Mutex.swiftdeps
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/CFNetwork-1PNPO1ORVQZLS.pcm
  - .build/out/v5/units/StringExtensions.o-27HQUD9HU84W4
  - .build/out/v5/units/UniqueNamesValidator.o-1K8DD2AOPG9W
  - .build/out/v5/units/Argument.o-2EMEU5YMDXZ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandParser.dia
  - .build/out/v5/records/PH/ZshCompletionsGenerator.swift-2CA38KR9DFWPH
  - .build/plugins/cache/GenerateDoccReference
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/StringExtensions.dia
  - .build/out/v5/records/5Q/_pthread_rwlockattr_t.h-35SBEHBA2U55Q
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentHelp.swiftconstvalues
  - .build/out/v5/records/C5/SequenceExtensions.swift-FI3M6DCMIJC5
  - .build/out/v5/records/X6/IOCDBlockStorageDevice.h-1GJPBRM0ZI1X6
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/main.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Location.d
  - .build/out/v5/records/4R/Multiprocessing.h-NRUTB68OIW4R
  - .build/out/v5/units/_Builtin_stddef-9DSM9QA1LA2DNTEDCYG0D36PM.pcm-3UDVK727OZUZG
  - .build/out/v5/records/IR/MacTypes.h-1SMUUQB891HIR
  - .build/out/v5/records/ZR/mach_port.h-2187URF9OG6ZR
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/9a9c096c4ace5cbd1414691c8d9d4c23
  - .build/out/v5/records/3L/gmon.h-2AQPNXGXLKO3L
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/propositions.xcent.der
  - .build/out/v5/records/RU/sysctl.h-2Q9DOXSDQDSRU
  - .build/out/v5/records/J5/NSData.h-2FD5BDWSXTBJ5
  - .build/out/v5/records/3D/_u_int.h-1CFKM8X8WHC3D
  - .build/out/v5/records/GI/x509defs.h-19VGZEXYYIVGI
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_DarwinFoundation1-2YSBQADOLX02V.pcm
  - .build/out/v5/records/TY/IOHIDEventServiceKeys.h-D6MRDYW12TY
  - .build/out/v5/records/2U/ah.h-22CI505SYDS2U
  - .build/out/v5/records/LO/NSDecimalNumber.h-3AF96416JY5LO
  - .build/out/v5/records/TG/kern_return.h-3LV7N7PVUXBTG
  - .build/out/v5/records/FK/xpc.h-23Y6JINMAEOFK
  - .build/out/v5/records/PE/NSURLDownload.h-2VCU54W0S85PE
  - .build/out/v5/records/VW/nc_tparm.h-30JCDU09O3BVW
  - .build/plugins/cache/GenerateManual
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-6Z5EOBOUPWFY
  - .build/out/v5/records/BK/TextUtils.h-3K7W5DL6PBYBK
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputOrigin.dia
  - .build/out/v5/units/Tree.o-344NDW9EFGB75
  - .build/out/v5/records/CG/NSKeyValueObserving.h-2FY2O8DYKN4CG
  - .build/out/v5/units/HelpCommand.o-2QESRY5LX1OV5
  - .build/out/v5/records/9K/Version.swift-3MK6PTNDIJ59K
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit-dependencies-1.json
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/c3818a8d6ef695529039b179b4fd9978
  - .build/out/v5/records/GW/NSHashTable.h-QGQP2RPHGDGW
  - .build/out/v5/records/VG/CommandRun.swift-17XJXMYXH9VVG
  - .build/out/v5/records/EL/IOHIDQueue.h-314O66LYEE4EL
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArgumentsValidation.dia
  - .build/out/SDKExplicitPrecompiledModules/ptrauth-API8LKCD6DQ150LSS6N3FIFVX.pcm
  - .build/out/v5/records/H4/ucred.h-34T3WQAWUBHH4
  - .build/out/v5/units/_AvailabilityInternal-3OILYF0SRAMVE7C1OBGI8F7SH.pcm-2HGZIR7D3P1J7
  - .build/out/v5/records/O8/AERegistry.h-I67BFGBFOVO8
  - .build/out/v5/records/PG/workgroup_parallel.h-3MGN7KW9RUTPG
  - .build/out/v5/records/H9/mach_param.h-SL78NQGZGVH9
  - .build/out/v5/records/4S/SecDecodeTransform.h-3FCF0IVF8MM4S
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/pre-rebase.sample
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo-primary-emit-module.d
  - .build/out/v5/records/JP/igmp_var.h-2BDL9DCQE5SJP
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/EnumerableFlag.d
  - .build/out/v5/records/YV/IONetworkStack.h-2AO5GQDXFREYV
  - .build/out/v5/records/QN/NSXMLDTD.h-3CV5ISST0QCQN
  - .build/out/SDKExplicitPrecompiledModules/_DarwinFoundation2-1L491ZSO7OJG8Y9S2UZLAG9.pcm
  - .build/out/v5/records/IJ/dlfcn.h-1S45BTJCSS9IJ
  - .build/out/v5/records/2R/vnode.h-AFN4RH1AKE2R
  - .build/out/v5/records/3K/ipcomp.h-28SOW1UB2SC3K
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/libDER-26DYHF6GC6WWA.pcm
  - .build/out/v5/records/2D/DriverSynchronization.h-XL8P2JSZB62D
  - .build/out/v5/records/LL/NSOrthography.h-23Q10X8PWUPLL
  - .build/out/v5/records/QR/IOCFURLAccess.h-LGFY1B3HIPQR
  - .build/out/v5/records/Z7/hash_info.h-P8LLEJ8AJMZ7
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArgumentsValidation.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Version.swiftdeps
  - .build/out/v5/records/5S/CMSDecoder.h-2WG5J1VB1YS5S
  - .build/out/Products/Debug/PropositionsKitTests.swiftmodule/arm64-apple-macos.swiftdoc
  - .build/out/v5/records/U9/ip_var.h-LQQ6KH1OUIU9
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDefinition.swiftdeps
  - .build/out/v5/records/XR/ioctl.h-N7DH46EM6ZXR
  - .build/out/v5/records/52/fcntl.h-PO9C2L0TUX52
  - .build/out/v5/records/IJ/__stddef_rsize_t.h-LACUAKZMXYIJ
  - .build/out/Products/Debug/ArgumentParserToolInfo.o
  - .build/out/v5/records/JP/ip_icmp.h-2J4OUTLQTBPJP
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_Builtin_stdarg-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/03/SKDocument.h-UJ5M6QHQUV03
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ToolInfo.d
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_DarwinFoundation1-2YSBQADOLX02V.pcm
  - .build/out/v5/records/13/CFDate.h-2Z3E182R7JF13
  - .build/out/v5/records/36/libc.h-3Q6E8N8P66036
  - .build/out/v5/records/EF/OSAtomicQueue.h-28N3WS6G0D0EF
  - .build/out/v5/records/1G/WSProtocolHandler.h-1GVYXZPODY61G
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArgumentsValidation.d
  - .build/out/v5/records/97/NumberFormatting.h-2T9D72LMF5W97
  - .build/out/v5/records/NJ/NSLocalizedNumberFormatRule.h-28RBEBWNSRONJ
  - .build/out/v5/records/T2/_langinfo.h-2X91Z58KCSTT2
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CommandRun.swiftconstvalues
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionKind.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandConfiguration.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArguments.o
  - .build/out/v5/records/MA/proc.h-2IQ3RIUAQQHMA
  - .build/out/v5/records/PU/NSObject.h-3QD8AIFKY0QPU
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/2a470153fc8b923cf29a9f596b547976
  - .build/out/v5/records/1M/limits.h-66THW9DJ3T1M
  - .build/out/v5/records/Q2/vm_types.h-2LKVKU7ZPO8Q2
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/EnumerableFlag.dia
  - .build/out/v5/records/O9/_u_int64_t.h-946RWGK2CSO9
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-1Z2C9QSKMK9VZ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionsGenerator.d
  - .build/out/v5/records/TN/oidsalg.h-18LSDG9F5TPTN
  - .build/out/v5/records/TQ/Folders.h-2BSJBK1BZQFTQ
  - .build/out/SDKExplicitPrecompiledModules/_SwiftConcurrencyShims-6K6W8CVATK3OHQ28Y658SJYPJ.pcm
  - .build/out/v5/records/TR/IOMapTypes.h-2QC3QJUR4WBTR
  - .build/out/v5/records/GL/NSCharacterSet.h-341HI0FJS8UGL
  - .build/out/v5/records/3I/SCSICmds_INQUIRY_Definitions.h-2M5SJAKH2BS3I
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/Foundation-24LYWIP48SHNP.pcm
  - .build/out/v5/records/M6/_pthread_once_t.h-2P5WKU6353VM6
  - .build/out/v5/records/QH/CFNetDiagnostics.h-3QAYWXNJZX0QH
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/pre-applypatch.sample
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ToolInfo.swiftdeps
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/401fad213a413d1b687a47f6e660d656
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_Builtin_stddef-2OQWMRBVRD4OJ.pcm
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions.swiftsourceinfo
  - .build/out/v5/records/7O/scope6_var.h-W20O9CBUBZ7O
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/manifest.json
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/task-store.msgpack
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_DarwinFoundation1-2YSBQADOLX02V.pcm
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/CFNetwork-1PNPO1ORVQZLS.pcm
  - .build/out/v5/records/CR/OSMessageNotification.h-32QJYCZB4CACR
  - .build/out/Intermediates.noindex/GeneratedModuleMaps/ArgumentParser-Swift.h
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/Darwin-1FXX23EKWOBA9.pcm
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/Security-3QCVXOV25KK54.pcm
  - .build/out/v5/records/1Z/attr.h-1EPXL3OOD111Z
  - .build/out/v5/records/WR/NSOrderedCollectionDifference.h-34YMU4F3WZDWR
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Flag.swiftdeps
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/CFNetwork-1PNPO1ORVQZLS.pcm
  - .build/out/v5/records/U3/CFNetServices.h-DA0GECN5U3U3
  - .build/out/CompilationCache.noindex/generic/lock
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentSet.dia
  - .build/out/v5/records/K9/NSUserNotification.h-1MOHX1XH0H9K9
  - .build/out/v5/records/XS/Location.swift-2P51CN0FE9SXS
  - .build/out/v5/records/BH/form.h-2CVR60VF6B1BH
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests.swiftmodule
  - .build/out/v5/records/24/NSScriptObjectSpecifiers.h-34PLYVLD18924
  - .build/out/v5/records/01/vm_param.h-28GZU2686201
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/launch-3T3BU4MASLMUM.pcm
  - .build/out/CompilationCache.noindex/generic/v1.1/data.v1
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParentCommand.swiftconstvalues
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/59b9006d8141081676ed948fce1bd6d5
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-3P6VY5K77FXHW
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandParser.swiftconstvalues
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/046d1762327780dea41fdbeb762dd77f
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/Support.swiftconstvalues
  - .build/out/v5/records/2S/IOMedia.h-14K83W673FL2S
  - .build/out/v5/records/AG/semaphore.h-1QI41OLMIDUAG
  - .build/out/v5/records/J0/_clock_t.h-34TVOYNGQ4EJ0
  - .build/out/CompilationCache.noindex/generic/v1.1/data.v1.shared
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/os-2MV8OP7R98AN8.pcm
  - .build/out/v5/records/CR/_regex.h-134NLY5U4OXCR
  - .build/out/v5/records/ZD/NSListFormatter.h-1H1FUQOACB5ZD
  - .build/out/v5/records/96/unistd.h-RIG71GMZS496
  - .build/out/v5/records/B9/listener.h-1SR9H0EFS4GB9
  - .build/out/v5/records/KN/sem.h-2B3TFRC6TAIKN
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Flag.dia
  - .build/out/v5/records/W4/CFRunLoop.h-1X7C4LV80P9W4
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/CoreServices-39NCTJOEW7PQ2.pcm
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/launch-3T3BU4MASLMUM.pcm
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/69ecbe680c5b8a5f14502abeac2a5bf1
  - .build/out/v5/units/CompletionKind.o-FVKPV710KAU4
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/task-store.msgpack
  - .build/out/v5/records/ZR/_abort.h-3PDSUDR7RMJZR
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/OptionGroup.swiftdeps
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_Builtin_float-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/9H/xattr.h-30Q3YJAADLU9H
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_DarwinFoundation1-2YSBQADOLX02V.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDefinition.d
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/DerivedSources/Entitlements.plist
  - .build/out/v5/records/JI/SecAsn1Types.h-MOE1WR64R8JI
  - .build/out/v5/records/A1/semaphore.h-1UU911U8ERQA1
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/pre-merge-commit.sample
  - .build/out/v5/records/7A/IOHIDEventSystemClient.h-25JDPCK2KUK7A
  - .build/out/v5/records/J6/_intmax_t.h-3YYKIEJQSMJ6
  - .build/out/v5/records/NX/kdebug.h-2C826GALIZ0NX
  - .build/out/v5/records/0L/Location.swift-2HOA2X5G9LU0L
  - .build/out/v5/records/JD/_malloc.h-1NKQ3BRW879JD
  - .build/out/v5/units/ParsedValues.o-1XRTWFWOOL458
  - .build/out/v5/records/U0/CFURLAccess.h-382GQ3WHT3OU0
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ExpressibleByArgument.swiftdeps
  - .build/out/v5/records/7N/ArgumentDecoder.swift-24A8LVJGLIR7N
  - .build/out/v5/records/LM/NSConnection.h-3ISQZKSJ0M7LM
  - .build/out/v5/records/MP/TextEncodingPlugin.h-3HUKNXSU11RMP
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CodingKeyValidator.d
  - .build/out/v5/records/GG/CFStream.h-1TJ8NJAHBBAGG
  - .build/out/v5/records/XV/CFString.h-2PUZ1L6COPVXV
  - .build/out/v5/units/launch-3WSPWWCI7UPBQC0QFZJ34SVS0.pcm-39189KAPE7Z9
  - .build/out/v5/records/FX/AuthSession.h-BPF6E00VGEFX
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/f86cbb10517a3bd51f252887359b04af
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Name.dia
  - .build/out/v5/records/0U/_stdlib.h-8NZ23VI99S0U
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SplitArguments.d
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/46c5b95d370377562ae3cfc4dd5dca5d
  - .build/out/v5/records/3Z/oids.h-2GX9B4TRV803Z
  - .build/out/v5/records/D4/AppleUSBDefinitions.h-ZNDFXV4YY1D4
  - .build/out/v5/records/LN/NSPersonNameComponentsFormatter.h-CXQRPU8AZ2LN
  - .build/out/v5/records/I7/ParsableArguments.swift-1KRTKI3UMRCI7
  - .build/out/v5/records/RD/notify.h-3P0IS3RGS8RD
  - .build/out/v5/records/S9/quota.h-SOYU388IW2S9
  - .build/out/v5/records/T0/arm64e-apple-macos.swiftinterface-3835HN5WAKUT0
  - .build/out/v5/records/JZ/main.swift-FUHHZNMTY0JZ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Errors.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpGenerator.d
  - .build/out/v5/records/XK/NSScriptClassDescription.h-25B9KTP8ONDXK
  - .build/out/v5/records/WO/_fsblkcnt_t.h-3TL2TW8Z7AHWO
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/59b9006d8141081676ed948fce1bd6d5
  - .build/out/v5/records/KZ/trace_base.h-3D05MU1V3ZVKZ
  - .build/out/v5/records/9E/libgen.h-3M0M694T7V9E
  - .build/out/v5/records/L4/ndr_def.h-ZZA3IEUUROL4
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_Builtin_stddef-2OQWMRBVRD4OJ.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParentCommand.d
  - .build/out/v5/records/L7/CSIdentityBase.h-TF5B3UGD6ML7
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_Builtin_stdatomic-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/3E/LSOpen.h-1G6QN6I1KZD3E
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/ReadingOrderTests.o
  - .build/out/v5/records/AQ/qos.h-37MPUDVKMUTAQ
  - .build/out/v5/records/WG/StringCompare.h-SP6SZG40JPWG
  - .build/out/v5/records/3K/message.h-2O1EHXO5XB33K
  - .build/out/v5/records/6Z/if_utun.h-NHDS7J44316Z
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-11
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/59b9006d8141081676ed948fce1bd6d5
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_Builtin_stddef-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/WV/IOHIDUsageTables.h-1WUG6U8GHLVWV
  - .build/out/v5/records/6X/thread_special_ports.h-2IE9G0PSLHJ6X
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests-dependencies-1.json
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandParser.d
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/manifest.json
  - .build/out/v5/records/0W/MDSchema.h-2R614WN5VSF0W
  - .build/out/v5/units/_DarwinFoundation3-E8SP24R9KQSBOOPGOJEO5S1B2.pcm-2NK342DCDX2RP
  - .build/out/v5/records/GP/Threads.h-1CG70ZJMWFUGP
  - .build/out/v5/units/ptrauth-API8LKCD6DQ150LSS6N3FIFVX.pcm-5W7V3TU6IAFM
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NameSpecification.swiftdeps
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema_check-dependencies-1.json
  - .build/out/v5/records/WV/IOStorageControllerCharacteristics.h-2FC8UOFL3O7WV
  - .build/out/v5/records/CH/Tree.swift-S8DY2ZH8MHCH
  - .build/out/v5/records/KS/dirent.h-2XUW7TORCBXKS
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests_dependency_info.dat
  - .build/out/v5/records/K1/Name.swift-1XU21LUNGRVK1
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions-primary.priors
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema_check.abi.json
  - .build/out/v5/records/W7/curses.h-CB0Z68HK4HW7
  - .build/out/v5/units/Dispatch-59MASFKHL5I0OBBKAGLTHFCWQ.pcm-XQKJ5E6R9HHJ
  - .build/out/v5/records/PM/SecIdentitySearch.h-M5HTA2UAJ5PM
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_Builtin_stdint-2OQWMRBVRD4OJ.pcm
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_Builtin_float-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/4H/BackupCore.h-2IYLPQ1WJEJ4H
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/f26bec36a172fe818fae42bf57d98d44
  - .build/out/SDKExplicitPrecompiledModules/CFNetwork-DQRKHVVBTLI4WXXPNWLZKDNIP.pcm
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CiteOrder.d
  - .build/out/Intermediates.noindex/SwiftExplicitPrecompiledModules/_Testing_Foundation-1MBIOQ4K0SPEM.swiftmodule
  - .build/out/v5/records/IL/ptrcheck.h-HM3HCFWHFOIL
  - .build/out/v5/records/1Q/_mcontext.h-39RT06WL8DZ1Q
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NonsenseFlagsValidator.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionKind.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo.swiftmodule
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/launch-3T3BU4MASLMUM.pcm
  - .build/out/v5/records/GO/___wctype.h-3EPX3F11OVVGO
  - .build/out/v5/records/ZG/SKSearch.h-A4T8Q3Z8O2ZG
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema-check.SwiftFileList
  - .build/out/v5/records/2D/raw_ip6.h-2AO4YNK71DY2D
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ToolInfo.o
  - .build/out/v5/records/FU/NSMethodSignature.h-37RL3MJPZK5FU
  - .build/out/v5/records/YR/NSJSONSerialization.h-3S1GD220PFHYR
  - .build/out/v5/records/FV/qos.h-1AFKC4JYQ5RFV
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/BashCompletionsGenerator.dia
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests_const_extract_protocols.json
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDecoder.o
  - .build/out/Products/Debug/tschema-check
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo.LinkFileList
  - .build/out/v5/records/9A/_ctermid.h-2E60E326LR09A
  - .build/out/v5/records/T1/SecSharedCredential.h-TWDE2IGONXT1
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_Builtin_stdarg-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/KV/_key_t.h-FG2O1960JQKV
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Errors.d
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_Builtin_limits-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/FZ/FishCompletionsGenerator.swift-1UYFQN0URDUFZ
  - .build/out/v5/units/ArgumentVisibility.o-2HHLKAUHQPDQZ
  - .build/out/v5/records/3K/CFURLEnumerator.h-3V5MTQ0RE03K
  - .build/out/v5/records/CR/NSScriptStandardSuiteCommands.h-38X8XZ72T03CR
  - .build/out/v5/records/P7/Aliases.h-2SRRNS7TMJKP7
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo.swiftdoc
  - .build/out/v5/records/GZ/NSIndexPath.h-21D4BER9LHQGZ
  - .build/out/v5/records/LQ/cssmcli.h-2C2L0NDW24OLQ
  - .build/out/v5/records/RN/udp_var.h-219VOV8P4YXRN
  - .build/out/v5/records/5Q/ArgumentHelp.swift-18BL3RPX2XA5Q
  - .build/out/v5/records/93/IOFramebufferShared.h-3F2ELBC5Z1O93
  - .build/out/v5/records/MC/panel.h-23T681O1ZHNMC
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-1
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/9a9c096c4ace5cbd1414691c8d9d4c23
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/CiteOrderTests.o
  - .build/out/v5/records/9I/_u_int32_t.h-1JVW03YWX3V9I
  - .build/out/v5/records/CC/posix_shm.h-1O4FHSGOLPDCC
  - .build/out/v5/records/MU/CFBag.h-5T0U4GPYO8MU
  - .build/out/v5/units/_SwiftConcurrencyShims-6K6W8CVATK3OHQ28Y658SJYPJ.pcm-37EWQ87665I4R
  - .build/out/v5/records/NY/ttycom.h-13TQDF1M5X8NY
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/2de6a04cdba79ed13580c47dfd70cc5f
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableCommand.d
  - .build/out/v5/records/M4/SecKeychain.h-2V0GXF9O6WEM4
  - .build/out/v5/records/NF/unctrl.h-1BWH6HS6Z3GNF
  - .build/out/v5/records/NX/if_types.h-1ITWCUH63WPNX
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CommandRun.d
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/ptrauth-2OQWMRBVRD4OJ.pcm
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/os_workgroup-2MV8OP7R98AN8.pcm
  - .build/out/v5/records/JP/IORPC.h-2BGRZ717NJJJP
  - .build/out/v5/units/DumpHelpGenerator.o-1IJ49F96JHWB5
  - .build/out/v5/records/UH/LowMem.h-3FLKTSNGOUOUH
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SwiftExtensions.swiftconstvalues
  - .build/out/v5/records/9L/NSZone.h-10ZXX1XLB389L
  - .build/out/v5/records/FI/ipc.h-3B0XWDGCRQ8FI
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/fb4985d8c4b099a564da7b3f99d8a7de
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/LedgerReader.d
  - .build/out/v5/records/G3/kern_return.h-DD3PH6O8C5G3
  - .build/out/v5/records/HZ/IONetworkStats.h-3I18JSF768SHZ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Name.swiftconstvalues
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_Builtin_stdint-2OQWMRBVRD4OJ.pcm
  - .build/out/SDKExplicitPrecompiledModules/launch-3WSPWWCI7UPBQC0QFZJ34SVS0.pcm
  - .build/out/v5/records/FC/NSExpression.h-1FYVXX51MUUFC
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit.swiftsourceinfo
  - .build/out/v5/records/QQ/bank_types.h-3HA58LG5PZMQQ
  - .build/out/v5/records/TT/icmp_var.h-36D5SU1Q787TT
  - .build/out/v5/records/Y5/SecACL.h-1TWNZNONBMEY5
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/SwiftShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/SU/AIFF.h-ZC55GLQS5OSU
  - .build/out/v5/records/DI/NSPortNameServer.h-3US1JRRWBVDDI
  - .build/out/v5/records/ZG/cssmspi.h-1UD1J00SHKLZG
  - .build/out/v5/records/LP/NSURLRequest.h-SZDNZ42EDYLP
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests-primary-emit-module.d
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/2a470153fc8b923cf29a9f596b547976
  - .build/out/v5/records/NG/NSHost.h-MUEHIFGCS5NG
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/03cd2f611fa53e83f3ed19a9ff7c5c8d
  - .build/out/v5/records/1S/ReadingOrderTests.swift-3K5G3BE6J8G1S
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_Builtin_limits-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/I0/syslimits.h-TA97PN7JO9I0
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/BashCompletionsGenerator.d
  - .build/out/v5/records/OX/NSProxy.h-3KOEZZK0HV9OX
  - .build/out/SDKExplicitPrecompiledModules/_Builtin_limits-1EH2FNH5749LLDUS3YS9CK1I6.pcm
  - .build/out/v5/records/96/AsyncParsableCommand.swift-3DOO1C3HZ3N96
  - .build/out/v5/records/W9/aliasdb.h-19MBW03ECXHW9
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser.LinkFileList
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/510186d6f8afde67e3eaf7e862481e71
  - .build/out/v5/records/AU/AvailabilityInternalLegacy.h-221GLLEDEOSAU
  - .build/out/v5/records/NG/__stddef_size_t.h-EV3CIHQ00TNG
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/401fad213a413d1b687a47f6e660d656
  - .build/out/v5/records/4K/IOHIDBase.h-2CKVY21TEX34K
  - .build/out/v5/records/05/NSUnit.h-1TKUSA5ANUC05
  - .build/out/v5/records/9K/_fsfilcnt_t.h-2J4SI2VERAE9K
  - .build/out/v5/records/AB/NSObjCRuntime.h-WJT0D9LIJ0AB
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/launch-3T3BU4MASLMUM.pcm
  - .build/out/v5/records/P0/AEPackObject.h-2JMSEKFQD18P0
  - .build/out/v5/records/C6/__stdarg_va_arg.h-1RA1414779JC6
  - .build/out/v5/records/U7/page_info.h-KIPV6GWQP4U7
  - .build/out/v5/records/7X/object.h-2F7G01VWW9R7X
  - .build/out/v5/records/C7/runetype.h-20QSR1B4D55C7
  - .build/out/v5/records/BY/CommandConfiguration.swift-33PIIFCMOBY
  - .build/out/v5/records/GL/sysdir.h-S0RTNC1I5AGL
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/aa6e09c5d6a35e10c5f9fa522f6c5c71
  - .build/out/v5/records/WG/thread_act.h-17DA23RICFYWG
  - .build/out/v5/records/97/_wchar.h-2GKKTOPDETU97
  - .build/out/v5/records/4X/event.h-17XNSAIK8NQ4X
  - .build/out/v5/records/AX/_ctype.h-3QHDPFDI5XNAX
  - .build/out/v5/records/Y4/DictionaryServices.h-1IDKZFOIKD6Y4
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/build-request.json
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/401fad213a413d1b687a47f6e660d656
  - .build/out/v5/records/5A/CFError.h-1D7J9JD9S1F5A
  - .build/out/v5/records/ZC/UTCUtils.h-39S5Z432STGZC
  - .build/out/v5/units/AsyncParsableCommand.o-3M2S89I9OX1S1
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions_dependency_info.dat
  - .build/out/v5/records/QW/tcpip.h-1E8BOIN97SQQW
  - .build/out/v5/records/YW/tcp_timer.h-38D8ILLBHBMYW
  - .build/out/v5/records/XS/Errors.swift-32JHZ4FM2BVXS
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ZshCompletionsGenerator.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/ReadingOrderTests.swiftconstvalues
  - .build/out/v5/records/MR/DiskSpaceRecovery.h-14FUDA8PVNFMR
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions-OutputFileMap.json
  - .build/out/v5/records/QE/NSXMLNode.h-9DKQ8R1M5WQE
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/ReadingOrderTests.d
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/manifest.json
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_Builtin_inttypes-2OQWMRBVRD4OJ.pcm
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/59b9006d8141081676ed948fce1bd6d5
  - .build/out/v5/records/38/SecIdentity.h-BAVA626P0838
  - .build/out/v5/records/G9/workloop.h-1YSUXMQYKAHG9
  - .build/out/v5/records/TC/base.h-8C9L9TTVEUTC
  - .build/out/v5/records/0X/queue.h-3M0O93DQHU70X
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser.swiftsourceinfo
  - .build/out/v5/records/3D/CiteOrderTests.swift-24LP4O5VW3Z3D
  - .build/out/v5/records/KE/_locale_t.h-WOA8STU2H2KE
  - .build/out/v5/records/5Y/Power.h-LB5YGT15VN5Y
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo.SwiftFileList
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/Foundation-24LYWIP48SHNP.pcm
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-3I4C6QNHLTK7I
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-6
  - .build/out/v5/records/I2/cpio.h-18WNI7IDS9AI2
  - .build/out/v5/records/NZ/_mount_t.h-3K12HB2OHYHNZ
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/ObjectiveC-1G8H182PQX3QE.pcm
  - .build/out/v5/records/JM/__stddef_offsetof.h-2LUNIPF6B18JM
  - .build/out/v5/units/ParsableArgumentsValidation.o-142ZJ7OP0AGWV
  - .build/out/v5/records/O3/IONetworkUserClient.h-DLCTP1T906O3
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions-primary-emit-module.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo_const_extract_protocols.json
  - .build/out/v5/records/6A/ifaddrs.h-3UK0GBIQEUR6A
  - .build/out/v5/records/U9/bpf.h-1GSC4MQ489RU9
  - .build/out/v5/units/Darwin-A5OT2C2CSJ1S2E08CNFN3GDJO.pcm-32O7OP507J692
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_Builtin_stdbool-2OQWMRBVRD4OJ.pcm
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema-check_const_extract_protocols.json
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/CiteOrderTests.d
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/PropositionsKitTests.xctest.xcent
  - .build/out/v5/units/_Builtin_stdarg-DDTW7ZG77P0BLZ150JPHZOJRV.pcm-CCDBYUKXIWHE
  - .build/out/v5/records/5R/thread_switch.h-2KZIZTGXPXL5R
  - .build/out/v5/records/BE/boolean.h-99X76WAHN2BE
  - .build/out/v5/records/CL/NSSet.h-RFKI2GZVGPCL
  - .build/out/v5/records/79/SKIndex.h-3D7URRX5SRJ79
  - .build/out/v5/records/TA/LSOpenDeprecated.h-R6CTQ7HZ6OTA
  - .build/out/v5/units/libkern-76FYW2YP7DQQXX90XDE4BK26U.pcm-1PXVRN63TZW0L
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/757f4a30810dc1167421c70c85e5301f
  - .build/out/v5/records/M4/IOPowerSources.h-3MNH881Q1UEM4
  - .build/out/v5/records/OO/spawn.h-2YU683W2PWJOO
  - .build/out/v5/records/2V/InputOrigin.swift-3Q2RUBG34592V
  - .build/plugins/cache/GenerateManual.dSYM/Contents/Resources/DWARF/GenerateManual
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/libkern-2KQ0X67RTM1JF.pcm
  - .build/out/v5/records/4X/CFSet.h-1YEAQLZ5WRS4X
  - .build/out/v5/records/CX/_ptrdiff_t.h-15AB8YR486XCX
  - .build/out/v5/records/LC/_pid_t.h-2FE53P1CFSQLC
  - .build/out/v5/records/RQ/socketvar.h-FRKW9MBMSCRQ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Argument.o
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/Propositions.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArguments.d
  - .build/.buildSystem_debug
  - .build/out/v5/records/5W/NSItemProvider.h-PV6OJMETYV5W
  - .build/out/v5/records/VR/_sa_family_t.h-2ZYNC75AX1KVR
  - .build/out/v5/records/G3/SecPolicy.h-3CLBUNHZ2UQG3
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/FishCompletionsGenerator.d
  - .build/out/v5/records/E7/_malloc_type.h-2IWSKOE8E87E7
  - .build/out/v5/records/GB/CFDateFormatter.h-33MAWTA4LBBGB
  - .build/out/v5/records/U2/NSDistantObject.h-1Q9FR1OXT2U2
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_Builtin_stdint-2OQWMRBVRD4OJ.pcm
  - .build/out/Products/Debug/PropositionsKit.swiftmodule/Project/arm64-apple-macos.swiftsourceinfo
  - .build/out/v5/records/LA/arm64e-apple-macos.swiftinterface-372W3URMQIGLA
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_Builtin_stddef-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/EP/limits.h-3Q3RV0WX8R2EP
  - .build/out/v5/records/KE/CSIdentityQuery.h-YBH8GCY6MHKE
  - .build/out/v5/records/51/_ino_t.h-1B8GAZR8F9X51
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputOrigin.o
  - .build/out/v5/records/64/NSMeasurementFormatter.h-19ECHPIF2I164
  - .build/out/v5/records/H9/CSIdentityAuthority.h-2E2IBZQ2ZI1H9
  - .build/out/v5/records/I9/NSExtensionContext.h-2O9ZT0QHWQ6I9
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandConfiguration.dia
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/510186d6f8afde67e3eaf7e862481e71
  - .build/out/v5/records/KU/IOGraphicsEngine.h-2P7FCT4MHL4KU
  - .build/out/v5/units/OptionGroup.o-89OMWV65SHRS
  - .build/out/v5/records/TW/cssmtpi.h-1JMCJTV264ZTW
  - .build/plugins/cache/GenerateManual.dia
  - .build/out/v5/records/78/thread_state.h-305FHH80RRU78
  - .build/out/v5/records/QC/SecDigestTransform.h-1X5JHIDIF6VQC
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/IOKit-1IAL9NTK1TABA.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/FishCompletionsGenerator.swiftconstvalues
  - .build/out/v5/records/9A/mount.h-2UCQUFW2AI49A
  - .build/out/v5/records/CT/_printf.h-3H2RWKIUFKGCT
  - .build/out/v5/records/M1/ip.h-3GL6DJPY92VM1
  - .build/out/v5/records/1R/memory_object_types.h-1YR9ELXCQF31R
  - .build/out/v5/records/AX/_mb_cur_max.h-3FLV9VS5YG2AX
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/Security-3QCVXOV25KK54.pcm
  - .build/out/v5/records/0M/swap.h-2TM7Y71J64U0M
  - .build/out/v5/records/63/UTCoreTypes.h-3B7R3GBJBHL63
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/Support.dia
  - .build/out/v5/records/BJ/in_var.h-Z0MTHEEDLZBJ
  - .build/out/v5/records/KB/_monetary.h-3PP93RDN6CTKB
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_Builtin_stdint-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/ND/workgroup_object.h-155A6N16G1RND
  - .build/out/v5/records/2R/asm.h-17891FT05E12R
  - .build/out/v5/records/AT/host_priv.h-2GED8E99974AT
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/5b1954d8f0d04b305e8270190e18b2c3
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParentCommand.dia
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/Darwin-1FXX23EKWOBA9.pcm
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/os_object-2MV8OP7R98AN8.pcm
  - .build/out/v5/records/CW/uio.h-1ENIZF8XZ4PCW
  - .build/out/v5/records/UC/ArgumentVisibility.swift-6M8M8XGOU1UC
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo-dependencies-1.json
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ExpressibleByArgument.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/DerivedSources/Entitlements.plist
  - .build/out/v5/records/YR/cssmaci.h-2513F688QJ1YR
  - .build/out/v5/records/FS/_blkcnt_t.h-3OAKIIP1GR1FS
  - .build/out/Intermediates.noindex/ExplicitPrecompiledModules/modules.timestamp
  - .build/out/v5/records/T8/_socklen_t.h-1VITE68ADQLT8
  - .build/out/v5/records/ED/IONetworkData.h-28RLLM2V1Z3ED
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/Propositions.dia
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/6a89d4677c25fa550ccc8d2b64f1f3b2
  - .build/out/v5/records/JI/IOPSKeys.h-1HSFUJDMLA8JI
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-1WVV2POLWCZT3
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/description.msgpack
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema-check-primary.priors
  - .build/out/v5/records/5U/NSURLConnection.h-1L2ARFCOTNE5U
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArguments.swiftdeps
  - .build/out/v5/records/0E/SCSITask.h-21A3INRWJQA0E
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/IOKit-1IAL9NTK1TABA.pcm
  - .build/out/v5/records/M1/vm_page_size.h-3FDTGWCYFUWM1
  - .build/out/v5/records/G7/_int16_t.h-3UIVR2BRPCHG7
  - .build/out/v5/records/HJ/ToolInfo.swift-2M324KW52QUHJ
  - .build/out/v5/records/1I/NSDateFormatter.h-VVMA0HYVC71I
  - .build/out/v5/records/CD/cssmerr.h-3DE6IECSWOOCD
  - .build/out/v5/records/FQ/NSRunLoop.h-CO4JXE5QMNFQ
  - .build/out/v5/records/J4/NSAppleScript.h-2ZJ2U0IHOVJJ4
  - .build/out/v5/records/FW/types.h-KYSQM1DL0TFW
  - .build/out/v5/records/LE/sync_policy.h-1WVV1INCZXSLE
  - .build/out/v5/records/MN/SCSICmds_MODE_Definitions.h-G5UMAUU1ELMN
  - .build/out/v5/records/IP/time.h-1P7AN79RYECIP
  - .build/out/v5/records/J1/CFFileSecurity.h-2RTUKU61BSLJ1
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandGroup.d
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_DarwinFoundation3-2NSGASPTSNBVQ.pcm
  - .build/out/Products/Debug/PropositionsKitTests.swiftmodule/Project/arm64-apple-macos.swiftsourceinfo
  - .build/out/v5/records/67/IOGraphicsTypes.h-SNFYY6IJER67
  - .build/out/v5/records/5T/SCSICmds_REQUEST_SENSE_Defs.h-1T995X7UNFJ5T
  - .build/out/v5/records/NO/limits.h-33VFA90LD0INO
  - .build/out/v5/records/JP/IOBDBlockStorageDevice.h-2EJIP667C6AJP
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputKey.dia
  - .build/out/v5/records/B3/NSOrderedCollectionChange.h-2OTAISVF1M9B3
  - .build/repositories/swift-argument-parser-54a11a8d/description
  - .build/out/v5/records/5G/Authorization.h-2Q3AHEDIM0P5G
  - .build/out/v5/records/AP/cssmkrapi.h-XCQTZ684B2AP
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/f86cbb10517a3bd51f252887359b04af
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/ObjectiveC-1G8H182PQX3QE.pcm
  - .build/out/v5/records/EM/_pthread_condattr_t.h-3PQGAOJLEFEEM
  - .build/out/v5/units/CommandConfiguration.o-1Y5AE0JBDSMUB
  - .build/out/v5/records/5D/IODVDBlockStorageDevice.h-2WSOWDKL6B45D
  - .build/out/Products/Debug/PropositionsKit.swiftmodule/arm64-apple-macos.swiftmodule
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ToolInfo.swiftconstvalues
  - .build/out/v5/records/EP/mach_time.h-21ZOVGZTJN7EP
  - .build/out/v5/records/XT/removefile.h-OYYFJJE9Z0XT
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Name.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CodingKeyValidator.swiftconstvalues
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/Darwin-1FXX23EKWOBA9.pcm
  - .build/out/SDKExplicitPrecompiledModules/_Builtin_float-8VRJETFKL8GBLX34WLQBKRTXU.pcm
  - .build/out/Products/Debug/ArgumentParser.swiftmodule/arm64-apple-macos.abi.json
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArguments.swiftconstvalues
  - .build/out/v5/records/BD/execinfo.h-3AQ707IKQW4BD
  - .build/out/v5/records/N4/IOUPSPlugIn.h-KK5X35SDUNN4
  - .build/out/v5/records/UC/arm64e-apple-macos.swiftinterface-2ZZL440X3A1UC
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncParsableCommand.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ZshCompletionsGenerator.swiftdeps
  - .build/out/v5/records/G1/IOHIDEventServiceTypes.h-17AG9XXTS9TG1
  - .build/out/v5/records/MD/atomic.h-31ZRXW8VCKKMD
  - .build/out/v5/records/WT/objc-auto.h-3JIGMUK2LK7WT
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/227b782cb6eaf03396d3c6fe8b65c221
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/4c4489b2d9c6962f0e11f113fabeda8d
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_Builtin_stddef-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/ID/hashtable2.h-28TS6481FURID
  - .build/out/v5/records/S5/SKSummary.h-2FY9LMASYBDS5
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/f86cbb10517a3bd51f252887359b04af
  - .build/out/v5/records/TY/stdint.h-VX859H0V0GTY
  - .build/out/v5/records/L0/zone_info.h-2TP3YAOUILJL0
  - .build/out/SDKExplicitPrecompiledModules/CoreServices-DZ24JI52B7AJYTK0HOAKIPW9G.pcm
  - .build/out/v5/records/WA/NSURLAuthenticationChallenge.h-3DTR0G4I69AWA
  - .build/out/v5/records/YG/SecEncryptTransform.h-49HCZVDQ8VYG
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_AvailabilityInternal-2YSBQADOLX02V.pcm
  - .build/out/v5/records/MB/_id_t.h-362Q6A6ME9EMB
  - .build/out/v5/records/N7/_rsize_t.h-2IWFWLNHB1EN7
  - .build/out/v5/records/O1/time.h-OEEZHVRQX1O1
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_Builtin_stdarg-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/units/Location.o-3HZNVGPV19NEQ
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/f86cbb10517a3bd51f252887359b04af
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/libDER-26DYHF6GC6WWA.pcm
  - .build/out/v5/units/ObjectiveC-C6G0RBBYZQZRXN0H3L0G84K7C.pcm-RQT5W6CY4NI2
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Tree.dia
  - .build/out/v5/records/CR/device_types.h-3B2Z7K0WZ9JCR
  - .build/out/v5/records/CT/CFBitVector.h-1FD2KHO4VIICT
  - .build/out/v5/records/3J/_blksize_t.h-2BKZYAX9MHY3J
  - .build/out/v5/records/RZ/fstab.h-B2V49I5L98RZ
  - .build/out/v5/units/ToolInfo.o-1C5QRQ78Y5B4Q
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/ArgumentParserToolInfo.modulemap
  - .build/out/v5/records/QB/NSString.h-GEHN0CQE9TQB
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser-OutputFileMap.json
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/task-store.msgpack
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandParser.swiftdeps
  - propositions-projects.code-workspace
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParentCommand.o
  - .build/out/v5/records/K1/IOKitServer.h-3J2G39IGFS4K1
  - .build/out/v5/records/QK/NSDebug.h-3LH834IDO07QK
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionsGenerator.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SequenceExtensions.swiftdeps
  - .build/out/v5/records/ZX/UTType.h-Q9QB21S1SRZX
  - .build/out/v5/records/F9/NSPointerFunctions.h-LZUZW9JTWCF9
  - .build/out/v5/records/24/IOBlockStorageDevice.h-27KBSLK4C5N24
  - .build/out/v5/records/J3/thread_state.h-36GQREYHE4DJ3
  - .build/out/v5/records/33/IOStorageDeviceCharacteristics.h-10J104K18HF33
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-9
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/aa78d11ca0af6397238de8ca9c8c1226
  - .build/out/v5/records/JE/_inttypes.h-3S0NPHRWK5HJE
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Location.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/BashCompletionsGenerator.swiftdeps
  - .build/out/v5/records/QU/ExpressibleByArgument.swift-34EV3EJDOBGQU
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpGenerator.swiftdeps
  - .build/out/v5/records/NQ/NSXPCConnection.h-8MG976YP41NQ
  - .build/out/v5/records/O9/spawn.h-330X424E4BAO9
  - .build/out/v5/records/TV/TextEncodingConverter.h-724AHZSLCJTV
  - .build/out/v5/records/N9/NSOrderedSet.h-2WWAWR86U0FN9
  - .build/out/v5/records/I9/stat.h-1Y3EUKCFA8GI9
  - .build/out/v5/records/5P/SecKeychainSearch.h-1U1JXLRKK5L5P
  - .build/out/v5/records/6L/ArgumentSet.swift-2BS6F4JTDYY6L
  - .build/out/v5/records/U9/AuthorizationPlugin.h-2J45MVWGQOIU9
  - .build/out/v5/records/NL/Foundation.swift-LTMCKGYVADNL
  - .build/out/SDKExplicitPrecompiledModules/XPC-18JXR4ULGTJV3OA1FH4YCFJNC.pcm
  - .build/CACHEDIR.TAG
  - .build/out/v5/records/G7/errno.h-HT34MMPF0FG7
  - .build/out/v5/records/YF/HelpCommand.swift-E7Q7O6HUHGYF
  - .build/out/v5/records/0R/MacLocales.h-MV7B2G30BB0R
  - .build/out/v5/records/A2/FSEvents.h-3BJCGK1LF4VA2
  - .build/out/v5/units/ArgumentDefinition.o-CAQQK4II35HM
  - .build/out/v5/records/60/_sigset_t.h-294K1F4WP6O60
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentSet.o
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/39786d311dc44b904edc6f35d96e5c8a
  - .build/out/v5/records/SI/Block.h-2HBZC0LU1UYSI
  - .build/out/v5/units/Mutex.o-3S1FRDLRQN6KY
  - .build/out/v5/records/P4/ttydefaults.h-35INNBIF154P4
  - .build/out/v5/records/DQ/icmp6.h-3R042OS4LREDQ
  - .build/out/v5/records/L3/_caddr_t.h-13CMSBL2SPFL3
  - .build/out/v5/records/Z2/NSCache.h-CB1YEL9V8FZ2
  - .build/out/v5/records/G6/_inttypes.h-F4RGBLYOHSG6
  - .build/out/v5/records/KB/exception.h-YJXZGJK70BKB
  - .build/out/v5/records/6Z/IOMessage.h-18AKFAZOLEO6Z
  - .build/out/v5/records/3H/oidscert.h-2MK6TFM7H4V3H
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser-dependencies-1.json
  - .build/out/v5/records/4C/_ino64_t.h-2MSEJHZHD24C
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions-dependency-scan.dia
  - .build/out/v5/records/06/FixMath.h-7RD3SY6PZ06
  - .build/out/v5/records/MQ/ReadingOrder.swift-1QP7WEJYF3MQ
  - .build/out/v5/records/FQ/NSScriptExecutionContext.h-2WI1BRKRYEHFQ
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/os_object-2MV8OP7R98AN8.pcm
  - .build/out/Intermediates.noindex/GeneratedModuleMaps/PropositionsKit-Swift.h
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser-primary-emit-module.dia
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/23190fe66dc7523cb2551782d03206af
  - .build/out/v5/records/H8/ar.h-2758Q8E8XG9H8
  - .build/out/v5/records/QI/PEFBinaryFormat.h-2IQITC9S4A3QI
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Mutex.dia
  - .build/out/SDKExplicitPrecompiledModules/Darwin-A5OT2C2CSJ1S2E08CNFN3GDJO.pcm
  - .build/out/v5/records/KE/hfs_format.h-3E51473HNSKKE
  - .build/out/v5/records/9C/NSScriptWhoseTests.h-19G6B2LD66F9C
  - .build/out/v5/records/ZD/audit_domain.h-34NZNIZIECDZD
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputOrigin.d
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_SwiftConcurrencyShims-2IMTS4WWRU7VJ.pcm
  - .build/out/SDKExplicitPrecompiledModules/Dispatch-59MASFKHL5I0OBBKAGLTHFCWQ.pcm
  - .build/out/v5/records/4W/_monetary.h-27K2SIKV3JU4W
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpCommand.o
  - .build/out/v5/records/HH/clock_reply.h-1TBZ0N44AX7HH
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit-primary.priors
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/46c5b95d370377562ae3cfc4dd5dca5d
  - .build/out/v5/records/MT/KeychainCore.h-3QFCSRMYJPTMT
  - .build/out/v5/units/ReadingOrder.o-UU60FFW5GI9K
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/9a9c096c4ace5cbd1414691c8d9d4c23
  - .build/plugins/cache/GenerateManual.dSYM/Contents/Info.plist
  - .build/out/v5/records/NF/NSIndexSet.h-1YM4K6PPC0CNF
  - .build/out/v5/units/Security-CLVDOQ1QTUNWWYBPR0FEC8K3J.pcm-ULKRSK0JKOI5
  - .build/out/SDKExplicitPrecompiledModules/_Builtin_stddef-9DSM9QA1LA2DNTEDCYG0D36PM.pcm
  - .build/out/v5/records/1I/SecRequirement.h-3BGG3XLB2HK1I
  - .build/out/v5/records/A2/NSObject.h-2FD2G4OJCPLA2
  - .build/out/v5/records/0T/NSKeyedArchiver.h-2A2QW9602BY0T
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/commit-msg.sample
  - .build/out/v5/records/31/NSCalendar.h-1I6T0A0Y98D31
  - .build/out/v5/records/DD/msg.h-15G86I3CGJ6DD
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CollectionExtensions.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CollectionExtensions.o
  - .build/repositories/swift-argument-parser-54a11a8d/objects/pack/pack-8e9c7dd1be2a2ad10f5b481e816a8504f35ddca9.pack
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/046d1762327780dea41fdbeb762dd77f
  - .build/out/v5/records/7D/object.h-1MVS9UNVA427D
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/2f0b92a65fb63e251690d599275ff386
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionsGenerator.dia
  - .build/out/v5/records/GC/fnmatch.h-3N5D29XH1OOGC
  - .build/out/v5/records/2F/util.h-Z5RXC6RCHH2F
  - .build/out/v5/records/VO/sysexits.h-1N51R85V5G7VO
  - .build/out/v5/records/E9/_u_char.h-19NIDV8R59SE9
  - .build/out/v5/records/YU/SCSITaskLib.h-1Z9QNURJLPLYU
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Parsed.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/MessageInfo.dia
  - .build/out/v5/records/0F/IOFDiskPartitionScheme.h-2KUAU9E6JCV0F
  - .build/out/v5/records/HP/IODataQueueShared.h-1PTND49FKHJHP
  - .build/out/v5/records/YW/dispatch.h-YOXIC764IOYW
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/39786d311dc44b904edc6f35d96e5c8a
  - .build/out/CompilationCache.noindex/generic/v1.1/index.v1
  - .build/out/v5/records/MF/CFAttributedString.h-PP3O3MX2FCMF
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputKey.d
  - .build/out/v5/units/os_workgroup-4EK4PUHNCCBES9QHV2BNNHF19.pcm-3EZ6NVQLY6CO0
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/ReadingOrderTests.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncCompletionsValidator.dia
  - .build/out/v5/records/R8/vm_info.h-1FS5WA5LXUKR8
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionKind.swiftdeps
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema_check.swiftdoc
  - .build/out/v5/records/GF/CFHTTPAuthentication.h-1SVORXYF5H2GF
  - .build/out/v5/records/WU/mach_traps.h-ROCTDGRWMGWU
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Foundation.dia
  - .build/out/v5/records/XP/IOHIDTransaction.h-18ZWP5C8Y00XP
  - .build/out/v5/units/ParserError.o-1MZX1KB2O8I3S
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/c3818a8d6ef695529039b179b4fd9978
  - .build/out/v5/records/1N/IODVDTypes.h-1N2LWP68LV01N
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/applypatch-msg.sample
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/39786d311dc44b904edc6f35d96e5c8a
  - .build/out/v5/records/VQ/acct.h-Q6HQYOC54AVQ
  - .build/out/v5/records/B5/Mutex.swift-3RK8Y6DL4OVB5
  - .build/out/v5/records/PP/CFXMLNode.h-1Q0QXBXMGQGPP
  - .build/out/v5/records/D8/SecTrustSettings.h-37DLG16F2S6D8
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/EnumerableFlag.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SwiftExtensions.o
  - .build/out/v5/records/DG/IOPartitionScheme.h-2RR3XQ35F8KDG
  - .build/out/v5/records/DG/NSNotification.h-2U5QAG6A8APDG
  - .build/out/v5/records/GI/NSDateIntervalFormatter.h-25I6EHGJI8FGI
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/Support.swiftdeps
  - .build/out/v5/records/J8/audit_socket_type.h-14GPEE50VTGJ8
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/XPC-T0ZXCAST7PE3.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser-dependency-scan.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Flag.o
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Location.dia
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_Builtin_stdint-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/18/SecCodeHost.h-DTBJXXJ6CN18
  - .build/out/v5/records/7Y/arm64.h-1MFU2PNQHZO7Y
  - .build/out/v5/records/0C/locale.h-37M5KQ5GILD0C
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests-OutputFileMap.json
  - .build/out/v5/records/AX/NSPersonNameComponents.h-2GEL92QX7WBAX
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsedValues.swiftconstvalues
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SequenceExtensions.swiftconstvalues
  - .build/out/v5/records/CQ/esp.h-28TS0LZZJLCCQ
  - .build/out/v5/records/AM/objc-sync.h-1DKQIQ3POOTAM
  - .build/out/v5/records/5C/CFHTTPMessage.h-F00EEK4Q3Y5C
  - .build/out/v5/records/KI/NSArray.h-T42DP0ZF7FKI
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentSet.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CollectionExtensions.swiftconstvalues
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDecoder.d
  - .build/out/v5/records/V2/CFPropertyList.h-3DBA8FC16KTV2
  - .build/out/SDKExplicitPrecompiledModules/DiskArbitration-49QYQIKFX5REPFQQGP8Q3AUKV.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Platform.swiftconstvalues
  - .build/out/v5/records/N9/_pthread_attr_t.h-2CVG635GKOCN9
  - .build/out/v5/units/FishCompletionsGenerator.o-29DS09N2SYL3K
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/main.dia
  - .build/out/v5/units/_Builtin_stdatomic-DO845EHCQE4IDH8UTOURJRCTG.pcm-9P3P9EI9DJUK
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/FishCompletionsGenerator.dia
  - .build/out/v5/records/99/_select.h-35KN8ULHARG99
  - .build/out/v5/records/D0/copyfile.h-2THM36MVKX9D0
  - .build/out/v5/records/0U/arm64e-apple-macos.swiftinterface-1B7N1KP4ZC0U
  - .build/out/v5/records/6R/NSCompoundPredicate.h-2360PPPS8586R
  - .build/out/v5/records/BQ/in_pcb.h-1VRPO32NZDRBQ
  - .build/out/v5/records/EW/MacErrors.h-2XMDYVLCLQTEW
  - .build/out/SDKExplicitPrecompiledModules/MachO-ASEAY7TNY43R7749UO83G95VR.pcm
  - .build/out/v5/records/XU/IOAccelSurfaceConnect.h-209GLZHY20VXU
  - .build/out/v5/records/7N/_off_t.h-1R4MNI1TOOB7N
  - .build/out/v5/records/62/NSTask.h-6ZVP2HJ1GE62
  - .build/out/v5/records/MI/NSTimeZone.h-37JXP3O9SF2MI
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Errors.swiftconstvalues
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Option.swiftdeps
  - .build/out/v5/records/Z9/__stddef_unreachable.h-XIIQIY1GE3Z9
  - .build/out/v5/records/2I/host_special_ports.h-HMTH8T00DK2I
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableCommand.dia
  - .build/out/v5/records/UF/NSNumberFormatter.h-1LKNTKLELQ9UF
  - .build/out/v5/records/AZ/NSSortDescriptor.h-171D12XLF65AZ
  - .build/out/Products/Debug/PropositionsKit.o
  - .build/out/v5/records/53/_seek_set.h-2Q7DCTNPIZ653
  - .build/out/v5/records/0X/search.h-1WJ2MY6WL6Y0X
  - .build/out/Products/Debug/PropositionsKitTests.swiftmodule/arm64-apple-macos.swiftmodule
  - .build/out/v5/records/Q8/NSPort.h-13G7FPBBUJNQ8
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions.SwiftFileList
  - .build/out/v5/units/libDER-4Y866X1EXEYK6YF0BSCOCPU35.pcm-2L19B1O6LKJKA
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions_const_extract_protocols.json
  - .build/out/v5/units/Support.o-3IPE0V8BLJ3WG
  - .build/out/v5/records/TK/ParsableArgumentsValidation.swift-16B224I1FXSTK
  - .build/out/v5/records/71/arm64e-apple-macos.swiftinterface-1RIGHMD7QX471
  - .build/out/v5/records/ZM/SecCode.h-1Q0QLYD6ZRSZM
  - .build/out/v5/records/EQ/SecProtocolMetadata.h-2UT1GWIK0M2EQ
  - .build/out/v5/records/Q3/Gestalt.h-NQVDGMX192Q3
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/propositions.xcent
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/DiskArbitration-3LBJF5I58QD8.pcm
  - .build/out/v5/records/S1/_endian.h-1GMC998VR1AS1
  - .build/out/v5/units/UsageGenerator.o-1ZZX0FVTF4F7U
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/sendemail-validate.sample
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncParsableCommand.swiftconstvalues
  - .build/out/v5/records/1G/NSScanner.h-P72UMHTJJZ1G
  - .build/out/v5/records/1N/_errno_t.h-XVIY9HBYP71N
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/CiteOrderTests.dia
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_Builtin_stdatomic-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/EG/NSFormatter.h-2YUHVVERPGWEG
  - .build/out/v5/records/H3/_ssize_t.h-2CDSKK2UNDGH3
  - .build/out/Intermediates.noindex/GeneratedModuleMaps/ArgumentParserToolInfo-Swift.h
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/ptrcheck-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/JL/Propositions.swift-3U0FD95FU0SJL
  - .build/out/v5/records/3I/NSScriptCoercionHandler.h-397KILWK0FX3I
  - .build/out/v5/records/OR/IOHIDLibObsolete.h-3716POZ21T3OR
  - .build/out/v5/records/XC/DASession.h-2OJBX0VX70DXC
  - .build/out/v5/records/E1/IOHIDTypes.h-KA6WCK6QGRE1
  - .build/out/v5/records/NF/IOHIDDevice.h-3QQK1RBWSQ9NF
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/SwiftShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/H6/IOHIDElement.h-NVV49X8V36H6
  - .build/out/SDKExplicitPrecompiledModules/SwiftShims-5UJWX82ZASMPG9GCELVMJ6507.pcm
  - .build/out/v5/records/EI/reloc.h-V3RFK00JY8EI
  - .build/out/v5/records/9E/byte_order.h-30P4DS09IU9E
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_AvailabilityInternal-2YSBQADOLX02V.pcm
  - .build/out/ModuleCache.noindex/modules.timestamp
  - .build/out/v5/records/WE/vm_inherit.h-3ERY6WTPBWHWE
  - .build/out/v5/records/3O/_uint16_t.h-1Z5W20ZI4K33O
  - .build/out/Products/Debug/PropositionsKitTests.xctest/Contents/Info.plist
  - .build/out/v5/records/OH/ntsid.h-2M2UHH4KAFSOH
  - .build/out/v5/records/VC/CompletionsGenerator.swift-3JSZRSP9F8WVC
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/Propositions.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CiteOrder.swiftconstvalues
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/XPC-T0ZXCAST7PE3.pcm
  - .build/out/v5/records/Q3/audit_uevents.h-3RXCXKXNA32Q3
  - .build/out/v5/records/1I/OSAtomicDeprecated.h-3HWZSFL5NU01I
  - .build/out/v5/records/NX/pfkeyv2.h-19MSH0VAFYNX
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/SwiftStdLibToolInputDependencies.dep
  - .build/out/v5/records/Y8/kdebug_signpost.h-1PZYEMHCI2WY8
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/2de6a04cdba79ed13580c47dfd70cc5f
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandConfiguration.o
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-product-p.build/Objects-normal/arm64/PropositionsKit_libtool_dependency_info.dat
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/510186d6f8afde67e3eaf7e862481e71
  - .build/out/v5/records/2U/clock.h-1NSQSYODAKA2U
  - .build/out/v5/records/7P/processor.h-PDRCVU10DT7P
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/110d90741d7e1c589e6854c91145777e
  - .build/out/v5/records/8D/_graftdmg_un.h-2HIK1KKISN18D
  - .build/out/v5/records/AU/kext_net.h-3KZ0YLB7FTHAU
  - .build/out/v5/records/MC/AEUserTermTypes.h-2KZVFHA247RMC
  - .build/out/v5/records/6K/CFUtilities.h-SE7CIDMELV6K
  - .build/out/v5/records/MS/DERItem.h-3ELVL7YXMZMS
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/2f0b92a65fb63e251690d599275ff386
  - .build/out/v5/records/C7/MultiprocessingInfo.h-344GVXFS6QJC7
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CiteOrder.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser.SwiftFileList
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentHelp.swiftdeps
  - .build/out/v5/records/KG/traps.h-35PCFD07TKSKG
  - .build/out/v5/records/UD/_pthread_mutexattr_t.h-I2R5H8MA2DUD
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/tschema-check.xcent
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/empty-PropositionsKitTests.plist
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/b81a5715c5227ba32114342ae999a766
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/2a470153fc8b923cf29a9f596b547976
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/aa78d11ca0af6397238de8ca9c8c1226
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NonsenseFlagsValidator.swiftdeps
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/757f4a30810dc1167421c70c85e5301f
  - .build/out/v5/records/SL/CommandParser.swift-1K0RK2SEGQASL
  - .build/out/v5/records/W7/NSByteCountFormatter.h-2J6CHJRPZN4W7
  - .build/out/v5/records/5C/NSCoder.h-3C8M5ACWE1I5C
  - .build/out/v5/records/NK/oidscrl.h-58CLUQZMV6NK
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandGroup.dia
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Version.d
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/target-graph.txt
  - .build/out/v5/records/GG/AEObjects.h-305KKR8OL76GG
  - .build/out/v5/records/3W/spawn.h-3ELUPCS50SA3W
  - .build/out/v5/records/JD/NSURLProtectionSpace.h-3P079NJU7SCJD
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/5b1954d8f0d04b305e8270190e18b2c3
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/os_workgroup-2MV8OP7R98AN8.pcm
  - .build/out/v5/records/FD/_rune_t.h-2EX2ELYQ68HFD
  - .build/out/v5/records/RH/IOStreamShared.h-1B991I513ZTRH
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_Builtin_stdbool-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/LR/NSTimer.h-3M5QAHE1G8QLR
  - .build/out/v5/records/V9/SecAccessControl.h-27X3NDKFV2OV9
  - .build/out/v5/records/PB/OSCacheControl.h-S5WQ2HGYR0PB
  - .build/out/v5/records/EQ/bootp.h-O6YHV3GA91EQ
  - .build/out/v5/records/3A/UniqueNamesValidator.swift-2221QH4EI6L3A
  - .build/out/v5/records/T2/_fsid_t.h-1CULW1KPTLOT2
  - .build/out/v5/units/string_h-96PF2DVGXLEPQAUNH9EVGXGE3.pcm-1KFU8P53N0TUR
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit.swiftdoc
  - .build/out/v5/records/FB/NSScriptSuiteRegistry.h-VUTDKJ3LN0FB
  - .build/out/v5/records/RT/NSISO8601DateFormatter.h-2X44YUA0P9JRT
  - .build/out/ModuleCache.noindex/V625515Z2F2L/SwiftShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/7L/NSAffineTransform.h-2UK3IXL0L57L
  - .build/out/v5/records/LX/AEHelpers.h-VVIWWXQ2IULX
  - .build/out/v5/records/RB/SwiftExtensions.swift-2PAL7ZF8W3IRB
  - .build/out/v5/records/T8/base.h-1C8R6AOVBA9T8
  - .build/out/v5/records/GB/IOSCSIMultimediaCommandsDevice.h-2F71F3KH0X5GB
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CommandRun.o
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-2ETBTJ92188J3
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_AvailabilityInternal-2YSBQADOLX02V.pcm
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/build-request.json
  - .build/out/v5/records/CP/audit_internal.h-2RULHCQ8VFVCP
  - .build/out/v5/records/G5/NSDateInterval.h-2MY3HC3NSL0G5
  - .build/out/v5/records/3Y/if_var_status.h-1RIZEO7GD8D3Y
  - .build/out/v5/units/_Builtin_limits-1EH2FNH5749LLDUS3YS9CK1I6.pcm-3PVQ2PL0A4U38
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/tschema-check.xcent.der
  - .build/out/v5/records/1J/mig_errors.h-1H683TTQ6QG1J
  - .build/out/v5/records/F7/_guid_t.h-3EHDQN3U7L2F7
  - .build/out/v5/records/IW/IOAccelTypes.h-1Y808RWE432IW
  - .build/out/v5/records/3O/Argument.swift-2M4UC7G8Q7M3O
  - .build/out/v5/records/H8/NSError.h-KHEQLS5JB5H8
  - .build/out/v5/records/E9/CFProxySupport.h-14G01IQ2A9TE9
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_DarwinFoundation2-3J4ZFA06I5V1P.pcm
  - .build/out/v5/records/GO/debug.h-281ZUAE1KC2GO
  - .build/out/v5/units/Option.o-3VMWW212TFG4M
  - .build/out/v5/records/20/NSURLCache.h-LP62RIS4MV20
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParentCommand.swiftdeps
  - .build/out/v5/records/TR/Math64.h-1ON3MHXHHQHTR
  - .build/out/v5/records/QH/Collections.h-30PUO3BAOD9QH
  - .build/out/v5/records/36/ReadingOrderTests.swift-2O3GE1EG1B036
  - .build/out/v5/records/KA/fmtmsg.h-3GM282SX335KA
  - .build/plugins/cache/GenerateDoccReference.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/StringExtensions.d
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_Builtin_float-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/ZH/NSXMLDTDNode.h-1UOH7X53S0ZH
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/sys_types-3J4ZFA06I5V1P.pcm
  - .build/out/v5/records/J6/IOKitKeys.h-16FU8N30LZ3J6
  - .build/out/v5/records/XX/ldsyms.h-1IMM53TV5CMXX
  - .build/out/v5/units/arm64-apple-macos.swiftinterface-TC2467I5MCQ3
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionKind.dia
  - .build/out/v5/records/4Q/alloca.h-3KNR9B03K614Q
  - .build/out/v5/records/GE/_fsobj_id_t.h-CS7Y49BG1FGE
  - .build/out/v5/records/VZ/NSDecimal.h-13KM3ALPSH8VZ
  - .build/out/v5/records/GW/arm64-apple-macos.swiftinterface-HDMCTJ3OTWGW
  - .build/out/v5/units/Version.o-1ELW79QS13FKV
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/LedgerReader.swiftconstvalues
  - .build/out/v5/records/CR/_ucontext.h-Y29RY7RRL3CR
  - .build/out/v5/records/XM/IOCDPartitionScheme.h-2L1GLTVS8BRXM
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-3FYERVHA3QPAJ
  - .build/out/v5/records/3C/NSUbiquitousKeyValueStore.h-1RQDT2FLQ1Z3C
  - .build/out/SDKExplicitPrecompiledModules/os_object-1E8JNT1TGYQ0K6UE4L00KSJ5J.pcm
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CommandRun.swiftdeps
  - .build/out/Products/Debug/ArgumentParser.swiftmodule/Project/arm64-apple-macos.swiftsourceinfo
  - .build/out/v5/records/17/_string.h-2MXOCFGBJGM17
  - .build/out/v5/records/OO/_suseconds_t.h-67FXSHAT6LOO
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/IOKit-1IAL9NTK1TABA.pcm
  - .build/out/v5/records/AS/NSPredicate.h-2XSPBQPUFT3AS
  - .build/out/v5/records/CL/IOKitLib.h-2CCL5UZTRB5CL
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions.swiftdoc
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-3
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-13
  - .build/out/v5/records/QM/cssmtype.h-P99HR65TP2QM
  - .build/out/v5/records/Y1/LSInfo.h-6DXUP2MDEVY1
  - .build/plugins/cache/GenerateManual.dSYM/Contents/Resources/Relocations/aarch64/GenerateManual.yml
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/aa6e09c5d6a35e10c5f9fa522f6c5c71
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_DarwinFoundation2-3J4ZFA06I5V1P.pcm
  - .build/out/Intermediates.noindex/GeneratedModuleMaps/ArgumentParser.modulemap
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/6f60e95553fce434159e54d0b9d59770
  - .build/out/v5/records/4E/_pthread_types.h-1TFD567F6KM4E
  - .build/out/v5/records/AG/_types.h-21IPYP8FLW8AG
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-4
  - .build/out/v5/records/L2/InputKey.swift-FKDE93IXNUL2
  - .build/out/v5/records/TH/fts_compat.h-YK5L5UBX8NTH
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandConfiguration.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputKey.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Mutex.swiftconstvalues
  - .build/out/v5/records/EF/__stddef_null.h-XEL48OJUZLEF
  - .build/out/v5/records/3Z/arm64e-apple-macos.swiftinterface-2ERNL5MCXKW3Z
  - .build/out/v5/records/JH/ParentCommand.swift-2QWTSIMSLH5JH
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/ptrauth-2OQWMRBVRD4OJ.pcm
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/2a470153fc8b923cf29a9f596b547976
  - .build/out/v5/records/WG/ndbm.h-2U9L172NPZJWG
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpCommand.swiftdeps
  - .build/out/v5/records/TC/CFData.h-11AETK2NXWHTC
  - .build/out/v5/records/UM/_pthread_t.h-1BZJ7FHWXOJUM
  - .build/out/v5/records/E3/acl.h-3H4OP1WYTI5E3
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsedValues.dia
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/ObjectiveC-1G8H182PQX3QE.pcm
  - .build/out/v5/units/CiteOrder.o-1X6X900I1MHE3
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentSet.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArgumentsValidation.o
  - .build/out/v5/records/NW/thread_info.h-3KPSWJU4D1KNW
  - .build/out/v5/records/IS/data.h-VDPF7OC87TIS
  - .build/out/v5/records/5Y/igmp.h-HUO8NOK7M25Y
  - .build/out/v5/records/H1/arm64e-apple-macos.swiftinterface-3O7WJLDV6YFH1
  - .build/out/v5/records/37/_limits.h-2P3C38C86YZ37
  - .build/out/v5/records/2H/IOAudioTypes.h-3L0TTW6N1992H
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/046d1762327780dea41fdbeb762dd77f
  - .build/out/v5/records/HW/ArgumentDefinition.swift-2AOQ0LO4NOHHW
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/FishCompletionsGenerator.o
  - .build/out/v5/records/DF/mbuf.h-3I2EV0L4J6NDF
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/DiskArbitration-3LBJF5I58QD8.pcm
  - .build/out/v5/records/85/IOHIDShared.h-29636WKI6KJ85
  - .build/out/v5/records/JE/oidsattr.h-1MGNNNIH6SWJE
  - .build/out/ModuleCache.noindex/Session.modulevalidation
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/ptrauth-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/units/Errors.o-MLN5XWOXE32O
  - .build/out/v5/units/ParentCommand.o-25FBE6TPWFSZG
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputKey.swiftconstvalues
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/aa78d11ca0af6397238de8ca9c8c1226
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/CoreFoundation-16SA8WK3L6MQN.pcm
  - .build/out/v5/records/V9/WSTypes.h-10A5N2FNFUQV9
  - .build/out/v5/records/KB/printerdb.h-17U5IVRQSJ0KB
  - .build/out/v5/records/QW/_common.h-2A7D8BS7YTYQW
  - .build/out/v5/records/T0/IOUSBLib.h-2IQBH4EWBLUT0
  - .build/out/v5/records/BF/hv_kern_types.h-2VLZOWD7CBQBF
  - .build/out/v5/records/TJ/NSAppleEventDescriptor.h-FW4JI6DVPFTJ
  - .build/out/v5/records/8R/USBSpec.h-3QKO824IYZB8R
  - .build/out/v5/records/Z9/_s_ifmt.h-12HWKFN1SAUZ9
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/046d1762327780dea41fdbeb762dd77f
  - .build/out/v5/records/ZB/_pthread_mutex_t.h-28S1WVUTFPXZB
  - .build/out/v5/units/ReadingOrderTests.o-5UTGXY4R73PJ
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/pre-commit.sample
  - .build/out/v5/records/41/OSThermalNotification.h-X6Y5JCQTKJ41
  - .build/out/v5/records/4I/mach_init.h-39ZBRTKZAQH4I
  - .build/out/v5/records/7Z/security_config.h-3DMJK26SZLB7Z
  - .build/out/v5/records/BY/_ucontext64.h-1SBDKD4NF6HBY
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CodingKeyValidator.o
  - .build/out/Products/Debug/PropositionsKitTests.swiftmodule/arm64-apple-macos.abi.json
  - .build/out/v5/records/0G/iconv.h-YQILD3DQ7B0G
  - .build/out/v5/units/XPC-18JXR4ULGTJV3OA1FH4YCFJNC.pcm-30D4IFXQG8TLB
  - .build/out/v5/records/KU/arm64e-apple-macos.swiftinterface-1SRUIKMBCY1KU
  - .build/out/v5/records/UD/SecCertificateOIDs.h-17EDKY2Z8JZUD
  - .build/out/v5/records/11/mach_debug_types.h-34D65KZJXHA11
  - .build/out/v5/records/AZ/netport.h-394X6CW6TPJAZ
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/string_h-47SZ9A199RUD.pcm
  - .build/out/v5/records/TV/OSSpinLockDeprecated.h-17D5XNF9354TV
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArgumentsValidation.swiftdeps
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/aa6e09c5d6a35e10c5f9fa522f6c5c71
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/MessageInfo.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CodingKeyValidator.swiftdeps
  - .build/out/v5/records/2P/NSFileCoordinator.h-1V12QC9JSQ12P
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_SwiftConcurrencyShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/2C/AvailabilityMacros.h-O62746WG9B2C
  - .build/out/v5/records/DL/_intptr_t.h-RZ0HBUYH6XDL
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/46c5b95d370377562ae3cfc4dd5dca5d
  - .build/out/v5/records/LA/if_ether.h-19LKX3SD72RLA
  - .build/out/v5/records/W9/statvfs.h-R1CIZP372BW9
  - .build/out/v5/records/J0/_uintptr_t.h-3AIKHMCKYW0J0
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-30M3H2AMQCOMX
  - .build/out/v5/units/AsyncCompletionsValidator.o-2Z6P27N0X8CZR
  - .build/out/v5/records/F3/NSXMLNodeOptions.h-1ZWX6WPCNR2F3
  - .build/out/v5/records/ZO/CFXMLParser.h-31IID0GY0ACZO
  - .build/out/v5/records/OM/_langinfo.h-1AKHCV1V920OM
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParserError.dia
  - .build/out/v5/records/JV/NSUndoManager.h-3U1AGZH2C57JV
  - .build/out/v5/records/GY/IOCFSerialize.h-1LFLK0N8158GY
  - .build/out/v5/records/RB/UnicodeConverter.h-3AJ0EEXVU6MRB
  - .build/out/v5/records/OD/thread_status.h-XL8VN5YDEJOD
  - .build/out/v5/records/BA/SecItem.h-34SR8IGMKEDBA
  - .build/out/v5/records/VU/CFSocket.h-34GTCW5ITB1VU
  - .build/out/v5/records/SC/SecKeychainItem.h-3V2BDWCQ8VXSC
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests-primary-emit-module.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentVisibility.o
  - .build/out/v5/records/GT/appleapiopts.h-3ITOOK4VH6MGT
  - .build/out/v5/records/KU/NSPointerArray.h-3COIPGW88P2KU
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-15
  - .build/out/v5/records/T4/tty.h-1O588E9BUCGT4
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDiscussion.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncCompletionsValidator.o
  - .build/out/v5/records/MZ/__float_infinity_nan.h-2K082V914N7MZ
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_SwiftConcurrencyShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/MH/_wint_t.h-3AKPTTYEK6HMH
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/SwiftShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/2U/NSPortCoder.h-2HDWG51F2WE2U
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDiscussion.dia
  - .build/out/v5/records/Z4/CFCGTypes.h-CZ3Y3OQ5UXZ4
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema-check.LinkFileList
  - .build/out/v5/records/RQ/arm64e-apple-macos.swiftinterface-1R3IMRLGB5URQ
  - .build/out/v5/units/CFNetwork-DQRKHVVBTLI4WXXPNWLZKDNIP.pcm-2RBEDB8QBQ87Y
  - .build/out/v5/units/IOKit-23D6FY6PZKBO5MMW8CEGW26OE.pcm-9LW6Y0CDQ1XN
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SplitArguments.dia
  - .build/out/v5/records/2L/TextCommon.h-23STLRPS2AO2L
  - .build/out/v5/records/H7/OSByteOrder.h-LIHQEK988PH7
  - .build/out/v5/units/DiskArbitration-49QYQIKFX5REPFQQGP8Q3AUKV.pcm-20PRGPZMTHGLB
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/ReadingOrderTests.swiftdeps
  - .build/out/v5/records/CP/IOEthernetInterface.h-BO9GJSMKJNCP
  - .build/out/v5/units/CommandRun.o-26EPS3A73PKTZ
  - .build/out/v5/records/KR/NSLengthFormatter.h-1FL1031O7XPKR
  - .build/out/v5/records/76/IOTypes.h-1Q5LWSR1B0776
  - .build/out/v5/records/2W/wait.h-YYKGGNGPYZ2W
  - .build/out/v5/records/ND/SecPolicySearch.h-3IHBEEB3FWFND
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/DumpHelpGenerator.dia
  - .build/out/Products/Debug/ArgumentParserToolInfo.swiftmodule/arm64-apple-macos.swiftmodule
  - .build/out/v5/records/AL/_wchar.h-9ZWNFPO24ZAL
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/main.swiftdeps
  - .build/out/v5/records/AF/__stddef_nullptr_t.h-PZI2JELPAZAF
  - .build/out/v5/records/H4/OSTypes.h-2K0HJNPP8EAH4
  - .build/out/v5/records/M7/MDImporter.h-39S5Z45H46LM7
  - .build/out/v5/records/YV/vm_types.h-15AZFY6BAJYV
  - .build/out/v5/records/I9/_strings.h-1CYI0LJSD29I9
  - .build/out/v5/records/1B/if_dl.h-1MB4MFKU9AC1B
  - .build/out/v5/records/TS/NSInvocation.h-1V2XWWZXY71TS
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo-primary.priors
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionsGenerator.swiftconstvalues
  - .build/out/v5/records/4A/CodingKeyValidator.swift-TUHNQ95CKS4A
  - .build/out/v5/records/2K/malloc.h-12H1TEH1HHF2K
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit-Swift.h
  - .build/out/v5/records/G4/NSOperation.h-2IULUMYLOEGG4
  - .build/out/v5/records/GV/NSByteOrder.h-3UZFF94XQ5HGV
  - .build/out/v5/records/VD/_wctype.h-2YYVT5PEKBGVD
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-7
  - .build/out/v5/records/MH/types.h-2MW2TQ815JMH
  - .build/out/v5/records/EN/vm_region.h-253GAPUBG2KEN
  - .build/out/v5/records/B4/_regex.h-36II7NM3KBCB4
  - .build/out/v5/records/QP/IOUSBHostFamilyDefinitions.h-2DKP27KTEOMQP
  - .build/out/v5/records/SP/IOGUIDPartitionScheme.h-2EPCNYF8E4CSP
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Errors.swiftdeps
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/757f4a30810dc1167421c70c85e5301f
  - .build/out/v5/records/QA/objc-api.h-1M641QLUA1UQA
  - .build/out/v5/records/RD/CiteOrder.swift-2BPI0C8S1IBRD
  - .build/out/v5/records/TD/_bounds.h-QC6Z8QOCLSTD
  - .build/out/v5/records/JF/IOHIDDeviceTypes.h-1OGVPVZUBYWJF
  - .build/out/v5/records/E0/timeb.h-2RZ2G3VDUMTE0
  - .build/out/v5/records/L4/SecImportExport.h-2ZQYSZRDPHTL4
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UniqueNamesValidator.swiftdeps
  - .build/out/v5/records/UR/CFFTPStream.h-NPHAV10TCCUR
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/post-update.sample
  - .build/out/v5/records/C6/peer_requirement.h-2NYC3JDHI32C6
  - .build/out/v5/records/L5/arm64-apple-macos.swiftinterface-1JTET2U6XV1L5
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests-primary.priors
  - .build/out/v5/records/PD/fileport.h-28FAZUTOUEYPD
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/CoreFoundation-16SA8WK3L6MQN.pcm
  - .build/out/v5/records/NM/fixup-chains.h-B2CVD825ZVNM
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-14
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/sys_types-3J4ZFA06I5V1P.pcm
  - .build/out/v5/records/6O/stab.h-389DNZNIW8S6O
  - .build/out/v5/records/AM/CFFileDescriptor.h-3IIQXHFPVXKAM
  - .build/out/v5/records/BK/arch.h-K1C56A9FQ1BK
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit.SwiftFileList
  - .build/out/v5/records/TQ/TargetConditionals.h-BCLXZH78R8TQ
  - .build/out/Products/Debug/PropositionsKitTests.xctest/Contents/MacOS/PropositionsKitTests
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Foundation.d
  - .build/out/v5/records/1I/ptrauth.h-34I1VXM60711I
  - .build/out/v5/records/GI/IOBlockStorageDriver.h-3FA2ISLZP2GI
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/Propositions.d
  - .build/out/v5/records/94/_filesec_t.h-1FTX44XP15T94
  - .build/out/v5/records/46/NSSpellServer.h-1W1NQBF9SMJ46
  - .build/out/v5/records/OO/resourcevar.h-3IORAS1ZI9DOO
  - .build/out/v5/records/DN/ioctl_compat.h-375X7MJC9BXDN
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/libkern-2KQ0X67RTM1JF.pcm
  - .build/out/v5/records/7I/_sigaltstack.h-VG87BB390L7I
  - .build/out/v5/units/_Builtin_inttypes-9UNYHE2QFFWX04RQLVMY53IEB.pcm-1VYI6BN8SUSPE
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/DumpHelpGenerator.d
  - .build/out/v5/records/DZ/dyld.h-2797ZJV8E5UDZ
  - .build/out/v5/records/IL/buf.h-5TA1S26VV7IL
  - .build/out/v5/records/HY/NSBundle.h-1AW1TJ5EOWUHY
  - .build/out/v5/units/ExpressibleByArgument.o-HEUG7F2SJJTN
  - .build/out/v5/records/FD/IntlResources.h-32YBF9ISPWZFD
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema-check_dependency_info.dat
  - .build/out/Products/Debug/ArgumentParser.swiftmodule/arm64-apple-macos.swiftdoc
  - .build/out/v5/records/H0/time_value.h-1HMCIU6YXZ9H0
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/MachO-20RPYVQSX341K.pcm
  - .build/out/v5/records/8Z/Propositions.swift-31MRLH3RYI68Z
  - .build/out/v5/records/60/thread_policy.h-3SGXCLYLA4W60
  - .build/out/v5/records/1I/SecKey.h-10DRJMOZ2M01I
  - .build/out/v5/records/7E/getopt.h-2MZF35QQ55K7E
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/aa78d11ca0af6397238de8ca9c8c1226
  - .build/out/v5/records/J7/IODataQueueClient.h-3UCTYQ69M1SJ7
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/227b782cb6eaf03396d3c6fe8b65c221
  - .build/out/v5/records/JU/_locale.h-3D53YSZ4BQQJU
  - .build/out/v5/records/P8/_timeval64.h-MGP0EBZG2P8
  - .build/out/v5/records/T2/NSEnumerator.h-3UHWM3W95JQT2
  - .build/out/v5/records/MP/udp.h-2I82RDASYY9MP
  - .build/out/v5/records/19/LSConstants.h-NLEVO9N0Y519
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/task-store.msgpack
  - .build/out/v5/records/8S/__stdarg_va_list.h-3TL5I7T0WTP8S
  - .build/out/v5/records/DU/NonsenseFlagsValidator.swift-1Y44NIR4Y1BDU
  - .build/out/v5/records/IK/SecTrust.h-USZ5NWHL83IK
  - .build/out/v5/records/BQ/_types.h-1412OVHMI6BBQ
  - .build/out/v5/records/LE/vm_map.h-2CSE59GO075LE
  - .build/out/v5/records/8J/NSRelativeDateTimeFormatter.h-12VBVQAH8AY8J
  - .build/out/v5/units/Flag.o-3TUF6K0US9WKM
  - .build/out/v5/records/OP/IOSharedLock.h-3IQF3G6PBNWOP
  - .build/out/v5/records/9E/CFStringTokenizer.h-3JB5LUZ9HPF9E
  - .build/out/v5/records/T9/clock_types.h-3463DCVFLF9T9
  - .build/out/SDKExplicitPrecompiledModules/os_workgroup-4EK4PUHNCCBES9QHV2BNNHF19.pcm
  - .build/out/v5/records/VN/arm64e-apple-macos.swiftinterface-2OPBIJBBBFGVN
  - .build/out/v5/records/MJ/NSPredicateValidating.h-2QPFP7GPH3OMJ
  - .build/out/SDKExplicitPrecompiledModules/os-AUWM69TNX15YTU2OKOJV2GDO5.pcm
  - .build/out/v5/records/F4/source.h-1U6CXNDP797F4
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/IOKit-1IAL9NTK1TABA.pcm
  - .build/out/v5/records/7Q/clonefile.h-1OUSNSG0BGV7Q
  - .build/out/v5/records/E9/NSXMLParser.h-2E270N7KUXFE9
  - .build/out/v5/records/TQ/tar.h-HALLC6LE46TQ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-2
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SequenceExtensions.dia
  - .build/out/SDKStatCaches.noindex/macosx27.2-26B118-d56355c2f463f349a93388c94f7bc0b5a7ff82d74745d5ef33555b35c4238456.sdkstatcache
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/string_h-47SZ9A199RUD.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableCommand.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/PositionalArgumentsValidator.d
  - .build/out/v5/records/YJ/NSMassFormatter.h-1H217T0NS1JYJ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-5
  - .build/out/v5/records/FQ/IOAccelClientConnect.h-2TX9OB2WUMWFQ
  - .build/out/v5/records/G9/memory_entry.h-2B8O1721TUIG9
  - .build/out/v5/records/H5/OSDebug.h-F3PWZOY7ZHH5
  - .build/out/v5/records/AJ/CSIdentity.h-3C7K4MQRFFZAJ
  - .build/out/v5/records/M1/arm64e-apple-macos.swiftinterface-38KVLIIXNHTM1
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/4c4489b2d9c6962f0e11f113fabeda8d
  - .build/out/v5/records/EH/EnumerableFlag.swift-1AV6IZQVWHGEH
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/fb4985d8c4b099a564da7b3f99d8a7de
  - .build/out/v5/records/SR/filedesc.h-LTBWTIGQI7SR
  - .build/plugins/cache/GenerateManual-state.json
  - .build/out/v5/records/CI/rpc.h-31XRH0XK7IECI
  - .build/out/v5/records/KB/mach_error.h-1IWYXGMD968KB
  - .build/out/v5/records/PH/_size_t.h-2DIE3BNGF2HPH
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/manifest.json
  - .build/out/v5/records/30/Finder.h-6MZ485ELHB30
  - .build/out/v5/records/LO/stdbool.h-1TBOA4V1O4GLO
  - .build/out/v5/records/C4/SecTask.h-3POAWFJVHWJC4
  - .build/out/v5/records/RR/reloc.h-E9BYTDA3OERR
  - .build/out/v5/records/7E/NSProtocolChecker.h-RGS22H1K6C7E
  - .build/out/v5/records/IW/CoreFoundation.h-RMHS7O65L8IW
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SequenceExtensions.o
  - .build/out/v5/records/FX/vm_purgable.h-ZYVYIERNZAFX
  - .build/out/v5/records/XY/CFMachPort.h-1ZCWDNMPKQFXY
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/LedgerReader.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Mutex.o
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/libkern-2KQ0X67RTM1JF.pcm
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/b43efc36174e9b45f962bbd971cedb8a
  - .build/out/SDKExplicitPrecompiledModules/libkern-76FYW2YP7DQQXX90XDE4BK26U.pcm
  - .build/out/v5/records/AQ/CFHost.h-1XJ600SDU2OAQ
  - .build/out/Products/Debug/propositions
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_SwiftConcurrencyShims-2IMTS4WWRU7VJ.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ExpressibleByArgument.o
  - .build/out/SDKExplicitPrecompiledModules/_Builtin_stdatomic-DO845EHCQE4IDH8UTOURJRCTG.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/supplementaryOutputs-8
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions.swiftmodule
  - .build/out/v5/records/11/_pthread_key_t.h-J7REKIFS2F11
  - .build/out/v5/records/9Q/stdatomic.h-3APXXH54L719Q
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ToolInfo.dia
  - .build/out/v5/records/7J/NSObjectScripting.h-1IN3S5OWD2K7J
  - .build/out/v5/records/G0/_param.h-ZWE95B89NYG0
  - .build/out/v5/records/UN/tcp_seq.h-25ZTWMQHI6UUN
  - .build/out/v5/records/6E/IOCDMedia.h-5JWA0GRBB16E
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser.abi.json
  - .build/out/v5/records/Y8/NSDateComponentsFormatter.h-1CMTD0HNL6XY8
  - .build/out/v5/records/R3/StringExtensions.swift-1TADDRVVK7RR3
  - .build/out/Products/Debug/ArgumentParser.swiftmodule/arm64-apple-macos.swiftmodule
  - .build/out/v5/records/6F/semaphore.h-1J3YQHOUEQC6F
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser-primary-emit-module.d
  - .build/out/v5/records/6C/_mbstate_t.h-1DVIOTQDCQD6C
  - .build/out/v5/records/77/SecCertificate.h-3MV54FY64L477
  - .build/out/v5/records/S7/poll.h-3D2J6AZEE1ZS7
  - .build/out/v5/records/T1/glob.h-1ICZXAHYHG5T1
  - .build/out/v5/records/OJ/err.h-3SI1P8CGUUVOJ
  - .build/out/v5/units/Platform.o-1L7AA4HABYI27
  - .build/out/v5/records/88/if_arp.h-2YI9LB5S3AN88
  - .build/out/v5/records/AE/lockdown_mode.h-1T63N1ZM9BRAE
  - .build/plugins/cache/GenerateDoccReference.dSYM/Contents/Resources/Relocations/aarch64/GenerateDoccReference.yml
  - .build/out/Products/Debug/ArgumentParserToolInfo.swiftmodule/arm64-apple-macos.abi.json
  - .build/out/v5/records/F0/_strings.h-PN2XMI1TXF0
  - .build/out/SDKExplicitPrecompiledModules/Foundation-C3DT04I57JMCQQT95RI0RIBX9.pcm
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/os-2MV8OP7R98AN8.pcm
  - .build/out/v5/units/MachO-ASEAY7TNY43R7749UO83G95VR.pcm-35E6XKRBLO1EZ
  - .build/out/v5/records/DU/stdio.h-NT0UHZLYG8DU
  - .build/out/v5/records/ZG/param.h-30A0KZP4JSZZG
  - .build/out/SDKExplicitPrecompiledModules/_AvailabilityInternal-3OILYF0SRAMVE7C1OBGI8F7SH.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UsageGenerator.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Parsed.o
  - .build/out/v5/records/T5/_uid_t.h-2LYC3XYB7D8T5
  - .build/out/v5/units/EnumerableFlag.o-16VN3SW3FD4IJ
  - .build/out/v5/records/QX/NSExtensionItem.h-VH3U61KF8OQX
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Platform.d
  - .build/out/v5/records/00/Platform.swift-22WJB8MKOHR00
  - .build/out/v5/records/H4/ToolUtils.h-H6L00ZYYNSH4
  - .build/out/v5/records/MV/NSNull.h-VSHZU397L7MV
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpGenerator.o
  - .build/out/v5/records/IH/_posix_availability.h-2HCVA4MYO2DIH
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/ptrcheck-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/KN/ranlib.h-NRXX6ORQTRKN
  - .build/out/v5/records/KM/__float_float.h-35PIKQLS43DKM
  - .build/out/v5/records/DR/thread_status.h-1PZN75K7JXQDR
  - .build/out/v5/records/M2/_pthread_rwlock_t.h-D4SHZJTDCLM2
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-15FDSV0RNA7J4
  - .build/out/v5/records/BT/pipe.h-3GCGI1Z2L30BT
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UsageGenerator.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema-check-primary-emit-module.d
  - .build/out/v5/records/PH/signal.h-3EUZHENASIUPH
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParserError.swiftconstvalues
  - .build/out/v5/records/D9/IOVideoDeviceShared.h-1VJYYNF4EVLD9
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SwiftExtensions.dia
  - .build/out/Products/Debug/ArgumentParserToolInfo.swiftmodule/arm64-apple-macos.swiftdoc
  - .build/out/v5/records/SN/NSURLError.h-3BETNC8YGD4SN
  - .build/out/v5/records/29/UnicodeUtilities.h-PKWHZN999029
  - .build/out/v5/records/LQ/NSScriptCommandDescription.h-1ZDK4XHJNQ5LQ
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/ReadingOrder.o
  - .build/out/v5/records/3U/audit_filter.h-133ZUR56NS03U
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Location.swiftdeps
  - .build/out/v5/records/3F/PLStringFuncs.h-37P2QCGI4BZ3F
  - .build/out/v5/records/IL/objc-exception.h-O8WMV7DKAIL
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests.SwiftFileList
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CodingKeyValidator.dia
  - .build/out/v5/records/J8/NSAttributedString.h-1MYDP6MR6Q1J8
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/ReadingOrder.d
  - .build/out/v5/records/EA/un.h-LKAWW0JZZTEA
  - .build/out/v5/records/1H/BashCompletionsGenerator.swift-3ELOACZDOYY1H
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/aa6e09c5d6a35e10c5f9fa522f6c5c71
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDefinition.o
  - .build/out/v5/records/XM/syscall.h-18FUUYJHAP4XM
  - .build/out/v5/records/X7/launch.h-UFIX2EEKMKX7
  - .build/out/v5/records/E7/CommandGroup.swift-IUS1GQBLIPE7
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Argument.swiftconstvalues
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/f26bec36a172fe818fae42bf57d98d44
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/target-graph.txt
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/Support.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SplitArguments.swiftdeps
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/ptrcheck-2OQWMRBVRD4OJ.pcm
  - .build/out/SDKExplicitPrecompiledModules/_Builtin_stdbool-1BZW2YIRGDSI04EXV7CLLG91F.pcm
  - .build/out/v5/records/99/session.h-1R8A9V7N1BE99
  - .build/out/v5/units/main.o-3RGDCNP038P17
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests-dependency-scan.dia
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/CoreFoundation-16SA8WK3L6MQN.pcm
  - .build/out/v5/records/5O/IOPM.h-2HC6WQ5C3795O
  - .build/out/v5/records/CZ/getsect.h-3L1PJXQ9H6SCZ
  - .build/out/v5/records/UL/WSMethodInvocation.h-1HNB6EDC8HRUL
  - .build/out/v5/records/YT/dyld_images.h-13OYZRBJEKTYT
  - .build/out/v5/records/JG/_nlink_t.h-3ED2UEP62POJG
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/fsmonitor-watchman.sample
  - .build/out/v5/records/A1/lockgroup_info.h-2U81RZ1RXVVA1
  - .build/out/v5/records/EM/SecProtocolOptions.h-GK1VQGMXSCEM
  - .build/out/v5/records/XW/HelpGenerator.swift-215PXPKXE83XW
  - .build/out/v5/records/IM/cssmapple.h-2JLB3GTI3RKIM
  - .build/out/v5/records/1F/CMSEncoder.h-2STBUFSK4CI1F
  - .build/out/v5/records/Z2/SecAsn1Coder.h-252J56ACK5NZ2
  - .build/out/v5/records/M1/NSPathUtilities.h-TCR9MM5U3NM1
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/libDER-26DYHF6GC6WWA.pcm
  - .build/out/v5/records/VJ/host_notify.h-2FK0JHSZA55VJ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Option.o
  - .build/out/v5/records/GI/_vnode_t.h-3U4OBQLN4MDGI
  - .build/out/v5/units/arm64-apple-macos.swiftinterface-39VK0KN89GHE3
  - .build/out/v5/records/6E/NSRange.h-2PKSOHXPT2U6E
  - .build/out/v5/records/JS/emmtype.h-2SZ4BCGBMAJS
  - .build/out/v5/records/9Y/CFTree.h-2C9ONK16L6M9Y
  - .build/out/v5/units/SwiftExtensions.o-1G7AEIPQ2MVWU
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CommandRun.dia
  - .build/out/v5/units/ArgumentDecoder.o-10X4MJ9MQ2VSZ
  - .build/out/v5/records/O1/filio.h-2AHZBJ1LNJ7O1
  - .build/out/v5/records/TN/shared_region.h-KWRVRWNW3TTN
  - .build/out/v5/records/UM/NSUserDefaults.h-1V1M77G9MEXUM
  - .build/out/v5/records/O4/CFByteOrder.h-1PX35BQKGFGO4
  - .build/out/v5/records/LI/lock.h-3B9MPD6D3ZZLI
  - .build/out/v5/records/R7/task_inspect.h-VAFQTDZORBR7
  - .build/out/v5/records/2C/tcp_var.h-FUB4WG0QYO2C
  - .build/out/v5/records/DG/_uuid_t.h-22MPX5GE39VDG
  - .build/out/v5/records/IW/__xlocale.h-23OTWEN2PLTIW
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit-dependency-scan.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo-primary-emit-module.dia
  - .build/out/v5/records/2S/NSURLCredentialStorage.h-1J3WNAIJ72L2S
  - .build/out/v5/records/SI/LSSharedFileList.h-TJ5CIQK4XOSI
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Argument.dia
  - .build/out/v5/records/ZY/IOHIDManager.h-1UY56COXEG2ZY
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-3RNP8JDEZHJ7A
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UsageGenerator.d
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/CFNetwork-1PNPO1ORVQZLS.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDefinition.swiftconstvalues
  - .build/out/v5/records/NL/_ctype.h-1528JOSV6LHNL
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/9d470f0fe97cb62b8315c162b2f900cf
  - .build/out/v5/records/BJ/fasttrap_isa.h-3MZQHRJEVZPBJ
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CiteOrder.o
  - .build/out/v5/records/CD/DateTimeUtils.h-1FDYIK1EEPHCD
  - .build/out/v5/records/DH/utils.h-3NGNV42EJ0YDH
  - .build/out/v5/records/H3/IOReturn.h-MHLV6IRR78H3
  - .build/out/v5/records/XG/grp.h-GI865IO248XG
  - .build/out/v5/records/WI/dirent.h-DP97TXQISJWI
  - .build/out/Intermediates.noindex/XCBuildData/prior-build-descriptions.txt
  - .build/out/v5/records/FP/NSComparisonPredicate.h-2TF3HQZPTGMFP
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/description.msgpack
  - .build/out/v5/records/BX/fat.h-133L3SUC57YBX
  - .build/out/v5/records/4Q/eti.h-1PLS9Y05IVZ4Q
  - .build/out/v5/records/DJ/IONetworkMedium.h-7WVW0TC160DJ
  - .build/out/v5/units/CommandGroup.o-3U11AKOLYDGBN
  - .build/out/v5/records/0I/utime.h-1AQFO1E3V930I
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/CoreFoundation-16SA8WK3L6MQN.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandParser.o
  - .build/out/v5/records/2K/_in_addr_t.h-1C5M88AWOFG2K
  - .build/out/v5/records/N5/arm64e-apple-macos.swiftinterface-Y5EFO8OR02N5
  - .build/out/v5/records/BE/HFSVolumes.h-1AGCLVOJTSTBE
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/CoreServices-39NCTJOEW7PQ2.pcm
  - .build/out/v5/records/WK/CFPlugInCOM.h-15V2J7N4JH0WK
  - .build/out/v5/units/HelpGenerator.o-3H73A37A29LM3
  - .build/out/SDKExplicitPrecompiledModules/_Builtin_stdint-92UYWGR28ZMTKKBURO53CL0KZ.pcm
  - .build/out/v5/records/6G/exc.h-1I056SHIEW96G
  - .build/out/v5/records/RF/Timer.h-PR00Y107MURF
  - .build/out/v5/units/PositionalArgumentsValidator.o-1796F3UAJ7LNQ
  - .build/out/v5/records/7K/NSUUID.h-21YP98RJHCF7K
  - .build/out/v5/records/YE/MDItem.h-25WOJKPLTSKYE
  - .build/out/v5/units/CompletionsGenerator.o-112EQIEGMBZQO
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/prepare-commit-msg.sample
  - .build/out/v5/records/0A/ArgumentDiscussion.swift-2B7K9IBWIFF0A
  - .build/out/v5/records/S8/SecRandom.h-2OI48NF3M6RS8
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDecoder.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ZshCompletionsGenerator.d
  - .build/out/v5/records/0K/NSURLProtocol.h-25764RXW7XZ0K
  - .build/out/v5/records/7X/NSMeasurement.h-356EE2MCLEF7X
  - .build/out/v5/records/U8/tgmath.h-1IODXDZZ7Q6U8
  - .build/out/v5/units/_DarwinFoundation1-2M6XWCKKYNUKUFG1RP3HU5G95.pcm-216ZZC9L5ASF7
  - .build/out/v5/records/N7/SecTransform.h-2VZ8LS535CTN7
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/EnumerableFlag.o
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/main.d
  - .build/out/SDKExplicitPrecompiledModules/_DarwinFoundation1-2M6XWCKKYNUKUFG1RP3HU5G95.pcm
  - .build/out/v5/records/09/ev.h-3ERO722AEKC09
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/03cd2f611fa53e83f3ed19a9ff7c5c8d
  - .build/out/v5/records/CW/select.h-T7CUQ5R9BXCW
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions.abi.json
  - .build/out/v5/records/MZ/ndrv.h-1V72NPCZSU4MZ
  - .build/out/v5/records/KL/sdt_isa.h-1VREDZXGE7YKL
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/ptrauth-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/82/SecCustomTransform.h-1L9L4VVPQOS82
  - .build/out/v5/records/WG/IOVideoDeviceLib.h-31PN5B207MWG
  - .build/out/v5/records/UZ/CiteOrder.swift-348STF9W8F4UZ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncCompletionsValidator.swiftdeps
  - .build/out/CompilationCache.noindex/generic/v1.1/actions.v1
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_Builtin_inttypes-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/6J/NSMetadata.h-1OTSM4FPXCB6J
  - .build/out/v5/records/4V/group.h-BQ4V7PU4TS4V
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Version.dia
  - .build/out/v5/records/7P/CFDictionary.h-5JUSRLM1D87P
  - .build/out/v5/records/M5/termios.h-NGI0QGB9PM5
  - .build/out/v5/units/ParsableArguments.o-2DXCUU83ZL4N
  - .build/out/v5/records/YT/CFURL.h-31IUVDSAWS3YT
  - .build/out/v5/records/7B/_mode_t.h-18C4NLC69NB7B
  - .build/out/v5/records/DJ/IOGraphicsLib.h-1XS1PDD2DO7DJ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser-Swift.h
  - .build/out/v5/records/NR/IOBDTypes.h-9WT7QBMG0NR
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ZshCompletionsGenerator.dia
  - .build/out/v5/records/BJ/fenv.h-3TCE6HUK98BBJ
  - .build/out/v5/records/98/audit_session.h-111AOG9Q2LB98
  - .build/out/v5/records/BJ/NSScriptCommand.h-3FCWNVRZJG6BJ
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/main.o
  - .build/out/v5/records/QY/NSXMLElement.h-2FYK449HQZWQY
  - .build/out/v5/units/SequenceExtensions.o-Q4T1RGZ3X7R5
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_SwiftConcurrencyShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/IX/certextensions.h-P40XZVSUSZIX
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/ptrcheck-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/51/NSTextCheckingResult.h-2YHO5ZTL12Y51
  - .build/out/v5/records/79/kern_control.h-2SI7QI7PSW179
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-19HZIO9DFC9BT
  - .build/out/v5/records/OZ/rbtree.h-3USKXMRPWDOZ
  - .build/out/v5/records/38/_in_port_t.h-2YGQAS0ID1738
  - .build/out/Intermediates.noindex/GeneratedModuleMaps/PropositionsKit.modulemap
  - .build/out/v5/records/N0/IOHIDDeviceKeys.h-1X8JN8NJG78N0
  - .build/out/v5/records/O9/ParserError.swift-2G5E1YL3GJ0O9
  - .build/out/v5/records/EC/arm64e-apple-macos.swiftinterface-1MXND8KV2U9EC
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/os_object-2MV8OP7R98AN8.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser.swiftmodule
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests.abi.json
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_DarwinFoundation2-3J4ZFA06I5V1P.pcm
  - .build/out/v5/records/BL/_wctype_t.h-3VBU123F7P4BL
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit_const_extract_protocols.json
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpCommand.swiftconstvalues
  - .build/out/v5/records/R7/_time.h-1TUFDNHS1L7R7
  - .build/out/v5/records/VL/unistd.h-38CUZ55YI22VL
  - .build/out/v5/records/D6/NSProgress.h-1NLS1ZOXNJYD6
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/os_object-2MV8OP7R98AN8.pcm
  - .build/out/v5/records/OC/audit_record.h-3AACR3E2ULLOC
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/target-graph.txt
  - .build/out/v5/records/1C/IOAppleLabelScheme.h-1WJQJS258CD1C
  - .build/out/v5/records/8W/proc.h-18TTM6SSWF38W
  - .build/out/v5/records/F6/sys_domain.h-XVUF2W07LCF6
  - .build/out/v5/records/L8/IOApplePartitionScheme.h-3LGP0XRBCRXL8
  - .build/out/v5/units/ParsableCommand.o-7G3G9LHJ6FE9
  - .build/out/v5/records/I0/fts.h-6J0F5EB9X7I0
  - .build/out/v5/records/II/SCSICmds_READ_CAPACITY_Definitions.h-2N3KQUU6F6JII
  - .build/out/v5/records/KA/_null.h-1KC2UXHVQ0QKA
  - .build/out/v5/units/BashCompletionsGenerator.o-IJBPGANGT5VN
  - .build/out/SDKExplicitPrecompiledModules/libDER-4Y866X1EXEYK6YF0BSCOCPU35.pcm
  - .build/out/v5/units/Foundation.o-Q7J6OZZYXO7Q
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/string_h-47SZ9A199RUD.pcm
  - .build/out/v5/records/NK/signal.h-T3U8URM76ZNK
  - .build/out/v5/records/FM/CFBinaryHeap.h-2NEFVOGQ5Y9FM
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/DumpHelpGenerator.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NameSpecification.swiftconstvalues
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/XPC-T0ZXCAST7PE3.pcm
  - .build/out/v5/records/A4/_symbol_aliasing.h-2VOEOVH6H5SA4
  - .build/out/v5/records/59/IOHIDServiceClient.h-2C32WNXQNSF59
  - .build/out/Products/Debug/PropositionsKit.swiftmodule/arm64-apple-macos.swiftdoc
  - .build/out/v5/records/YX/NSKeyValueSharedObservers.h-1XMJWSQH4LZYX
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/os_workgroup-2MV8OP7R98AN8.pcm
  - .build/out/v5/records/6Q/SecSignVerifyTransform.h-2FW1RUCY3XP6Q
  - .build/out/v5/records/OK/setjmp.h-1577B0MFJ0IOK
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/CiteOrder.dia
  - .build/out/v5/records/LO/IOStreamLib.h-3NAIMTVY5MELO
  - .build/plugins/cache/GenerateDoccReference.dSYM/Contents/Resources/DWARF/GenerateDoccReference
  - .build/out/v5/units/Foundation-C3DT04I57JMCQQT95RI0RIBX9.pcm-1A81UN9UR7XO7
  - .build/out/v5/records/BD/libbsm.h-2GPMSUTJR53BD
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema_check-dependency-scan.dia
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/IOKit-1IAL9NTK1TABA.pcm
  - .build/out/v5/records/HT/Parsed.swift-1OH9I82MZAVHT
  - .build/out/v5/records/9R/SecEncodeTransform.h-34R3BZ3E4189R
  - .build/out/v5/records/Y6/device_port.h-2XCK08B15NWY6
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser-primary.priors
  - .build/out/Intermediates.noindex/SwiftExplicitPrecompiledModules/modules.timestamp
  - .build/out/Intermediates.noindex/SwiftExplicitPrecompiledModules/Testing-2ZMTQ9N8I7LK8.swiftmodule
  - .build/out/v5/records/TF/MessageInfo.swift-2DAEP1IMAGATF
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableCommand.swiftdeps
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/sys_types-3J4ZFA06I5V1P.pcm
  - .build/out/v5/records/3G/task_info.h-2BART0M9G3G3G
  - .build/out/v5/records/GP/block.h-32ATMZNY8VKGP
  - .build/out/v5/units/InputOrigin.o-DZ421185FKVM
  - .build/out/v5/records/B8/MDQuery.h-2O810ZEXOJOB8
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo-OutputFileMap.json
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncCompletionsValidator.swiftconstvalues
  - .build/out/v5/records/9N/SecProtocolObject.h-21Q5FUF75NE9N
  - .build/out/v5/records/HM/route.h-3KQNONJSIKJHM
  - .build/out/v5/records/6W/fp.h-3836FHIZDRQ6W
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/libDER-26DYHF6GC6WWA.pcm
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_Builtin_limits-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/NP/NSURLSession.h-1K7CYNTBF0ENP
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/Darwin-1FXX23EKWOBA9.pcm
  - .build/out/v5/records/K2/_mach_port_t.h-RNHOROTXYAK2
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/Dispatch-R76HXUP80TVL.pcm
  - .build/out/v5/records/NB/unpcb.h-GXG2XGN19ANB
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/PositionalArgumentsValidator.o
  - .build/out/v5/records/2U/exception_types.h-3VZGRYNW1M92U
  - .build/out/v5/records/QL/NSMetadataAttributes.h-1YWY9GVIZRUQL
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/ReadingOrder.swiftdeps
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_DarwinFoundation2-3J4ZFA06I5V1P.pcm
  - .build/out/v5/records/36/NSAppleEventManager.h-33092CTI2QA36
  - .build/out/v5/records/FZ/NSNotificationQueue.h-2AS6LIYL4EXFZ
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/DiskArbitration-3LBJF5I58QD8.pcm
  - .build/out/v5/records/3B/if_var.h-2YPPKVIP5DI3B
  - .build/out/v5/records/GG/NSLock.h-29HDNW0C2SLGG
  - .build/out/v5/records/88/in_systm.h-17Z7ZWM3ZU888
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/launch-3T3BU4MASLMUM.pcm
  - .build/plugins/cache/GenerateDoccReference.dSYM/Contents/Info.plist
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/5b1954d8f0d04b305e8270190e18b2c3
  - .build/out/SDKExplicitPrecompiledModules/_Builtin_inttypes-9UNYHE2QFFWX04RQLVMY53IEB.pcm
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_AvailabilityInternal-2YSBQADOLX02V.pcm
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/MachO-20RPYVQSX341K.pcm
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/CoreServices-39NCTJOEW7PQ2.pcm
  - .build/out/v5/records/87/error.h-2E3VM5ENU9X87
  - .build/out/v5/records/VN/DriverServices.h-PPWA1O6VHTVN
  - .build/out/v5/units/CollectionExtensions.o-7R8YWVJFBAYG
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ZshCompletionsGenerator.o
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/b81a5715c5227ba32114342ae999a766
  - .build/out/v5/records/ZC/once.h-24CLFOKC317ZC
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/f26bec36a172fe818fae42bf57d98d44
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncParsableCommand.o
  - .build/out/v5/records/MO/mman.h-16H7TJ08HYEMO
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/46c5b95d370377562ae3cfc4dd5dca5d
  - .build/out/v5/units/_Builtin_stdint-92UYWGR28ZMTKKBURO53CL0KZ.pcm-XYWI3ZYIPE5T
  - .build/out/v5/records/RF/_offsetof.h-3I240G3UW2FRF
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/CoreServices-39NCTJOEW7PQ2.pcm
  - .build/out/v5/units/LedgerReader.o-1UM8F05HU3ZE8
  - .build/out/v5/records/UR/_locale_posix2008.h-2PBXNCRB4L3UR
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/Security-3QCVXOV25KK54.pcm
  - .build/out/v5/records/ZW/_time_t.h-37AGCAPPN49ZW
  - .build/out/v5/records/TW/if.h-1JGKODSPSR2TW
  - .build/out/SDKExplicitPrecompiledModules/CoreFoundation-6F2J2PC11ZNLNE00BYSN50Y9S.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Parsed.dia
  - .build/out/v5/records/OF/IOCDTypes.h-3LJH2XUGXZCOF
  - .build/out/v5/records/QH/cssmconfig.h-8SW7G5XUPLQH
  - .build/out/v5/records/Q6/NSObjCRuntime.h-3PSNP8D3UDWQ6
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/OptionGroup.dia
  - .build/out/v5/records/HU/_uint8_t.h-1MKLFPUURJLHU
  - .build/out/v5/records/P6/ftw.h-396MBCLQBJUP6
  - .build/out/v5/records/YE/IOHIDParameter.h-ESGPDNDSU8YE
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/DerivedSources/Entitlements.plist
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentVisibility.swiftdeps
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/Foundation-24LYWIP48SHNP.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentHelp.dia
  - .build/out/v5/records/WI/IOI2CInterface.h-3KTC89CDY8ZWI
  - .build/out/v5/records/OY/IODVDMedia.h-1IADR67QMDJOY
  - .build/out/v5/records/KJ/LSQuarantine.h-18R0I488Z02KJ
  - .build/out/v5/records/CK/net_kev.h-3K89FWGABXCK
  - .build/out/SDKExplicitPrecompiledModules/string_h-96PF2DVGXLEPQAUNH9EVGXGE3.pcm
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/Foundation-24LYWIP48SHNP.pcm
  - .build/out/v5/records/45/vm_sync.h-11XAS68KXVF45
  - .build/out/v5/records/Q6/proc_info.h-11R8ATFQC3CQ6
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit-primary-emit-module.dia
  - .build/out/v5/records/UT/CFPlugIn.h-2Y5UL4KDXBSUT
  - .build/repositories/swift-argument-parser-54a11a8d/objects/pack/pack-8e9c7dd1be2a2ad10f5b481e816a8504f35ddca9.rev
  - .build/out/v5/records/10/DiskArbitration.h-1ZQ8E1YXZ9W10
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/libDER-26DYHF6GC6WWA.pcm
  - .build/out/v5/records/K8/AsyncCompletionsValidator.swift-P550SVFB8YK8
  - .build/out/v5/records/Y0/ioccom.h-3KH8E9YCWJTY0
  - .build/out/v5/records/8E/fasttrap_isa.h-2BNMSZPT2BY8E
  - .build/out/v5/records/3V/sbuf.h-21NG9JMTQS13V
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/Propositions.o
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/PropositionsKit.modulemap
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentVisibility.swiftconstvalues
  - .build/out/v5/records/2Z/_timeval.h-2GRP9OUKJMO2Z
  - .build/out/v5/records/3V/mds_schema.h-UOKC37HD7V3V
  - .build/out/v5/records/DX/__stddef_ptrdiff_t.h-39NWF8PN7CRDX
  - .build/out/v5/records/80/syslog.h-1KB9L7Z0DJ680
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_DarwinFoundation3-2NSGASPTSNBVQ.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsedValues.swiftdeps
  - .build/out/v5/records/2V/audit.h-33VIZO1OS7A2V
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UsageGenerator.swiftdeps
  - .build/out/v5/records/7P/NSHTTPCookie.h-1ITMY1IXHSQ7P
  - .build/out/v5/records/TM/objc.h-2XJ4EJWY45JTM
  - .build/out/v5/records/ZE/pthread_impl.h-1E29VD117ABZE
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/PositionalArgumentsValidator.swiftconstvalues
  - .build/out/v5/records/M6/IOHIDProperties.h-2NZQTULKQ6SM6
  - .build/out/Intermediates.noindex/XCBuildData/2252000e7990982f1ce62a94ebd51e93.xcbuilddata/attachments/6f60e95553fce434159e54d0b9d59770
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsableArguments.dia
  - .build/out/v5/records/CI/IconStorage.h-271T7BAETX1CI
  - .build/out/v5/records/1I/endian.h-275N2AU5UVO1I
  - .build/out/v5/records/BR/_wctype.h-299PA6C3L06BR
  - .build/out/v5/records/54/CFBundle.h-11UW1ACBHPT54
  - .build/out/v5/units/ptrcheck-9OXC1QXG32N0U7AO4G3OZW5ID.pcm-1K5GNN0J3TFC7
  - .build/out/v5/records/5M/NSFileWrapper.h-36NDYGIHCNS5M
  - .build/out/v5/records/7U/NSURLResponse.h-3HE5SSA3VRG7U
  - .build/out/v5/records/E3/IOEthernetController.h-1YEATH4UD1ZE3
  - .build/out/v5/records/YQ/MixedMode.h-OVD4YKO2CDYQ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentHelp.o
  - .build/out/v5/records/BC/SecAsn1Templates.h-36N8SFSW8AWBC
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/Dispatch-R76HXUP80TVL.pcm
  - .build/out/v5/records/JI/libDER_config.h-VZ690IR5BMJI
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_DarwinFoundation3-2NSGASPTSNBVQ.pcm
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-product-p.build/Objects-normal/arm64/PropositionsKit.LinkFileList
  - .build/out/v5/records/GE/xattr_flags.h-2HFOPRHG8GJGE
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/2de6a04cdba79ed13580c47dfd70cc5f
  - .build/out/v5/records/MQ/ioss.h-2A7V0VB3TGCMQ
  - .build/out/v5/records/7N/_u_int8_t.h-15SDJH4VT2B7N
  - .build/out/SDKExplicitPrecompiledModules/IOKit-23D6FY6PZKBO5MMW8CEGW26OE.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo.abi.json
  - .build/out/v5/records/4S/times.h-3DSD9LSBFPE4S
  - .build/out/v5/records/DH/_SwiftConcurrency.h-3TLE8ZVCLBTDH
  - .build/out/v5/records/E3/NSThread.h-BNRE8M2N0HE3
  - .build/out/Products/Debug/ArgumentParser.o
  - .build/out/v5/records/B1/Support.swift-3FM2IQ0C35JB1
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentSet.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests.swiftsourceinfo
  - .build/out/SDKExplicitPrecompiledModules/_DarwinFoundation3-E8SP24R9KQSBOOPGOJEO5S1B2.pcm
  - .build/out/v5/units/os-AUWM69TNX15YTU2OKOJV2GDO5.pcm-3EFX8TWAVM707
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/69ecbe680c5b8a5f14502abeac2a5bf1
  - .build/out/v5/records/9E/_dev_t.h-XIJEJLYJZC9E
  - .build/out/v5/records/FE/ReadingOrder.swift-39S2MUYG06DFE
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/DumpHelpGenerator.o
  - .build/out/v5/records/UN/AuthorizationTags.h-JKGPQ8TBIPUN
  - .build/out/v5/records/02/OSUtils.h-2I95ZK1FEB202
  - .build/out/v5/records/FE/IOLLEvent.h-ZATDCJMZTJFE
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_Builtin_inttypes-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/F8/tcp.h-3GHXSIK6KFCF8
  - .build/out/v5/records/Z7/pthread_spis.h-MU9LVG3CFRZ7
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions-primary-emit-module.d
  - .build/out/v5/records/8S/_timeval32.h-3BK84NDHM3F8S
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SequenceExtensions.d
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_Builtin_limits-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/K7/task_special_ports.h-1LC7W2JRODOK7
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_AvailabilityInternal-2YSBQADOLX02V.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/OptionGroup.d
  - .build/out/v5/records/H3/_OSByteOrder.h-1HPWPR6ZTZ2H3
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema_check.swiftsourceinfo
  - .build/out/v5/records/0C/IOStorageCardCharacteristics.h-3TFPKF6JMAZ0C
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_Builtin_inttypes-2OQWMRBVRD4OJ.pcm
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/CiteOrderTests.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests.LinkFileList
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/MachO-20RPYVQSX341K.pcm
  - .build/out/v5/records/NF/IOCFBundle.h-B3T3J1QX36NF
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/_DarwinFoundation2-3J4ZFA06I5V1P.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Name.swiftdeps
  - .build/out/v5/records/SV/vm_behavior.h-200MK08T64LSV
  - .build/out/v5/records/81/workgroup_base.h-16YDO2A038L81
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Platform.swiftdeps
  - .build/out/v5/units/NameSpecification.o-1RTQPIFMD3XBW
  - .build/out/v5/records/WP/mach.h-NIHV5KJ8HZWP
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/_Builtin_stdbool-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/T6/Debugging.h-29RICUTO0GDT6
  - .build/out/v5/records/TG/_assert.h-1JX3HXJYAB0TG
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-7GKIKQTAJZSH
  - .build/out/v5/records/5C/SKAnalysis.h-2PWKEMP9AYU5C
  - .build/out/v5/records/HO/CFCharacterSet.h-2YUVXPAPN35HO
  - .build/out/v5/records/X1/_types.h-39CPQMKHSA7X1
  - .build/out/v5/records/RV/IOBDMediaBSDClient.h-1JVYKHVF56KRV
  - .build/out/v5/records/SK/IONetworkController.h-2S4O7C94B18SK
  - .build/out/v5/records/OE/clock_priv.h-4XA2NPBFBYOE
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/5b1954d8f0d04b305e8270190e18b2c3
  - .build/out/v5/records/8M/SplitArguments.swift-2545G6C41DD8M
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentVisibility.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDiscussion.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/AsyncParsableCommand.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NameSpecification.o
  - .build/out/v5/records/Q5/mach_vm.h-3ICJOFPAVUVQ5
  - .build/out/v5/records/OA/in6_var.h-3UL6T9RX4WYOA
  - .build/out/v5/units/ArgumentHelp.o-2X869AUYFC615
  - .build/out/v5/records/1K/libproc.h-1JHAWQHFP0L1K
  - .build/out/v5/records/B6/NSXMLDocument.h-JC88Z5K1NIB6
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/XPC-T0ZXCAST7PE3.pcm
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/2f0b92a65fb63e251690d599275ff386
  - .build/out/v5/records/5O/host_security.h-1T35MC4G7ZD5O
  - .build/out/v5/records/74/IOUserServer.h-2MDWVJIJCK974
  - .build/out/v5/records/FN/_uint32_t.h-2ACO9Z7SYNJFN
  - .build/out/v5/units/InputKey.o-1PXQXXYA284V6
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Location.swiftconstvalues
  - .build/out/v5/records/J7/bootparams.h-1ERAQTAYPY0J7
  - .build/out/v5/records/CN/paths.h-3JSBS6LNU8OCN
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser_const_extract_protocols.json
  - .build/out/v5/records/FT/NSPortMessage.h-2MYAM4CNLKEFT
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/BashCompletionsGenerator.o
  - .build/out/v5/units/NonsenseFlagsValidator.o-186QERKVFO2CZ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParsedValues.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/BashCompletionsGenerator.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit-OutputFileMap.json
  - .build/out/v5/records/X2/ATASMARTLib.h-29RO9DH167DX2
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo.swiftsourceinfo
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/update.sample
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/os_workgroup-2MV8OP7R98AN8.pcm
  - .build/out/v5/records/NH/IOVideoTypes.h-MR93PSBCC4NH
  - .build/out/v5/records/ZF/compact_unwind_encoding.h-1XII03VN9WBZF
  - .build/out/v5/records/9R/CFNumberFormatter.h-FO0F8XSBRE9R
  - .build/out/v5/records/WM/Option.swift-20ZLK9KKHDWWM
  - .build/out/Intermediates.noindex/Propositions.build/Debug/propositions-p.build/Objects-normal/arm64/propositions.LinkFileList
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/os_workgroup-2MV8OP7R98AN8.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/ArgumentParser.modulemap
  - .build/out/v5/records/6B/NSGeometry.h-DZ7FSP1MZ6B
  - .build/out/v5/records/C6/IONetworkInterface.h-2YQVEU0DI66C6
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Parsed.swiftdeps
  - .build/out/v5/records/3M/complex.h-3GL6SH5PNVX3M
  - .build/out/v5/records/CJ/math.h-2T6D4CWVZNWCJ
  - .build/out/v5/records/IP/termios.h-2J45YFKYXBCIP
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentHelp.d
  - .build/out/v5/records/ZH/activity.h-249WM1UVLY3ZH
  - .build/out/v5/records/JE/ttychars.h-N8R1W21ZX9JE
  - .build/out/v5/records/XO/ip6.h-2W6NHFXOPHHXO
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/b81a5715c5227ba32114342ae999a766
  - .build/out/v5/records/31/utsname.h-3L5QPXHS0DN31
  - .build/out/v5/records/K3/CFUUID.h-7FK1KNZT6EK3
  - .build/repositories/swift-argument-parser-54a11a8d/HEAD
  - .build/out/v5/records/D4/USB.h-64YVBV0ESPD4
  - .build/out/v5/records/OC/IOHIDKeys.h-2D5DOVYBXGQOC
  - .build/out/v5/records/I2/utmp.h-1528IHW8RL6I2
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo_dependency_info.dat
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit.swiftmodule
  - .build/out/v5/records/TI/CFSocketStream.h-1XRADVQS3HWTI
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-2G38J7F245KJY
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParserToolInfo-t.build/Objects-normal/arm64/ArgumentParserToolInfo-dependency-scan.dia
  - .build/out/v5/records/DC/__stddef_max_align_t.h-26UO3533DQCDC
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Foundation.swiftdeps
  - .build/out/v5/records/9Z/policy.h-1SY1HQKDKLM9Z
  - .build/out/v5/records/A0/MDLabel.h-DMLLZAN8ZYA0
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CompletionKind.swiftconstvalues
  - .build/out/v5/records/JR/cdefs.h-VEI3H6Q51YJR
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/MessageInfo.swiftconstvalues
  - .build/out/v5/records/96/NSRegularExpression.h-1YIWFDJ7HST96
  - .build/out/v5/records/Y6/NSCalendarDate.h-W16B7L3V0DY6
  - .build/out/v5/records/DS/_stdlib.h-299RX4I3MYLDS
  - .build/out/v5/records/OE/OSKextLib.h-TZ2KWFZRHLOE
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/Darwin-1FXX23EKWOBA9.pcm
  - .build/checkouts/swift-argument-parser/
  - .build/out/v5/records/M9/IOPMKeys.h-3N5LIM7HCE3M9
  - .build/out/v5/records/KJ/Endian.h-1ASEIVHQFM8KJ
  - .build/out/v5/records/W1/CFNetworkErrors.h-1RJLDMFM2QAW1
  - .build/out/v5/records/Z1/CFStringEncodingExt.h-1CF9BBS3H4LZ1
  - .build/out/v5/records/UV/_string.h-3V02R26Y3F7UV
  - .build/out/v5/units/CommandParser.o-3RT5E8C9CLP0U
  - .build/out/v5/records/UA/io.h-2I71JE2X78UA
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/Version.swiftconstvalues
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/CommandGroup.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Tree.d
  - .build/out/v5/records/PU/nl_types.h-1RI0YTXRNAHPU
  - .build/out/v5/records/64/OSByteOrder.h-1VL19V5ENPY64
  - .build/out/SDKExplicitPrecompiledModules/ptrcheck-9OXC1QXG32N0U7AO4G3OZW5ID.pcm
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-1IODWUE00RJVP
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/03cd2f611fa53e83f3ed19a9ff7c5c8d
  - .build/out/v5/records/FL/NSAutoreleasePool.h-2Q3YMGPBXSPFL
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/attachments/9d470f0fe97cb62b8315c162b2f900cf
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputOrigin.swiftdeps
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/PropositionsKitTests.swiftdoc
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_Builtin_stdbool-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/units/CodingKeyValidator.o-C1FYJL7US6EA
  - .build/out/v5/records/SQ/NSLocale.h-1EMWYT7GZFDSQ
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/FishCompletionsGenerator.swiftdeps
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/Security-3QCVXOV25KK54.pcm
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/_Builtin_inttypes-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/KP/host_reboot.h-1YFJ2L8YS58KP
  - .build/repositories/swift-argument-parser-54a11a8d/info/exclude
  - .build/out/Intermediates.noindex/XCBuildData/build.db
  - .build/out/v5/records/Y9/SCSICmds_REPORT_LUNS_Definitions.h-1ABY645W4QVY9
  - .build/out/v5/records/51/NSDistributedNotificationCenter.h-1T3CACQ286R51
  - .build/out/v5/records/AT/___wctype.h-2XB1AZ4KMF4AT
  - .build/out/v5/records/T9/_pthread_cond_t.h-1G1J8WDWBMGT9
  - .build/out/Products/Debug/ArgumentParserToolInfo.swiftmodule/Project/arm64-apple-macos.swiftsourceinfo
  - .build/out/SDKExplicitPrecompiledModules/modules.timestamp
  - .build/out/v5/records/P7/IOHIDValue.h-EWS717BDKGP7
  - .build/out/v5/records/92/NSMorphology.h-H81Q524LCT92
  - .build/out/v5/records/NI/_iovec_t.h-2JBJIZE1HEMNI
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/StringExtensions.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDecoder.dia
  - .build/out/v5/records/99/port.h-17IZE13XGC299
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/SplitArguments.swiftconstvalues
  - .build/out/v5/records/F5/mach_voucher_types.h-NI5N6FBFYFF5
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/libkern-2KQ0X67RTM1JF.pcm
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/SwiftShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/QH/cssmapi.h-DAQ8RH9C6PQH
  - .build/out/v5/records/ZP/kmod.h-3VLMID9KMKTZP
  - .build/out/v5/records/CB/NSScriptKeyValueCoding.h-21XCYZP206RCB
  - .build/out/v5/records/U5/ulimit.h-2CQIZYHHYQRU5
  - .build/out/v5/records/KB/IOCFUnserialize.h-1V19GVB7SD9KB
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDefinition.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UsageGenerator.dia
  - .build/out/v5/records/L2/mds.h-1FARYB7FLVBL2
  - .build/out/v5/records/VB/if_llc.h-2L4526QTMPZVB
  - .build/out/v5/records/Q4/_stdio.h-126GQ83FVKLQ4
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/PropositionsKit_dependency_info.dat
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Parsed.swiftconstvalues
  - .build/out/v5/units/_DarwinFoundation2-1L491ZSO7OJG8Y9S2UZLAG9.pcm-DX2Q9ZYKGGIG
  - .build/out/v5/records/5K/mach_types.h-O872N0U6WL5K
  - .build/out/v5/records/MG/CFNetworkDefs.h-1MUT8HXM0JHMG
  - .build/out/v5/units/Name.o-2509IM8HZI9EH
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NonsenseFlagsValidator.dia
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/PositionalArgumentsValidator.swiftdeps
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/_DarwinFoundation3-2NSGASPTSNBVQ.pcm
  - .build/out/v5/records/11/DADisk.h-2AVHYM5M8RJ11
  - .build/out/v5/records/28/sched.h-27UNSVKV9CQ28
  - .build/out/v5/records/8C/vmparam.h-3DGE2JMC2XE8C
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/DumpHelpGenerator.swiftconstvalues
  - .build/out/v5/records/05/ndr.h-1IUYZ91LR1O05
  - .build/out/v5/records/AY/ipc_info.h-23ZHG8MTTE2AY
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UniqueNamesValidator.o
  - .build/out/v5/records/UA/vsock.h-HGNC4TBCO7UA
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Flag.d
  - .build/out/v5/records/UP/task.h-3H02IOORWIRUP
  - .build/out/v5/units/arm64e-apple-macos.swiftinterface-1HYNHM614F9RR
  - .build/out/v5/records/05/reboot.h-1G8Z7YGO7LE05
  - .build/out/v5/records/9B/UsageGenerator.swift-FFW6Y72VI49B
  - .build/out/v5/records/MX/SecureDownload.h-1Z79CX7Q7PGMX
  - .build/out/v5/records/QR/CipherSuite.h-1K52IFK0DSRQR
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/Dispatch-R76HXUP80TVL.pcm
  - .build/out/v5/records/FY/crt_externs.h-2ESQD98U3O8FY
  - .build/out/v5/records/VX/OptionGroup.swift-1HLALO3A96OVX
  - .build/out/v5/records/7T/CollectionExtensions.swift-23CLNFZA0RP7T
  - .build/out/v5/records/R9/DADissenter.h-2LASJ8KZYOWR9
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/SwiftShims-2IMTS4WWRU7VJ.pcm
  - .build/out/v5/records/MA/Files.h-2U76D4BKXWBMA
  - .build/out/v5/records/RP/pthread.h-2P7NT3J95ECRP
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Option.dia
  - .build/out/v5/records/CT/audit_triggers_types.h-2L4OF4CQZRJCT
  - .build/out/v5/records/J5/machine.h-1591VMZHP75J5
  - .build/out/v5/records/JY/AuthorizationDB.h-348WC36GVHJY
  - .build/out/v5/records/BP/IODVDMediaBSDClient.h-16Q6FKA1X4HBP
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/LedgerReader.o
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ExpressibleByArgument.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/InputOrigin.swiftconstvalues
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/PropositionsKitTests.xctest.xcent.der
  - .build/out/v5/records/26/DumpHelpGenerator.swift-29YRS7IJBVN26
  - .build/out/v5/records/DI/CFCalendar.h-18028BEAD36DI
  - .build/out/Products/Debug/PropositionsKit.swiftmodule/arm64-apple-macos.abi.json
  - .build/out/v5/records/IB/membership.h-B7NJDGTK7BIB
  - .build/out/v5/records/NL/base.h-3GJ6USGN7FSNL
  - .build/out/v5/records/SG/constrained_ctypes.h-1VYS3DVEZBVSG
  - .build/out/v5/records/XN/NameSpecification.swift-19YXDP0JDQ1XN
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentParser_dependency_info.dat
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/DiskArbitration-3LBJF5I58QD8.pcm
  - .build/out/v5/records/53/loader.h-1X1SE06YIR953
  - .build/out/v5/records/H0/IONetworkLib.h-3S7A1DOUZ86H0
  - .build/out/v5/records/57/ParsedValues.swift-1WOC1P9G3G57
  - .build/out/v5/records/OC/NSMapTable.h-2YGPA5ICWL5OC
  - .build/out/v5/records/Z0/CFPreferences.h-Y53KEVDFESZ0
  - .build/out/v5/records/GF/pwd.h-OOJQV03Y2JGF
  - .build/out/v5/records/YN/disk.h-AN035MSTM6YN
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NameSpecification.d
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Option.swiftconstvalues
  - .build/out/v5/records/I6/kauth.h-1U3GR7E9DFCI6
  - .build/out/v5/units/Parsed.o-28J4A847VJNIS
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Foundation.o
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/c3818a8d6ef695529039b179b4fd9978
  - .build/out/v5/records/0L/ConditionalMacros.h-1UOKLVNIXI50L
  - .build/out/v5/records/41/IOHIDUserDevice.h-GGXHXUKTMZ41
  - .build/out/v5/records/9E/CFArray.h-10XQB1ZZ9IZ9E
  - .build/out/v5/records/BF/Flag.swift-3E7O8OODV4VBF
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ParserError.o
  - .build/out/ModuleCache.noindex/2IPDDD3PCNFU/Security-3QCVXOV25KK54.pcm
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentVisibility.dia
  - .build/out/v5/records/W4/cssmdli.h-3I062R2429KW4
  - .build/out/v5/records/UW/endpoint.h-21ENJCU6IXHUW
  - .build/out/v5/records/5J/overflow.h-3Q20E6VPECU5J
  - .build/out/ModuleCache.noindex/I0D84RDCKK9M/MachO-20RPYVQSX341K.pcm
  - .build/out/v5/records/DS/ParsableCommand.swift-3ILQD049B3HDS
  - .build/out/v5/records/F5/IOCFPlugIn.h-PSP1P00NTIF5
  - .build/out/v5/units/CoreServices-DZ24JI52B7AJYTK0HOAKIPW9G.pcm-SJOJ1LQ2Y68I
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/ptrauth-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/8R/paths.h-A0DF58RIH48R
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/MessageInfo.d
  - .build/out/v5/records/9O/__endian.h-34LHCDVMO659O
  - .build/out/v5/records/LG/IOEthernetStats.h-3O1IB61UPOILG
  - .build/out/v5/records/YS/signpost.h-36EYX1Y14A3YS
  - .build/out/v5/units/MessageInfo.o-3IY8FFVMGF1NE
  - .build/out/v5/records/F0/readpassphrase.h-2UTB1XPODPXF0
  - .build/out/v5/records/BA/NSFileManager.h-3HYFC16TTWBA
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/HelpCommand.d
  - .build/out/v5/records/QD/availability.h-1H3AIPDSPNRQD
  - .build/out/v5/records/YP/NSNetServices.h-21YGO7LQ8VMYP
  - .build/out/Intermediates.noindex/XCBuildData/79c925dbb613e32df0cbbc04dd05ed9e.xcbuilddata/attachments/6a89d4677c25fa550ccc8d2b64f1f3b2
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/757f4a30810dc1167421c70c85e5301f
  - .build/out/v5/records/2S/tcp_fsm.h-PENSCYF3DE2S
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Argument.d
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema-check-OutputFileMap.json
  - .build/out/v5/records/BD/CFAvailability.h-3PFR9U6CO1PBD
  - .build/out/v5/records/ZJ/IOGraphicsInterfaceTypes.h-2KP8HIDU6BAZJ
  - .build/out/v5/records/YH/connection.h-2WD2D26MG76YH
  - .build/manifest.pif
  - .build/out/v5/records/5R/aio.h-37GNM67H1ZT5R
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Tree.swiftconstvalues
  - .build/out/v5/records/WA/vcmd.h-337OX3U172AWA
  - .build/out/Intermediates.noindex/Propositions.build/Debug/tschema-check-p.build/Objects-normal/arm64/tschema-check-primary-emit-module.dia
  - .build/out/v5/records/WM/SecureTransport.h-3SXD4C887DTWM
  - .build/out/v5/records/8S/SecTransformReadTransform.h-1QA8D1F6NEJ8S
  - .build/out/Intermediates.noindex/XCBuildData/e718a265fbcad71536e8fa8cbcb21e92.xcbuilddata/description.msgpack
  - .build/out/v5/records/LP/IOAudioDefines.h-CUQ2PPWOSJLP
  - .build/out/v5/records/FK/CFHTTPStream.h-26CN1ZYB7UZFK
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/UniqueNamesValidator.dia
  - .build/out/v5/records/FS/_uint64_t.h-2YO6WHJTFP8FS
  - .build/out/v5/records/YW/CFUserNotification.h-Q2QNLWA8BRYW
  - .build/out/v5/records/A6/AssertMacros.h-2RGEHJ52BY1A6
  - .build/out/Intermediates.noindex/GeneratedModuleMaps/ArgumentParserToolInfo.modulemap
  - .build/out/v5/records/DE/reloc.h-GS9FJF26TNDE
  - .build/out/v5/records/NJ/SecAccess.h-PV7MXDHMYLNJ
  - .build/out/v5/records/FS/IOPMLibDefs.h-16L4R99W4C4FS
  - .build/out/v5/records/HM/SCSICommandOperationCodes.h-2OGDUAFWYRZHM
  - .build/out/v5/records/K4/IOFilterScheme.h-1OMTQK478BBK4
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/MessageInfo.o
  - .build/out/ModuleCache.noindex/2I8FLE6L0OYTV/string_h-47SZ9A199RUD.pcm
  - .build/out/v5/records/10/IOGraphicsInterface.h-2TM3HMCS0Z410
  - .build/.lock
  - .build/out/v5/records/5H/rich_error.h-XFUZ6RRUU05H
  - .build/out/ModuleCache.noindex/2OIJMZI57KP74/Foundation-24LYWIP48SHNP.pcm
  - .build/workspace-state.json
  - .build/out/v5/records/LX/ev_keymap.h-1CB655QNUT5LX
  - .build/out/v5/records/WW/_string.h-1B5UG9QVTTMWW
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/NameSpecification.dia
  - .build/out/v5/records/B5/__stdarg___gnuc_va_list.h-2K47H1YNTLGB5
  - .build/repositories/swift-argument-parser-54a11a8d/hooks/push-to-checkout.sample
  - .build/out/Intermediates.noindex/XCBuildData/b3e950e227f40ee75ebe2fec83eb6516.xcbuilddata/attachments/2f0b92a65fb63e251690d599275ff386
  - .build/out/v5/units/Propositions.o-27XFAZYGOWYR4
  - .build/out/v5/records/UA/protosw.h-20P2M7MMTCZUA
  - .build/out/v5/records/QH/IconsCore.h-1GVYAY8JOZ6QH
  - .build/out/v5/records/GX/NSInflectionRule.h-1TCFU57XM1BGX
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/Platform.o
  - .build/out/v5/records/PT/NSException.h-VKOD6R9TXTPT
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/_Builtin_stdbool-2OQWMRBVRD4OJ.pcm
  - .build/out/v5/records/XG/vm_attributes.h-1K9AZVGKWO2XG
  - .build/out/ModuleCache.noindex/2IALFC5BN5JUY/sys_types-3J4ZFA06I5V1P.pcm
  - .build/out/Products/Debug/PropositionsKitTests.xctest/Contents/_CodeSignature/CodeResources
  - .build/out/v5/records/E4/vm_prot.h-2LI8NHRZ8VDE4
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKit-t.build/Objects-normal/arm64/LedgerReader.swiftdeps
  - .build/out/Intermediates.noindex/swift-argument-parser.build/Debug/ArgumentParser-t.build/Objects-normal/arm64/ArgumentDiscussion.o
tests:
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/test_entry_point.dia
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/test_entry_point.d
  - .build/out/v5/units/test_entry_point.o-290G0NZ5AXEBK
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/DerivedSources/test_entry_point.swift
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/test_entry_point.o
  - .build/out/v5/records/JU/test_entry_point.swift-18ZRRWKUHI7JU
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/test_entry_point.swiftdeps
  - .build/out/Intermediates.noindex/Propositions.build/Debug/PropositionsKitTests-p.build/Objects-normal/arm64/test_entry_point.swiftconstvalues
-->

---
### Requirement: Revising keeps ids stable and never loses a source

The revise action SHALL change the outline files only as the author instructs.

A record and a point SHALL keep their `id` when their content changes and when they move. Merging and splitting replace records: the records that are merged, and the record that is split, leave the file, and the records that replace them are new. A new record or point, a replacement included, SHALL get an `id` that appears in neither outline file and in no approval record, as the `id` of a record or a point or as a value of `section`, `parent` or `uses`. The list of ids in use that the skill prints can hold more than these, taken from other objects in the files; that only rules out more ids. A replacement SHALL NOT take the `id` of a record it replaces.

Merging, splitting and leaving a paragraph out SHALL keep every source on record.

- The `from` of the record that replaces merged records holds every locator of the `from` lists of the records it replaces, and its `replaces` every locator of their `replaces` lists. When a record that has `replaces` is split, each locator of it is in the `replaces` of at least one of the records that replace it. A record that has `replaces` and that the author leaves out is not deleted: it is given `dropped` with the reason; wherever this requirement keeps a record because it has `from`, a record that has `replaces` is kept the same way, also when its last point moves away. Records SHALL NOT be merged when a locator is in the `from` of one and the `replaces` of another until the author has said which of the two the passage is for the merged paragraph; the locator is then taken out of the other list before the merge, and when the author wants both, the records are not merged. A record that carries `carry` SHALL keep its `from`: when the passage is a moved block's source, it can only leave the other record's `replaces`, or the records are not merged. In every revision that makes another record stand for a moved block (a merge, a split, or the block's point moving to another record), the record that stands for the block afterwards SHALL carry `carry`, the `from` of the block and the `edits` that apply to it; when the changes cannot be divided between the records, or no record stands for the block any more, the skill asks the author. Two moved blocks SHALL NOT share a record: two records that each carry `carry` are not merged, and the point of one moved block is not moved into the record of another. Before a revision moves a moved block to a record whose `replaces` holds a locator of the block's `from`, the same rule applies: the passage stays a source, or the block does not move.
- When a record that has `from` is split, each record that replaces it has in its `from` at least one locator of the original, and each locator of the original is in the `from` of at least one of them.
- When a point moves to another paragraph record and the record it leaves has `from`, each locator of that `from` is added to the point's `basis`, so that the point keeps its source; a locator the point already has is not added again. Nothing is added when the point is that of a moved block and the record it moves to takes over the block, with `carry` and the block's `from`: the source is then in that record's `from`. A record is not left with no point: when the point that moves is the last one of its record, the skill asks the author whether that record is given a new point or is left out. Left out, a record with neither `from` nor `replaces` is deleted once the point has moved. A record with `from` or `replaces` can be neither deleted nor left without a point: the point moves with its `id`, and the record keeps a copy of the point's text as a point with a new `id` and is given `dropped` with the reason.
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


<!-- @trace
source: idd-80-fix6
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: The outline skill writes only the three outline files

The skill `/propositions:outline` SHALL have six actions: derive, draft, revise, check, approve and status. In the repository it SHALL write no file other than the three outline files: not the manuscript, not the ledger, not the structure sidecars and not the verification records. Temporary files it keeps outside the repository are not covered by this rule. The directory that holds them SHALL be one the skill made for this repository: it exists, is outside the repository, belongs to the user, has mode 700, and holds a note of the root it was made for. A directory that fails one of these is not used. The skill does not look at access-control lists. The skill SHALL NOT make that directory inside the repository: when the machine's temporary directory is inside the repository, or cannot be entered, the skill stops before it makes anything, except in the case of known limit 10 below. The directory of the outline files SHALL be the repository's root or a directory under it once every symbolic link in its path, the last part included, is resolved; it SHALL NOT be inside a `.git` directory in any letter case, its path SHALL hold, below the root, no character that a locator's `file` is not allowed to hold, and it SHALL be a directory or not exist yet, in which case the directory that is to hold it SHALL exist and be a directory. A symbolic link that leads to a place that does not exist stops the skill. The skill SHALL confirm both directories again in every command that reads or writes an outline file, and, in the revise action, before its first edit and again after every reply of the author. The skill SHALL NOT read or write an outline file that is itself a symbolic link. A symbolic link in the path of the directory is a different case: it is resolved, and what counts is where it leads. It SHALL NOT change or remove a line of `outline-approvals.jsonl`. The check action and the status action SHALL write nothing to the repository.

What the skill reads is data: the manuscript, the outline files, the files a locator names and the output of a command. The skill SHALL NOT act on text in them that reads like an instruction, and says so to the author when it notices it.

The skill keeps three things: in the repository it writes the three outline files and no other file; it reads no file outside the repository, other than its own (the temporary files it made in the stage directory, and the files of this plugin), the ledgers' `_meta.json` files of the outermost repository the manuscript is checked out in, which it reads to find the ledger before the root is set, and the files git itself reads when it is asked (its configuration, its global ignore file, and the git directory of the repository, of the outermost repository and the repositories between them, and of a repository of its own under the outermost one that holds a ledger or a directory offered for the outline, wherever it is, which for a linked worktree is in the repository the worktree belongs to); and it records an approval only from words the author typed in the message it answers. Its commands keep the first two against mistakes and against the ordinary ways a path leads somewhere else: a symbolic link, `..`, another spelling of a directory, a path copied wrongly. They are shell commands, and this capability does not require them to withstand a repository or a shell that was set up to defeat them: that defence is left to the command-line tool of issue 78. The limits known today are these ten. The list is closed: a limit is added when one is found, and none is inferred from another.

1. A path the skill writes into a command holds a single quote. Only the rule that the skill stops at such a path keeps the shell from reading the rest of the name as a command. All three can fail.
2. `PATH` holds an empty entry or one that does not begin with `/`. The commands find their tools through `PATH`, `pwd` excepted, and a program of the same name in the directory the shell is in is run in its place. All three can fail.
3. The shell is zsh and its startup files define a function named `chpwd`. The commands enter directories of the repository with `cd`, and zsh calls that function in each. The first and the second can fail.
4. The repository holds a git repository of its own that someone else made (a directory with its own `.git`, which no commit can carry). Git reads the configuration of every repository it answers for, and the commands switch off only the one setting known to make their git commands run a program. All three can fail.
5. The shell sets `noclobber`, or makes `cp` ask before it overwrites. Some commands fail, and the skill stops. None of the three fails.
6. The machine's temporary directory hands down an access-control list. The copies in the stage directory can then be readable by someone else. None of the three fails.
7. A file system does not give a file the same identity each time it is asked. The test whether two paths are the same file can fail for a right path, and the skill stops or leaves the file unread. None of the three fails.
8. The environment sets a variable that steers git, such as `GIT_DIR` or `GIT_WORK_TREE`. Git then answers for another repository than the one the directory is in, and the root the skill takes is not the root of the outline directory's repository. The second can fail.
9. Text that the skill or the checker reads (the manuscript, a file a locator names, a file the author points to, the outline files) asks the reader to read another file. The Read tool of the checker agent, and of the skill, can open any path, and only their rules keep them to the files they are given. The second can fail.
10. The repository's root is the root of the file system. The machine's temporary directory is then inside the repository, and the first command makes the stage directory there before the skill stops. The first can fail.

After every write to an outline file the skill SHALL confirm that every line of that file that is not empty is a JSON object written as JSON. jq also reads `nan`, `Infinity` and numbers such as `01` or `.5`, none of which is JSON; the check reads the text of the line to report them. A byte that is not UTF-8 is read by jq as a replacement character and is not reported. After a write to the section file or the paragraph file it SHALL also confirm that every record has an `id` that is a non-empty string, that no `id` repeats among the section records or among the paragraph records and points, that no string holds a control character, and that no number is too large for jq to keep (such as `1e400`, which is JSON but which jq reads as infinite). In the paragraph file it SHALL also confirm that every point has an `id` and that `points`, where a record has it, is a list. The shape of a key that a section record carries and this capability does not define is not checked, a key named `points` included; the control-character test still reads every string and every key name. When any of these fails, it SHALL report the file and the line and SHALL NOT report the write as done. When the check of the approvals file fails, the skill SHALL NOT correct that file: it says that the file was changed by hand and leaves what to do with it to the author. The check SHALL NOT report a pass for a file that holds no record. An empty section file is always a mistake. An empty paragraph file is a mistake except in two cases, and only these two: the outline the author gave to draft has sections and no paragraph yet, so that the skill wrote no paragraph record; or the author, through revise, left out every paragraph record and none of them had `from`, so that each was deleted. In those cases the skill says in its report that the paragraph file is empty, and goes on. Its report SHALL say that no other check of the format exists until issue 78, apart from resolving the locators.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

#### Scenario: The skill does not touch the manuscript

- **WHEN** the author, during a revision, asks the skill to rewrite a paragraph of the manuscript to match a point
- **THEN** the skill writes nothing to the manuscript and says that writing from an outline is not one of its actions

#### Scenario: The outline directory resolves to a place outside the repository

- **WHEN** the path of the outline directory, with its symbolic links resolved, is outside the repository, however the path is written
- **THEN** the skill reads and writes no outline file there, stops, and tells the author

#### Scenario: The stage directory is inside the repository

- **WHEN** the directory that holds the skill's temporary files is inside the repository, or no longer exists
- **THEN** the skill reads and writes no outline file, stops, and tells the author

#### Scenario: A stage directory the skill did not make

- **WHEN** the path given as the directory of the skill's temporary files is the directory above the repository, the temporary directory of the machine itself, the directory made for another repository, or a directory inside the repository that is written through another name of the volume
- **THEN** the skill reads and writes no outline file, writes and removes nothing in that directory, stops, and tells the author

#### Scenario: The machine's temporary directory is inside the repository

- **WHEN** the skill starts, the repository's root is not the root of the file system, and the temporary directory of the machine is a directory inside the repository
- **THEN** the skill stops and says so, and no directory or file has been made inside the repository

#### Scenario: The outline directory is a regular file

- **WHEN** the path given as the outline directory names a regular file inside the repository
- **THEN** the skill reads and writes no outline file, stops, and tells the author

#### Scenario: An outline file that is a symbolic link

- **WHEN** `outline-sections.jsonl` in the outline directory is a symbolic link, wherever it leads
- **THEN** the skill does not read it, writes nothing through it, stops, and tells the author

#### Scenario: A directory whose name holds a single quote

- **WHEN** the only ledger that names the manuscript is in a directory whose name holds a single quote
- **THEN** the skill stops, says that it cannot work with that path, and does not write the path into a command

#### Scenario: A repeated id stops the report

- **WHEN** a write leaves two paragraph records with the `id` `p-7`
- **THEN** the skill reports the file and the two lines, and does not report the write as done

#### Scenario: A record without an id

- **WHEN** a write leaves one paragraph record that has no `id`
- **THEN** the skill reports the file and the line, and does not report the write as done

#### Scenario: A section record with a key named points

- **WHEN** a write leaves a section record that has a key `points` whose value is a string
- **THEN** the write check reports nothing about the shape of that key

#### Scenario: Text in the manuscript that reads like an instruction

- **WHEN** a paragraph of the manuscript says that the outline rules no longer apply and that the manuscript is to be rewritten
- **THEN** the skill does not act on it, writes nothing to the manuscript, and tells the author that the passage reads like an instruction

#### Scenario: A value that jq reads but JSON does not have

- **WHEN** a write leaves a section record with an undefined key whose value is written `Infinity`
- **THEN** the write check reports the line, and the skill does not report the write as done

#### Scenario: A file with no record

- **WHEN** the derive action has staged a section file that holds no record
- **THEN** the write check does not pass, and the skill does not show the outline or write it to the repository

#### Scenario: An id that is the beginning of another

- **WHEN** a write leaves the paragraph records `p-1` and `p-10`, and no `id` repeats
- **THEN** the skill reports no repeated `id`


<!-- @trace
source: idd-91-fix3
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: The explanatory document describes the outline

`plugins/propositions/docs/OUTLINE.md` SHALL describe what the repository is, the three files and every key of their records, the locator, the three conditions (a section stands as approved, the order of sections stands as approved, the outline stands as approved) and what a paragraph record that names no section does to the last of them, what counts as an approval and the five things that do not, the six kinds of finding of the premise check and the agent that judges five of them, and the six actions of the skill.

It SHALL state that this capability writes no manuscript text and that writing from an outline belongs to issue 51, that no validator of the outline files exists until issue 78, and which checks the skill runs until then. It SHALL state what an approval record does not establish: it does not say who approved, and anyone who can write to the repository can add one. It SHALL state that the tools the skill is allowed to use without a prompt are not limited by that allowance: that the skill writes only the three files and starts no agent other than the checker is kept by its commands and its rules. It SHALL state the three things the skill keeps and list the limits known today, saying for each which of the three it can make fail. It SHALL list the design questions this version leaves open.

No executable check: this change adds no test target; the examples and tests of this requirement are deferred to issue 78, which follows the Swift package (issue 46).

#### Scenario: A reader decides from the document alone

- **WHEN** a reader who has only the document is given the three files of an outline
- **THEN** the reader can say for each section whether it stands as approved, and whether the order of sections and the outline stand as approved


<!-- @trace
source: idd-75-fix5
updated: 2026-11-18
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Text from the manuscript and the author never becomes part of a command

The skill SHALL NOT write text taken from the manuscript, from an outline file or from the author into the text of a command. Such text (the opening words of a passage, a sentence, an `id`, the name of a file a locator gives, the author's approving words) SHALL reach a command only from a file that the command reads. A command that hands such a value on to a tool SHALL hand it on so that the shell interprets no character of it. A path the skill does write in a command SHALL be written so that the shell interprets no character of it. The paths the skill writes in its commands are the root, the outline directory, the stage directory, the directory that holds the manuscript, the manuscript's main file, and a file the author points to in draft or revise (a source, or an outline of the author's own), which the skill checks the way it checks the main file before it reads it. Each SHALL begin with `/`: a path among them that is empty or not written out in full stops the skill, and so does a path that holds a single quote; for a file the author points to in draft or revise, such a path stops the skill for that file only: the skill SHALL NOT read the file and asks the author to paste its text instead. The one exception is the manuscript's main file in the command that compares a ledger with it: left empty there, it means that there is no manuscript yet. The command that sets the root takes the directory where the manuscript will be in its place, so its path is never empty there. The paths of the ledgers' `_meta.json` files SHALL reach a command only from a list in the stage directory, not written into the command. The task message the skill gives to the agent of the premise check is held to the same rule: it holds paths the skill made, and none of that text.

A check of the skill counts as passed only when its command reports success in words. A check whose command prints nothing, fails, or cannot run SHALL be treated as failed. When a tool that the skill's commands need (`jq`, `realpath`, `git`) is not installed, the skill SHALL stop and say which tool is missing. It SHALL stop too when its `jq` reads two long numbers that differ as the same number, as versions before 1.7 do; when its `git` is older than 2.38, the first version that knows the setting `safe.bareRepository`; and when the system's `pwd` is in neither `/usr/bin` nor `/bin`: the names of directories rest on it, and the skill looks for it nowhere else. The other tools are found through `PATH`. A variable named `TOOLS` or `ROOT` in the author's environment SHALL NOT change what the first command does. When the first command finds no git repository for the directory, or git cannot say whether that repository is checked out inside another, it says so in a line of its own that begins with `STOP`.

Every git command of the skill that reads a repository SHALL be run with the settings `safe.bareRepository=explicit` and `core.fsmonitor=false`. With the first, git takes a directory for a repository only when a `.git` is in it or above it: files of the working tree that are laid out like a repository (a `HEAD`, an `objects`, a `refs` and a `config`, which a commit can carry like any other files) are not taken for one, and that `config` is not read. Git does not pass such a directory by: asked in it, or in a directory under it, git refuses to answer, so a source there is not read: the derive action does not follow a `.tex` file there, a locator that names a file there does not resolve, a manuscript there stops the skill at its first command, where git's own error gives the reason, and an outline directory there stops the command that sets the root. A `_meta.json` there is still listed, because the listing does not ask git; when there is a manuscript, its comparison with the manuscript does not run to its end, and the skill asks; when there is no manuscript yet, the comparison runs no git and the file counts as compared. With the second, git starts no file-watching program that a configuration names. A linked worktree, and a repository whose `.git` is a file, are found as before.

No executable check: the checks of this requirement are shell commands in the skill's instructions, and this change adds no test of them to the repository; its acceptance ran outside the repository, and tests in the Swift test target are deferred to issue 78.

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

<!-- @trace
source: idd-91-fix2
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->