## ADDED Requirements

### Requirement: Write mode and reorganize mode follow the article file, the plan of commitments and the destinations

In write mode, the construct skill SHALL read the `banned` list of the staged `article.json`, when `write prepare` copied one, before it writes the paragraph, and not write those phrasings; when `write check` reports one, it rewords the paragraph and does not change `article.json`.

When it writes from an outline record, the skill SHALL: make the paragraph open and discharge exactly what the record's `opens` and `discharges` plan, with those ids and kinds in the records it adds, and nothing when another record of the outline plans commitments and this one does not; tell the author, before writing, each `[unread]` line that `write prepare` printed; when `write prepare` says the section goes to a part and names the files of another document, run it again with those files and the sidecars beside that ledger, and stop when `article.json` names no destination for the part; and, after the commit, when the outline or `article.json` carries a `length`, run `propositions outline length` (with `--written` when there are destinations) and report the section's line, the parts and the limit.

In reorganize mode the skill SHALL, with destinations, rewrite one document in a run: only the sections that go to it, with `outline-map.jsonl` listing only their records; and stop when the revised outline moves content from one document to another.

No executable check: the modes are instructions that a model follows; the commands they run are tested under the capabilities `write` and `article-outline`.

#### Scenario: A paragraph of the supplement is written into the supplement

- **WHEN** the next record's section has `part` `supplement`, `article.json` names a destination for it, and the author asks to write from the outline
- **THEN** the skill prepares with the supplement's main file, ledger and sidecars, and the trace record carries `"part": "supplement"`
