## ADDED Requirements

### Requirement: The banned phrasings of an article are refused in the text a run adds

`article.json` is an optional file that holds what is true of the whole article. It SHALL be a JSON object. Its key `banned`, when present, SHALL be a list of objects, each with a `phrase` and a `reason` that are non-empty strings; a `phrase` holds at least one character that is not white space and no control character. Keys this requirement does not define are left alone.

`propositions write prepare` SHALL look for `article.json` in the outline directory when the run has one (`--outline`), and otherwise in the directory of the ledger. When nothing is there, the run goes on as without the file. When the file is there, prepare reads it once, refuses (exit 2) when it is not a regular file or not in the format above, and copies it into the staging directory as `article/article.json`, an input of the run: `write check` reports, and `write commit` refuses, when the file or its copy changed after prepare.

A text holds a banned phrasing when the phrasing occurs in it under this comparison: letter case does not count; a run of white space, a line break included, counts as one space; the text from a `%` that is not escaped to the end of its line is not compared; both sides are compared in Unicode normalisation form C; and a phrasing does not run across an empty line. The comparison is literal: a phrasing is not a pattern.

`write check` SHALL report each banned phrasing in the text the run adds as a problem, and exit with 1: for one paragraph, the lines added to the staged manuscript file; for a rewrite, every staged file of the input tree. Each report names the file, the line the phrasing starts on, the phrasing and its reason. `write commit` writes nothing while one is reported.

`propositions phrasing --tex <main file> --article <file>` SHALL make the same comparison over every file of the main file's input tree, print one line per occurrence and then `<n> occurrence(s) of <k> banned phrasing(s) in <m> file(s)`, and exit with 0 when there is none, 1 when there is one, and 2 when a file cannot be read or `article.json` is not in the format.

#### Scenario: A new paragraph that holds a banned phrasing is not written

- **WHEN** `article.json` beside the ledger bans a phrasing and the staged paragraph holds it
- **THEN** `check` names the line, the phrasing and the reason and exits with 1, and `commit` writes nothing

##### Example: a paragraph that holds a banned phrasing is refused

- **GIVEN** the structure fixture, and `article.json` beside the ledger with `{"banned": [{"phrase": "very  Large", "reason": "the effect is reported with its size"}]}`
- **WHEN** after `write prepare`, the paragraph `The effect was very` / `large.` is added over two lines with its proposition and record, and `write check` and `write commit` run
- **THEN** `check` exits with 1 and prints `main.tex:L32: the banned phrasing "very  Large" (the effect is reported with its size)`; `commit` exits with 2 and `main.tex` is unchanged

##### Example: a comment, another paragraph and other text do not make a phrasing

- **GIVEN** the banned phrasing `very large`
- **WHEN** the lines `The effect was very % large`, then `big.`, and the lines `It was very`, an empty line, `large.` are compared
- **THEN** no occurrence is reported; `It was VERY` / `  large.` on two lines is one occurrence, on the first of the two lines; and `\%` does not start a comment

##### Example: article.json changed after prepare, or not in the format

- **GIVEN** the structure fixture and an `article.json` beside the ledger
- **WHEN** `write prepare` runs with `{"banned": [{"phrase": " ", "reason": "x"}]}`, with `{"banned": {}}`, and with `[]`; and, with a file in the format, the file is changed after prepare and `write check` runs
- **THEN** each of the three prepares exits with 2 and names `article.json`; the check exits with 1 and says the file changed after prepare

##### Example: a rewrite is compared over every file of the tree

- **GIVEN** the rewrite of the example "a manuscript is rewritten from an outline approved as a whole", with `article.json` in the outline directory banning words that an untouched paragraph of `main.tex` holds
- **WHEN** `write check` runs
- **THEN** it exits with 1 and names that line of `main.tex`

##### Example: phrasing scans the input tree

- **GIVEN** a main file that inputs `sections/intro.tex`, the banned phrasings `clearly shows` and `it is obvious`, and `Clearly  shows` on line 2 of the included file only
- **WHEN** `propositions phrasing --tex main.tex --article article.json` runs, and again after that line is removed
- **THEN** the first prints `sections/intro.tex:L2: the banned phrasing "clearly shows" (…)` and `1 occurrence(s) of 2 banned phrasing(s) in 2 file(s)` and exits with 1; the second prints `0 occurrence(s) of 2 banned phrasing(s) in 2 file(s)` and exits with 0; with `--article` naming no file it exits with 2
