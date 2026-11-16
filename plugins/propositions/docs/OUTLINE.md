# Article outline

The ledger records what a manuscript already says. The outline records what an
article is **planned** to say, before the text is written: one sentence for
each section and at least one sentence for each paragraph. The author reads the
outline, changes it, and approves it; only then is text written from it.

An outline can be built from a finished manuscript, so that a large
restructuring is decided on sentences instead of on pages, or from a title and
ideas. It is written by the skill `/propositions:outline`.

Two things are outside this document. Writing manuscript text from an outline
belongs to a later step (issue #51); nothing described here writes to the
manuscript. No validator of the outline files exists yet (issue #78): apart
from the few checks listed under "What is checked today", the rules below are
kept by the skill and by the reader.

## The three files

The outline is three files in the directory that holds, or would hold, the
ledger. The directory can hold them without a `main.jsonl`: a manuscript does
not need a ledger to have an outline.

**The repository** is the git repository that holds the manuscript, or, when
that repository is checked out as a submodule of another (as git reports it,
from the index of the outer repository), the outermost repository it is
checked out in, up to two levels of submodules. The skill works only on a
manuscript inside a git repository: with more levels of submodules, or when
the manuscript is in no git repository, it stops and says why. The
repository's root is the boundary of the outline files and of every file the
skill reads as a source, and the skill does not take that boundary from an
answer of the author. Its own temporary files are outside the repository. For
a draft with no manuscript yet, the directory the author names for it stands
in for the manuscript when the repository is found; no ledger names a
manuscript that does not exist yet. A repository that
sits inside another without being its submodule is a repository of its own.
Everything this document says is inside the repository is inside this one, and
every path a locator gives is relative to its root. An outline kept inside a
submodule therefore does not resolve in a checkout of the submodule alone. When
the manuscript's repository sits inside another without being its submodule, a
ledger of the outer repository is outside the repository: it does not name the
manuscript for the skill, and the outline cannot go beside it. When no ledger
of the inner repository names the manuscript either, the skill asks the author
which directory of the inner repository to use. The other way round,
a directory under the repository's root counts as inside it even when it holds
a git repository of its own.

**The manuscript's main file** is a regular file inside the repository. It is
not itself a symbolic link, it is not inside a `.git` directory in any letter
case, and git lists it: git tracks it, or does not track it and does not
ignore it. When it is not such a file, the skill stops, says why and does not
read it. A symbolic link in the path of the directory that holds it is a
different case: it is resolved, and from then on the skill reads the
manuscript by its real path.

**Which file a ledger names.** A ledger names one file at most.
`docs/SCHEMA.md` writes a ledger's `source.file` from the "manuscript repo
root". When the git repository that holds the ledger is a submodule of
another, some ledgers read that as the submodule's root and others as the root
of the outermost repository. The skill reads `source.file` both ways, in this
order: from the root of the git repository that holds the ledger (for a ledger
inside a submodule, the submodule's root), and then from the root of the
repository. The first reading that leads to a regular file under the root of
the ledger's own git repository decides which file the ledger names. A reading
that leads to no file, or to a file outside the ledger's own git repository, is
not taken. The ledger names this manuscript when the file it names is the
manuscript's main file, both resolved to real paths. So the ledger of another
paper, kept in a submodule or in a git repository of its own under the root,
does not name a manuscript of the outer repository.

| The ledger is in | Its `source.file` | The manuscript is | Names it |
|---|---|---|---|
| the submodule `paper` | `main.tex` | `paper/main.tex` | yes, by the first reading |
| the submodule `paper/manuscript` | `paper/manuscript/main.tex` | `paper/manuscript/main.tex` | yes, by the second reading |
| the outer repository | `paper/main.tex` | `paper/main.tex` | yes |
| the submodule `paper` | `main.tex` | `main.tex` at the root of the outer repository | no: that file is outside the ledger's repository |

A `_meta.json` that is a symbolic link, that is inside a `.git` directory in
any letter case, or whose path holds a line break is not listed, is not read
and does not count as a ledger. A listed `_meta.json` is read as one ledger
when it holds exactly one JSON value and that value is an object.

**Which directory.** The skill uses a directory without asking only when every
`_meta.json` it lists was read as one ledger, exactly one of those ledgers
names this manuscript, and the author's request names no other directory; it
then uses that ledger's directory. In every other case the skill does not
choose a directory itself. These are the cases, and the list is closed:

1. no ledger names the manuscript;
2. more than one does;
3. there is no manuscript yet;
4. a listed `_meta.json` could not be read as one ledger (the skill also says
   which one: it might be the manuscript's ledger);
5. one ledger names the manuscript and the request names another directory.

When the request names the directory, every listed `_meta.json` was read as
one ledger, and no ledger names the manuscript or there is no manuscript yet,
the request is the author's answer and the skill uses that directory.
Otherwise it asks the author which directory to use. Outline files elsewhere
in the repository are then offered, not taken, because they can belong to
another manuscript. The directory is always the repository's root or a directory under
it, not inside a `.git` directory in any letter case, and it is a directory or
does not exist yet,
in which case the directory that is to hold it exists. The skill resolves every
symbolic link in its path, the last part included, before it decides; a link
that leads to a place that does not exist can stop it, depending on the
machine's `realpath`. It
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

## Paragraph records

Each line of `outline-paragraphs.jsonl` is a paragraph record.

| Key | Required | Value |
|---|---|---|
| `id` | yes | A non-empty string, different from the `id` of every other paragraph record and of every point |
| `section` | yes | The `id` of a section record. A paragraph record whose `section` names no section record belongs to no section (see "When a section stands as approved") |
| `points` | yes | A list of one or more points |
| `from` | no | A list of one or more locators naming the passages this record comes from |
| `carry` | no | `true`: the record stands for a block that is moved unchanged from the passage its `from` names |
| `uses` | no | A list of ids, each the `id` of a paragraph record on an earlier line or of a point of such a record |
| `dropped` | no | A non-empty string giving the reason the paragraph is left out of the article |
| `note` | no | A string for the author |

A point is an object.

| Key | Required | Value |
|---|---|---|
| `id` | yes | A non-empty string, different from the `id` of every other point and of every paragraph record |
| `text` | yes | One complete sentence stating one key point of the paragraph |
| `basis` | no | A list of one or more locators naming what supports the point |
| `pending` | no | A non-empty string naming what the author still has to supply before the point can be written |

**One point or several.** A record with one point states, in that point, what
the whole paragraph says. A record with several points states one key point of
the paragraph in each, in the order the paragraph makes them.

**Blocks that are moved, not rewritten.** A theorem statement, a proof, a
figure, a table, or a displayed formula or derivation that has a blank line
before it and a blank line after it is one record that carries `carry`. Its
points are complete sentences stating what the block states or shows ("Theorem
1 states that the interval covers the true value at the nominal rate."), and the
text of the block is not rewritten. "States Theorem 1." is not such a sentence. A record that carries `carry` has `from`: without it nothing
says which block is moved. Any other displayed formula or derivation is not a
block of its own: with no blank line on either side it belongs to the record of
the paragraph it stands in, and with a blank line on one side only it belongs
to the record of the paragraph on the other side.

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

## Locators

A locator names a passage. `from` and `basis` use the same object.

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
not in its lines: words that occur twice on one line occur twice. In the
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

**Two passages that read the same.** Two passages of one file that read the
same to their end, neither with a label of its own, cannot be told apart: the
opening words of each occur twice however many of them are taken. This format
has no locator for either. Derive stops when it meets such a pair (see "The six
actions of the skill"); whether the format should be able to name them is open
(issue #84).

**The file is inside the repository, and git lists it.** It can be outside the
manuscript, such as a note in the same repository. Git has to list it: git
tracks it, or does not track it and does not ignore it. A new note that is not
committed yet is such a file. A file git ignores, or one git gives no answer
for, is not a locator's file: the skill does not read it, and an object naming
it is not a locator. Git is asked in the directory of the file, so a file
inside a submodule, or inside a git repository of its own under the root, is
judged by the rules of that repository. The outline files sit beside the
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
one recorded when the copy was taken, or when the copy is no longer available, the skill appends nothing and shows the sections again. When a
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
  `says`, every paragraph record naming it with its points, and every record
  that carries `dropped` together with the reason.
- A section that differs from its approved copy is shown by its differences:
  for each record that was changed, added, removed or moved, the approved
  content and the current content. The skill says that the rest of the section
  is as it was approved, and shows the section in full when the author asks.
- A section that equals its approved copy is shown as unchanged since its
  approval.

The findings of the premise check on a section are shown with it in all three
cases.

Before an approval of the whole outline the skill shows two more things,
because that approval approves both.

- **The order of the sections**, when it does not stand as approved: the
  sections in the order they are in now, and beside it their order in the last
  approval of the whole outline when one is on record. Two sections that were
  swapped each still equal their approved copy, so without this the author
  would approve a new order without seeing it.
- **The sections that are gone**: every section that has a copy in some
  approval record and is no longer in the section file, with its heading, its
  `says` and the points of its paragraph records as they were last approved.

When particular sections are shown and either of the two applies, the skill
says that the order of the sections, or the removal of a section, is not part
of this approval.

Agreeing to have a derived or drafted outline written to disk is not an
approval of it.

## The premise check

Each time before sections are shown for approval, they are checked. The check
begins with the checks the skill runs after a write (see "What is checked
today"), on the section file and the paragraph file it examines: a file that
was changed by hand can hold a line that is not a record. When one of them
fails, the skill reports the file and the lines, counts nothing and starts no
agent. The check reports findings of six kinds and no others.

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
   outside the repository, is inside a `.git` directory, is not a file git
   lists, or has a name the locator rules do not allow, whose `label` text
   does not occur exactly once in the file, or whose `starts` does not occur
   exactly once in the file. An object in `from` or `basis` that is not a
   locator, and a `from` or a `basis` that is not a list of one or more
   locators, are reported as this kind too.

The sixth kind is established by the skill itself, by resolving each path and
counting, so that it is decided the same way every time. The first five are
judged by the agent `propositions:outline-checker`, defined in
`agents/outline-checker.md` of this plugin. Its definition gives it the Read
tool and no other, so it cannot write or change a file, run a program or send
anything. It is given four paths and nothing else: the section file, the
paragraph file, a list that the skill writes outside the repository, and, when
only some sections are examined, a file that lists their ids. Each line of the
list is a JSON object with the `file` a locator gives and the real path of the
file that was counted for it:

```json
{"file": "manuscript/main.tex", "path": "/home/author/paper/manuscript/main.tex"}
```

A file is in the list only when the count read it. The path is the real one,
with every symbolic link and every `..` resolved, so the agent opens the file
that was counted and no other. The task message holds no text taken from the
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

Findings are shown with the section they concern. The skill does not change the
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
this repository when it starts: the directory belongs to the user, can be read
and written by no one else, and holds a note of the root it was made for.
Every later command confirms all of that, and a directory that fails one of
these is not used. When the machine's temporary directory is inside the
repository, the skill stops before it makes anything. It
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

**derive** produces one section record for each section of the manuscript and
one paragraph record for each of its paragraphs and blocks. It reads the
manuscript's main file by its real path, after confirming again that the file
is one it reads (see "The three files"). It follows the
`.tex` files that the manuscript includes only when they are regular files
inside the repository whose path holds no line break and that git lists. Any other included file
is named to the author and not read: one outside the repository, a symbolic
link, a file reached through a directory that is a symbolic link, a file
inside a `.git` directory in any letter case, a file git ignores (a generated
table, for instance), a missing
file, a file whose path holds a line break, or a file that is not `.tex`. A
table or a figure that comes from a file that was not read is still one record
that carries `carry`, named in the file that includes it. Prose that comes
before the first heading and is not the abstract gets one section record,
whose `heading` is the title of the article: that title is what heads the text
on the page, as in APA style, where the introduction has no heading of its
own. The skill tells the author that this section has no heading of its own in
the manuscript, and asks what to put in `heading` when the manuscript gives no
title. Every paragraph record it produces has `from` naming the passage it
comes from, with the real path of the file, relative to the root, as `file`,
and every point states only what that passage states. A
theorem-like statement, a figure or a table is named by its own label; the
label of a section names the whole section and is not used for a record. It
writes no `lines` and no `commit`. Before it shows the outline, it confirms
that every locator it wrote resolves. When a passage that has no label of its
own reads the same, to its end, as another passage of the same file, no
locator names it. Derive then stops: it tells the author which passages they
are, shows no outline and writes nothing to the repository. It does not take
opening words from the passage that follows. The author can change one of the
two passages, or give one a label when it is a block that can carry one. It
stops the same way when a file it read cannot be named by a locator. A
manuscript that has paragraphs never gives an empty paragraph file.

**draft** does not invent content. A point that would report a result, a number
or a citation the author has not supplied says what will be reported without
stating it, and carries `pending`. When the outline the author supplies has
sections and no paragraph yet, draft writes no paragraph record, and the
paragraph file is empty. Draft needs no manuscript: with none, no ledger names
it, and the directory of the outline files is the author's decision.

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
  the records it replaces.
- When a record that has `from` is split, each record that replaces it has in
  its `from` at least one locator of the original, and each locator of the
  original is in the `from` of at least one of them.
- When a point moves to another paragraph record and the record it leaves has
  `from`, each locator of that `from` is added to the point's `basis`, so that
  the point keeps its source. A record is not left with no point: when the
  point that moves is the last one of its record, the skill asks the author
  whether that record is left out, by the next rule, or is given a new point.
- When the author leaves a paragraph out of the article and its record has
  `from`, the record is not deleted: it is given `dropped` with the reason. A
  record without `from` that the author leaves out is deleted from the file.
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
the original go" can be answered from the `from` lists, together with the
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

After a revision the skill says which sections no longer stand as approved,
and which sections that have an approved copy are no longer in the section
file.

**status** reports, for each section, whether it stands as approved, and for a
section that does not, whether it was never approved or differs from its latest
approved copy. It reports whether the order of sections stands as approved,
the sections that have a copy in some approval record and are no longer in the
section file,
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
`section` object and a `paragraphs` list. Whenever it fails, nothing it
printed is a status.
The approve action checks the file the same way before it appends, and appends
nothing when the file fails: the file was changed by hand, the skill says so,
and what to do with it is the author's decision. The skill never changes a
line of it.

## What is checked today

The skill's checks are commands that call `jq`, `realpath` and `git`. A check
counts as passed only when its command says so; a command that prints nothing,
fails or cannot run is a failed check, and when one of the three tools is not
installed the skill stops and says which. It stops too when its `jq` reads two
long numbers that differ as the same number, and, with a line that begins with
`STOP`, when git finds no repository for the manuscript's directory. Text from the manuscript, from an outline file
or from the author reaches those commands only from a file that the command
reads; it is never written into the text of a command. The paths the skill
writes into its commands are the repository's root, the outline directory, the
stage directory, the directory that holds the manuscript and the manuscript's
main file. Each begins with `/`: an empty path, or one not written out in
full, stops the skill, and so does a path that holds a single quote. The paths
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
paragraph file it also confirms that every point has an `id` and that `points`,
where a record has it, is a list. The shape of a key that a section record
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

## What this version leaves open

Four questions about the design were raised with this format and are not
answered by it.

- **How an outline paragraph is tied to a paragraph of the structure sidecar.**
  A paragraph record here and a paragraph of `structure.json` have separate
  ids, and nothing maps one to the other. The tie can only be made once text
  has been written from the outline, which is when a paragraph of text exists
  to point at (issue #51).
- **Whether commitments can be planned on the outline.** The structure
  sidecars record which sentence opens a commitment and which discharges it.
  The outline has no key for either: it cannot say that a paragraph will open
  or discharge a commitment (issue #51).
- **Whether the points of one paragraph are related to each other.** A
  paragraph's points are an ordered list and nothing more. `uses` says that a
  record relies on an earlier record or point; it does not say how.
- **How two passages that read the same are told apart.** A locator names a
  passage by a label or by opening words that occur once. Two passages of one
  file that are the same to their end have neither, and derive stops on them
  (issue #84).
