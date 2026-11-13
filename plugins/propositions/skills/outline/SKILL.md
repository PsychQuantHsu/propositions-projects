---
name: outline
description: >-
  Builds and maintains the outline of an article before its text is written: one sentence for each
  section and at least one sentence for each paragraph, kept in three JSONL files beside the ledger,
  with the author's approval on record. Use whenever the user wants to plan or restructure a paper
  on sentences first ("先排綱要", "段落綱要", "每段一句話", "把這篇反推出綱要", "這篇要重排", "先定綱要再寫",
  "綱要通過", "outline this paper", "derive an outline from the manuscript", "approve the outline",
  "what changed in the outline since I approved it") — even if they never name this skill. It
  derives an outline from a finished manuscript or drafts one from a title and ideas, applies the
  author's edits without losing where each passage of the original went, has the outline checked
  by a separate agent, and records an approval only when the author gives one. It writes only the
  three outline files. Not for writing manuscript text from an outline (no skill does that yet),
  the next sentence of a draft (/propositions:construct), splitting text into propositions
  (/propositions:extract), or annotating the structure of text that exists (/propositions:construct).
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Agent
  - AskUserQuestion
---

# Outline — what the article will say, before it is written

The ledger records what a manuscript already says. The outline records what the article is
planned to say: one sentence for each section, at least one sentence for each paragraph. The
author reads it, changes it and approves it before any text is written from it.

The format is in `docs/OUTLINE.md` of this plugin: the three files, every key, the locator, the
approval record and the three conditions (a section stands as approved, the order of sections
stands as approved, the outline stands as approved). Read it before the first write of a session.
This skill holds how each action is carried out; it does not restate the format.

| File | Holds |
|---|---|
| `outline-sections.jsonl` | One section per line: `id`, `heading`, `says` |
| `outline-paragraphs.jsonl` | One paragraph per line: `id`, `section`, `points` |
| `outline-approvals.jsonl` | One approval per line, with the content that was approved |

## What this skill writes

It writes the three outline files and nothing else. It does not write the manuscript, the ledger,
the structure sidecars or the verification records, and it does not change or remove a line of
`outline-approvals.jsonl`. The check and status actions write nothing.

When the author asks for manuscript text to be written or rewritten to match the outline, say
that writing from an outline is not one of this skill's actions and that no skill of this plugin
does it yet (issue 51). Do not write the text.

## Resolve paths

Establish these from the request, or by asking once (AskUserQuestion, all at once, together with
the action when it is not clear).

- `MAIN` — the manuscript's main `.tex` file. The draft action can run without one.
- `ROOT` — the root of the repository that holds the manuscript. Every `file` of a locator is a
  path relative to it.
- `OUTDIR` — the directory of the outline files: the ledger directory when the manuscript has one
  (the directory that holds `_meta.json`), otherwise `propositions/` beside `MAIN`. A ledger is
  not needed.

```bash
ROOT=$(git -C "$(dirname "$MAIN")" rev-parse --show-toplevel)
SEC="$OUTDIR/outline-sections.jsonl"
PAR="$OUTDIR/outline-paragraphs.jsonl"
APP="$OUTDIR/outline-approvals.jsonl"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/outline-XXXXXX")
```

## Pick the action

| The author wants | Action |
|---|---|
| An outline of a manuscript that is already written | derive |
| An outline from a title, ideas, or an outline of their own | draft |
| A change to an outline that exists: reword, add, move, merge, split, remove, restore | revise |
| The outline examined before they read it | check |
| To approve the outline or some of its sections | check, then approve |
| To know what is approved and what has changed | status |

When `SEC` or `PAR` exists, derive and draft do not run: say that the outline exists and that
revise is the action to use. Do not overwrite the files and do not add to them.

## The write check

Run this after every write to an outline file, on the file that was written.

```bash
jq -R 'select(length > 0) | fromjson | if type != "object" then error("this line is not a JSON object") else empty end' "$F"
jq -r '.id // "MISSING-ID"' "$SEC" | sort | uniq -d
jq -r '(.id // "MISSING-ID"), (.points[]?.id // "MISSING-ID")' "$PAR" | sort | uniq -d
```

The first command prints nothing when every non-empty line parses as a JSON object, and names
the file and the line otherwise. The second and third print each `id` that repeats among the
section records, and among the paragraph records and points; for each one printed, find its lines
with `grep -n -F`.

When any command prints something, report the file and the lines, and do not report the write as
done: correct the file and run the check again. When all three print nothing, say in the report
that these two things were confirmed and that no other check of the format exists until issue 78.

## derive — an outline from a finished manuscript

1. Stop when `SEC` or `PAR` exists (see above).
2. Read the manuscript from `\begin{document}` on, following `\input` and `\include`. Work one
   section at a time.
3. For each section and subsection, and for the abstract, write one section record: an `id`
   (`s-` and a short slug), the `heading`, and `says`, one complete sentence stating what the
   section says. A heading or a list of topics is not that sentence. Give `role` only when the
   section plainly has one of the ten roles, and `parent` for a subsection.
