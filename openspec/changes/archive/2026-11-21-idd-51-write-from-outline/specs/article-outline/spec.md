## ADDED Requirements

### Requirement: outline-trace.jsonl records which outline record each written paragraph came from

The outline directory MAY hold a fourth file, `outline-trace.jsonl`, written only by `propositions write commit` (the capability `write`). Each line is one paragraph written from the outline: `outline`, the id of the paragraph record; `first_prop`, the id of the first proposition of the written paragraph; `section`, the id of the record's section; and `approval_line`, the line of `outline-approvals.jsonl` that held the approval the section stood on. It is the only tie between a paragraph record and written text: the ids of paragraph records and the ids of paragraphs in `structure.json` have the same shape and are unrelated. The ledger and the structure sidecars do not change format for it.

`propositions outline trace <directory> --jsonl <ledger>` SHALL print, for each record, the paragraph record's id, the proposition's id and its location, tab-separated, then the problems and a count, and exit with 1 when any record is not an object with exactly those four keys (`outline`, `first_prop`, `section` strings, `approval_line` a number), names no paragraph record of the outline, names a proposition that is not exactly one live proposition of the ledger, or names a proposition an earlier record names; with 0 otherwise; and with 2 when a file cannot be read.

#### Scenario: The trace is checked

- **WHEN** `outline trace` reads a trace whose records hold
- **THEN** it lists each with the proposition's location and exits with 0; a record it cannot follow is named and the command exits with 1

##### Example: the trace check reports a record it cannot follow

- **GIVEN** the structure fixture and the outline of the previous example, and a trace whose lines are a valid record for `p-1`, the same record again, a record naming `p-9` and the proposition `nobody`, and `{"outline": "p-1"}`
- **WHEN** `propositions outline trace` runs
- **THEN** it exits with 1 and reports that line 2 records a proposition already recorded on line 1, that `p-9` is no paragraph record, that `nobody` is no proposition of the ledger, and that line 4 is not a record
