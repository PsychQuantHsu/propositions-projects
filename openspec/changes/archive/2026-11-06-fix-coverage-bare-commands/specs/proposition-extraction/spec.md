## MODIFIED Requirements

### Requirement: Coverage check reports uncovered text in a line range

The plugin SHALL ship `check-extraction-coverage.py`, which takes a `.tex` file, an inclusive line range, and a JSONL ledger. Candidate propositions SHALL be those that carry no `retired` field, whose `location` refers to the same file under the file-qualified location rules, and whose line span intersects the range. The script SHALL normalize the range with the same normalization R1 uses, locate each candidate's normalized text within it, and report every maximal run of normalized text that no candidate covers and that contains at least one letter or digit once layout commands are removed, with the source line numbers where the run starts and ends. When a candidate's text occurs more than once in the range, the occurrence nearest its `location` start line SHALL be used; a tie SHALL be reported as a warning rather than resolved by guessing. A candidate whose text cannot be located in the range SHALL be reported as a warning and SHALL NOT count toward coverage. The layout commands SHALL be exactly these 22, each with an optional star: `\appendix`, `\bigskip`, `\centering`, `\clearpage`, `\footnote`, `\footnotesize`, `\Huge`, `\huge`, `\item`, `\LARGE`, `\Large`, `\large`, `\maketitle`, `\medskip`, `\newpage`, `\noindent`, `\normalsize`, `\par`, `\scriptsize`, `\small`, `\smallskip`, `\tiny`. No other command SHALL be removed. The script SHALL exit with status 0 when no uncovered run exists, 1 when at least one exists, and 2 when its inputs cannot be read or the range is invalid.

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

#### Scenario: A run of layout commands only

- **WHEN** `\maketitle` stands alone on a line in the range and every other piece of text is covered
- **THEN** the script reports zero uncovered runs and exits with status 0

#### Scenario: Footnote text already covered

- **WHEN** a line holds `\footnote{The effect was small.}` and a proposition covers `The effect was small.`
- **THEN** the script reports zero uncovered runs for that line

#### Scenario: Uncovered footnote text

- **WHEN** a line holds `\footnote{The effect was small.}` and no proposition covers it
- **THEN** the script reports one uncovered run for that line whose excerpt contains "The effect was small"

#### Scenario: A command argument is text

- **WHEN** `\cite{smith2020}` stands alone on a line in the range and no proposition covers it
- **THEN** the script reports one uncovered run for that line

#### Scenario: A formula written in control words is text

- **WHEN** `\alpha \le \beta` stands alone in an `equation` environment and no proposition covers it
- **THEN** the script reports one uncovered run for that line

#### Scenario: An unlisted command is text

- **WHEN** `\mycommand` stands alone on a line in the range and no proposition covers it
- **THEN** the script reports one uncovered run for that line
