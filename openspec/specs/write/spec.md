# write Specification

## Purpose

TBD - created by archiving change 'idd-49-write'. Update Purpose after archive.

## Requirements

### Requirement: A new paragraph is made in copies and written behind one confirmation

The command-line tool SHALL have three subcommands that write one new paragraph into a draft, with its propositions and its structure records.

`propositions write prepare --jsonl <ledger> --tex <main file> --structure <structure.json> --discourse <discourse.jsonl> --stage <directory>` SHALL find where the paragraph goes: after the run of non-blank lines that holds the start of the last live proposition in reading order (read by the rules of the capability `citation-order`), in the file that proposition's `location` names. It copies every file of the input tree under `manuscript/` of the staging directory, at the paths they have from the main file's directory, and the ledger, `_meta.json` (when there is one) and the two sidecars under `ledger/`; and it writes `write.json`, which records the four files a paragraph changes (the manuscript file that gets the paragraph, the ledger, the discourse sidecar and the structure sidecar), the SHA-256 of each, and the line after which the paragraph goes. Every file is read once; the placement, the copies and the hashes come from those bytes, and `prepare` refuses when one of the four files changed while it ran. Each copy is created as a new file. The other files of the tree and `_meta.json` are recorded with their SHA-256 too: they are not written back, and their originals and copies have to stay as they were, because the skill validates against the copies. It refuses, with exit 2, a staging directory that is not empty or cannot be listed, a ledger and two sidecars that do not have three different file names (or one of them named `_meta.json`), four files that are not four different files, a last line of the paragraph without a line ending at the end of its file, a file it cannot read, a ledger without a live proposition, a live proposition located outside the input tree, and a file of the tree outside the main file's directory. A retired proposition located after the new paragraph in the same file is named in a warning: its location will no longer name its old lines.

The paragraph, its propositions and its records are made in the copies (the skill writes them). A placeholder for what is still to be supplied, which the paragraph does not invent (a result, a number, a citation), is written `{PENDING: <what is to be supplied>}`.

`propositions write check --stage <directory>` SHALL report, and exit with 1 when any holds: the staged manuscript file is not the original with bytes added after the line ending of the recorded line and every other byte as it was; the added lines are not UTF-8, do not start with a blank line, do not hold exactly one run of non-blank lines, or, when text follows them, do not end with a line ending and a blank line; the staged ledger or discourse sidecar is not the original with whole lines added at its end (a last line without a line ending may get one), or an added line is not a JSON object; the staged ledger has no new line; the staged structure sidecar is not JSON or does not keep everything the original has (every key of an object, with what it holds, and every element of an array in its place; it may only add); a file recorded as not written back, or its copy, is not as `prepare` found it. It prints the number of lines added, of new propositions, of new records, and of added lines that hold `{PENDING:`, with their line numbers. It exits with 0 when none holds, and with 2 when the staging directory holds no `write.json` or a file cannot be read. The validators (the ledger validator, the coverage check, the structure validator) are run on the copies by the skill.

`propositions write commit --stage <directory>` SHALL read every original and copy once, and write nothing unless every one of the four originals still has the SHA-256 recorded by `prepare` and the check, run on those bytes, reports nothing; a copy that cannot be read is refused before any write. It then makes `backup/` in the staging directory, refusing one that exists, keeps a copy of each original there, each created as a new file, and replaces the four files with the bytes it checked, in this order: the manuscript file, the ledger, the discourse sidecar, the structure sidecar, each as `propositions ledger-order` replaces a ledger. The manuscript comes first because text without its propositions is a state the plugin already knows (text not yet extracted), while propositions without their text are not. When a replacement fails, for any reason, it stops, and its message names the files already written and where the originals are kept; putting them back is the author's decision. It exits with 0 when it wrote the four files and with 2 when it refused or failed.

#### Scenario: A paragraph is written after the last proposition

- **WHEN** the paragraph, one proposition and one record are made in the copies prepared for a draft, and the author confirms
- **THEN** `check` reports nothing, `commit` writes the four files, and the originals are kept

##### Example: a paragraph is written after the last proposition behind one confirmation