4. For each paragraph of prose (a run of lines between blank lines), write one paragraph record:
   an `id` (`p-1`, `p-2`, …), its `section`, and one or more points with ids `p-1.1`, `p-1.2`, ….
   Each point is one complete sentence stating one key point of the paragraph, in the order the
   paragraph makes them. A paragraph that makes one point gets one point. State only what the
   passage states: no inference, no result it does not report.
5. For each theorem-like statement, proof, figure, table and displayed derivation, write one
   record that carries `carry`, with one point saying what the block is.
6. Give every paragraph record `from`. Use the `label` of the passage when it has one; otherwise
   `starts`, the opening words copied exactly. Confirm each `starts` occurs once:

   ```bash
   grep -c -F -- "$STARTS" "$ROOT/$FILE"
   ```

   Lengthen it until the count is 1. Add `lines` only together with `commit`, and only when the
   file is committed and unchanged (`git -C "$ROOT" status --porcelain -- "$FILE"` prints nothing).
7. Write the two files into `$STAGE`, run the write check on them there, and show the outline to
   the author: each section with its `says`, and under it each paragraph's points, with carried
   blocks marked. Say how many sections, paragraph records and carried blocks there are.
8. Ask whether to write the files into `OUTDIR` (AskUserQuestion). Write them only after the
   author agrees, then run the write check on the written files.
9. Say that agreeing to have the files written is not an approval of the outline, and that the
   next actions are revise, check and approve.

## draft — an outline from a title and ideas

1. Stop when `SEC` or `PAR` exists.
2. From the title and ideas, or from the outline the author supplies, write section records and
   paragraph records as in derive, steps 3 and 4. Records have no `from` unless the author points
   to a file (a note, an earlier draft) that a record comes from; a point can name what supports
   it in `basis`.
