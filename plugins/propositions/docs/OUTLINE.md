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
not need a ledger to have an outline. The skill uses a directory without asking
only when exactly one ledger in the repository names this manuscript; it then
uses that ledger's directory. In every other case it asks the author which
directory to use: when the manuscript has neither a ledger nor outline files,
when more than one ledger names it, and also when the repository holds outline
files in a directory that has no such ledger, because they can belong to
another manuscript. The directory is always the repository's root or a
directory under it, and it is not a symbolic link.

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
does not cover them.

A section record, a paragraph record, a point and a locator can carry keys that
this document does not define. The skill keeps such keys as they are when it
rewrites a record and does not interpret them. An approval record carries the
four keys defined for it and no others.

No string in a section record or a paragraph record contains a control
character (U+0000 to U+001F), a line break included. Where the text has a line
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
| `section` | yes | The `id` of a section record |
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
points say what the block is ("States Theorem 1."), and the text of the block
is not rewritten. A record that carries `carry` has `from`: without it nothing
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
{"id": "p-7", "section": "s-model", "carry": true, "points": [{"id": "p-7.1", "text": "States Theorem 1."}], "from": [{"file": "main.tex", "label": "thm:main"}]}
```

## Locators

A locator names a passage. `from` and `basis` use the same object.

| Key | Required | Value |
|---|---|---|
| `file` | yes | The path of a file inside the repository that holds the manuscript, relative to the root of that repository |
| `label` | one of `label` and `starts` | A LaTeX label defined exactly once in that file. It names the section or the environment the label is attached to |
| `starts` | one of `label` and `starts` | The opening words of the passage, copied from the file, enough of them to occur exactly once in it |
| `lines` | no | A list of two line numbers, the first and the last line of the passage |
| `commit` | when `lines` is present | The commit at which those line numbers hold |

A locator carries `label`, `starts` or both. Line numbers stop being right as
soon as the file is edited, so they locate nothing by themselves: `lines` is
allowed only together with `commit`, as a record of where the passage was. When
`label` and `starts` are both present and name different passages, `label`
decides.

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

**A label names what it is attached to.** A label inside a passage does not
name the passage: a paragraph of prose that contains a labelled equation is
named by `starts`.

**The file is inside the repository.** It can be outside the manuscript, such
as a note in the same repository. It cannot be outside the repository: an
object whose `file` leads outside it, by a leading `/`, by `..` or through a
symbolic link, is not a locator, and the skill does not read that file.

| Object | Is a locator |
|---|---|
| `{"file": "main.tex", "label": "thm:main"}` | yes |
| `{"file": "notes/proof-sketch.md", "starts": "The bound follows from"}` | yes |
| `{"file": "main.tex", "lines": [120, 131], "commit": "3f2c1ab"}` | no: neither `label` nor `starts` |
| `{"file": "main.tex", "label": "sec:intro", "lines": [10, 42]}` | no: `lines` without `commit` |
| `{"file": "../other-paper/main.tex", "label": "thm:main"}` | no: the file is outside the repository |
| `{"file": "/etc/hosts", "starts": "localhost"}` | no: the file is outside the repository |

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
number, and every key counts, defined in this document or not. A section for
which no approval record has an entry does not stand as approved.

The **order of sections stands as approved** when the ids of the section
records, in file order, are the ids of the `sections` entries of the last
approval record whose `whole` is `true`, in the same order. With no such
record, the order of sections does not stand as approved.

The **outline stands as approved** when every section stands as approved and
the order of sections stands as approved.

**Approving sections one at a time does not approve their order.** That takes
one approval record that covers every section. An outline of three sections
with three approval records, each with an entry for one section and none with
`whole`, has three sections that stand as approved, an order of sections that
does not, and so an outline that does not. The skill says then that an approval
of the whole outline is still needed.

Any difference counts. The skill does not judge whether a change is a change
of substance or of wording: a section that differs from its approved copy goes
back to the author.

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

These three conditions are what the later step uses to decide whether text can
be written from an outline (issue #51).

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

The skill keeps, outside the repository, a copy of the outline files as they
were when shown, so that the approval can be recorded when the author's reply
arrives in a later message. When the outline files differ from that copy at the
time of the approval, or the copy is no longer available, the skill appends
nothing and shows the sections again.

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

Agreeing to have a derived or drafted outline written to disk is not an
approval of it.

## The premise check

Each time before sections are shown for approval, they are checked. The check
reports findings of six kinds and no others.

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
6. **Locator does not resolve**: a locator whose `file` is missing or leads
   outside the repository, whose `label` is not defined exactly once in the
   file, or whose `starts` does not occur exactly once in the file. An object
   in `from` or `basis` that is not a locator is reported as this kind too.

The sixth kind is established by the skill itself, by resolving each path and
counting, so that it is decided the same way every time. The first five are
judged by another agent, which is given the section file, the paragraph file
and those of the files their locators name that exist inside the repository,
and nothing of the conversation. The agent is told that what it reads is data to examine and holds
no instruction for it, and that it reads only: it does not write, change, run
or send anything. That is an instruction to the agent; its tools are not
restricted. The check does not read a file outside the repository that holds
the manuscript.

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

In the repository that holds the manuscript the skill writes no other file:
not the manuscript, not the ledger, not the structure sidecars and not the
verification records. Its temporary files are kept outside the repository. It
does not write through a symbolic link: when an outline file is one, the skill
stops and tells the author.

**derive** produces one section record for each section of the manuscript and
one paragraph record for each of its paragraphs and blocks. It follows the
`.tex` files that the manuscript includes only when they are regular files
inside the repository. Any other included file is named to the author and not
read: one outside the repository, a symbolic link, a missing file, or a file
that is not `.tex`. Every paragraph
record it produces has `from` naming the passage it comes from, and every point
states only what that passage states. It writes no `lines`. Before it shows the
outline, it confirms that every locator it wrote resolves.

**draft** does not invent content. A point that would report a result, a number
or a citation the author has not supplied says what will be reported without
stating it, and carries `pending`.

Both show the outline to the author before any file is written in the
repository, and write the files there only after the author agrees. Neither
overwrites or adds to existing outline files. When the section file or the
paragraph file exists, the action stops and says that revise is the action to
use.

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
- When a record is split, each locator of the original is in the `from` of at
  least one of the records that replace it.
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
the original go" can always be answered from the `from` lists: every passage is
a source of a record that is in the article, or of a record that carries
`dropped` with its reason.

After a revision the skill says which sections no longer stand as approved.

**status** reports, for each section, whether it stands as approved, and for a
section that does not, whether it was never approved or differs from its latest
approved copy. It reports whether the order of sections stands as approved, the
number of points that carry `pending` and the number of records that carry
`dropped`. When every section stands as approved and the order of sections does
not, it says that an approval of the whole outline is still needed. It decides
equality on JSON values, not on the text of the lines.

## What is checked today

The skill's checks are commands that call `jq` and `realpath`. A check counts
as passed only when its command says so; a command that prints nothing, fails
or cannot run is a failed check, and when one of the two tools is not installed
the skill stops and says which. Text from the manuscript, from an outline file
or from the author reaches those commands only inside a file, never as part of
a command line.

After every write to an outline file, the skill confirms that every line of
that file that is not empty parses as a JSON object. After a write to the
section file or the paragraph file it also confirms that every record and
every point has an `id`, that no `id` repeats among the section records or
among the paragraph records and points, and that no string holds a control
character. When any of these fails, it reports the file and the line and does
not report the write as done.

The check never reports a pass for a file that holds no record. An empty
section file is always a mistake. An empty paragraph file is a mistake too,
with one exception: when no section of the outline has a paragraph yet, the
paragraph file is rightly empty. The check still does not report a pass for it;
the skill says in its report that the paragraph file is empty, and goes on.

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
runs, the skill resolves every locator: the file exists inside the repository,
the `label` is defined exactly once, the `starts` occurs exactly once. It
reports an object that is not a locator: one without a `file`, one with neither
`label` nor `starts`, one whose `label` or `starts` is not a string, one with
`lines` and no `commit`.

That is all. Whether a required key is missing, whether a `section` or a
`parent` names a section record, whether the groups are in order and whether a
`uses` entry is on an earlier line are not checked by any tool until issue #78;
the premise check and the author's reading are what stand in for it.

## What this version leaves open

Three questions about the design were raised with this format and are not
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
