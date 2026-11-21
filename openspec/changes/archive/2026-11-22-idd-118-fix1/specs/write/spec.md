## ADDED Requirements

### Requirement: The comparison with banned phrasings is not passed over

The comparison of a text with a banned phrasing SHALL treat two spellings that differ only in letter case as the same, also where a language writes the cases with different letters (`ß` and `SS`, the two lower-case sigmas). White space at the beginning or the end of a phrase is one space there: the phrase ` cat ` occurs where `cat` stands between two spaces, a line break counting as one, and not inside `concatenate`. Every occurrence is reported, also one that overlaps another. A `%` begins a comment whatever follows it, a combining mark included. A report names the main file by its own file name.

`propositions write check` and `write commit` SHALL refuse (exit 2) a staging directory in which prepare copied an `article.json` or an outline and whose `write.json` no longer names it.

On a rewrite, `write check` SHALL report as a problem a staged manuscript whose input tree holds a file that prepare did not copy, or whose input tree cannot be read: a rewrite cannot add a file to the input tree.

#### Scenario: A list cannot be switched off by editing write.json

- **WHEN** the entry for `article.json` is removed from `write.json` after prepare
- **THEN** check and commit exit with 2

##### Example: how the comparison folds case, ends and overlaps

- **GIVEN** the banned phrasings `Straße`, ` cat ` and `ana`
- **WHEN** the lines `Die STRASSE ist lang.`, `We concatenate lists.`, `A cat` / `sat.`, `banana` and `Unrelated %` followed by a combining acute accent and ` strasse` are compared
- **THEN** the first holds `Straße`; the second holds nothing; the third holds ` cat `, reported on its first line; the fourth holds `ana` twice; the fifth holds nothing

##### Example: write.json that no longer names what prepare copied

- **GIVEN** a run prepared with an `article.json` beside the ledger, and another prepared from an outline record
- **WHEN** the key `article` is removed from the first `write.json`, the key `outline` from the second, and `write check` and `write commit` run
- **THEN** all four exit with 2 and say to prepare again

##### Example: a rewrite that adds an included file

- **GIVEN** the rewrite of the example "a manuscript is rewritten from an outline approved as a whole"
- **WHEN** the staged `main.tex` gets a line `\input{extra}`, a file `extra.tex` is put beside it in the staging directory, and `write check` runs
- **THEN** it exits with 1 and reports that the staged manuscript includes `extra.tex`, which prepare did not copy

##### Example: the main file is reported under its own name

- **GIVEN** a manuscript whose main file is `supp.tex`, with an empty ledger, and `article.json` beside the ledger banning `extra analysis`
- **WHEN** a paragraph that holds the phrasing is drafted and `write check` runs
- **THEN** the report begins with `supp.tex:L`