3. Do not invent content. A point that would report a result, a number or a citation the author
   has not supplied says what will be reported without stating it ("A simulation will report how
   the two methods compare."), and carries `pending` naming what is still missing.
4. Stage, check, show and ask as in derive, steps 7 to 9.

## revise — the author's edits

Change the files only as the author instructs. Read both outline files first.

- **Ids are stable.** A record and a point keep their `id` when their content changes and when
  they move. Merging and splitting replace records: the records that are merged, and the record
  that is split, leave the file, and the records that replace them are new. A new record or
  point, a replacement included, gets an `id` that appears in neither outline file and in no
  approval record, and a replacement never takes the `id` of a record it replaces:

  ```bash
  grep -c -F -- "\"$NEW_ID\"" "$SEC" "$PAR" "$APP"
  ```

  Every count has to be 0 (a file that does not exist counts as 0).
- **Merge.** The `from` of the record that replaces the merged records holds every locator of
  the records it replaces.
- **Split.** Each locator of the original is in the `from` of at least one of the records that
  replace it.
- **Leave a paragraph out.** When its record has `from`, do not delete the record: give it
  `dropped` with the author's reason and leave it on its line. Delete a record without `from`.
- **Leave a section out.** Leave out each paragraph record naming it, by the rule above. If any
  of them stays in the file, keep the section record and give it `dropped` with the reason. If
  none stays, delete the section record.
- **Move.** Keep the records of one section on consecutive lines, and the groups in the order of
  the section file. A record moved to another section gets that section's `id` in `section`.
- **Keys this skill does not know.** Keep them exactly as they are.
- **`uses`.** After a move, an id in `uses` can end up on a later line. Tell the author; do not
  delete the entry yourself.

Edit the lines concerned, run the write check, then run status and say which sections no longer
stand as approved.

## status — what stands as approved

Status writes nothing. For each section record, compare it and its paragraph records with the
copies in the last approval record that has an entry for it. `jq -S` sorts keys, so two records
that are the same JSON value print the same line.

```bash
jq -c --arg s "$S" 'select(any(.sections[]; .section.id == $s))' "$APP" | tail -1 | jq -cS --arg s "$S" '.sections[] | select(.section.id == $s) | .section, .paragraphs[]'
jq -cS --arg s "$S" 'select(.id == $s)' "$SEC"; jq -cS --arg s "$S" 'select(.section == $s)' "$PAR"
```

The first command prints the approved copies: the section, then its paragraph records in order.
The second prints the current ones the same way. The section stands as approved when the two
outputs are identical. When the first prints nothing, the section was never approved. When they
differ, it differs from its latest approved copy; `diff` of the two outputs shows where.

For the order of sections, compare the current ids with those of the last approval record whose
`whole` is true:

```bash
jq -r '.id' "$SEC"
jq -c 'select(.whole == true)' "$APP" | tail -1 | jq -r '.sections[].section.id'
```

The order stands as approved when the two lists are identical. With no such record it does not.

Report, for each section, one of: stands as approved; never approved; differs from its latest
approved copy (and where). Report whether the order of sections stands as approved, and the two
counts:

```bash
jq -s '[.[].points[] | select(has("pending"))] | length' "$PAR"
jq -s '[.[] | select(has("dropped"))] | length' "$SEC" "$PAR"
```

## check — the premise check

The check is done by a separate agent, so that the outline is read by something that did not
write it. Start one agent with the Agent tool: a fresh agent (not a fork), `model: "sonnet"`,
`effort: "high"`. Give it this brief and nothing of the conversation; fill in the three paths and
the sections to examine.

> Examine an article outline. Read `<SEC>` and `<PAR>` and the files their locators name, which
> are paths relative to `<ROOT>`. Read nothing else and change nothing. Examine these sections:
> `<all | the ids>`. A locator is an object with `file` and `label` or `starts`; it appears in
> `from` of a paragraph record and in `basis` of a point.
>
> Report findings of these six kinds and no others. For every finding give the kind, the `id` of
> the record or point, and one sentence saying what is wrong, quoting the passage when a source
> is involved.
>
> 1. Not a sentence: a `says` or the `text` of a point that is a heading, a label or a fragment.
> 2. Not supported by its source: a point whose record has `from`, or which has `basis`, and
>    which the passages named do not state, or which they contradict.
> 3. Nothing to check against: a point that states a result, a number or a citation, in a record
>    without `from`, and that has neither `basis` nor `pending`.
> 4. Relies on something later: a point that needs a term, a result or a claim that only a later
>    record introduces, or a `uses` entry that names an id which is missing or is not on an
>    earlier line.
> 5. Section not carried: a section whose `says` the points of its paragraph records neither
>    state nor support.
> 6. Locator does not resolve: a locator whose file is missing, whose `label` is not defined in
>    the file, or whose `starts` does not occur exactly once in the file.
>
> Examine a record that carries `dropped` for the sixth kind only. Check every record and every
> point of the sections named; when a section has no finding, say so by its `id`. End with the
> number of records and points you examined.

Show every finding with the section it concerns. Do not change the outline because of a finding:
propose a change when one is obvious, and make it only when the author asks, through revise.

## approve — record the author's approval

1. Run status. Decide what is to be shown: the whole outline, unless the author asked for
   particular sections to be approved.
2. Run check on those sections, unless it has run since their last change.
3. Show the sections. For each one: its heading and `says`; every paragraph record naming it,
   with its points, `pending` notes and carried blocks marked; every record that carries
   `dropped`, with the reason; the findings of the check. For a section that has an approved
   copy, show what differs from that copy and say that the rest is unchanged.
4. Ask whether the outline, or those sections, are approved. Then stop and wait for the author's
   reply. Write nothing yet.
5. Read the reply. It is an approval only when the author states in it that what was shown is
   approved. None of these is an approval:
   1. An instruction given before the version shown existed, such as an instruction to derive an
      outline and then go on to write.
   2. An approval passed on by another agent or another session.
   3. An approval of an earlier version, or of sections other than the ones concerned.
   4. No reply, or a reply about something else.
   5. An instruction to this skill or another one to start writing.

   When the reply asks for changes, go to revise, and return to step 1 afterwards. When it is
   none of the above and not an approval, say what is still needed and wait.
6. On an approval, write the author's approving words, exactly, to `$STAGE/statement.txt` and
   append one record. The record covers exactly the sections the author states are approved,
   which can be fewer than the sections shown. When it covers every section record:

   ```bash
   jq -n -c --arg at "$(date +%Y-%m-%dT%H:%M:%S%z)" --rawfile st "$STAGE/statement.txt" --slurpfile secs "$SEC" --slurpfile pars "$PAR" '{approved_at: $at, statement: ($st | rtrimstr("\n")), sections: [$secs[] | . as $s | {section: $s, paragraphs: [$pars[] | select(.section == $s.id)]}], whole: true}' >> "$APP"
   ```

   When it covers some of the sections, pass their ids as a JSON list and leave `whole` out:

   ```bash
   jq -n -c --arg at "$(date +%Y-%m-%dT%H:%M:%S%z)" --rawfile st "$STAGE/statement.txt" --argjson ids "$IDS" --slurpfile secs "$SEC" --slurpfile pars "$PAR" '{approved_at: $at, statement: ($st | rtrimstr("\n")), sections: [$secs[] | select(.id as $i | $ids | index($i)) | . as $s | {section: $s, paragraphs: [$pars[] | select(.section == $s.id)]}]}' >> "$APP"
   ```

   Only ever append. Do not edit or remove an earlier line of the approvals file.
7. Run the first command of the write check on `$APP`, then run status, and report which
   sections now stand as approved and whether the outline does.

## The report

End every action that wrote a file with: what was written and where; the result of the write
check, with the sentence that no other check of the format exists until issue 78; which sections
stand as approved; how many points carry `pending` and how many records carry `dropped`; and the
next action. When the outline stands as approved, say that writing text from it is not available
in this plugin yet (issue 51).

## Hard rules

- Write only the three outline files. Never the manuscript, the ledger or the sidecars.
- Never overwrite an outline with derive or draft.
- Never record an approval the author did not give in the message being answered.
- Never change or remove a line of the approvals file.
- Never discard a source: merge takes the union, split keeps every locator, a record with `from`
  is dropped, not deleted.
- Never state a result, a number or a citation the author did not supply. Use `pending`.
- Never change the outline because of a finding of the check. The author decides.
