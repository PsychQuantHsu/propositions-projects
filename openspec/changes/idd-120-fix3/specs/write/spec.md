## MODIFIED Requirements

### Requirement: The parts of a run are taken from article.json, not from write.json

On a rewrite, `propositions write check` and `write commit` SHALL work out again, from the staged copy of `article.json` and the main file and ledger of the run, the parts whose destination the document is, and report as a problem (commit: write nothing) a `write.json` that names other parts, or parts when `article.json` names no destinations.

When a paragraph is written from an outline with destinations, a proposition id that `outline-trace.jsonl` already names in a record of a part of another document SHALL NOT stop the commit; one that it names in a record of a part of the same document does, as before.

The trace records a rewrite keeps SHALL be written byte for byte as they were, each with the line ending it had. The one exception: a kept record that had no line ending (the last line of the old file) gets one line feed when a record follows it, so that the file stays one record per line.

A destination is the document given when its `tex` and `jsonl` name the same files as the main file and ledger given, by the names the file system gives them, links followed in the order of the path. A `tex` or `jsonl` that holds a control character is not in the format of `article.json`.

#### Scenario: write.json cannot widen a rewrite to another document

- **WHEN** `write.json` of a rewrite of the main text is edited to name the part `supplement` too
- **THEN** check reports it and commit writes nothing

##### Example: a write.json that names another part

- **GIVEN** the rewrite of the main text of the example "a rewrite of one document keeps the trace of the other", prepared and drafted
- **WHEN** the `parts` of `rewrite` in `write.json` are changed to `["main", "supplement"]`, and `write check` and `write commit` run
- **THEN** check exits with 1 and says that `write.json` does not name the parts `article.json` gives; commit exits with 2 and the trace is unchanged

##### Example: the same id in another document, and kept records as they were

- **GIVEN** the two documents, with a trace that holds one record of the supplement, ending in CR LF, whose `first_prop` is the id the main text's new paragraph will use
- **WHEN** the paragraph `p-1` is written into the main text and committed; and, in another run, the main text is rewritten and committed
- **THEN** the first commit exits with 0; after the rewrite the first bytes of the trace are the supplement's record with its CR LF

<!-- @trace
source: idd-120-fix1
updated: 2026-11-22
code:
  - propositions-projects.code-workspace
-->
