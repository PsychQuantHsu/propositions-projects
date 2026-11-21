## ADDED Requirements

### Requirement: Write mode writes from an approved outline record, read back by a reader

The write mode of the construct skill SHALL, when the author asks to write from the outline, take its plan from one paragraph record of the outline: by default the first record in the paragraph file that does not carry `dropped`, whose section stands as approved (`propositions outline status`), and that `outline-trace.jsonl` does not name (`propositions outline trace`); another record only when the author names it. When there is none, the skill stops and says that the section has to be approved with the outline skill. The paragraph says the record's points in order and nothing the points do not say; a point with `pending` gets `{PENDING: <its pending text>}`; a record that carries `carry` is the block its `from` names, copied with only the changes its `edits` lists; the first record of a section whose heading is not in the draft comes with that heading line (`write prepare --heading`). `write prepare` runs with `--outline` and `--outline-paragraph`.

After the gates of write mode pass and before the author is asked, the skill SHALL write the paragraph record and the new paragraph to two files in the staging directory and dispatch the agent `propositions:outline-point-reader` (Read only) with those two paths and nothing else. The agent reports, as a closed list of two kinds, a point the paragraph does not say (or says in part, or contradicts) and a result, number or citation the points do not state. Its findings are shown to the author with the rest, as a reader's judgment; they are not entered in the obligations table. The skill does not write `outline-trace.jsonl`; `write commit` appends to it, and the skill runs `outline trace` after the commit.

No executable check: the mode is instructions that a model follows; the commands it runs are tested under the capabilities `write` and `article-outline`.

#### Scenario: A paragraph is written from the outline

- **WHEN** the author asks to write from an outline whose first untraced record is in an approved section, and confirms what is shown
- **THEN** the skill writes it through `write commit` with `--outline`, shows the reader's findings before asking, and `outline trace` lists the record afterwards
