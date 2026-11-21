## ADDED Requirements

### Requirement: The length report counts each written paragraph once and stops on a file it cannot read

In the word count, a command that takes a name is followed by its optional arguments in square brackets and one argument in braces, white space allowed before each; they are not counted, and a group after them is text. An equation environment ends at its `\end`, white space allowed before the brace. The punctuation of the kana and Han blocks is not a word, a half-width kana is one, and a number sign that is not a digit (a fraction) is not part of a word.

`propositions outline length` SHALL exit with 2, and print no report, when a file of a manuscript it counts from cannot be read as UTF-8: the main file, or the file a counted proposition is located in. Such a file is not counted as a proposition that was not found.

A paragraph SHALL be counted once however many trace records name its proposition, and a trace record that names a dropped paragraph record, or no paragraph record, does not keep a later record of the same proposition from being counted.

#### Scenario: A stale trace record does not hide a paragraph

- **WHEN** the trace names one proposition twice, first for a dropped record and then for a record that is not dropped
- **THEN** the paragraph is counted once, for the second record's section

##### Example: names with spaces, groups after a name, and a spaced end

- **GIVEN** the lines `See \cite {smith2020} and \label{eq:r}{visible words} here.`, the lines `\begin{equation}` / `x = y` / `\end {equation}` / `After it.`, and the line `カ・ナ ｶﾅ ¼ cup`
- **WHEN** their words are counted
- **THEN** the counts are 5, 2 and 5

##### Example: a stale record, a repeated record and an unreadable file

- **GIVEN** the structure fixture, an outline of section `s-a` with a dropped record `p-old` and a record `p-1`, and a trace that names the proposition of the fixture's last paragraph for `p-old`, then twice for `p-1`
- **WHEN** `propositions outline length <directory> --jsonl <ledger> --tex <main file>` runs; and again after the main file is replaced by bytes that are not UTF-8
- **THEN** the first prints `"s-a"	main	target -	written 13	1 of 1 record(s)`; the second exits with 2 and prints no report
