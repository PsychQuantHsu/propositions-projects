## ADDED Requirements

### Requirement: Text written from an outline goes to the document of its section's part

`article.json` MAY carry `destinations`, an object whose keys are parts (`main`, `appendix`, `supplement`), each once, and whose values are objects with `tex` and `jsonl`: the main file and the ledger of the document the part is written into, as paths from the directory of `article.json` that do not begin with `/`. Two parts MAY name the same document. An object that names no part, or an entry that is not in this format, is not in the format of `article.json`.

When the `article.json` of the outline directory has `destinations`, `propositions write prepare --outline <directory> --outline-paragraph <id>` SHALL stage nothing (exit 2) unless the part of the record's section (its own `part`, else that of the section it is under, else `main`) has a destination and the main file and ledger given are that destination; the refusal names the part and, when it has a destination, the two files to give. `write commit` then writes the record of `outline-trace.jsonl` with a fifth key, `part`.

`write prepare --rewrite --outline <directory>` SHALL then stage nothing unless the main file and ledger given are the destination of at least one part and every section that is not dropped goes to a part that has a destination. The rewrite is of that document only: `outline-map.jsonl` has to list exactly the paragraph records, not dropped, whose sections go to its parts; a line that names a record of another document is reported. `write commit` writes the trace as the records of the old trace that belong to other parts, as they were, followed by the records of the map, each with its `part`. A trace record without `part` belongs to `main`.

Without `article.json`, or without `destinations` in it, the commands behave as before and no record carries `part`.

#### Scenario: A paragraph of the supplement is not written into the main text

- **WHEN** a section's part is `supplement` and the files given are the main text's
- **THEN** prepare refuses and names the supplement's main file and ledger

##### Example: a paragraph goes to the document of its part

- **GIVEN** the structure fixture as the main text, a second document `supp/supp.tex` with an empty ledger, an approved outline with section `s-a` (record `p-1`) and section `s-sup` (`part` `supplement`, record `p-s`), and `article.json` in the outline directory naming the main text for `main` and the second document for `supplement`
- **WHEN** `write prepare --outline … --outline-paragraph p-s` runs with the main text's files, then with the supplement's files followed by a draft and `write commit`; and then `p-1` is written with the main text's files
- **THEN** the first prepare exits with 2 and names `supp/supp.tex` and its ledger; the others succeed; `outline-trace.jsonl` holds the record of `p-s` with `"part": "supplement"` and the record of `p-1` with `"part": "main"`

##### Example: a part without a destination

- **GIVEN** the same outline with a section whose `part` is `appendix`, and `destinations` that names `main` and `supplement` only
- **WHEN** `write prepare` runs for a record of that section, and `write prepare --rewrite` for the main text
- **THEN** both exit with 2 and say that `article.json` names no destination for the part `appendix`

##### Example: a rewrite of one document keeps the trace of the other

- **GIVEN** the same two documents and outline, approved as a whole, with a trace that holds one record of `p-s` with `"part": "supplement"`
- **WHEN** the main text is rewritten as in the example "a manuscript is rewritten from an outline approved as a whole", with `outline-map.jsonl` listing the two records of `s-a`; and, in another run, with a third line for `p-s`
- **THEN** the first check exits with 0 and commit leaves a trace of three records: the supplement's record as it was, then the two of `s-a` with `"part": "main"`; the second check exits with 1 and reports the line for `p-s`

##### Example: destinations that are not in the format

- **GIVEN** `article.json` with `{"destinations": {}}`, with `{"destinations": {"online": {"tex": "a.tex", "jsonl": "a.jsonl"}}}`, with `{"destinations": {"main": {"tex": "/abs/main.tex", "jsonl": "a.jsonl"}}}`, and with `{"destinations": {"main": {"tex": "a.tex"}}}`
- **WHEN** each is read
- **THEN** each is refused, and the message names `article.json` and `destinations`
