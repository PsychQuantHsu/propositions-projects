## MODIFIED Requirements

### Requirement: A whole manuscript is rewritten from an outline approved as a whole

`propositions write prepare --rewrite --outline <directory>` SHALL stage a rewrite of the whole manuscript. It takes neither `--outline-paragraph` nor `--heading` (exit 2). It reads the three outline files once and stages nothing unless the outline passes `propositions outline check` and stands as approved as a whole: every section stands as approved, the order of sections stands as approved, no section is removed since its approval, and no paragraph record names no section (as `propositions outline status` says). It copies every file of the input tree; the files other than the main file are recorded, with their SHA-256, as files a rewrite may change. Every file the run writes has to be named once (an included file cannot also be a sidecar) and none may be `_meta.json`, an outline file or `outline-trace.jsonl`. It prints `rewrite: every file of the input tree may change; list the outline records in <the map file>` in place of the line of a new paragraph. A `write.json` that holds the fields of both modes is refused.

`write check` on a rewrite SHALL report, and exit with 1 when any holds: a file of an input of the run (`_meta.json`, an outline file) or its copy changed; a staged file of the manuscript is not UTF-8; a line of either ledger writes a key twice, or a line of the original ledger has no id or shares its id with another line; a line of the original ledger is not exactly one line of the staged ledger (by id); such a line changed in anything other than `location`, `cites` and `retired`; a line that was retired changed its retirement; a new line is retired, or its id names several lines; the staged discourse sidecar is not one JSON object per line, or the staged structure is not JSON (both read as strict UTF-8); a live proposition of the staged ledger is located outside the staged input tree; the staging directory holds no `outline-map.jsonl`, or a line of it is not an object with exactly the keys `outline` and `first_prop`, names no paragraph record of the outline that is not dropped, names a proposition that is not exactly one live line of the staged ledger, names a proposition that does not start a paragraph (its line follows neither a blank line nor a sectioning line), or repeats an outline record or a proposition; a paragraph record of the outline that is not dropped is not listed. When `article.json` names destinations, the records that have to be listed, and may be, are those whose sections go to the document rewritten, as the requirement on destinations says. That a paragraph says what its record plans is the author's to confirm, not this check's. The order of the ledger's lines may change. It prints `rewrite: <n> file(s) changed, <n> new proposition(s), <n> outline record(s) listed`.

`write commit` on a rewrite SHALL read the outline files and `outline-map.jsonl` once, judge, check and build the trace from those bytes before anything is written, and SHALL write nothing when a file of the tree, the ledger or a sidecar changed after `prepare`, `outline-trace.jsonl` changed (or appeared), or the outline no longer stands as approved as a whole; it then keeps a copy of every original in `backup/`, the old `outline-trace.jsonl` included, with `backup/restore.jsonl` naming the destination of each copy (and that the trace was absent, when it was); writes, among the main file, the other files of the tree, the ledger, the discourse sidecar and the structure sidecar, those whose bytes changed; and writes `outline-trace.jsonl` anew with one record per line of `outline-map.jsonl`, in its order, in the format of the capability `article-outline`: the old records name paragraphs of the text the rewrite replaces. When `article.json` names destinations, the old records of the other documents are kept, byte for byte, before the new ones.

#### Scenario: A manuscript is rewritten from its revised outline

- **WHEN** the outline stands as approved as a whole, and the copies rewrite a paragraph, retire its proposition, add a new one, reorder the ledger and list both outline records
- **THEN** `check` passes and `commit` writes the files and traces both records; a rewrite that loses or changes a proposition, or leaves a record unlisted, is refused

##### Example: a manuscript is rewritten from an outline approved as a whole

- **GIVEN** the structure fixture and an outline of one section `s-a` with paragraph records `p-1` and `p-2`, approved on line 1 with `whole` true
- **WHEN** after `write prepare --rewrite`, the last paragraph of the staged `main.tex` is replaced, its proposition is given a `retired` block, a new proposition for the new text is added, the first two lines of the ledger are swapped, `outline-map.jsonl` lists `p-1` with the first proposition and `p-2` with the new one, and `write check` and `write commit` run
- **THEN** `check` prints `rewrite: 1 file(s) changed, 1 new proposition(s), 2 outline record(s) listed` and exits with 0; `commit` exits with 0, `main.tex` has the new text, and `outline-trace.jsonl` has two records, for `p-1` and `p-2`, each with section `s-a` and approval line 1

##### Example: a rewrite that loses or changes a proposition is refused

- **GIVEN** the same rewrite, with a line removed from the staged ledger, the text of another line changed, and `outline-map.jsonl` listing `p-2` only
- **WHEN** `write check` and `write commit` run
- **THEN** `check` exits with 1 and names the removed line, the changed line and the unlisted record `p-1`; `commit` exits with 2

