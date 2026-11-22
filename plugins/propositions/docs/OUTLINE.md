# Article outline

The ledger records what a manuscript already says. The outline records what an
article is **planned** to say, before the text is written: one sentence for
each section and at least one sentence for each paragraph. The author reads the
outline, changes it, and approves it; only then is text written from it.

An outline can be built from a finished manuscript, so that a large
restructuring is decided on sentences instead of on pages, or from a title and
ideas. It is written by the skill `/propositions:prop-outline`.

Two things are outside this document. Manuscript text is written from an outline
by `/propositions:prop-construct` (see "Writing text from the outline"); the outline
skill writes nothing to the manuscript. No validator of the outline files exists yet (issue #78): apart
from the few checks listed under "What is checked today", the rules below are
kept by the skill and by the reader.

## The three files

The outline is three files in the directory that holds, or would hold, the
ledger, when that directory is in a repository that holds the manuscript. The
directory can hold them without a `main.jsonl`: a manuscript does
not need a ledger to have an outline.

**The repository** is the git repository that holds the directory of the
outline files (issue #91). The skill finds it in two steps. First it finds the
outermost repository the manuscript is checked out in: the git repository that
holds the manuscript, or, when that repository is checked out as a submodule
of another (as git reports it, from the index of the outer repository), the
outermost repository above it, however many levels of submodules lie between.
That is where it looks for ledgers and outline files, and where the directory
of the outline files has to be. Once that directory is known, the repository
that holds it is the repository from then on: it has to hold the manuscript
too, and its submodules are inside it. Every `file` of a locator is written
from its root, so an outline resolves in every checkout of that repository: on
its own, or as a submodule of any other. The skill works
only on a manuscript inside a git repository: when the manuscript is in no git
repository, it stops and says why. The
repository's root is the boundary of the outline files and of every file the
skill reads as a source. The skill does not take that boundary from an answer
of the author: the author's choice of the outline directory can only narrow it
to a repository inside the outermost one, and the skill stops when that
repository does not hold the manuscript (for a draft, the directory where the
manuscript will be). The root only moves down; to choose an outline directory
outside it, the skill starts again. Its own temporary files are outside the repository. For
a draft with no manuscript yet, the directory where the author says the
manuscript will be stands in for it when the repository is found; the skill
asks when the author has not said. When that directory does not exist yet, the
nearest directory above it that does is used in its place: it only finds the
repository. Because that directory can belong to a larger repository the
manuscript will not be in, the skill then tells the author which repository it
found and asks whether the manuscript will be there, and stops when it will
not. A repository whose root is the root of the file system is not supported:
the skill stops, after its first command has already made its temporary
directory inside it (the machine's temporary directory is then inside the
repository, which that command does not see in this one case). That
directory is not the directory of the outline files unless the author says
so, and no ledger names a manuscript that does not exist yet. A repository that
sits inside another without being its submodule is a repository of its own.
Everything this document says is inside the repository is inside this one, and
every path a locator gives is relative to its root. When the directory of the
outline files is in a repository that does not hold the manuscript (a
submodule that holds only the ledger, or a repository of its own beside the
manuscript's), the skill stops and asks for a directory of a repository that
does. It stops too when the outline directory is inside a submodule that is
not checked out (files written there could not be tracked), and when git finds
no repository for it, which includes a directory in or under one that is laid
out like a git repository, where git refuses to answer. An outline written
before this rule (issue #91) gives every `file` from the outermost repository.
The skill does not convert such an outline and does not try to recognise one:
when the root is a repository below the outermost one, its locators do not
resolve and check reports each of them, and the skill then says that such an
outline names its files from the outermost repository and that the path from
that repository down to this one can be removed from each `file` with revise.
Every section whose records change then no longer stands as approved. A
`file` outside the new root is reported too, and no locator can name it any
more. One case is not reported and is left to the author: a `file` that by
chance names another file under the new root that holds the same label or
opening words. Such an outline in a repository that does not hold the
manuscript is refused like any other outline directory there, and the author
moves its three files. When
the manuscript's repository sits inside another without being its submodule, a
ledger of the outer repository is outside the repository: it does not name the
manuscript for the skill, and the outline cannot go beside it. When no ledger
of the inner repository names the manuscript either, the directory is the
author's decision (see "Which directory" below). The other way round,
a directory under the repository's root counts as inside it even when it holds
a git repository of its own.

**The manuscript's main file** is a regular file inside the repository. It is
not itself a symbolic link, it is not inside a `.git` directory in any letter
case, and git lists it: git tracks it, or does not track it and does not
ignore it ("Locators" says which repositories are asked). Its path from
the root holds no character that a locator's `file` is not allowed to hold
(see "Locators"), so that every locator can carry that path. When it is not such a file, the skill stops, says why and does
not read it. A symbolic link in the path of the directory that holds it is a
different case: it is resolved, and from then on the skill reads the
manuscript by its real path.

**Directories are compared by the name the system gives them**, not by the
way a path was written. A path through a symbolic link, in another letter case
on a file system that ignores case, or through another name of the same volume
(`/System/Volumes/Data/…` on macOS) leads to the same name. A file is named
the same way: by its real path, with its directory named as the system names
it, and only when that name and the path it was reached by are the same file.
For the manuscript's main file and for a file a locator names, the last part
of the name is the one the directory itself gives: `main.tex`, written for a
file the disk has as `Main.tex`, is named `Main.tex`. The directory is looked
into for that name only once the file is known to be inside the repository and
outside `.git`. When the directory holds two names for that file (a hard
link), the last part stays as it was resolved, which differs between the
`realpath` macOS ships (the name the disk has) and GNU's (the name as typed).
When git does not have that name, the whole path ignores letter case, and git
tracks a path that differs from it only in letter case (a file renamed on the
disk in letter case alone, which git does not notice on such a file system),
the file counts as tracked and keeps the name it has by the rule above (its
last part as the directory gives it), not the name git has; the `.tex` files
that derive follows are treated the same way. One such file is still refused:
one whose name the repository ignores at its root, because it is asked about
that name and answers so. A file in a submodule is not refused that way: the
repository gives no answer for it.
Wherever this document says that a directory or a file is inside or outside
the repository, it means by that name.

**Which file a ledger names.** A ledger names one file at most.
`docs/SCHEMA.md` writes a ledger's `source.file` from the "manuscript repo
root". When the git repository that holds the ledger is a submodule of
another, some ledgers read that as the submodule's root and others as the root
of the outermost repository. The skill reads `source.file` both ways, in this
order: from the root of the git repository that holds the ledger (for a ledger
inside a submodule, the submodule's root), and then from the root of the
outermost repository. The first reading that leads to a regular file under the root of
the ledger's own git repository decides which file the ledger names; a file in
a directory under that root counts, also when the directory is a submodule or
holds a git repository of its own. A reading
that leads to no file, or to a file outside the ledger's own git repository, is
not taken. The ledger names this manuscript when the file it names is the
manuscript's main file, both resolved to real paths. So the ledger of another
paper, kept in a submodule or in a git repository of its own under the root,
does not name a manuscript of the outer repository. For the same reason a
ledger that is kept in a git repository of its own, apart from its manuscript
(a submodule that holds only the ledger), names no file, and the skill asks.
A `source.file` that holds a control character names no file.

| The ledger is in | Its `source.file` | The manuscript is | Names it |
|---|---|---|---|
| the submodule `paper` | `main.tex` | `paper/main.tex` | yes, by the first reading |
| the submodule `paper/manuscript` | `paper/manuscript/main.tex` | `paper/manuscript/main.tex` | yes, by the second reading |
| the outer repository | `paper/main.tex` | `paper/main.tex` | yes |
| the submodule `paper` | `main.tex` | `main.tex` at the root of the outer repository | no: the ledger names `paper/main.tex` when that file exists, and no file when it does not, because the outer `main.tex` is outside the ledger's repository |
| the submodule `manuscript/propositions`, which holds only the ledger | `manuscript/main.tex` | `manuscript/main.tex` in the outer repository | no: that file is outside the ledger's repository; the skill asks |

A `_meta.json` that is a symbolic link, that is inside a `.git` directory in
any letter case, or whose path holds a line break is not listed, is not read
and does not count as a ledger. One whose path holds, below the root, another
character that a locator's `file` is not allowed to hold is not listed, is not
read and does not count as a ledger either; the part of the path down to the
root is not tested. Whether git ignores a `_meta.json` is not asked: a ledger
in a directory git ignores is listed and compared like any other, and the
directory of the outline files can be one git ignores. Only the sources are
held to what git lists: the manuscript, the files it includes and the files a
locator names. A listed `_meta.json` is read as one ledger when it
holds exactly one JSON value, that value is an object, and the file is written
as JSON by the test the write check applies to an outline file: jq also reads
`nan`, `Infinity`, numbers such as `01` or `.5`, and a file that begins with a
byte-order mark, none of which is JSON, and such a file is not read as one
ledger. A byte that is not UTF-8 is not reported, as in the write check.

**Which directory.** The skill uses a directory without asking only when every
`_meta.json` it lists was read as one ledger and compared with the manuscript,
exactly one of those ledgers names this manuscript, and the author's request
names no other directory; it then uses that ledger's directory. In every other case the skill does not
choose a directory itself. These are the cases, and the list is closed:

1. no ledger names the manuscript;
2. more than one does;
3. there is no manuscript yet;
4. a listed `_meta.json` could not be read as one ledger, or its comparison
   with the manuscript did not run to its end (the skill also says which one:
   it might be the manuscript's ledger);
5. one ledger names the manuscript and the request names another directory.

When the request names the directory of the outline files, every listed
`_meta.json` was read as one ledger and compared, and no ledger names the
manuscript or there is no manuscript yet, the request is the author's answer
and the skill uses that directory. Otherwise it asks the author which
directory to use. Outline files elsewhere in the outermost repository are then
offered, not taken, because they can belong to another manuscript; when there
is nothing to offer, the skill proposes a directory `propositions` beside the
manuscript, where a ledger is put by convention. A directory in a repository
that does not hold the manuscript, such as a submodule that holds only
ledgers, cannot hold the outline, and the skill asks for another. When the command that lists
the ledgers fails, the skill stops. The path of the directory holds, below the
root, no character that a locator's `file` is not allowed to hold (see
"Locators"). The
directory is always the repository's root or a directory under
it, not inside a `.git` directory in any letter case, and it is a directory or
does not exist yet,
in which case the directory that is to hold it exists. The skill resolves every
symbolic link in its path, the last part included, before it decides; a link
that leads to a place that does not exist stops it. It
decides again in every command that reads or writes an outline file, and, when
it revises, before its first edit and again after every reply of the author.

```
manuscript/propositions/
├── main.jsonl                # the ledger, if there is one (unchanged)
├── outline-sections.jsonl    # the article layer: one section per line
├── outline-paragraphs.jsonl  # the paragraph layer: one paragraph per line
└── outline-approvals.jsonl   # one approval per line
```

In each file every line that is not empty is one JSON object. Adding, changing
or removing these files changes nothing in the ledger, its metadata, the
structure sidecars or the verification records, and the ledger's schema version
does not cover them. The rule that keeps the ledger in step with the manuscript
(`rules/manuscript-jsonl-sync.md` of this plugin) does not cover them either: a
change to the manuscript obliges no change to the outline files.

A section record, a paragraph record, a point and a locator can carry keys that
this document does not define. The skill keeps such keys as they are when it
rewrites a record and does not interpret them. An approval record carries the
four keys defined for it and no others.

No string in a section record or a paragraph record, the name of a key
included, contains a control character (U+0000 to U+001F), a line break
included. Where the text has a line
break, the string has a space. This rule is what exposes the commonest mistake
in writing LaTeX into JSON: a backslash that is written once instead of twice
(see "What is checked today").

## Section records

Each line of `outline-sections.jsonl` is a section record. The order of the
lines is the order of the sections in the article.

| Key | Required | Value |
|---|---|---|
| `id` | yes | A non-empty string, different from the `id` of every other section record |
| `heading` | yes | The heading of the section, a non-empty string |
| `says` | yes | One complete sentence stating what the section says |
| `role` | no | One of `abstract`, `introduction`, `background`, `formal_setup`, `method`, `results`, `proofs`, `discussion`, `conclusion`, `appendix` |
| `parent` | no | The `id` of a section record on an earlier line |
| `dropped` | no | A non-empty string giving the reason the section is left out of the article |
| `moved_to` | no | A non-empty string naming where a section that is left out goes: another article, or a part that has no outline here. Only on a record that carries `dropped` |
| `part` | no | One of `main`, `appendix`, `supplement`: the part of the article the section is in. Without it the section is in the part of the section it is under, and a section under none is in the main text |
| `unread` | no | A list of one or more included files that were not read when the outline was derived, each `{"file": <the name as the include command writes it>, "why": <the reason>}` (see below) |
| `length` | no | A whole number from 1 to 999999999: the target length of the section in words, the sections under it included (see "article.json") |

`says` is a sentence. A heading, a label or a list of topics does not state
what the section says.

A section record that carries `dropped` is not part of the article. It stays in
the file so that the records naming it, and their sources, stay on record.
Every paragraph record naming such a section carries `dropped` too, and so does
every section record that names it as `parent`: a section is not part of the
article when the section it is under is not.

```json
{"id": "s-intro", "heading": "Introduction", "role": "introduction", "says": "Standard errors from the usual method are too small in short tests, and this article shows why."}
```

**Included files that were not read.** A section record can list, in `unread`, the included
files of its section that were not read when the outline was derived (a file git ignores, one
outside the repository, one behind a symbolic link, a missing one), each with the reason
(issue #117). An entry belongs to the record of the section the include command stands in. It
is not a locator: it names the file as the include command writes it and does not have to name
one place, so a file that is included twice is two entries, and a section whose whole text is
in such files still has its section record to carry them. The position of the include inside
the section is not recorded, and neither is what the file holds: the outline only keeps that
something there was not read. `propositions outline check` checks the shape,
`propositions outline status` counts the sections that carry `unread`, and
`propositions write prepare` names the unread files of a section before a paragraph is written
into it (for a rewrite, of every section). An outline whose sections all carry `unread` can have
an empty paragraph file. When the file becomes readable, the section is derived again or the
entry is removed through revise; either way the section is approved again.

```json
{"id": "s-method", "heading": "Method", "says": "The study compared two review schedules.", "unread": [{"file": "generated/sample-sizes", "why": "ignored by git"}]}
```

## Paragraph records

Each line of `outline-paragraphs.jsonl` is a paragraph record.

| Key | Required | Value |
|---|---|---|
| `id` | yes | A non-empty string, different from the `id` of every other paragraph record and of every point |
| `section` | yes | The `id` of a section record. A paragraph record whose `section` names no section record belongs to no section (see "When a section stands as approved") |
| `points` | yes | A list of one or more points |
| `from` | no | A list of one or more locators naming the passages this record comes from |
| `carry` | no | `true`: the record stands for a block that is moved from the passage its `from` names, unchanged apart from what `edits` lists and from cross-references that point elsewhere |
| `edits` | no | A non-empty string listing the changes made to the statement of a moved block. Only on a record that carries `carry` |
| `replaces` | no | A list of one or more locators naming the passages of the manuscript that this record takes the place of. They are not its source |
| `uses` | no | A list whose entries are ids, each the `id` of a paragraph record on an earlier line or of a point of such a record, or references to another outline (see "Several articles from one manuscript") |
| `dropped` | no | A non-empty string giving the reason the paragraph is left out of the article |
| `moved_to` | no | A non-empty string naming where a paragraph that is left out goes. Only on a record that carries `dropped` |
| `note` | no | A string for the author |
| `opens` | no | A list of one or more commitments the paragraph is planned to open, each `{"id": <commitment id>, "kind": <kind>}` (see "Planned commitments") |
| `discharges` | no | A list of one or more ids of commitments the paragraph is planned to discharge |

A point is an object.

| Key | Required | Value |
|---|---|---|
| `id` | yes | A non-empty string, different from the `id` of every other point and of every paragraph record |
| `text` | yes | One complete sentence stating one key point of the paragraph |
| `basis` | no | A list of one or more entries naming what supports the point: locators, or references to another outline |
| `pending` | no | A non-empty string naming what the author still has to supply before the point can be written |

**One point or several.** A record with one point states, in that point, what
the whole paragraph says. A record with several points states one key point of
the paragraph in each, in the order the paragraph makes them.

**Blocks that are moved, not rewritten.** A theorem statement, a proof, a
figure, a table, or a displayed formula or derivation that has a blank line
before it and a blank line after it is one record that carries `carry`. Its
points are complete sentences stating what the block states or shows ("Theorem
1 states that the interval covers the true value at the nominal rate."), and the
text of the block is not rewritten beyond the changes `edits` lists and cross-references that point elsewhere. "States Theorem 1." is not such a sentence. A record that carries `carry` has `from`: without it nothing
says which block is moved. A block that is moved with changes to what it states
(a sentence removed, a hypothesis added, a statement that no longer refers to a
theorem moved elsewhere) is still a moved block: its record carries `carry`
and `edits`, a string that lists those changes for the author, and its points
state what the block states after them. A change that only redirects a
cross-reference (where a `\ref` points, a number) is not a change to the
statement and needs no `edits`. `edits` on a record without `carry` is a
mistake, and so is an empty one: the write check reports both. Any other displayed formula or derivation is not a
block of its own: with no blank line on either side it belongs to the record of
the paragraph it stands in, and with a blank line on one side only it belongs
to the record of the paragraph on the other side.

**Passages a record takes the place of.** A paragraph that is written anew
in place of a passage of the manuscript (an abstract, a roadmap of the
sections) does not come from that passage, so the passage is not in its
`from`. It is named in `replaces`, a list of locators that are checked like
those of `from` and `basis`: each names one place. The passages of `replaces`
are not a source: the premise check does not read them as support for the
record's points. A record can carry both `from` and `replaces`, for a
paragraph that draws on one passage and takes the place of another; the same
locator is not in both, and the write check reports one that is.


**Planned commitments.** The structure sidecars record which proposition opens a commitment
(a question, an aim, a hypothesis, a plan item, an announcement, a setup, future work) and which
discharges it (`docs/STRUCTURE.md`). A paragraph record can plan both before the text exists
(issue #116): `opens` lists the commitments its paragraph will open, with the `kind` of each,
and `discharges` lists the ids of the ones it will discharge. The ids and kinds are written as
in the sidecars, so that the plan and the written text can be compared by id. A commitment is
opened once in the outline; a discharge names a commitment that the same record or a record on
an earlier line opens; a record that carries `dropped` carries neither key; and a record of a
section whose role is `abstract` opens none, as in the sidecars. `propositions outline check`
reports each of these. An outline plans commitments when a record that is not dropped carries
either key; a record of such an outline that carries neither plans that its paragraph opens and
discharges none. When a paragraph is written from such an outline, `write check` compares what
the paragraph opens and discharges in the staged discourse sidecar with its record, and each
difference is a problem that stops `write commit`: the author changes the text, or changes the
plan and approves the section again. An outline with neither key on any record (one derived
from a finished manuscript: derive does not write them) is not compared. The comparison is by
id and kind only; whether a sentence really opens a commitment is the judgment of whoever
annotates the paragraph.

```json
{"id": "p-1", "section": "s-intro", "points": [{"id": "p-1.1", "text": "It is not known whether spacing helps delayed recall."}], "opens": [{"id": "c-q-spacing", "kind": "question"}]}
{"id": "p-9", "section": "s-results", "points": [{"id": "p-9.1", "text": "Spacing improved delayed recall."}], "discharges": ["c-q-spacing"]}
```

**Order.** The paragraph records are grouped by section. The records naming one
section are on consecutive lines, and the groups come in the order of the
section file. Inside a group, the order of the lines is the order of the
paragraphs in the section. A paragraph record that carries `dropped` is not
part of the article and keeps its line in its group. A section can have no
paragraph record.

**`uses`.** A record can list what it relies on. Every id in `uses` belongs to
a record on an earlier line or to a point of such a record, so a paragraph
never declares that it uses something that comes later.

```json
{"id": "p-2", "section": "s-intro", "points": [{"id": "p-2.1", "text": "The method proposed here does not need that assumption."}, {"id": "p-2.2", "text": "A simulation will report how the two methods compare.", "pending": "the simulation has not been run"}], "uses": ["p-1.1"]}
{"id": "p-7", "section": "s-model", "carry": true, "points": [{"id": "p-7.1", "text": "Theorem 1 states that the interval covers the true value at the nominal rate."}], "from": [{"file": "manuscript/main.tex", "label": "thm:main"}]}
```

## Several articles from one manuscript

An outline is one article. When a finished manuscript is cut into several
articles, each article has its own outline directory with its own three files,
and the outline derived from the long manuscript stays as the record of where
everything came from. Three things then cross from one outline to another, and
each has a place.

**Where something went.** A section or a paragraph that is left out of this
article because it goes to another one carries `dropped` with the reason and
`moved_to`, a string in the author's words naming where it goes; `moved_to`
needs a `dropped` that is a non-empty string. `dropped`
alone means that it is left out; with `moved_to` it was moved. The string is
for the reader: the skill does not resolve it. A record with `moved_to` is
never deleted, whether or not it has `from` or `replaces`; when the author
takes it back into the article, `dropped` and `moved_to` are removed together.

**Which part.** A section record can carry `part`: `main`, `appendix` or
`supplement`. It says which part of this article the section is in; it does
not change the order of the sections or what the premise check does. `role`
says what a section does in the argument and `part` where it is printed: an
appendix of proofs has the `role` `proofs` and the `part` `appendix`.

**What another article establishes.** An entry of `uses`, or of the `basis`
of a point, can be a reference to another outline: an object with `outline`,
the path of that outline's directory from the repository's root, and `id`,
the `id` of a paragraph record or of a point in its paragraph file. It has no
`file`. An object with `outline` is always such a reference and never a
locator, however it is written; it goes in `uses` and `basis` only, and one in
`from` or `replaces` is reported. The other outline is in the same repository
(its root directory included; not a submodule, checked out or not, and not
a repository of its own under it), and is not this outline: a record of the same outline is named by
its `id` alone. The skill confirms that the directory is in the repository
and outside `.git`, that its paragraph file is a regular file, not a symbolic
link, that is JSON, and that the `id` is that of a paragraph record or of a
point in it (a section record's `id` is not). A reference that fails one of
these does not resolve and is a finding of the sixth kind, as is a `uses`
that is not a list or an entry of it that is neither a non-empty id nor a
reference.
Derive, draft and revise go on only when none is left, and revise checks
after every edit of the paragraph file: a record of another outline may have
gone since the last check. With an empty paragraph file there is no reference
to check. Nothing else is checked: the skill does not read what the other
record says, whether it carries `dropped`, or whether the other article comes
first, and the premise check does not judge a point against it. Whether two
articles that reuse one passage of the manuscript say the same thing about it
is not checked either: each outline names the passage in its own `from`.

## Locators

A locator names a passage. `from`, `replaces` and the locator entries of `basis` use the same object; an entry of `basis` with `outline` is a reference to another outline, not a locator.

| Key | Required | Value |
|---|---|---|
| `file` | yes | The path of a file inside the repository, relative to its root, not inside a `.git` directory in any letter case, and not ignored by git |
| `label` | one of `label` and `starts` | A LaTeX label whose text `\label{…}` occurs exactly once in that file. It names the section or the environment the label is attached to |
| `starts` | one of `label` and `starts` | The opening words of the passage, copied from the file, enough of them to occur exactly once in it |
| `lines` | no | A list of two line numbers, the first and the last line of the passage |
| `commit` | when `lines` is present | The commit at which those line numbers hold |

A locator carries `label`, `starts` or both. Line numbers stop being right as
soon as the file is edited, so they locate nothing by themselves: `lines` is
allowed only together with `commit`, as a record of where the passage was. When
`label` and `starts` are both present and name different passages, `label`
decides. When both are present, each is counted and each has to occur exactly
once.

**How `starts` is counted.** Occurrences are counted in the text of the file,
not in its lines: words that occur twice on one line occur twice, and two
occurrences that overlap count as two. In the
comparison every run of spaces, tabs and line breaks, in the file and in
`starts`, counts as one space, so the opening words can go on past the end of a
line. White space at either end of `starts` is ignored.

- A file has two proofs. Each opens with a line that holds only
  `\begin{proof}`, and the second goes on, on its next line, with "Let $y$ be".
  The words `\begin{proof}` alone occur twice and name neither proof. The words
  `\begin{proof} Let $y$ be` occur once, with the line break counted as one
  space, and name the second proof.
- The words "It repeats." occur twice on one line of a file and nowhere else. A
  `starts` of "It repeats." does not name a passage: it occurs twice.

**How `label` is counted.** The text `\label{` followed by the value of `label`
and `}` is counted in the text of the file the way `starts` is: every run of
spaces, tabs and line breaks, in the file and in `label`, counts as one space.
An occurrence in a LaTeX comment counts too, and a label written with a space
between `\label` and its brace is not found.

**A label names what it is attached to.** A label inside a passage does not
name the passage: a paragraph of prose that contains a labelled equation is
named by `starts`.

**A passage whose text occurs twice.** A passage that has no label of its own
and whose whole text, to its end, occurs a second time in the file cannot be
named: its opening words occur twice however many of them are taken. The
second occurrence can be another passage that reads the same, or part of a
longer one. This format has no locator for such a passage. Derive stops when
it meets one (see "The six
actions of the skill"); whether the format should be able to name them is open
(issue #84).

**The file is inside the repository, and git lists it.** It can be outside the
manuscript, such as a note in the same repository. Git has to list it: git
tracks it, or does not track it and does not ignore it. A new note that is not
committed yet is such a file. A file git ignores, or one that the repository
holding it gives no answer for, is not a locator's file: the skill does not read it, and an object naming
it is not a locator. Two repositories are asked. The first is the one that
holds the file, asked in the directory of the file: a file inside a submodule,
or inside a git repository of its own under the root, is judged by the rules
of that repository. The second is the repository, asked at its root whether it
ignores the path: when it does, the file is not a locator's file whatever the
first said, so a repository of its own inside a directory that the
repository ignores does not make its files readable. (Outlines written before
this rule can have locators into such a directory that resolved then and do
not now.) When the
repository gives no answer for the path, as it gives none for a file inside a
submodule, the answer of the first stands; any error of that second question
counts as no answer. A repository between the two is not
asked. The outline files sit beside the
manuscript and can reach the author from someone else, so a locator is not
allowed to make the skill read a file that was kept out of the repository on
purpose, such as one that holds credentials. The file
cannot be outside the repository: an object whose `file` leads outside it, by a
leading `/`, by `..` or through a symbolic link, is not a locator, and the skill
does not read that file. What counts is where the path leads: a path whose `..`
lead out and back into the repository is taken, though it then depends on the
name of the repository's directory; derive writes no `..`. A file inside a `.git` directory, or the `.git` file of
a submodule, is not a locator's file either.

The value of `file` holds no character from U+007F to U+009F and none that
breaks a line or turns the direction of text (U+2028 to U+202E, U+2066 to
U+2069); characters below U+0020 are already ruled out for every string. An
object whose `file` holds one is not a locator, and the skill does not print
that name as it is.

`from` and `basis` are lists of one or more locators. A `from` or a `basis`
that is not such a list, an empty list included, names no passage and is
reported like an object that is not a locator.

| Object | Is a locator |
|---|---|
| `{"file": "manuscript/main.tex", "label": "thm:main"}` | yes |
| `{"file": "notes/proof-sketch.md", "starts": "The bound follows from"}` | yes |
| `{"file": "manuscript/main.tex", "lines": [120, 131], "commit": "3f2c1ab"}` | no: neither `label` nor `starts` |
| `{"file": "manuscript/main.tex", "label": "sec:intro", "lines": [10, 42]}` | no: `lines` without `commit` |
| `{"file": "../other-paper/main.tex", "label": "thm:main"}` | no: the file is outside the repository |
| `{"file": "/etc/hosts", "starts": "localhost"}` | no: the file is outside the repository |
| `{"file": ".git/HEAD", "starts": "ref"}` | no: the file is inside a `.git` directory |
| `{"file": "secret.env", "starts": "API_KEY"}`, where `.gitignore` lists `*.env` | no: git ignores the file |

## Approval records

Each line of `outline-approvals.jsonl` is an approval record. Lines are only
ever added; the skill does not change or remove one.

| Key | Required | Value |
|---|---|---|
| `approved_at` | yes | The time of the approval, with its offset from UTC, such as `2026-11-13T16:30:00+08:00` |
| `statement` | yes | Words the author typed that state the approval, copied character for character from the author's message |
| `sections` | yes | A list of one or more entries |
| `whole` | no | `true` when `sections` has an entry for every section record of the section file as it was, in file order |

An entry of `sections` has two keys: `section`, a copy of a section record as
it was when the author approved, and `paragraphs`, copies of all the paragraph
records naming that section as they were, in file order, those that carry
`dropped` included.

The record stores the approved content itself, not a fingerprint of it. That is
what lets a later approval show the author exactly what has changed.

**What an approval record does not establish.** It does not say who approved,
and nothing in it is signed: anyone who can write to the repository can add a
record that makes every section stand as approved. The record is the author's
own note of what was agreed in a conversation, kept so that the skill does not
write from a plan the author has not seen. It is not evidence for a third
party; who added a line is in the history of the repository, not in the file.

## When a section stands as approved

A section **stands as approved** when the last approval record that has an
entry for it holds a `section` copy equal to the current section record and
`paragraphs` copies equal, one for one and in the same order, to the current
paragraph records naming that section. Two records are equal when they are the
same JSON value: the order of keys does not count, `1` and `1.0` are the same
number, and every key counts, defined in this document or not. Two numbers that
differ are different however long they are: the skill does not run with a `jq`
that reads 9007199254740993 and 9007199254740992 as the same number, as
versions before 1.7 do. A section for
which no approval record has an entry does not stand as approved.

The **order of sections stands as approved** when the ids of the section
records, in file order, are the ids of the `sections` entries of the last
approval record whose `whole` is `true`, in the same order. With no such
record, the order of sections does not stand as approved.

A section is **removed since its approval** when the order of sections does
not stand as approved, the section is not in the section file, and its latest
approved copy is in the last approval record whose `whole` is `true`, or in an
approval record after that one; with no approval of the whole outline on
record, any approved copy counts. Once an approval of the whole outline is
recorded without the section, its removal is approved and the section is no
longer reported. When the order of sections stands as approved, the section
file holds exactly the sections of the last approval of the whole outline, and
no removal is waiting for an approval. A section that is put back after its
removal was approved stands as approved when it equals its own latest approved
copy, which an earlier record holds; the order of sections then does not stand
as approved, and before the next approval of the whole outline the skill shows
that section as added (see "What counts as an approval").

The **outline stands as approved** when every section stands as approved, the
order of sections stands as approved, and every paragraph record names a
section record in `section`.

A paragraph record whose `section` names no section record belongs to no
section. It is in no `paragraphs` copy, so no approval covers it, and it is
never shown with a section. While the paragraph file holds one, the outline
does not stand as approved, whatever the approval records say, and the skill
appends no approval record.

**Approving sections one at a time does not approve their order.** That takes
one approval record that covers every section. An outline of three sections
with three approval records, each with an entry for one section and none with
`whole`, has three sections that stand as approved, an order of sections that
does not, and so an outline that does not. The skill says then that an approval
of the whole outline is still needed.

Any difference counts. The skill does not judge whether a change is a change
of substance or of wording: a section that differs from its approved copy goes
back to the author.

A section is compared with its own records only. When a point of another
section that one of its records names in `uses` changes, the section still
stands as approved: no tool follows `uses` (issue #78).

An outline has the sections `s-a` (paragraph records `p-1`, `p-2`) and `s-b`
(paragraph record `p-3`) and one approval record with `whole` true that covers
both. Then one change is made:

| Change | `s-a` stands | `s-b` stands | Order of sections stands |
|---|---|---|---|
| The text of a point of `p-2` is reworded | no | yes | yes |
| The lines of `p-1` and `p-2` are swapped | no | yes | yes |
| `p-2` is moved to `s-b` | no | no | yes |
| `p-3` is given `dropped` | yes | no | yes |
| An undefined key `length_target` is added to `p-3` | yes | no | yes |
| `p-1` is written again with its keys in another order and the same values | yes | yes | yes |
| A section `s-c` with one paragraph record is added | yes | yes | no |
| The lines of `s-a` and `s-b` are swapped, with their groups of paragraph records | yes | yes | no |

After the change in the seventh row, `s-c` does not stand as approved either:
no approval record has an entry for it.

These conditions are what the later step uses to decide whether text can be
written from an outline (issue #51).

## What counts as an approval

The skill appends an approval record only when both of these hold: it has shown
the sections concerned, as they now are, earlier in the same conversation; and
the author, in the message the skill is answering, states in words the author
typed that the outline or those sections are approved.

The skill asks for the approval in plain text and waits for the author's
message. It does not offer approval as an option to select: a selected option
is not words the author typed. `statement` holds the words of that message that
state the approval, copied character for character.

None of the following is an approval. The list is closed.

1. An instruction given before the version shown existed, such as an
   instruction to derive an outline and then go on to write.
2. An approval passed on by another agent or another session.
3. An approval of an earlier version, or of sections other than the ones
   concerned.
4. No reply, or a reply about something else.
5. An instruction to this skill or another one to start writing.

By default the skill shows the whole outline and asks for approval of the whole
outline. When the author asks for particular sections to be approved, it shows
those sections only. The record it appends covers the sections the author
states are approved, which can be fewer than the sections shown, has at least
one entry, and holds the sections as they were shown. It has no entry for a
section that was not shown: when the author names such a section, the skill
leaves it out of the record, says that it was not shown, and shows it. When
none of the sections the author names was shown, the skill appends nothing. The
record has `whole` true when it covers every section record, and no `whole`
otherwise.

The skill keeps, outside the repository, a copy of the section file and the
paragraph file as they were when shown, so that the approval can be recorded
when the author's reply arrives in a later message. The premise check that runs
before the sections are shown reads this copy, and what is shown comes from it.
When the section file or the paragraph file differs from that copy at the time
of the approval, when the real path of the outline directory differs from the
one recorded when the copy was taken, or when the copy, or the record of which sections were shown, is no longer available, the skill appends nothing and shows the sections again. When a
paragraph record of the copy names no section record, the skill appends nothing
either: it shows that record first, and the record is corrected through revise
before the outline is shown again.

The record is appended as a line of its own: when the last line of the
approvals file is not ended by a line break, the skill ends that line first.
The line break that ends a line is not part of its content, and the skill does
not change the content of an earlier line. What the skill writes down for one
approval, the author's words and the sections approved, is not used for a later
one.

What the skill shows for a section depends on its approved copy.

- A section that has no approved copy is shown in full: its `heading` and
  `says`, every paragraph record naming it with its points and its `note`, and
  every record that carries `dropped` together with the reason.
- A section that differs from its approved copy is shown by its differences:
  for each record that was changed, added, removed or moved, the approved
  content and the current content. The skill says that the rest of the section
  is as it was approved, and shows the section in full when the author asks.
- A section that equals its approved copy is shown as unchanged since its
  approval.
- In both ways of showing a section, and wherever else a paragraph record is
  shown for approval (the approved copy of a changed record, the records of a
  section removed since its approval), two things are said beside the record
  they concern, as labelled quotations of the record and not as words of the
  skill: a record's `edits`, with the sentence that the block is moved with
  these changes, not unchanged; and what a record's `replaces` names, with the
  sentence that the record takes the place of those passages. What a record
  names in another outline is shown the same way in both, with whether each
  reference resolved, did not resolve, or was not checked. Text taken from a record is shown inside a fenced
  code block whose fence is longer than any run of backticks in the text, so
  that nothing in it closes the block or is rendered as a link, as markup or
  as a heading, and a control character in it is written as its code point.

The findings of the premise check on a section are shown with it in all three
cases.

Whenever the sections shown are all the sections of the section file, the
skill shows three more things first, because an approval of all of them is an
approval of the whole outline and approves all three.

- **The order of the sections**, when it does not stand as approved: the
  sections in the order they are in now, and beside it their order in the last
  approval of the whole outline when one is on record. Two sections that were
  swapped each still equal their approved copy, so without this the author
  would approve a new order without seeing it.
- **The sections that are gone**: every section removed since its approval,
  with its heading, its `says` and the points of its paragraph records as they
  were last approved.
- **The sections that were added**: every section of the file that the last
  approval of the whole outline does not hold, when one is on record, shown in
  full. A section that was taken out, approved as gone with the whole outline,
  and put back unchanged still equals its own latest approved copy, so without
  this the author would approve its return without seeing it.

When fewer than all the sections are shown, and the order of sections does not
stand as approved or a section was removed since its approval, the skill says
that the order of the sections, with the sections added to it, or the removal
of a section, is not part of this approval: it takes an approval of the whole
outline.

Agreeing to have a derived or drafted outline written to disk is not an
approval of it.

## The premise check

Each time before sections are shown for approval, they are checked. The check
begins with the checks the skill runs after a write (see "What is checked
today"), on the section file and the paragraph file it examines: a file that
was changed by hand can hold a line that is not a record. When one of them
fails, the skill reports the file and the lines, counts nothing and starts no
agent. A paragraph file with no record is not reported as passing, and it
does not stop the check either: an outline can have sections and no paragraph
record yet, so the skill says that the file is empty and goes on. The check reports findings of six kinds
and no others.

1. **Not a sentence**: a `says` or the `text` of a point that is a heading, a
   label or a fragment.
2. **Not supported by its source**: a point whose record has `from`, or which
   has `basis`, and which the passages named do not state, or which they
   contradict.
3. **Nothing to check against**: a point that states a result, a number or a
   citation, in a record without `from`, and that has neither `basis` nor
   `pending`.
4. **Relies on something later**: a point that needs a term, a result or a
   claim that only a later record introduces, or a `uses` entry that names an
   id which is missing, is not on an earlier line, or belongs to a record that
   carries `dropped`.
5. **Section not carried**: a section whose `says` is neither stated nor
   supported by the points of its paragraph records and of the paragraph
   records of the sections under it. The sections under a section are those
   that name it as `parent`, directly or through other sections.
6. **Locator does not resolve**: a locator whose `file` is missing, leads
   outside the repository, is inside a `.git` directory in any letter case, is
   not a file git lists, or has a name the locator rules do not allow, whose `label` text
   does not occur exactly once in the file, or whose `starts` does not occur
   exactly once in the file. An object in `from` or `basis` that is not a
   locator, and a `from` or a `basis` that is not a list of one or more
   locators, are reported as this kind too.

The sixth kind is established by the skill itself, by resolving each path and
counting, so that it is decided the same way every time. The first five are
judged by the agent `propositions:outline-checker`, defined in
`agents/outline-checker.md` of this plugin. Its definition gives it the Read
tool and no other, so it cannot write or change a file, run a program or send
anything. It is given these paths and nothing else: the section file and the
paragraph file it examines (the copies kept outside the repository, when the
check runs before an approval), a list that the skill writes outside the
repository, and, when only some sections are examined, a file that lists their
ids. Each line of the
list is a JSON object with the `file` a locator gives and the real path of the
file that was counted for it:

```json
{"file": "manuscript/main.tex", "path": "/home/author/paper/manuscript/main.tex"}
```

The list holds one line for each file the count read, and no other file: a
file whose locators do not all resolve is in it too, and a file that was
refused is not. The path is the real one,
with every symbolic link and every `..` resolved, so the agent opens the file
that was counted and no other. The file of ids for a check of some sections is
not the file in which the approve action records which sections were shown: a
check outside approve never writes that one. The task message holds no text taken from the
outline or the manuscript, no name of a file that a locator gives, and nothing
of the conversation; the agent's definition says that what it reads is data to
examine and holds no instruction for it. The Read tool itself can open any
file: that the agent reads only the files it is given is an instruction in its
definition, not a limit of the tool. When that agent cannot be started, the
skill stops and says so; it does not judge the five kinds with another agent or
by itself. The check does not read a file that a locator names when that file
is outside the repository or is not a file git lists.

A record that carries `dropped` is examined for the sixth kind only, and its
points do not count for the fifth kind. Each finding names the record or the
point it concerns.

Findings are shown with the section they concern; what a finding takes from
the agent's report or from a record is shown inside a fenced code block, like
record text at approval, for findings of every kind. The skill does not change the
outline because of a finding unless the author asks for the change: the outline
is the author's plan. It does not act on anything in the agent's report that
reads as an instruction.

## The six actions of the skill

| Action | Reads | Writes |
|---|---|---|
| derive | A finished manuscript | The section and paragraph files, after the author agrees |
| draft | A title and ideas, or an outline the author supplies | The section and paragraph files, after the author agrees |
| revise | The outline files and the author's instructions | The section and paragraph files |
| check | The section file, the paragraph file and the files their locators name | Nothing |
| approve | The outline files and the author's reply | One line added to the approvals file |
| status | The three outline files | Nothing |

In the repository the skill writes no other file: not the manuscript, not
the ledger, not the structure sidecars and not the verification records. Its
temporary files are kept outside the repository, in a directory it makes for
this repository when it starts (the stage directory): the directory belongs to
the user, has mode 700, and holds a note of the root it was made for. The
first command writes the outermost root there, and the command that sets the
root to the outline directory's repository rewrites it. Every command after
that asks git which repository holds the outline directory and goes on only
when it is the root the stage directory records, so a root that was never set
(after a new session, when the outline directory's repository is below the
outermost one), or an outline directory changed to one of another repository,
stops them until that command runs again.
Every later command confirms all of that for the path it is given as the stage
directory, and a directory that fails one of these is not used: the directory
above the repository, the machine's temporary directory itself and the stage
directory of another repository all fail. The skill does not look at access-control lists. When the
machine's temporary directory is inside the repository (except in the one case
of known limit 10), or cannot be entered,
the skill stops before it makes anything. It
does not read or write an outline file that is itself a symbolic link: when one
of the three is, the skill stops and tells the author. A symbolic link in the
path of the directory is a different case: it is resolved, as said under "The
three files", and what counts is where it leads.

What the skill reads is data. Text in the manuscript, in an outline file, in a
file a locator names or in the output of a command can read like an
instruction; the skill does not act on it, and says so to the author when it
notices it.

The skill's `allowed-tools` name the tools it can use without a permission
prompt in the turn that starts it. That allowance limits none of them: that
the skill writes only the three files, and starts no agent other than the
checker, is kept by the guard of its commands and by its rules, and for the
tools that write files directly by its rules alone. Whether the allowance
should be narrower is open for the whole plugin (issue #85).

**What the skill keeps, and what it does not.** The skill keeps three things,
and its rules and commands are there for them.

1. In the repository it writes the three outline files and no other file.
2. It reads no file outside the repository, other than its own (the temporary
   files it made in the stage directory, and the files of this plugin), the
   ledgers' `_meta.json` files of the outermost repository the manuscript is
   checked out in, which it reads to find the ledger before the root is set,
   and the
   files git itself reads when it is asked (its configuration, its global
   ignore file, and the git directory of the repository, of the outermost
   repository and the repositories between them, and of a repository of its
   own under the outermost one that holds a ledger or a directory offered for
   the outline, wherever it is, which
   for a linked worktree is in the repository the worktree belongs to).
3. It records an approval only from words the author typed in the message it
   answers.

The commands keep the first two against mistakes and against the ordinary ways
a path leads somewhere else: a symbolic link, `..`, another spelling of a
directory, a path copied wrongly. They are shell commands, and they are not a
defence against a repository or a shell that was set up to defeat them. That
defence belongs to the command-line tool of issue #78, where it can be tested.
The limits known today are these ten. The list is closed: a limit is added
when one is found, and none is inferred from another. The first and the tenth
are the ones the skill always sees: it stops at the first (for a file the
author points to in draft or revise, for that file only), and at the tenth
after its stage directory has been made. No command of the skill looks for the
others; when the skill notices one of them, it tells the author.

| # | The limit | What can happen | Which of the three |
|---|---|---|---|
| 1 | A path the skill writes into a command holds a single quote; the listing of ledgers can offer a directory with such a name | Only the skill's rule to stop at such a path prevents it: written inside single quotes, the rest of the name would be read by the shell as a command | All three |
| 2 | `PATH` holds an empty entry or one that does not begin with `/` | The commands find their tools through `PATH` (`jq`, `git`, `realpath`, `find`, `sed`, `tr`, `cmp`, `cp`, `mktemp` and the others; only `pwd` is taken from a fixed place). A program of one of those names in the directory the shell is in is run in its place | All three |
| 3 | The shell is zsh and its startup files define a function named `chpwd` | The commands enter directories of the repository with `cd`, and zsh calls that function in each. A function that acts on files of the directory it is called in then acts on files of the repository | The first and the second |
| 4 | The repository holds a git repository of its own that someone else made (a directory with its own `.git`, which no commit can carry) | Git reads the configuration of every repository it answers for. The commands switch off the one setting known to make their git commands run a program, and look no further into that configuration | All three |
| 5 | The shell sets `noclobber`, or makes `cp` ask before it overwrites | Some commands fail, and the skill stops | None |
| 6 | The machine's temporary directory hands down an access-control list | The stage directory has mode 700, which says nothing about such a list: the copies in it can be readable by someone else | None |
| 7 | A file system that does not give a file the same identity each time it is asked (some network volumes) | The test "is this the same file" can fail for a right path, and the skill stops or leaves the file unread | None |
| 8 | The environment sets a variable that steers git, such as `GIT_DIR` or `GIT_WORK_TREE` | Git answers for another repository than the one the directory is in, and the root the skill takes is not the root of the outline directory's repository | The second |
| 9 | Text that the skill or the checker reads (the manuscript, a file a locator names, a file the author points to, the outline files) asks the reader to read another file | The Read tool of the checker agent, and of the skill, can open any path; only their rules keep them to the files they are given | The second |
| 10 | The repository's root is the root of the file system | The machine's temporary directory is then inside the repository, and the first command makes the stage directory there before the skill stops | The first |

**derive** produces one section record for each section of the manuscript and
one paragraph record for each of its paragraphs and blocks. It reads the
manuscript's main file by its real path, after confirming again that the file
is one it reads (see "The three files"). It follows the
files that the manuscript includes, whose names end in `.tex` in any letter
case, only when they are regular files
inside the repository that git lists and whose path holds no line break and,
below the root, no other character that a locator's `file` is not allowed to
hold. Any other included file
is named to the author and not read: one outside the repository, a symbolic
link, a file reached through a directory that is a symbolic link, a file
inside a `.git` directory in any letter case, a file git ignores (a generated
table, for instance), a file git gives no answer for (one in or under a
directory laid out like a git repository), a file whose path holds such a
character, or a missing file. An include whose name does not end in `.tex` in any letter case names the
file with `.tex` added (`\input{fig.tikz}` names `fig.tikz.tex`): that file is read when it exists and is a file the skill reads, and is a missing file when it does not exist, the usual case for a figure, a table or a style file kept under its own name. A
table or a figure that comes from a file that was not read is still one record
that carries `carry`, named in the file that includes it. Any other included
file that was not read is recorded in `unread` on the record of the section
its include command stands in, one entry for each include command (issue
#117), and gets nothing else (no paragraph record, no locator, no point, no
`note`); derive names it to the author. An include command
`\input{x}` or `\include{x}` names the file `x` when `x` ends in `.tex` in any letter case, and
`x.tex` otherwise, taken from the directory of the main file; it is read only
when it is a file the skill reads, and the skill does not look for it
anywhere else. On a file system that ignores letter case the same file in
another letter case is the same file. A command inside a LaTeX comment includes nothing. When the files
derive read hold no paragraph and no block at all (a paragraph counts when
derive read any of its text; a block, which is a theorem-like statement, a
proof, a figure, a table or a displayed formula, counts when derive read the
environment or the delimiters that hold it, even when its content is in a file
that was not read) and no included file was left unread, derive stops and writes nothing; it
stops before it asks for any section's `says`, and says that draft builds an
outline from the headings of such a manuscript. When they hold none because
the text is in included files that were not read, derive goes on: the section
records carry those files in `unread` and the paragraph file is empty. When
all the text of a section is in included
files that were not read, derive asks the author for the `says` of each of those sections, since
it has nothing to state it from, and stops when the author gives none. When such a
section ends with no paragraph record, of its own or of a section under it,
the premise check reports it under its fifth kind each time, and derive tells
the author why. An abstract that has
no heading of its own gets the `heading` "Abstract". Prose that comes
before the first heading and is not the abstract gets one section record,
whose `heading` is the title of the article: that title is what heads the text
on the page, as in APA style, where the introduction has no heading of its
own. The skill tells the author that this section has no heading of its own in
the manuscript, and asks what to put in `heading` when the manuscript gives no
title. Every paragraph record it produces has `from` naming the passage it
comes from, with the name of the file from the root, as "The three files"
defines it, as `file`,
and every point states only what that passage states. A
theorem-like statement, a figure or a table is named by its own label; the
label of a section names the whole section and is not used for a record. It
writes no `lines` and no `commit`. Before it shows the outline, it confirms
that every locator it wrote resolves. When a passage that has no label of its
own has a text that, to its end, occurs a second time in the same file, no
locator names it. Derive then stops: it tells the author which passages they
are, shows no outline and writes nothing to the repository. It does not take
opening words from the passage that follows. The author can change one of the
two places, or give the passage a label when it is a block that can carry one.
It stops the same way when a file it read is not accepted as a locator's file. A
manuscript that has paragraphs never gives an empty paragraph file.

**draft** does not invent content. A point that would report a result, a number
or a citation the author has not supplied says what will be reported without
stating it, and carries `pending`. When the outline the author supplies has
sections and no paragraph yet, draft writes no paragraph record, and the
paragraph file is empty. Draft needs no manuscript: with none, no ledger names
it, and the directory of the outline files is the author's decision. When a
locator the author asked for does not resolve, draft does not rewrite it: it
says which and why, and asks the author whether to correct it or to leave it
out of the record. A file the author points to (a note, an earlier draft, an
outline of the author's own) is read only after the check the skill runs on
the manuscript's main file accepts it, and by the path that check gives; when
the check refuses it, the skill asks the author to paste the text instead.
The same holds in revise.

Both show the outline to the author before any file is written in the
repository, and write the files there only after the author agrees. Neither
overwrites or adds to existing outline files. When the section file or the
paragraph file exists, the action stops and says that revise is the action to
use. When only the approvals file exists, the action stops too: a new outline
is not started beside the approvals of an earlier one, and what to do with
that file is the author's decision.

**revise** changes the files only as the author instructs, under these rules.

- A record and a point keep their `id` when their content changes and when
  they move.
- Merging and splitting replace records. The records that are merged, and the
  record that is split, leave the file; the records that replace them are new.
  A new record or point, a replacement included, gets an `id` that appears in
  neither outline file and in no approval record. A replacement never takes
  the `id` of a record it replaces.
- The `from` of the record that replaces merged records holds every locator of
  the `from` lists of the records it replaces, and its `replaces` every locator
  of their `replaces` lists. When a record that has `replaces` is split, each locator of it is
  in the `replaces` of at least one of the records that replace it. A record
  that has `replaces` and that the author leaves out is not deleted: like a
  record with `from`, it is given `dropped` with the reason. Records are not
  merged when a locator is in the `from` of one and the `replaces` of another
  until the author has said which of the two the passage is for the merged
  paragraph; the locator is then taken out of the other list before the merge.
  A record that carries `carry` keeps its `from`: when the passage is a moved
  block's source, it can only leave the other record's `replaces`, or the
  records are not merged. When the author wants both, the records are not
  merged. The same holds before a point of a moved block moves to a record
  whose `replaces` has a locator of the block's `from`. A record that
  stands for a moved block after a revision (a merge, a split, or the block's
  point moving to another record) carries `carry`, the `from` of the block and
  the `edits` that apply to it; when the changes cannot be divided, or no
  record stands for the block any more, the skill asks. Two moved blocks do
  not share a record: two records that each carry `carry` are not merged, and
  the point of one moved block is not moved into the record of another.
- When a record that has `from` is split, each record that replaces it has in
  its `from` at least one locator of the original, and each locator of the
  original is in the `from` of at least one of them.
- When a point moves to another paragraph record and the record it leaves has
  `from`, each locator of that `from` is added to the point's `basis`, so that
  the point keeps its source; a locator the point already has is not added
  again. Nothing is added when the point is that of a moved block and the
  record it moves to takes over the block, with `carry` and the block's
  `from`: the source is then in that record's `from`. A record is not left with no point: when the
  point that moves is the last one of its record, the skill asks the author
  whether that record is given a new point or is left out. Left out, a record
  with neither `from` nor `replaces` is deleted once the point has moved. A
  record with `from` or `replaces` can be neither deleted nor left without a point: the point moves with its `id`,
  and the record keeps a copy of the point's text as a point with a new `id`
  and is given `dropped` with the reason.
- A record's `note` stays with it when it changes, moves or is given
  `dropped`; a record that replaces merged records holds their notes, and
  each record that replaces a split record holds its note.
- When the author leaves a paragraph out of the article and its record has
  `from` or `replaces`, the record is not deleted: it is given `dropped` with
  the reason. A record with neither that the author leaves out is deleted from
  the file.
- When the author leaves a section out, three things happen in this order.
  First, the sections under it are settled: each is left out with it, or is
  given another `parent` or none, as the author says; the skill asks when the
  author has not said. Second, each paragraph record naming the section is left
  out by the rule above. Third, the skill looks at what still names the
  section: when no paragraph record and no section record names it any more,
  the section record is deleted from the file; otherwise it stays and is given
  `dropped` with the reason.
- A section that is moved takes the sections under it along, so that they stay
  on later lines than it. A section is not moved to a line before its own
  `parent`: it is given another `parent`, or none, first, as the author says.
  The skill asks when the author has not said.

Because no source is ever discarded, the question "where did each passage of
the original go" can be answered from the `from` lists and the `replaces`
lists (a passage named in a `replaces` went nowhere: the record that names it
stands in its place), together with the
`basis` of the points that were moved: every passage named in a `from` is
a source of a record that is in the article, or of a record that carries
`dropped` with its reason, and a point that was moved out of such a record
carries the locators of that passage in its `basis`. The `from` lists alone
do not show that a point of a passage now stands in another record. The
answer names the passages as they were when the
locators were written. Derive records no commit, so after the manuscript is
edited a locator can stop resolving; the `from` lists then still say which
records each passage went to, but the passage may no longer be found by its
locator.

When a revision leaves a `uses` entry that names a later line, a record that
is no longer in the file or a record that carries `dropped`, the skill tells
the author and does not delete the entry itself.

After a revision the skill says which sections no longer stand as approved,
and which sections were removed since their approval.

**status** reports, for each section, whether it stands as approved, and for a
section that does not, whether it was never approved or differs from its latest
approved copy. It reports whether the order of sections stands as approved,
the sections removed since their approval,
the paragraph records that name no section record, the number of points that
carry `pending` and the number of records that carry `dropped`. When every section stands as approved and the order of sections does
not, it says that an approval of the whole outline is still needed. It decides
equality on JSON values, not on the text of the lines. An approvals file that
is empty or holds only blank lines holds no approval record. When the approvals
file exists but cannot be read, or holds a line that is not empty and is not
one JSON object written as JSON on its own (a record spread over several
lines, two records on one line, a line of spaces, a value such as `nan`),
status fails and says so; it does not report the outline as never approved.
It fails too, and says that the approvals file is at fault, when the
`sections` of an approval record is not a list of entries that each hold a
`section` object and a `paragraphs` list of objects. Whenever it fails,
nothing it printed is a status. Before it compares, status runs the check of a
write on the section file and the paragraph file, and reports no status when
either fails (an empty paragraph file excepted): jq reads some values that are
not written as JSON, such as `01`, as if they were. When it fails because the
section file or the paragraph file is missing or is not a readable regular
file, or holds a line that is not a record, the skill
names the file, and the line when the check of a write finds it, and corrects
nothing: status writes nothing, a file with such a line is corrected through
revise, and a missing file is the author's to put back.
When writing the record into the approvals file fails (a full disk, for
one), the record may have been appended in whole, in part or not at all:
the skill shows the check of the approvals file and the
status, says that the approval may or may not be on record, and
stops without trying again, since it never changes a line of that
file.
The approve action checks the file the same way before it appends, and appends
nothing when the file fails or cannot be read: the file was changed by hand,
the skill says so,
and what to do with it is the author's decision. The skill never changes a
line of it.

## What is checked today

The skill's checks are commands that call `jq`, `realpath` and `git`. A check
counts as passed only when its command says so; a command that prints nothing,
fails or cannot run is a failed check, and when one of the three tools is not
installed the skill stops and says which. It stops too when its `jq` reads two
long numbers that differ as the same number, as versions before 1.7 do; when
its `git` is older than 2.38, the first version with the setting described
below; when the system's `pwd` is in neither `/usr/bin` nor `/bin` (the names
of directories rest on it, and the skill looks for it nowhere else; NixOS is
such a system); and, with a line that begins with `STOP`, when git finds no
repository for the manuscript's directory or cannot say whether that
repository is checked out inside another. On a system whose packaged `jq` or
`git` is older than that, the skill does not run.

Every git command of the skill that reads a repository is run with two
settings, `safe.bareRepository=explicit` and `core.fsmonitor=false`. With the
first, git takes a directory for a repository only when a `.git` is in it or
above it: files of the working tree that are laid out like a repository (a
`HEAD`, an `objects`, a `refs` and a `config`, which a commit can carry like
any other files) are not taken for one, and that `config` is not read. Git
does not pass such a directory by, though: asked in it, or in a directory
under it, git refuses to answer. A source there is not read: derive does not
follow a `.tex` file there, a locator that names a file there does not
resolve, and a manuscript there stops the skill at its first command, where
git's own error gives the reason. A `_meta.json` there is still listed,
because the listing does not ask git; when there is a manuscript, its
comparison with the manuscript does not run to its end, so the skill asks;
when there is no manuscript yet, the comparison runs no git, and the file
counts as compared. With
the second, git starts no file-watching program that a configuration names. A
linked worktree, and a repository whose `.git` is a file, are found as before.

Text from the manuscript, from an outline file
or from the author reaches those commands only from a file that the command
reads; it is never written into the text of a command. The paths the skill
writes into its commands are the repository's root, the outline directory, the
stage directory, the directory that holds the manuscript, the manuscript's
main file, and a file the author points to in draft or revise (a source, or
an outline of the author's own), checked the way the main file is before it
is read. Each begins with `/`: an empty path, or one not written out in
full, stops the skill, and so does a path that holds a single quote; for a
file the author points to, such a path stops the skill for that file only:
it does not read the file and asks the author to paste the text. The one
exception is the main file in the command that compares a ledger with it:
left empty there, it means that there is no manuscript yet. The command that
sets the root takes the directory where the manuscript will be in its place,
so its path is never empty. The paths
of the ledgers' `_meta.json` files are read from a list in the stage directory,
not written into a command. The task message for the agent of the premise
check is held to the same rule.

After every write to an outline file, the skill confirms that every line of
that file that is not empty is a JSON object written as JSON. jq also reads
`nan`, `Infinity` and numbers such as `01` or `.5`, none of which is JSON; the
check reads the text of the line to report them. It does not report a byte that
is not UTF-8: jq reads it as a replacement character. After a write to the
section file or the paragraph file it also confirms that every record has an
`id` that is a non-empty string, that no `id` repeats among the section
records or among the paragraph
records and points, that no string holds a control character, and that no
number is too large for jq to keep (such as `1e400`, which is JSON but which jq
reads as infinite). In the
paragraph file it also confirms that every point has an `id`, that `points`,
where a record has it, is a list, that `edits` is a non-empty string on a
record that carries `carry`, and
that no locator (the same `file` and `label`, or with no `label` the same
`starts`) is in both the `from` and the `replaces` of
a record. The shape of a key that a section record
carries and this document does not define is not checked, a key named `points`
included; the control-character test still reads every string and key name.
When any of
these fails, it reports the file and the line and does not report the write as
done.

The check never reports a pass for a file that holds no record. An empty
section file is always a mistake. An empty paragraph file is a mistake too,
with two exceptions, and only these two: the outline the author gave to draft
has sections and no paragraph yet, so the skill writes no paragraph record; or
the author, through revise, leaves out every paragraph record and none of them
has `from`, so each is deleted. Then the paragraph file is rightly empty. The
check still does not report a pass for it; the skill says in its report that
the paragraph file is empty, and goes on.

The control-character test catches some backslashes that were written once
instead of twice, not all of them.

| Written in the file | What the string holds | Caught |
|---|---|---|
| A backslash before most letters, as in `\alpha` | Nothing: the line is not JSON | yes, as a line that does not parse |
| A backslash before `b`, `f`, `n`, `r` or `t`, as in `\beta`, `\frac`, `\nu`, `\ref`, `\text` | A control character and the rest of the word | yes |
| A backslash before `"`, `\` or `/`, as in `\"o` or a LaTeX line break | The text without that backslash | no |

In a `starts` the third case shows up when the locator is resolved, because the
words no longer occur in the file. In a `says` or a `text` nothing catches it.

The write check also confirms, in both files, that `moved_to` is a non-empty
string on a record that carries `dropped`, and in the section file that `part`
is one of `main`, `appendix` and `supplement`. Each time the premise check
runs, and after a revision that wrote one, the skill confirms every reference
to another outline as "Several articles from one manuscript" says.

When derive or draft has written locators, and each time the premise check
runs, the skill resolves every locator: the file exists inside the repository
and not inside a `.git` directory in any letter case, git lists it, its name
holds none of the characters the locator rules exclude, the text of the `label`
occurs exactly once,
the `starts` occurs exactly once. It reports an object that is not a locator:
one without a `file`, one with neither `label` nor `starts`, one whose `label`
or `starts` is not a string, one with `lines` and no `commit`. It reports a
`from` or a `basis` that is not a list of one or more locators.

Status reports every paragraph record whose `section` names no section record,
and the approve action appends nothing while there is one.

That is all: the checks of a write, the resolving of locators, and what status
reports. Until issue #78 no tool checks whether a required key is missing
(a record whose `points` is missing or an empty list, a point without `text`, a
section record without `says`), whether a record
that carries `carry` has `from`, what `lines` and `commit` hold, whether an
approval record has only its four keys and the shapes of `approved_at`,
`statement` and `whole`, whether a record carries the same key twice (jq keeps
the last one, so the check of a write, status and an approval all see that
one), whether a
`parent`
names a section record on an earlier line, or whether the groups of paragraph
records are in the order of the section file; only the author's reading stands
in for these. Whether a `uses` entry names a record or a point on an earlier
line is one of the five kinds the premise check's agent judges.

## Writing text from the outline

Text is written from the outline one paragraph record at a time, by the write mode of
`/propositions:prop-construct`, through `propositions write prepare --outline <directory>
--outline-paragraph <id>`, `write check` and `write commit` (issue #51). Prepare stages nothing
unless the outline passes `propositions outline check`, the id names exactly one paragraph record,
that record does not carry `dropped`, and its section stands as approved (see "When a section
stands as approved"). The three files are copied into the staging directory as files that are
not written back: a change to them after prepare makes the commit refuse.

After it writes the paragraph, `write commit` appends one line to a fourth file in the outline
directory, `outline-trace.jsonl`:

| Key | Value |
|---|---|
| `outline` | The id of the paragraph record the paragraph was written from |
| `first_prop` | The id of the first proposition of the written paragraph |
| `section` | The id of the record's section |
| `approval_line` | The line of `outline-approvals.jsonl` that holds the approval the section stood on |
| `part` | Only when `article.json` names destinations: the part the section goes to, one of `main`, `appendix`, `supplement` (see "article.json"). A record without it belongs to `main` |

```json
{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-00000000000d", "section": "s-a", "approval_line": 1}
```

This file is the only tie between a paragraph record and text. The id of a paragraph record and
the id of a paragraph in `structure.json` have the same shape (`p-1`) and say nothing about each
other: `p-1` here is not `p-1` there. Neither the ledger nor the structure sidecars change format
for it. No skill writes the file except through `write commit`; the outline skill reads and
writes only the three files. `propositions outline trace <directory> --jsonl <ledger>` lists the
records with the location of each proposition and reports a record that names no paragraph
record, a proposition that is not exactly one live proposition of the ledger, or a proposition
recorded twice.

A finished manuscript is reorganised by rewriting it from its revised outline (issue #115):
derive the outline, revise it and approve it as a whole, then `write prepare --rewrite --outline
<directory>`. The whole outline has to stand as approved: every section, the order of sections,
and no removal waiting. Every file of the input tree may change; the ledger keeps every
proposition, and a passage that is not carried unchanged has its propositions retired with
`replaced_by` naming the new ones (the `from` of a record says which passages it comes from).
The staging directory holds `outline-map.jsonl`, one line per paragraph record that is not
dropped, `{"outline": <id>, "first_prop": <id>}`, each naming the proposition that starts the
paragraph. `write commit` writes `outline-trace.jsonl` anew from it, in the same format as above:
the old records name paragraphs of the text the rewrite replaces, and the old file is kept in the
backup with a list of where each copy came from. That a paragraph says what its record plans is the
author's to confirm; the commands check only that the map is complete and points at live
propositions that start paragraphs.

A trace outlives the outline it was written from when the three files are moved and a new
outline is started in the same directory: its records then name ids of the new outline. Move
`outline-trace.jsonl` with the three files.

## article.json: what is true of the whole article

One optional file, `article.json`, holds what is true of the whole article and not of one
section. It is a JSON object in the directory of the outline files, which is the directory of
the ledger; a manuscript with a ledger and no outline can have one too. It is not an outline
file: no approval record copies it, and changing it does not change whether a section stands as
approved. The outline skill does not write it; the author does. Every key is optional, and a
key that is not defined here is left alone.

| Key | Value |
|---|---|
| `banned` | A list of phrasings that are not to appear in the article: objects with a `phrase` and a `reason`, both non-empty strings (issue #118) |
| `destinations` | The document each part is written into: an object whose keys are parts and whose values are `{"tex": <main file>, "jsonl": <ledger>}`, paths from the directory of `article.json` (issue #120) |
| `length` | The limit on the article's length: an object with `limit`, a whole number of words from 1 to 999999999, and optionally `parts`, the parts the limit counts, a list of one or more of `main`, `appendix`, `supplement`; without `parts` it counts `main` (issue #119) |

```json
{"banned": [{"phrase": "clearly shows", "reason": "say what the data show"}]}
```

**Banned phrasings.** `propositions write prepare` reads the file from the outline directory
when a paragraph is written from an outline, and otherwise from the directory of the ledger,
and copies it as an input of the run. `write check` reports every banned phrasing in the text
the run adds (the new paragraph; for a rewrite, every file of the manuscript) as a problem, and
`write commit` then writes nothing: the author rewords the text, or changes the list and
prepares again. `propositions phrasing --tex <main file> --article <file>` compares a whole
manuscript, for a list that changed after text was written. The comparison is literal: letter
case does not count, a run of white space with its line breaks is one space, a LaTeX comment is
not compared, and a phrasing does not run across an empty line. It finds the words, not the
claim: the same thing said in other words is not found.

**Destinations.** The parts of an article can be different documents: the main text, an
appendix, an online supplement, each with its own main file, ledger and structure sidecars.
`destinations` says, for a part, which document it is written into (issue #120): the main file
(`tex`) and the ledger (`jsonl`), as paths from the directory of `article.json`. Two parts can
name the same document, as an appendix in the main text's input tree does. A section goes to
its own `part`, else to the part of the section it is under, else to `main`. With
`destinations`, `write prepare --outline` refuses a paragraph unless the main file and ledger it
is given are the destination of its section's part, and says which two files to give; `write
commit` records the part in `outline-trace.jsonl`. A rewrite (`write prepare --rewrite`) is of
one document: `outline-map.jsonl` lists the records whose sections go to that document, and the
trace records of the other documents are kept as they were. The whole outline still has to
stand as approved. `propositions outline trace` checks the records of the document whose ledger
it is given and lists the others, and `propositions outline length <directory> --written`
counts each part from its own document. Content moves from one document to another in two
rewrites (issue 133): first the document that receives it, then the document that gives it up,
whose retirements name the new propositions as `{"ledger", "id"}` replacements (schema v1.9). No
citation, and no other check, follows a reference from one document into another. Without `destinations`
everything is one document, as before.

```json
{"destinations": {"main": {"tex": "../main.tex", "jsonl": "main.jsonl"}, "supplement": {"tex": "../supplement/supplement.tex", "jsonl": "../supplement/propositions/main.jsonl"}}}
```

**Lengths.** A section record can carry `length`, its target in words, and `article.json` the
limit of the article. `propositions outline length <directory>` prints, for each section that
is not dropped, its part and its target, then the sum of the targets of each part and, against
the limit, the sum over the parts the limit counts; a target is counted once when a section and
a section above it both carry one, and a section whose subsections plan more than it does is
marked. With `--jsonl <ledger> --tex <main file>` it also counts what was written: the words of
each paragraph that `outline-trace.jsonl` ties to a paragraph record, added up by section (the
sections under it included) and by part. A line over its target or its limit is marked. The
command only reports: it exits with 0 whatever the lengths are, and no other command refuses
text because of its length. The count is an estimate for planning, not the count of any
journal: comments, mathematics, command names, and the arguments of commands that take names
(labels, references, citations, included files) are not counted; a run of letters and digits
is one word, and each Chinese character, kana or hangul syllable is one. Pages are not counted,
and text that was not written from the outline has no trace record and is not counted either.

```json
{"banned": [], "length": {"limit": 8000, "parts": ["main"]}}
```

## What this version leaves open

Three questions about the design were raised with this format and are not
answered by it.

- **How an outline paragraph is tied to a paragraph of the structure sidecar.**
  Answered for text written from the outline: `outline-trace.jsonl` names the
  first proposition of each written paragraph (see "Writing text from the
  outline"). Text that was not written from the outline has no tie.
- **Whether the points of one paragraph are related to each other.** A
  paragraph's points are an ordered list and nothing more. `uses` says that a
  record relies on an earlier record or point; it does not say how.
- **How two passages that read the same are told apart.** A locator names a
  passage by a label or by opening words that occur once. Two passages of one
  file that are the same to their end have neither, and derive stops on them
  (issue #84).
