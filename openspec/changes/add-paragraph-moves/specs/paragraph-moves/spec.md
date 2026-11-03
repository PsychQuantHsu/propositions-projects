## Purpose

Paragraph moves record what each sentence does for its paragraph, on top of the dependency tree that records how sentences connect, so that the relation between sentences can be read out. They consist of a closed vocabulary, optional fields on the structure sidecars, a read-out tool, a generated catalog of observed paths and metrics.

## ADDED Requirements

### Requirement: A closed vocabulary defines moves and paragraph types

`plugins/propositions/catalog/vocabulary.yaml` SHALL define two lists, `moves` and `paragraph_types`. Each entry SHALL have `id` (lowercase letters, digits and hyphens, unique within its list), `does` (one English sentence saying what a sentence or paragraph of this kind does) and `zh` (a Traditional Chinese label), and MAY have `not` (how to tell it from a neighbouring value). Any other key SHALL be an error, so that manuscript text has no field to go into. A move states what a sentence does for its paragraph; it SHALL NOT merely restate a `claim_type` value or a relation.

#### Scenario: An unknown key is refused

- **WHEN** a move in the vocabulary has a key named `example`
- **THEN** loading the vocabulary fails and the message names the entry and the key

#### Scenario: A repeated id is refused

- **WHEN** two moves have the id `state-goal`
- **THEN** loading the vocabulary fails and the message names `state-goal`

### Requirement: Records name a move and paragraphs name a type

A record in `discourse.jsonl` MAY have a string field `move`, and a paragraph in `structure.json` MAY have a string field `type`. Both are optional and `structure_version` SHALL remain `"2.0"`. Rule S9 of `validate-structure.py` SHALL report an error for a `move` not in the vocabulary's `moves` and for a `type` not in its `paragraph_types`. `--vocabulary` SHALL override the default path. The tool SHALL load the vocabulary only when at least one such field is present. No order of moves within a paragraph SHALL be reported as a problem by any rule.

#### Scenario: An unknown move fails S9

- **WHEN** a record has `move` set to `state-gaol`
- **THEN** S9 is marked FAIL, the problem names the position, and the exit status is 1

#### Scenario: Sidecars without moves need no vocabulary

- **WHEN** no record has `move`, no paragraph has `type`, and PyYAML is not installed
- **THEN** S9 is marked PASS and the exit status follows the other rules

#### Scenario: A missing parser is an input error

- **WHEN** a record has `move` and PyYAML is not installed
- **THEN** the exit status is 2 and the message names PyYAML

#### Scenario: An unusual order of moves is not reported

- **WHEN** a paragraph's moves appear in an order no other paragraph has
- **THEN** no rule reports a problem about that order

### Requirement: The explain tool reads out how sentences relate

`structure-explain.py` SHALL accept `--jsonl`, optional `--structure`, `--discourse` and `--vocabulary`, exactly one of `--paragraph <id>`, `--section <id>` or `--all`, `--no-text`, and `--format text|json`. For each paragraph it SHALL print the paragraph's id, its type's `zh` label when it has a type, and, when the paragraph has a head paragraph, that paragraph's id and the relation. For each proposition, in reading order, it SHALL print the position, the move's `zh` label or the words `未標` when it has none, the head's position with a plain-language gloss of the relation and the relation's name, the words `段根` for a paragraph root, each `also` entry with its target's position, and the proposition's text unless `--no-text` is given. Text output SHALL indent each proposition by its depth in the paragraph's tree. The tool SHALL write no file. It SHALL exit 0 when it reports and 2 when an input is missing or invalid, the structure version is not `"2.0"`, or the paragraph or section does not exist.

#### Scenario: A sentence says what it does and what it hangs on

- **WHEN** position 139 has move `state-baseline`, relation `specification` and head position 138
- **THEN** its line shows position 139, the label of `state-baseline`, position 138, a gloss of `specification` and the word `specification`

#### Scenario: Depth is visible

- **WHEN** position 141 hangs on 140, which hangs on the root 138
- **THEN** the line for 141 is indented further than the line for 140

#### Scenario: An unlabelled sentence is shown as unlabelled

- **WHEN** a record has a head and relation but no move
- **THEN** its line shows `未標` and still shows the head and relation

#### Scenario: Text can be left out

- **WHEN** `--no-text` is given
- **THEN** the output contains no text from the ledger

#### Scenario: An unknown paragraph is an input error

- **WHEN** `--paragraph p-999` names no paragraph
- **THEN** the exit status is 2 and the message names `p-999`

### Requirement: The paragraph catalog is generated from annotated sidecars

`build-paragraph-catalog.py` SHALL accept `--sidecars <label>=<ledger directory>` one or more times, `--vocabulary`, `--out`, and `--check`. It SHALL write a YAML file that lists, for each paragraph type seen, the number of paragraphs per label, the moves that open it with counts per label, and, for each move, the options that follow it within a paragraph of that type: the next move or `END`, the next proposition's relation, the move of the next proposition's head, and counts per label. Sentences without a move and paragraphs without a type SHALL be left out and their numbers reported in the file's `excluded` section. The file SHALL contain no ledger text, no proposition ids, no paragraph ids and no paths. With `--check` the tool SHALL write nothing and exit 1 when the file on disk differs from what it would write. Output SHALL be sorted so that the same input gives the same bytes.

#### Scenario: A transition is counted per label

- **WHEN** one paragraph of type `goal-summary` under the label `empirical` goes from `state-goal` to `state-baseline` by `specification` with its head at `state-goal`
- **THEN** the catalog has that option under `goal-summary` and `state-goal` with `empirical` count 1

#### Scenario: The catalog carries no manuscript content

- **WHEN** the catalog is built from a fixture ledger
- **THEN** no proposition text, proposition id or directory path of the fixture occurs in the file

#### Scenario: The check mode finds a stale catalog

- **WHEN** a move in the sidecars changes after the catalog was written and `--check` is given
- **THEN** the exit status is 1 and the file is unchanged

### Requirement: Metrics report whether moves add anything

`structure-metrics.py` SHALL also report, when records have moves: the share of propositions and of paragraphs labelled; the count of each move; Cramér's V between move and `claim_type` and between move and relation; and the leave-one-paragraph-out top-3 hit rate for the next proposition's relation and for its move, each given the current move and given no condition. `--compare-moves <ledger directory>` SHALL report Cohen's κ and raw agreement for moves and for types over the propositions and paragraphs labelled in both, with the numbers compared. These are reports; no threshold SHALL change the tool's exit status.

#### Scenario: Agreement is reported

- **WHEN** a second labelling agrees on 8 of 10 moves
- **THEN** the report shows raw agreement 0.80, Cohen's κ and the number 10

#### Scenario: Sidecars without moves report nothing new

- **WHEN** no record has a move
- **THEN** the report has no move section and otherwise does not change

### Requirement: Moves are batch-annotated without touching the tree

`structure-batch.py split --moves-only` SHALL add each proposition's head position and relation to the input, and `structure-batch.py merge --moves-only` SHALL accept answers of the form `{"propositions": {"<position>": {"move": <string>}}, "paragraphs": {"<id>": {"type": <string>}}}` and change only `move` and `type`. Every other field of the staged sidecars SHALL be unchanged. An answer that omits a proposition or paragraph of its batch SHALL make merge write nothing and exit 2.

#### Scenario: The tree survives a moves-only merge

- **WHEN** a moves-only merge finishes
- **THEN** removing `move` and `type` from the merged files gives the staged content

#### Scenario: A missing answer stops the merge

- **WHEN** an output file omits one proposition of its batch
- **THEN** the exit status is 2 and no sidecar is written
