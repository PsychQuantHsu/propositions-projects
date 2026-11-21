## ADDED Requirements

### Requirement: Write mode writes one paragraph through the write commands, behind one confirmation

The construct skill SHALL have a write mode that adds one paragraph at the end of a draft, after the paragraph that holds the last live proposition in reading order. Next mode is unchanged and still writes nothing; a request that does not say a paragraph is to be written is next mode.

Write mode runs, in this order: the preconditions of next mode and a check that the pinned tool runs; an agreement with the author, in one question, on what the paragraph does; `propositions write prepare`; the paragraph written in the staged manuscript file, after the line `prepare` names; its propositions, by steps 1 and 5 to 7 of the extraction skill on the staged copy, added at the end of the staged ledger; one record per new proposition added at the end of the staged discourse sidecar, and the paragraph added to the staged structure sidecar; the gates on the copies (`propositions write check`, the ledger validator, the structure validator with `--partial`, `propositions cite-order`); the new paragraph, propositions, records, placeholders and the diff of each of the four files shown to the author, who is asked once; and `propositions write commit` only on that confirmation. A change to the copies after the question runs the gates and asks again.

The paragraph never invents a result, a number or a citation: each is written `{PENDING: <what is to be supplied>}`, and a citation key may be used only when it is in the manuscript's bibliography file. A claim that changes what the paper argues is the author's. When the launcher runs nothing, write mode stops and offers next mode. When `commit` reports files already written, the skill reports them and where the originals are kept and stops; putting the originals back is the author's decision. The report lists every placeholder with its line, and says that the paragraph was checked mechanically and not proofread.

No executable check: the mode is instructions that a model follows; the commands it runs are tested under the capability `write`. The mode was run once by hand on the structure fixture with binary 0.4.0, from `prepare` to `commit`, and the ledger validator and the structure validator passed on the written files.

#### Scenario: The next paragraph is written into a draft

- **WHEN** the author asks to write the next paragraph into the draft and confirms what is shown
- **THEN** the skill writes it through `propositions write commit` and reports what was written, where the originals are, and every placeholder left
