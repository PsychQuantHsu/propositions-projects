## ADDED Requirements

### Requirement: The trace and the length report follow the destinations of the parts

A record of `outline-trace.jsonl` MAY carry a fifth key, `part`, one of `main`, `appendix`, `supplement`: the part its section went to when `article.json` named destinations. A record without it belongs to `main`.

When the `article.json` of the outline directory has `destinations`, `propositions outline trace <directory> --jsonl <ledger>` SHALL check, against that ledger, the records of the parts whose destination names it, and print each other record as its outline id, its proposition and `in the document of the part <part>`, without checking it. It exits with 2 when the ledger is the destination of no part. Without `destinations` it checks every record against the ledger given, as before.

`propositions outline length <directory> --written` SHALL count what was written from the documents the destinations name: each trace record in the ledger and main file of its part. It exits with 2 when `article.json` has no `destinations`, when a document cannot be read, or when it is given with `--jsonl` and `--tex`; and `--jsonl` and `--tex` are refused (exit 2) when `article.json` has `destinations`. A trace record of a part without a destination is not counted and is in the count of records that were not found.

#### Scenario: Each document is checked with its own ledger

- **WHEN** the trace holds records of the main text and of the supplement
- **THEN** `outline trace` with the main text's ledger checks the first and lists the second as being in the other document

##### Example: trace and length with two documents

- **GIVEN** the two documents, the outline and the trace of the example "a paragraph goes to the document of its part" of the capability `write`, after both paragraphs were written
- **WHEN** `propositions outline trace <directory> --jsonl <the main text's ledger>` runs, then with a ledger that no destination names, then `propositions outline length <directory> --written`, then `outline length` with `--jsonl` and `--tex`
- **THEN** the first prints the record of `p-s` as `in the document of the part supplement`, the record of `p-1` with its location, and `2 record(s), 0 problem(s)`, and exits with 0; the second exits with 2; the third prints `written` counts above zero for `s-a` and for `s-sup` and a line for each of the parts `main` and `supplement`; the fourth exits with 2 and says to use `--written`
