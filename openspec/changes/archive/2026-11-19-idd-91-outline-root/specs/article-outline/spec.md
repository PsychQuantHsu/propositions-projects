## MODIFIED Requirements

### Requirement: The outline is three files beside the ledger

The outline SHALL consist of three files in the directory that holds, or would hold, the manuscript's ledger: `outline-sections.jsonl`, `outline-paragraphs.jsonl` and `outline-approvals.jsonl`. In each file every line that is not empty SHALL be one JSON object.

The repository is the git repository that holds the directory of the outline files (issue 91). The skill SHALL find it in two steps. First it finds the outermost repository the manuscript is checked out in: the git repository that holds the manuscript, or, when that repository is checked out as a submodule of another (as git reports it, from the index of the outer repository), the outermost repository above it, however many levels of submodules lie between; it looks for ledgers and outline files there, and the directory of the outline files SHALL be inside it. Once that directory is known, the git repository that holds it (for a directory that does not exist yet, the one that holds the directory that is to hold it) is the repository from then on, and its submodules are inside it. That repository SHALL hold the manuscript; when it does not, the skill SHALL stop and ask for a directory of a repository that does. When the manuscript is in no git repository, the skill SHALL stop and say why, and SHALL NOT take the boundary of the repository from an answer of the author. For a draft with no manuscript yet, the directory where the author says the manuscript will be stands in for it when the repository is found; when that directory does not exist yet, the nearest directory above it that does is used in its place, and the skill SHALL then tell the author which repository it found and ask whether the manuscript will be in it, and stop when it will not. A repository whose root is the root of the file system is not supported: the skill stops after its first command, which has already made its temporary directory inside it. That directory is not the directory of the outline files unless the author says so, and no ledger names a manuscript that does not exist yet. A repository that sits inside another without being its submodule is a repository of its own; a ledger of the outer repository is then outside the repository, does not name the manuscript, and cannot have the outline beside it. A directory under the repository's root counts as inside it even when it holds a git repository of its own. Wherever this capability says inside the repository, it means inside this one, and every path a locator gives is relative to its root; an outline therefore resolves in every checkout of the repository that holds it, on its own or as a submodule of any other. An outline written before this rule gives every path from the outermost repository; when that is not the outline directory's repository its locators do not resolve, and the check reports each of them.

The manuscript's main file SHALL be a regular file inside the repository that is not itself a symbolic link, is not inside a `.git` directory in any letter case, and that git lists: a file git tracks, or one git does not track and does not ignore (the requirement on locators says which repositories are asked). Its path from the root SHALL hold no character that a locator's `file` is not allowed to hold. When it is not such a file, the skill SHALL stop, say why, and not read it. A symbolic link in the path of the directory that holds it is a different case: it is resolved, and from then on the skill reads the manuscript by its real path.

Directories are compared by the name the system itself gives them, not by the way a path was written: a path through a symbolic link, in another letter case on a file system that ignores case, or through another name of the same volume leads to the same name. A file is named the same way: by its real path, with its directory named as the system names it, and only when that name and the path it was reached by are the same file. For the manuscript's main file and for a file a locator names, the last part of the name is the one the directory itself gives: `main.tex`, written for a file the disk has as `Main.tex`, is named `Main.tex`. When the directory holds two names for that file, the last part stays as it was resolved, which differs between the `realpath` macOS ships (the name the disk has) and GNU's (the name as typed). When git does not have that name, the whole path ignores letter case, and git tracks a path that differs from it only in letter case, the file counts as tracked and keeps the name it has by the rule above (its last part as the directory gives it), not the name git has; the `.tex` files the derive action follows are treated the same way. One such file is still refused: one whose name the repository ignores at its root, because it is asked about that name and answers so; a file in a submodule is not refused that way, because the repository gives no answer for it. The directory is looked into for the name only once the file is known to be inside the repository and outside `.git`. Wherever this capability says that a directory or a file is inside or outside the repository, it means by that name.

The outline SHALL NOT depend on a ledger: the directory can hold the three files without a `main.jsonl`. The skill SHALL use a directory without asking only when every `_meta.json` it lists in the repository was read as one ledger and compared with the manuscript, exactly one of those ledgers names this manuscript, and the author's request names no other directory; it then uses that ledger's directory.

A ledger names one file at most. `docs/SCHEMA.md` writes a ledger's `source.file` from the "manuscript repo root"; when the git repository that holds the ledger is a submodule of another, some ledgers read that as the submodule's root and others as the root of the outermost repository. The skill reads `source.file` both ways, in this order: as a path from the root of the git repository that holds the ledger (for a ledger inside a submodule, the submodule's root), and then as a path from the root of the repository. The first reading that leads to a regular file under the root of the ledger's own git repository decides which file the ledger names, and a file in a directory under that root counts also when the directory is a submodule or holds a git repository of its own; a reading that leads to no file, or to a file outside the ledger's own git repository, is not taken. The ledger names this manuscript when the file it names is the manuscript's main file, both resolved to real paths. The ledger of another paper, kept in a submodule or in a git repository of its own under the root, therefore does not name a manuscript of the outer repository. For the same reason a ledger that is kept in a git repository of its own, apart from its manuscript, names no file, and the skill asks. A `source.file` that holds a control character names no file.

A `_meta.json` that is a symbolic link, that is inside a `.git` directory in any letter case, or whose path holds a line break is not listed, is not read and does not count as a ledger; one whose path holds, below the root, another character that a locator's `file` is not allowed to hold is not listed, is not read and does not count as a ledger either, and the part of the path down to the root is not tested. Whether git ignores a `_meta.json`, or the directory of the outline files, is not asked: only the sources (the manuscript, the files it includes and the files a locator names) are held to what git lists. A listed `_meta.json` is read as one ledger when it holds exactly one JSON value, that value is an object, and the file passes the test of written JSON that the write check applies to an outline file: outside its strings it holds only `true`, `false`, `null` and numbers written as JSON writes them. A file that fails this test SHALL NOT be read as one ledger, even when the tool reading it accepts it; it is such a file when it holds `nan`, `Infinity`, or a number such as `01` or `.5` outside a string, or begins with a byte-order mark. As in the write check, a byte that is not UTF-8 is read as a replacement character and is not reported.

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

- **WHEN** the manuscript's repository is checked out as a submodule of a submodule of a submodule of another repository, and the directory of the outline files is in the outermost one
- **THEN** the repository is that outermost one, and the skill does not stop for the number of levels

#### Scenario: The outline in the article's repository

- **WHEN** the manuscript's repository is a submodule of an article repository, the article repository is a submodule of an outer repository, and the directory of the outline files is in the article repository
- **THEN** the repository is the article repository, every `file` of a locator is written from its root, and the same locators resolve in a checkout of the article repository on its own

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

- **WHEN** the only `_meta.json` in the repository holds `{"source":{"file":"main.tex"},"extra":01}`
- **THEN** the skill does not read it as one ledger, tells the author which `_meta.json` could not be read, and asks where the outline files go

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

`from` and `basis` SHALL be lists of one or more locators. A `from` or a `basis` that is not such a list, an empty list included, names no passage.

No executable check: this change adds no test target; the examples and tests of this requirement are deferred to issue 78, which follows the Swift package (issue 46).

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
