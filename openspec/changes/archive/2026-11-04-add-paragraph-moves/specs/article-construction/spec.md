## MODIFIED Requirements

### Requirement: Annotation writes sidecars only after validation and confirmation

The skill SHALL start the paragraph plan from the output of `derive-paragraphs.py`, then draft `structure.json` and `discourse.jsonl` in a staging location outside the ledger directory: a head and relation for every record that is not a paragraph root, a move for every record, a head and relation for every paragraph that is not its section's root paragraph, a type for every paragraph, and a `parent` for every section that sits under another section. It SHALL run `validate-structure.py` on the staged files until it exits 0, then show the user a summary containing the count of each relation, the count of each move and each paragraph type, the number of records whose head comes before them and after them, the number of paragraphs, every commitment with the positions that open and discharge it, the section list with roles and parents, every S7 and S8 warning, and the median length of the sentence part of the right frontier reported by `structure-metrics.py`. The skill SHALL write the sidecars into the ledger directory only after the user confirms, and SHALL NOT modify `main.jsonl` at any point.

#### Scenario: The user declines

- **WHEN** the user does not confirm the summary
- **THEN** no file in the ledger directory changes and the staged files remain where the summary said they are

#### Scenario: Validation errors are fixed before the summary

- **WHEN** the staged files fail S2 because a paragraph has two roots
- **THEN** the skill corrects the staged files and reruns the validator before showing any summary

#### Scenario: Warnings are shown, not hidden

- **WHEN** the staged files pass validation with two S7 warnings
- **THEN** the summary lists both crossing pairs

#### Scenario: A needed move is missing from the vocabulary

- **WHEN** no move in the vocabulary fits a sentence
- **THEN** the skill stops and reports the sentence's position instead of choosing a near value

### Requirement: Construction requests route to the construct skill

The skill's description SHALL claim requests about an article's overall structure, its commitments to the reader, the relation between consecutive propositions, how the sentences of a paragraph relate to each other, and what to write next, and SHALL direct requests to split text into propositions to `propositions:extract`. The `propositions:extract` and `propositions:propositions` descriptions SHALL NOT claim construction requests.

#### Scenario: A next-sentence request

- **WHEN** a user asks what the next sentence of a draft section should do
- **THEN** the request matches `propositions:construct` and not `propositions:extract`

#### Scenario: A request about how sentences relate

- **WHEN** a user asks how the sentences of a paragraph relate to each other
- **THEN** the request matches `propositions:construct`

## ADDED Requirements

### Requirement: Explain mode reads out how sentences relate

When the user asks how the sentences of a paragraph or section relate, the skill SHALL run `structure-explain.py` on that paragraph or section and show its output, then say in plain language what the paragraph does and which sentence the others hang on. When the user asks about one sentence's connections, the skill SHALL run `structure-links.py sentence` on it. The skill SHALL NOT write any file in explain mode. When the requested text has no sidecars, the skill SHALL say so and offer annotation mode.

#### Scenario: Explain mode leaves files untouched

- **WHEN** explain mode finishes
- **THEN** the manuscript, `main.jsonl`, `structure.json` and `discourse.jsonl` are byte-identical to before

#### Scenario: No sidecars

- **WHEN** the user asks about a paragraph of a manuscript whose ledger directory has no `discourse.jsonl`
- **THEN** the skill says the sidecars are missing and offers annotation mode without writing anything

### Requirement: Next mode does not consult the link catalog

In this version the skill's next mode SHALL NOT read `links.csv`. Whether it should is decided later from the hit rates `structure-metrics.py` reports.

#### Scenario: The catalog has no effect on next mode

- **WHEN** next mode runs with and without `links.csv` present
- **THEN** the state query it uses gives the same output
