## MODIFIED Requirements

### Requirement: Next mode proposes at most three candidates without writing

In next mode the skill SHALL run `validate-structure.py --partial` and `structure-state.py --at end`, report the current section's role, the current paragraph, the right frontier, the pending records and the open commitments in the order the state query gives, and propose at most three candidate next propositions. When pending records exist, the first candidate SHALL be a proposition that serves as the head of every pending record. Each candidate SHALL state the frontier node it attaches to, or the pending records it heads, or that it starts a new paragraph; the relation and connective that join it there; which open commitment it advances, if any; its expected `claim_type`; and its expected move, which SHALL be a value from `catalog/vocabulary.yaml` or the words `none fits` with a statement of what the proposition does. The skill SHALL NOT write to the manuscript, the ledger or the sidecars in next mode.

#### Scenario: Pending records shape the first candidate

- **WHEN** the state query lists the record at the last position as pending
- **THEN** the first candidate is a proposition that would be the head of that record

#### Scenario: An open announcement shapes the first candidate

- **WHEN** no record is pending and the state query lists an `announcement` as the first open commitment
- **THEN** the first candidate discharges that announcement

#### Scenario: Next mode leaves files untouched

- **WHEN** next mode finishes
- **THEN** the manuscript, `main.jsonl`, `structure.json` and `discourse.jsonl` are byte-identical to before

#### Scenario: Every candidate names a move

- **WHEN** next mode proposes three candidates
- **THEN** each of the three states an expected move

#### Scenario: No move in the vocabulary fits

- **WHEN** no value in `catalog/vocabulary.yaml` fits what a candidate does
- **THEN** the candidate states `none fits` and what the proposition does, and no near value is chosen

## ADDED Requirements

### Requirement: Next mode takes a move hint from the link catalog

Before proposing candidates, the skill SHALL read the move of the last proposition of the draft with `structure-links.py sentence`, and SHALL run `structure-links.py catalog` on that move with `--kind next` and `--format json` and with neither `--type` nor `--label`. The skill SHALL add the observed counts per next value, with `END` counted as a value, and SHALL report up to three values with the highest totals as the hint; a tie SHALL keep the order in which the values first appear in the listing. The skill SHALL state that the hint lists observed paths and is not a rule. The hint SHALL NOT change the order of the candidates, the rule for the first candidate, the attachment of any candidate or the relation of any candidate. A candidate's move SHALL NOT be required to appear in the hint, and the skill SHALL NOT warn when it does not. `END` SHALL NOT be stated as a candidate's move, and the hint SHALL NOT constrain the move of a candidate that starts a new paragraph.

#### Scenario: The hint counts moves, not rows

- **WHEN** the catalog lists `recap` in rows with counts 4, 2, 1 and 1, and `compare` in rows with counts 1 and 1
- **THEN** the hint gives `recap` with total 8 before `compare` with total 2

#### Scenario: Fewer than three values were observed

- **WHEN** the catalog lists two next values for the move
- **THEN** the hint gives those two values

#### Scenario: END leads the hint

- **WHEN** `END` is the first value of the hint
- **THEN** no candidate states `END` as its move, and a candidate that starts a new paragraph chooses its move from the vocabulary

#### Scenario: Pending records outrank the hint

- **WHEN** records are pending and the first value of the hint is not what would head them
- **THEN** the first candidate is still the head of every pending record

#### Scenario: A candidate outside the hint

- **WHEN** a candidate's move is not one of the three values of the hint
- **THEN** the candidate stands and no warning is given

#### Scenario: The hint does not choose the relation

- **WHEN** a catalog row pairs a next value with a relation
- **THEN** the relation of the candidate is decided as it is without the hint

#### Scenario: The state query does not read the catalog

- **WHEN** `structure-state.py` runs with and without `links.csv` present
- **THEN** its output is the same

### Requirement: Next mode completes without a hint

When the last proposition has no move, when the catalog holds no `next` path from that move, or when either query exits non-zero, the skill SHALL say so in one line, SHALL give no hint, and SHALL complete next mode with every candidate still stating an expected move. Both queries SHALL work on a draft that passes `validate-structure.py --partial`, including a draft with records whose head is `pending`.

#### Scenario: The last proposition has no move

- **WHEN** `structure-links.py sentence` reports no move for the last proposition
- **THEN** the skill says the hint is skipped and why, and still proposes candidates

#### Scenario: A query fails

- **WHEN** `structure-links.py catalog` exits 2 because `links.csv` is missing
- **THEN** the skill says the hint is skipped and why, and still proposes candidates

#### Scenario: A draft with a pending record

- **WHEN** `structure-links.py sentence` reads the last proposition of a draft whose last record has head `pending`
- **THEN** it exits 0 and reports that proposition's move

## REMOVED Requirements

### Requirement: Next mode does not consult the link catalog

**Reason**: The hit rates this requirement waited for were measured in #36, and the maintainer decided on 2026-11-06 that next mode uses the catalog in a narrowed form.

**Migration**: Replaced by the requirements "Next mode takes a move hint from the link catalog" and "Next mode completes without a hint".
