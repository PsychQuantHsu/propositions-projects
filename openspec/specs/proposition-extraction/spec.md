# proposition-extraction Specification

## Purpose

Proposition extraction turns a paragraph or section of a manuscript into ledger propositions through a skill with mechanical gates at each step. It exists because the validator alone proves that extracted text was not fabricated but cannot show that nothing in the target range was left out.

## Requirements

### Requirement: Extraction ships as its own skill

The propositions plugin SHALL ship a skill whose `SKILL.md` declares `name: extract`, located under the plugin's `skills/extract/` directory. The propositions skill's Operation C SHALL direct the reader to this skill instead of describing the extraction procedure itself.

#### Scenario: Skill is present in the published payload

- **WHEN** the plugin payload is inspected
- **THEN** `plugins/propositions/skills/extract/SKILL.md` exists with frontmatter `name: extract`, and no other `SKILL.md` in the repository declares `name: extract`

#### Scenario: Operation C points to the extraction skill

- **WHEN** a reader opens Operation C in the propositions skill
- **THEN** the section names `propositions:extract` as the procedure for extraction

---
### Requirement: Profile selects the extraction reference

The extraction skill SHALL read the target ledger's declared profile before extracting and SHALL load exactly one domain reference: `references/empirical.md` for `empirical`, and `references/math.md` for `default` or an absent profile.

#### Scenario: Empirical ledger

- **WHEN** the target ledger's `_meta.json` declares `"profile": "empirical"`
- **THEN** the skill loads `references/empirical.md` and does not load `references/math.md`

#### Scenario: Ledger without a profile

- **WHEN** the target ledger's `_meta.json` declares no profile
- **THEN** the skill loads `references/math.md`

---
### Requirement: Temporary identifiers are replaced by UUID v7

The plugin SHALL ship `assign-prop-ids.py`, which reads a JSONL file in which proposition identifiers matching `tmp:[A-Za-z0-9_-]+` are temporary. For each temporary identifier used as an `id`, the script SHALL generate one UUID v7 (RFC 9562) and SHALL substitute it for that identifier in every `id` and `cites` entry. Identifiers that are already UUIDs SHALL be left unchanged, as SHALL every other field and the line order. Within one run, generated UUIDs SHALL strictly increase in the order their temporary identifiers first appear as an `id`. The script SHALL write to standard output, or to the path given by `--out`, and SHALL NOT modify its input file.

#### Scenario: Temporary ids and cites are replaced consistently

- **WHEN** the input holds three propositions with ids `tmp:a`, `tmp:b`, `tmp:c`, where `tmp:c` cites `tmp:a` and an existing UUID `0190a000-0000-7000-8000-000000000001`
- **THEN** the output holds three distinct UUID v7 ids in increasing order, the cites of the third proposition are the UUID assigned to `tmp:a` followed by `0190a000-0000-7000-8000-000000000001`, and the output passes validator rules R2, R7 and R8

#### Scenario: Dangling temporary cite

- **WHEN** a proposition cites `tmp:z` and no proposition has `id` `tmp:z`
- **THEN** the script reports `tmp:z` as unresolved, writes no output, and exits with status 1

#### Scenario: Duplicate temporary id

- **WHEN** two propositions both have `id` `tmp:a`
- **THEN** the script reports the duplicate, writes no output, and exits with status 1

#### Scenario: Refusal to overwrite

- **WHEN** `--out` names a file that already exists or names the input file itself
- **THEN** the script writes nothing and exits with status 2

---
### Requirement: Coverage check reports uncovered text in a line range

The plugin SHALL ship `check-extraction-coverage.py`, which takes a `.tex` file, an inclusive line range, and a JSONL ledger. Candidate propositions SHALL be those that carry no `retired` field, whose `location` refers to the same file under the file-qualified location rules, and whose line span intersects the range. The script SHALL normalize the range with the same normalization R1 uses, locate each candidate's normalized text within it, and report every maximal run of normalized text that no candidate covers and that contains at least one letter or digit, with the source line numbers where the run starts and ends. When a candidate's text occurs more than once in the range, the occurrence nearest its `location` start line SHALL be used; a tie SHALL be reported as a warning rather than resolved by guessing. A candidate whose text cannot be located in the range SHALL be reported as a warning and SHALL NOT count toward coverage. The script SHALL exit with status 0 when no uncovered run exists, 1 when at least one exists, and 2 when its inputs cannot be read or the range is invalid.

#### Scenario: Fully covered paragraph

- **WHEN** a range holds two sentences and the ledger holds one proposition per sentence with verbatim text
- **THEN** the script reports zero uncovered runs and exits with status 0

#### Scenario: Dropped clause

- **WHEN** a range holds the sentence "The sample was large, but the effect was small." on line 12, and the ledger covers only "The sample was large,"
- **THEN** the script reports one uncovered run starting and ending on line 12 whose excerpt contains "but the effect was small", and exits with status 1

#### Scenario: Proposition spanning a line break

- **WHEN** a sentence is wrapped across lines 20 and 21 and one proposition holds the whole sentence on a single line
- **THEN** the sentence counts as covered

#### Scenario: Retired proposition is not a candidate

