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
manuscript. No mechanical check of the outline files exists yet (issue #78):
the rules below are kept by the skill and by the reader.

## The three files

The outline is three files in the directory that holds, or would hold, the
ledger. The directory can hold them without a `main.jsonl`: a manuscript does
not need a ledger to have an outline.

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
the file so that the paragraph records naming it, and their sources, stay on
record. Every paragraph record naming such a section carries `dropped` too.

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
figure, a table or a displayed derivation is one record that carries `carry`.
Its points say what the block is ("States Theorem 1."), and the text of the
block is not rewritten. A record that carries `carry` has `from`: without it
nothing says which block is moved.

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
| `file` | yes | The path of a file, relative to the root of the repository that holds the manuscript |
| `label` | one of `label` and `starts` | A LaTeX label defined in that file |
| `starts` | one of `label` and `starts` | The opening words of the passage, copied exactly, enough of them to occur once in the file |
| `lines` | no | A list of two line numbers, the first and the last line of the passage |
| `commit` | when `lines` is present | The commit at which those line numbers hold |

A locator carries `label`, `starts` or both. Line numbers stop being right as
soon as the file is edited, so they locate nothing by themselves: `lines` is
allowed only together with `commit`, as a record of where the passage was. When
`label` and `starts` are both present and name different passages, `label`
decides.

The file can be outside the manuscript, such as a note in the same repository.

| Object | Is a locator |
|---|---|
| `{"file": "main.tex", "label": "thm:main"}` | yes |
| `{"file": "notes/proof-sketch.md", "starts": "The bound follows from"}` | yes |
| `{"file": "main.tex", "lines": [120, 131], "commit": "3f2c1ab"}` | no: neither `label` nor `starts` |
| `{"file": "main.tex", "label": "sec:intro", "lines": [10, 42]}` | no: `lines` without `commit` |

## Approval records

Each line of `outline-approvals.jsonl` is an approval record. Lines are only
ever added; the skill does not change or remove one.

| Key | Required | Value |
|---|---|---|
| `approved_at` | yes | The time of the approval, with its offset from UTC |
| `statement` | yes | The author's approving words, copied exactly |
| `sections` | yes | A list of one or more entries |
| `whole` | no | `true` when `sections` has an entry for every section record of the section file as it was, in file order |

An entry of `sections` has two keys: `section`, a copy of a section record as
it was when the author approved, and `paragraphs`, copies of all the paragraph
records naming that section as they were, in file order, those that carry
`dropped` included.

The record stores the approved content itself, not a fingerprint of it. That is
what lets a later approval show the author exactly what has changed.

## When a section stands as approved

A section **stands as approved** when the last approval record that has an
entry for it holds a `section` copy equal to the current section record and
`paragraphs` copies equal, one for one and in the same order, to the current
paragraph records naming that section. Two records are equal when they are the
same JSON value: the order of keys does not count, and every key counts,
defined in this document or not. A section for which no approval record has an
entry does not stand as approved.

The **order of sections stands as approved** when the ids of the section
records, in file order, are the ids of the `sections` entries of the last
approval record whose `whole` is `true`, in the same order. With no such
record, the order of sections does not stand as approved.

The **outline stands as approved** when every section stands as approved and
the order of sections stands as approved.

Any difference counts. The skill does not judge whether a change is a change
of substance or of wording: a section that differs from its approved copy is
shown to the author again, with only the difference marked.

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
the author, in the message the skill is answering, states that the outline or
those sections are approved.

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
those sections only. The record it appends covers exactly the sections the
author states are approved, which can be fewer than the sections shown. The
record has `whole` true when it covers every section record, and no `whole`
otherwise.

What is shown for a section includes its `says`, every paragraph record naming
it with its points, every record that carries `dropped` together with the
reason, and the findings of the premise check on the section. For a section
that has an approved copy, the skill shows what differs from that copy.

Agreeing to have a derived or drafted outline written to disk is not an
approval of it.

## The premise check

Before sections are shown for approval, another agent examines them. It is
given the section file, the paragraph file and the files their locators name,
and nothing of the conversation. It reports findings of six kinds and no
others.

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
   id which is missing or is not on an earlier line.
5. **Section not carried**: a section whose `says` the points of its paragraph
   records neither state nor support.
6. **Locator does not resolve**: a locator whose file is missing, whose `label`
   is not defined in the file, or whose `starts` does not occur exactly once in
   the file.

A record that carries `dropped` is examined for the sixth kind only. Each
finding names the record or the point it concerns.

Findings are shown with the section they concern. The skill does not change the
outline because of a finding unless the author asks for the change: the outline
is the author's plan.

## The six actions of the skill

| Action | Reads | Writes |
|---|---|---|
| derive | A finished manuscript | The section and paragraph files, after the author agrees |
| draft | A title and ideas, or an outline the author supplies | The section and paragraph files, after the author agrees |
| revise | The outline files and the author's instructions | The section and paragraph files |
| check | The section file, the paragraph file and the files their locators name | Nothing |
| approve | The outline files and the author's reply | One line added to the approvals file |
| status | The three outline files | Nothing |

The skill writes no other file: not the manuscript, not the ledger, not the
structure sidecars and not the verification records.

**derive** produces one section record for each section of the manuscript and
one paragraph record for each of its paragraphs and blocks. Every paragraph
record it produces has `from` naming the passage it comes from, and every point
states only what that passage states.

**draft** does not invent content. A point that would report a result, a number
or a citation the author has not supplied says what will be reported without
stating it, and carries `pending`.

Neither derive nor draft overwrites or adds to existing outline files. When the
section file or the paragraph file exists, the action stops and says that
revise is the action to use.

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
- When the author leaves a section out, each paragraph record naming it is
  left out by the rule above. If any of them stays in the file, the section
  record stays and is given `dropped` with the reason. If none stays, the
  section record is deleted from the file.

Because no source is ever discarded, the question "where did each passage of
the original go" can always be answered from the `from` lists: every passage is
a source of a record that is in the article, or of a record that carries
`dropped` with its reason.

After a revision the skill says which sections no longer stand as approved.

**status** reports, for each section, whether it stands as approved, and for a
section that does not, whether it was never approved or differs from its latest
approved copy. It reports whether the order of sections stands as approved, the
number of points that carry `pending` and the number of records that carry
`dropped`.

## What is checked today

After every write to an outline file, the skill confirms that every line of
that file that is not empty parses as a JSON object and that no `id` repeats
among the section records or among the paragraph records and points. When
either fails, it reports the file and the line and does not report the write as
done.

That is all. Whether a required key is missing, whether a `section` names a
section record, whether the groups are in order and whether a locator resolves
are not checked by any tool until issue #78; the premise check and the author's
reading are what stand in for it.
