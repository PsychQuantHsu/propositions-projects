## Purpose

Article construction is the `propositions:construct` skill. It annotates an existing manuscript with its article structure, and for a draft in progress it reports what the article still owes the reader and proposes what the next proposition could do. It exists so that the ledger can support writing a whole article, not only checking finished sentences.

## ADDED Requirements

### Requirement: Annotation starts from a validated, fully covered ledger

In annotation mode the skill SHALL first run `validate-propositions.py` on the ledger and `check-extraction-coverage.py` on every range it will annotate. If the validator exits non-zero or any range has uncovered text, the skill SHALL stop, report the failures, and direct the user to `propositions:extract`, without writing any sidecar.

#### Scenario: Uncovered text stops annotation

- **WHEN** the coverage check reports an uncovered run in the introduction
- **THEN** the skill stops before drafting sidecars and names `propositions:extract` as the next step

### Requirement: Annotation writes sidecars only after validation and confirmation

The skill SHALL draft `structure.json` and `discourse.jsonl` in a staging location outside the ledger directory, run `validate-structure.py` on the staged files until it exits 0, then show the user a summary containing the count of each relation, every commitment with the positions that open and discharge it, and the section list with roles. The skill SHALL write the sidecars into the ledger directory only after the user confirms, and SHALL NOT modify `main.jsonl` at any point.

#### Scenario: The user declines

- **WHEN** the user does not confirm the summary
- **THEN** no file in the ledger directory changes and the staged files remain where the summary said they are

#### Scenario: Validation errors are fixed before the summary

- **WHEN** the staged files fail S3 because a discharge precedes its opening
- **THEN** the skill corrects the staged files and reruns the validator before showing any summary

### Requirement: Next mode proposes at most three candidates without writing

In next mode the skill SHALL run `validate-structure.py --partial` and `structure-state.py --at end`, report the current section's role and the open commitments in the order the state query gives, and propose at most three candidate next propositions. Each candidate SHALL state which open commitment it advances or why a `shift` is due, the relation and connective that join it to the last proposition, and its expected `claim_type`. The skill SHALL NOT write to the manuscript, the ledger or the sidecars in next mode.

#### Scenario: An open announcement shapes the first candidate

- **WHEN** the state query lists an `announcement` as the first open commitment
- **THEN** the first candidate discharges that announcement

#### Scenario: Next mode leaves files untouched

- **WHEN** next mode finishes
- **THEN** the manuscript, `main.jsonl`, `structure.json` and `discourse.jsonl` are byte-identical to before

### Requirement: Construction requests route to the construct skill

The skill's description SHALL claim requests about an article's overall structure, its commitments to the reader, the relation between consecutive propositions, and what to write next, and SHALL direct requests to split text into propositions to `propositions:extract`. The `propositions:extract` and `propositions:propositions` descriptions SHALL NOT claim construction requests.

#### Scenario: A next-sentence request

- **WHEN** a user asks what the next sentence of a draft section should do
- **THEN** the request matches `propositions:construct` and not `propositions:extract`
