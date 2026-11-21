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