##### Example: a rewrite needs the outline approved as a whole

- **GIVEN** the same outline approved without `whole`
- **WHEN** `write prepare --rewrite` runs, and, on the approved outline, with `--outline-paragraph p-1` or with `--heading`
- **THEN** the first exits with 2 and says the order of sections does not stand as approved; the other two exit with 2

<!-- @trace
source: idd-115-rewrite
updated: 2026-11-21
code:
  - plugins/propositions/docs/OUTLINE.md
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/WriteParagraph.swift
  - Sources/PropositionsKit/WriteRewrite.swift
  - Sources/PropositionsKit/CLI.swift
  - CLAUDE.md
  - Sources/PropositionsKit/Version.swift
  - tests/PropositionsKitTests/WriteRewriteTests.swift
-->

<!-- @trace
source: idd-115-fix1
updated: 2026-11-21
code:
  - tests/PropositionsKitTests/WriteRewriteTests.swift
  - plugins/propositions/docs/OUTLINE.md
  - Sources/PropositionsKit/WriteRewrite.swift
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/WriteParagraph.swift
-->

---

### Requirement: A paragraph written from an outline record is gated on its approval and traced

`propositions write prepare --outline <directory> --outline-paragraph <id>` SHALL read the three outline files once each (each has to be a regular file, not a link) and judge the outline from those bytes, which are also the bytes it copies and hashes. It SHALL stage nothing unless the outline passes `propositions outline check`, exactly one paragraph record has that id, the record does not carry `dropped`, and its section stands as approved (as `propositions outline status` says). `--outline` and `--outline-paragraph` go together. It refuses an outline file or `outline-trace.jsonl` that is one of the four files the paragraph changes. `prepare` records the id, its section, the line of `outline-approvals.jsonl` that holds the last approval with an entry for that section, and the state of `outline-trace.jsonl` in the outline directory; it copies the three outline files under `outline/` of the staging directory as files that are not written back, so a change to them, or to their copies, after `prepare` makes `check` and `commit` refuse. `write check` SHALL require that the first proposition added to the ledger is exactly one line of the staged ledger, live, and starts in the added lines of the file that gets the paragraph. `write commit` SHALL refuse, writing nothing, when `outline-trace.jsonl` changed after `prepare` (or anything, a dangling link included, appeared at its path when there was nothing), when it already names that proposition (with destinations in `article.json`, in a record of a part of the same document), and when the outline record no longer gives the section and approval line `prepare` recorded, judged again from the outline files `write.json` names (which have to be the files recorded as not written back); and after writing the four files it appends one line to that file (creating it when there was none): `{"outline": <id>, "first_prop": <id of the first proposition added to the ledger>, "section": <section id>, "approval_line": <line>}`. A failure there is reported as a failure after writing started. As for the other files, two commits that write the same trace at the same moment are not kept apart: the second can find the trace changed only after it has written its four files.

#### Scenario: A paragraph is written from an approved outline record

- **WHEN** `prepare` names a paragraph record of a section that stands as approved, and the paragraph is made and committed
- **THEN** the four files are written and `outline-trace.jsonl` gets one record for it; a record of a section that does not stand as approved is refused before anything is staged

##### Example: a paragraph is written from an approved outline record and traced

- **GIVEN** the structure fixture and an outline with sections `s-a` and `s-b`, paragraph records `p-1` (in `s-a`) and `p-3` (in `s-b`), and one approval record, on line 1, with an entry for `s-a` only
- **WHEN** `write prepare` runs with `--outline-paragraph p-3`, then with `--outline` alone, then with `--outline-paragraph p-1`, the paragraph and one proposition are made, and `write commit` runs
- **THEN** the first exits with 2 and says that the section does not stand as approved; the second exits with 2; the third and the commit exit with 0, and `outline-trace.jsonl` is `{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-00000000000d", "section": "s-a", "approval_line": 1}` and a line feed

<!-- @trace
source: idd-51-write-from-outline
updated: 2026-11-21
code:
  - Sources/PropositionsKit/WriteFromOutline.swift
  - CLAUDE.md
  - plugins/propositions/docs/OUTLINE.md
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/CLI.swift
  - Sources/PropositionsKit/Version.swift
  - Sources/PropositionsKit/WriteParagraph.swift
  - tests/PropositionsKitTests/WriteFromOutlineTests.swift
-->

<!-- @trace
source: idd-51-fix1
updated: 2026-11-21
code:
  - Sources/PropositionsKit/WriteParagraph.swift
  - propositions-projects.code-workspace
  - tests/PropositionsKitTests/WriteFromOutlineTests.swift
  - Sources/PropositionsKit/WriteFromOutline.swift
-->

---