- **GIVEN** the structure fixture, whose last proposition starts at line 30 of `main.tex`
- **WHEN** `write prepare` runs, a blank line and a paragraph with one placeholder are added after line 30 of the staged `main.tex`, one proposition is added at the end of the staged ledger and one record at the end of the staged discourse sidecar, and `write check` and `write commit` run
- **THEN** `prepare` prints `the new paragraph goes after line 30 of main.tex`; `check` run before the paragraph is made exits with 1; after it, `check` prints `2 line(s) added, 1 new proposition(s), 1 new record(s), 1 placeholder line(s): 32` and exits with 0; `commit` exits with 0, the manuscript file, the ledger and the discourse sidecar have the bytes of their copies, and `backup/ledger` has the bytes of the original ledger

##### Example: a file changed after prepare is not overwritten

- **GIVEN** the same paragraph made in the copies, and a line added to the original `main.tex` after `prepare`
- **WHEN** `write commit` runs
- **THEN** it says that `main.tex` changed after prepare, exits with 2, and the original `main.tex` and ledger are as they were

##### Example: copies that change more than a new paragraph are refused

- **GIVEN** the same paragraph made in the copies, and in the copies a word changed in an earlier line of `main.tex` and a `claim_type` changed in an earlier line of the ledger
- **WHEN** `write check` and then `write commit` run
- **THEN** `check` names both changes and exits with 1, and `commit` exits with 2

<!-- @trace
source: idd-49-write
updated: 2026-11-21
code:
  - plugins/propositions/catalog/obligations.yaml
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/Version.swift
  - tests/PropositionsKitTests/WriteParagraphTests.swift
  - CLAUDE.md
  - Sources/PropositionsKit/WriteParagraph.swift
  - Sources/PropositionsKit/CLI.swift
tests:
  - tests/test_plugin_payload_tracked.py
-->

##### Example: a staged file that is missing writes nothing

- **GIVEN** the paragraph made in the copies, and the staged `structure.json` removed
- **WHEN** `write commit` runs
- **THEN** it exits with 2 and the original `main.tex` is as it was

<!-- @trace
source: idd-49-fix1
updated: 2026-11-21
code:
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/WriteParagraph.swift
  - tests/PropositionsKitTests/WriteParagraphTests.swift
-->

---
### Requirement: The first paragraph of a draft with no proposition goes before \end{document}

When the ledger has no live proposition, `propositions write prepare` SHALL place the paragraph after the last line of text before the first line of the main file that is `\end{document}` (white space around it aside). It SHALL refuse, with exit 2, a main file without such a line, and one with no line before it.

#### Scenario: An empty draft gets its first paragraph

- **WHEN** `prepare` runs on a draft whose ledger is empty
- **THEN** the paragraph goes after the last line of text before `\end{document}`

##### Example: an empty draft gets its first paragraph before \end{document}

- **GIVEN** a main file whose lines are `\documentclass{article}`, `\begin{document}`, `\section{Intro}`, a blank line and `\end{document}`, and an empty ledger
- **WHEN** `write prepare` runs
- **THEN** it prints `the new paragraph goes after line 3 of main.tex`; on a main file without `\end{document}` it exits with 2 and says so


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

---
### Requirement: A heading line comes with the paragraph only when prepare is asked for one

`propositions write prepare --heading` SHALL record that the added lines may begin with one heading: a single line that is a `\part`, `\chapter`, `\section`, `\subsection` or `\subsubsection` command and nothing else (starred or not, with an optional short title in brackets, one braced argument, and optionally one `\label{…}` and a comment), followed by a blank line. `write check` then requires, after the blank line that opens the added lines, either one paragraph or that heading followed by one paragraph, and prints `heading: <the line>`. Any other added line that begins a sectioning command is a problem, with `--heading` or without it: a heading with text after it on its line, a second heading, and a heading line inside the paragraph. Without `--heading`, a heading line set off by blank lines also counts as a paragraph of its own, so the check reports two paragraphs.

#### Scenario: A section begins with its first paragraph

- **WHEN** the added lines are a heading line, a blank line and a paragraph
- **THEN** `check` passes when `prepare` had `--heading`, and reports two paragraphs when it had not

##### Example: a heading line is allowed only when prepare was asked for one

- **GIVEN** the structure fixture, and a blank line, `\section{Outlook}`, a blank line and `The effect was large.` added after line 30 of the staged `main.tex`, with one proposition and one record
- **WHEN** `write check` runs after `prepare` with and without `--heading`
- **THEN** with it, `check` exits with 0 and prints `heading: \section{Outlook}` first; without it, `check` exits with 1 and says the lines hold 2 paragraphs


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
### Requirement: A paragraph written from an outline record is gated on its approval and traced

