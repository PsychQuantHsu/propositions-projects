## ADDED Requirements

### Requirement: The first paragraph of a draft with no proposition goes before \end{document}

When the ledger has no live proposition, `propositions write prepare` SHALL place the paragraph after the last line of text before the first line of the main file that is `\end{document}` (white space around it aside). It SHALL refuse, with exit 2, a main file without such a line, and one with no line before it.

#### Scenario: An empty draft gets its first paragraph

- **WHEN** `prepare` runs on a draft whose ledger is empty
- **THEN** the paragraph goes after the last line of text before `\end{document}`

##### Example: an empty draft gets its first paragraph before \end{document}

- **GIVEN** a main file whose lines are `\documentclass{article}`, `\begin{document}`, `\section{Intro}`, a blank line and `\end{document}`, and an empty ledger
- **WHEN** `write prepare` runs
- **THEN** it prints `the new paragraph goes after line 3 of main.tex`; on a main file without `\end{document}` it exits with 2 and says so

### Requirement: A heading line comes with the paragraph only when prepare is asked for one

`propositions write prepare --heading` SHALL record that the added lines may begin with one heading: a single line that is a `\part`, `\chapter`, `\section`, `\subsection` or `\subsubsection` command, starred or not, followed by a blank line. `write check` then requires, after the blank line that opens the added lines, either one paragraph or that heading followed by one paragraph, and prints `heading: <the line>`. Without `--heading`, a heading line counts as a paragraph of its own, so the check reports two paragraphs.

#### Scenario: A section begins with its first paragraph

- **WHEN** the added lines are a heading line, a blank line and a paragraph
- **THEN** `check` passes when `prepare` had `--heading`, and reports two paragraphs when it had not

##### Example: a heading line is allowed only when prepare was asked for one

- **GIVEN** the structure fixture, and the lines `\section{Outlook}`, a blank line and `The effect was large.` added after line 30 of the staged `main.tex`, with one proposition and one record
- **WHEN** `write check` runs after `prepare` with and without `--heading`
- **THEN** with it, `check` exits with 0 and prints `heading: \section{Outlook}` first; without it, `check` exits with 1 and says the lines hold 2 paragraphs

### Requirement: A paragraph written from an outline record is gated on its approval and traced

`propositions write prepare --outline <directory> --outline-paragraph <id>` SHALL stage nothing unless the outline in the directory passes `propositions outline check`, exactly one paragraph record has that id, the record does not carry `dropped`, and its section stands as approved (as `propositions outline status` says). `--outline` and `--outline-paragraph` go together. `prepare` records the id, its section, the line of `outline-approvals.jsonl` that holds the last approval with an entry for that section, and the state of `outline-trace.jsonl` in the outline directory; it copies the three outline files under `outline/` of the staging directory as files that are not written back, so a change to them, or to their copies, after `prepare` makes `check` and `commit` refuse. `write commit` SHALL refuse, writing nothing, when `outline-trace.jsonl` changed after `prepare` (or appeared, when there was none), and after writing the four files it appends one line to that file (creating it when there was none): `{"outline": <id>, "first_prop": <id of the first proposition added to the ledger>, "section": <section id>, "approval_line": <line>}`. A failure there is reported as a failure after writing started.

#### Scenario: A paragraph is written from an approved outline record

- **WHEN** `prepare` names a paragraph record of a section that stands as approved, and the paragraph is made and committed
- **THEN** the four files are written and `outline-trace.jsonl` gets one record for it; a record of a section that does not stand as approved is refused before anything is staged

##### Example: a paragraph is written from an approved outline record and traced

- **GIVEN** the structure fixture and an outline with sections `s-a` and `s-b`, paragraph records `p-1` (in `s-a`) and `p-3` (in `s-b`), and one approval record, on line 1, with an entry for `s-a` only
- **WHEN** `write prepare` runs with `--outline-paragraph p-3`, then with `--outline` alone, then with `--outline-paragraph p-1`, the paragraph and one proposition are made, and `write commit` runs
- **THEN** the first exits with 2 and says that the section does not stand as approved; the second exits with 2; the third and the commit exit with 0, and `outline-trace.jsonl` is `{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-00000000000d", "section": "s-a", "approval_line": 1}` and a line feed
