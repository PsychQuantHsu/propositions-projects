# article-construction Specification

## Purpose

Article construction is the `propositions:construct` skill. It annotates an existing manuscript with its article structure, and for a draft in progress it reports what the article still owes the reader and proposes what the next proposition could do. It exists so that the ledger can support writing a whole article, not only checking finished sentences.

## Requirements

### Requirement: Annotation starts from a validated, fully covered ledger

In annotation mode the skill SHALL first run `validate-propositions.py` on the ledger and `check-extraction-coverage.py` on every range it will annotate. If the validator exits non-zero or any range has uncovered text, the skill SHALL stop, report the failures, and direct the user to `propositions:extract`, without writing any sidecar.

#### Scenario: Uncovered text stops annotation

- **WHEN** the coverage check reports an uncovered run in the introduction
- **THEN** the skill stops before drafting sidecars and names `propositions:extract` as the next step

---
### Requirement: Annotation writes sidecars only after validation and confirmation

The skill SHALL start the paragraph plan from the output of `derive-paragraphs.py`, then draft `structure.json` and `discourse.jsonl` in a staging location outside the ledger directory: a head and relation for every record that is not a paragraph root, a head and relation for every paragraph that is not its section's root paragraph, and a `parent` for every section that sits under another section. It SHALL run `validate-structure.py` on the staged files until it exits 0, then show the user a summary containing the count of each relation, the number of records whose head comes before them and after them, the number of paragraphs, every commitment with the positions that open and discharge it, the section list with roles and parents, every S7 and S8 warning, and the median length of the sentence part of the right frontier reported by `structure-metrics.py`. The skill SHALL write the sidecars into the ledger directory only after the user confirms, and SHALL NOT modify `main.jsonl` at any point.

#### Scenario: The user declines

- **WHEN** the user does not confirm the summary
- **THEN** no file in the ledger directory changes and the staged files remain where the summary said they are

#### Scenario: Validation errors are fixed before the summary

- **WHEN** the staged files fail S2 because a paragraph has two roots
- **THEN** the skill corrects the staged files and reruns the validator before showing any summary

#### Scenario: Warnings are shown, not hidden

- **WHEN** the staged files pass validation with two S7 warnings
- **THEN** the summary lists both crossing pairs

---
### Requirement: Next mode proposes at most three candidates without writing

In next mode the skill SHALL run `validate-structure.py --partial` and `structure-state.py --at end`, report the current section's role, the current paragraph, the right frontier, the pending records and the open commitments in the order the state query gives, and propose at most three candidate next propositions. When pending records exist, the first candidate SHALL be a proposition that serves as the head of every pending record. Each candidate SHALL state the frontier node it attaches to, or the pending records it heads, or that it starts a new paragraph; the relation and connective that join it there; which open commitment it advances, if any; and its expected `claim_type`. The skill SHALL NOT write to the manuscript, the ledger or the sidecars in next mode.

#### Scenario: Pending records shape the first candidate

- **WHEN** the state query lists the record at the last position as pending
- **THEN** the first candidate is a proposition that would be the head of that record

#### Scenario: An open announcement shapes the first candidate

- **WHEN** no record is pending and the state query lists an `announcement` as the first open commitment
- **THEN** the first candidate discharges that announcement

#### Scenario: Next mode leaves files untouched

- **WHEN** next mode finishes
- **THEN** the manuscript, `main.jsonl`, `structure.json` and `discourse.jsonl` are byte-identical to before

---
### Requirement: Construction requests route to the construct skill

The skill's description SHALL claim requests about an article's overall structure, its commitments to the reader, the relation between consecutive propositions, and what to write next, and SHALL direct requests to split text into propositions to `propositions:extract`. The `propositions:extract` and `propositions:propositions` descriptions SHALL NOT claim construction requests.

#### Scenario: A next-sentence request

- **WHEN** a user asks what the next sentence of a draft section should do
- **THEN** the request matches `propositions:construct` and not `propositions:extract`
