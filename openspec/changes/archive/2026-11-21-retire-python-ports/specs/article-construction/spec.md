## MODIFIED Requirements

### Requirement: Annotation writes sidecars only after validation and confirmation

The skill SHALL start the paragraph plan from the output of `propositions paragraphs`, run through the plugin's launcher (when the pinned binary is not there, the skill lists the paragraphs by hand and says so), then draft `structure.json` and `discourse.jsonl` in a staging location outside the ledger directory: a head and relation for every record that is not a paragraph root, a move for every record, a head and relation for every paragraph that is not its section's root paragraph, a type for every paragraph, and a `parent` for every section that sits under another section. It SHALL run `validate-structure.py` on the staged files until it exits 0, then show the user a summary containing the count of each relation, the count of each move and each paragraph type, the number of records whose head comes before them and after them, the number of paragraphs, every commitment with the positions that open and discharge it, the section list with roles and parents, every S7 and S8 warning, and the median length of the sentence part of the right frontier reported by `structure-metrics.py`. The skill SHALL write the sidecars into the ledger directory only after the user confirms, and SHALL NOT modify `main.jsonl` at any point.

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