- **WHEN** the only proposition located in the range carries a `retired` field
- **THEN** the script counts zero candidates and reports the passage as uncovered

#### Scenario: Proposition that cannot be located

- **WHEN** a candidate proposition's text does not occur in the normalized range
- **THEN** the script lists that proposition's id as a warning and the surrounding text is still reported as uncovered

##### Example: paraphrased proposition

- **GIVEN** line 8 reads `Most participants preferred the second option.` and the only candidate proposition, with location line 8, holds `Most participants favoured the second option.`
- **WHEN** the coverage check runs on lines 8 through 8
- **THEN** the output lists that proposition's id under warnings as not locatable, reports one uncovered run on line 8 containing `Most participants preferred the second option`, and exits with status 1

---
### Requirement: Coverage exclusions are a closed set and are reported

The coverage check SHALL exclude exactly these five kinds of structure and no others: (1) text from an unescaped `%` to the end of its line; (2) `\label{...}`; (3) the sectioning commands `\section`, `\subsection`, `\subsubsection` and `\paragraph`, including starred forms, together with their braced titles; (4) `\begin{...}` and `\end{...}` markers, including an immediately following bracketed optional argument; (5) the full content of `table`, `table*`, `figure` and `figure*` environments. Text that follows a sectioning title on the same line SHALL be checked. Every excluded float SHALL be listed in the output with its environment name and line range.

#### Scenario: Heading followed by prose on the same line

- **WHEN** line 30 reads `\subsubsection{Participants}There were 40 students in this study.` and no proposition covers it
- **THEN** the uncovered run reported for line 30 contains "There were 40 students in this study" and does not contain "Participants"

#### Scenario: Float is excluded and listed

- **WHEN** the range contains a `table` environment on lines 50 through 70
- **THEN** no uncovered run is reported inside lines 50 through 70, and the output lists `table` with lines 50 through 70 as excluded

---
### Requirement: Coverage normalization is the R1 normalization

The normalization that the coverage check uses SHALL be defined by the same ordered list of rewrite steps as the normalization R1 uses, so that the text produced by the coverage check equals the text produced by R1 for every input.

#### Scenario: Equivalence on every fixture

- **WHEN** both normalizations are applied to each `.tex` file under `tests/fixtures`
- **THEN** the coverage check's normalized text equals R1's normalized text, character for character, for every file

---
### Requirement: Escaped percent signs are literal text in the shared normalization

The shared normalization used by R1 and by the coverage check SHALL treat `%` as the start of a comment only when it is preceded by an even number of backslashes, including zero. A `%` preceded by an odd number of backslashes SHALL be kept as literal text together with the rest of its line.

#### Scenario: Verbatim proposition containing an escaped percent sign

- **WHEN** the source line reads `We computed the 95\% confidence intervals for the mean.` and a proposition holds exactly that text
- **THEN** R1 passes for that proposition

#### Scenario: Comment after a forced line break

- **WHEN** a source line reads `first part \\% a comment` followed by a newline
- **THEN** the normalized text contains `first part` and does not contain `a comment`

#### Scenario: Coverage sees text after an escaped percent sign

- **WHEN** the coverage check runs on a range whose line reads `About 30\% of participants finished early.` and no proposition covers it
- **THEN** the reported uncovered run contains `of participants finished early`

---
### Requirement: Extraction stages outside the ledger and merges only after confirmation

The extraction skill SHALL write model output, identifier assignment and the coverage check to a staging location outside the ledger directory. The skill SHALL insert the staged propositions into a staging copy of the ledger's `main.jsonl` and run the validator on that copy. Only when the validator exits with status 0 on the copy SHALL the skill present the insertion position and the diff, and it SHALL write to the ledger's `main.jsonl` only after explicit user confirmation. When the target range already contains propositions that carry no `retired` field, the skill SHALL stop before extracting and list those propositions.

#### Scenario: User declines the merge

- **WHEN** the staged propositions pass validation and coverage and the user declines at the merge confirmation
- **THEN** the ledger's `main.jsonl` is byte-identical to its state before the skill started

#### Scenario: Target range already extracted

- **WHEN** the requested line range intersects the location of an existing proposition in `main.jsonl`
- **THEN** the skill lists the intersecting propositions with their ids and locations and performs no extraction

---
### Requirement: Extraction is complete only after both gates pass

The extraction skill SHALL report an extraction as complete only when the validator exits with status 0 on the ledger after the merge and the coverage check on the target range either exits with status 0 or reports only runs that the user explicitly accepted during curation. The completion report SHALL list every accepted uncovered run with its line numbers.

#### Scenario: Accepted uncovered run

- **WHEN** the coverage check reports one uncovered run on line 44, the user accepts it during curation, and the validator exits with status 0 on the merged ledger
- **THEN** the skill reports the extraction as complete and the completion report lists the accepted run on line 44

#### Scenario: Validator failure on the staged copy blocks the merge

- **WHEN** the validator exits with status 1 on the staging copy of `main.jsonl` that includes the new propositions
- **THEN** the skill shows the failing rules, does not offer the merge, does not report the extraction as complete, and the ledger's `main.jsonl` is unchanged