`propositions write prepare --outline <directory> --outline-paragraph <id>` SHALL read the three outline files once each (each has to be a regular file, not a link) and judge the outline from those bytes, which are also the bytes it copies and hashes. It SHALL stage nothing unless the outline passes `propositions outline check`, exactly one paragraph record has that id, the record does not carry `dropped`, and its section stands as approved (as `propositions outline status` says). `--outline` and `--outline-paragraph` go together. It refuses an outline file or `outline-trace.jsonl` that is one of the four files the paragraph changes. `prepare` records the id, its section, the line of `outline-approvals.jsonl` that holds the last approval with an entry for that section, and the state of `outline-trace.jsonl` in the outline directory; it copies the three outline files under `outline/` of the staging directory as files that are not written back, so a change to them, or to their copies, after `prepare` makes `check` and `commit` refuse. `write check` SHALL require that the first proposition added to the ledger is exactly one line of the staged ledger, live, and starts in the added lines of the file that gets the paragraph. `write commit` SHALL refuse, writing nothing, when `outline-trace.jsonl` changed after `prepare` (or anything, a dangling link included, appeared at its path when there was nothing), when it already names that proposition, and when the outline record no longer gives the section and approval line `prepare` recorded, judged again from the outline files `write.json` names (which have to be the files recorded as not written back); and after writing the four files it appends one line to that file (creating it when there was none): `{"outline": <id>, "first_prop": <id of the first proposition added to the ledger>, "section": <section id>, "approval_line": <line>}`. A failure there is reported as a failure after writing started. As for the other files, two commits that write the same trace at the same moment are not kept apart: the second can find the trace changed only after it has written its four files.

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
### Requirement: A whole manuscript is rewritten from an outline approved as a whole

`propositions write prepare --rewrite --outline <directory>` SHALL stage a rewrite of the whole manuscript. It takes neither `--outline-paragraph` nor `--heading` (exit 2). It reads the three outline files once and stages nothing unless the outline passes `propositions outline check` and stands as approved as a whole: every section stands as approved, the order of sections stands as approved, no section is removed since its approval, and no paragraph record names no section (as `propositions outline status` says). It copies every file of the input tree; the files other than the main file are recorded, with their SHA-256, as files a rewrite may change. Every file the run writes has to be named once (an included file cannot also be a sidecar) and none may be `_meta.json`, an outline file or `outline-trace.jsonl`. It prints `rewrite: every file of the input tree may change; list the outline records in <the map file>` in place of the line of a new paragraph. A `write.json` that holds the fields of both modes is refused.

`write check` on a rewrite SHALL report, and exit with 1 when any holds: a file of an input of the run (`_meta.json`, an outline file) or its copy changed; a staged file of the manuscript is not UTF-8; a line of either ledger writes a key twice, or a line of the original ledger has no id or shares its id with another line; a line of the original ledger is not exactly one line of the staged ledger (by id); such a line changed in anything other than `location`, `cites` and `retired`; a line that was retired changed its retirement; a new line is retired, or its id names several lines; the staged discourse sidecar is not one JSON object per line, or the staged structure is not JSON (both read as strict UTF-8); a live proposition of the staged ledger is located outside the staged input tree; the staging directory holds no `outline-map.jsonl`, or a line of it is not an object with exactly the keys `outline` and `first_prop`, names no paragraph record of the outline that is not dropped, names a proposition that is not exactly one live line of the staged ledger, names a proposition that does not start a paragraph (its line follows neither a blank line nor a sectioning line), or repeats an outline record or a proposition; a paragraph record of the outline that is not dropped is not listed. That a paragraph says what its record plans is the author's to confirm, not this check's. The order of the ledger's lines may change. It prints `rewrite: <n> file(s) changed, <n> new proposition(s), <n> outline record(s) listed`.

`write commit` on a rewrite SHALL read the outline files and `outline-map.jsonl` once, judge, check and build the trace from those bytes before anything is written, and SHALL write nothing when a file of the tree, the ledger or a sidecar changed after `prepare`, `outline-trace.jsonl` changed (or appeared), or the outline no longer stands as approved as a whole; it then keeps a copy of every original in `backup/`, the old `outline-trace.jsonl` included, with `backup/restore.jsonl` naming the destination of each copy (and that the trace was absent, when it was); writes, among the main file, the other files of the tree, the ledger, the discourse sidecar and the structure sidecar, those whose bytes changed; and writes `outline-trace.jsonl` anew with one record per line of `outline-map.jsonl`, in its order, in the format of the capability `article-outline`: the old records name paragraphs of the text the rewrite replaces.

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