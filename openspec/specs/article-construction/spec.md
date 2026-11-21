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


<!-- @trace
source: retire-python-ports
updated: 2026-11-21
code:
  - plugins/propositions/scripts/audit-citations.py
  - plugins/propositions/skills/construct/references/vocabulary.md
  - plugins/propositions/.claude-plugin/plugin.json
  - tests/fixtures/retired-python/reorder-ledger/text-outside-ascii-dry-run.json
  - tests/fixtures/retired-python/derive-paragraphs/a-location-past-the-end.json
  - tests/fixtures/retired-python/derive-paragraphs/no-proposition.json
  - tests/fixtures/retired-python/derive-paragraphs/ids-that-need-escaping.json
  - tests/fixtures/retired-python/reorder-ledger/another-file-write.json
  - tests/fixtures/retired-python/reorder-ledger/lines-that-follow-their-predecessor-write.json
  - tests/fixtures/retired-python/reorder-ledger/indented-lines-write.json
  - plugins/propositions/scripts/derive-paragraphs.py
  - tests/fixtures/retired-python/derive-paragraphs/a-row-with-white-space-outside-json-s-before-the-object.json
  - tests/fixtures/retired-python/derive-paragraphs/a-structure-sidecar-that-starts-with-a-byte-order-mark.json
  - tests/PropositionsKitTests/RetiredPython.swift
  - propositions-projects.code-workspace
  - tests/fixtures/retired-python/derive-paragraphs/no-location.json
  - docs/SCHEMA.md
  - tests/fixtures/retired-python/derive-paragraphs/a-section-start-splits-a-paragraph.json
  - tests/fixtures/retired-python/derive-paragraphs/a-location-from-the-root-of-the-file-system.json
  - tests/fixtures/retired-python/derive-paragraphs/retired-propositions-and-empty-lines-are-passed-over.json
  - tests/fixtures/retired-python/reorder-ledger/a-line-that-is-not-json-write.json
  - tests/fixtures/structure/README.md
  - tests/fixtures/retired-python/reorder-ledger/only-comments-dry-run.json
  - plugins/propositions/skills/construct-batch/SKILL.md
  - tests/fixtures/retired-python/derive-paragraphs/an-input-of-the-main-file-that-leads-nowhere.json
  - tests/fixtures/retired-python/derive-paragraphs/a-structure-that-is-not-json.json
  - tests/fixtures/retired-python/reorder-ledger/a-line-that-is-not-json-dry-run.json
  - plugins/propositions/skills/manuscript-audit/SKILL.md
  - tests/fixtures/retired-python/reorder-ledger/no-location-write.json
  - tests/fixtures/retired-python/derive-paragraphs/a-location-that-cannot-be-parsed.json
  - tests/fixtures/retired-python/reorder-ledger/a-key-written-twice-dry-run.json
  - plugins/propositions/scripts/reorder-ledger.py
  - .claude-plugin/marketplace.json
  - tests/fixtures/retired-python/derive-paragraphs/the-main-file-written-with-a-dot-before-it.json
  - plugins/propositions/rules/manuscript-consistency-audit.md
  - tests/fixtures/retired-python/reorder-ledger/indented-lines-dry-run.json
  - tests/fixtures/retired-python/reorder-ledger/a-comment-whose-slashes-carry-a-combining-mark-write.json
  - tests/fixtures/retired-python/reorder-ledger/lines-that-follow-their-predecessor-dry-run.json
  - tests/PropositionsKitTests/LedgerOrderTests.swift
  - plugins/propositions/docs/PLAYBOOK.md
  - tests/fixtures/retired-python/reorder-ledger/a-range-and-no-final-newline-write.json
  - tests/fixtures/retired-python/derive-paragraphs/a-location-in-another-file.json
  - tests/PropositionsKitTests/ParagraphsTests.swift
  - plugins/propositions/scripts/run-audit.sh
  - tests/fixtures/retired-python/derive-paragraphs/a-section-start-in-another-spelling-of-the-same-letters.json
  - tests/conftest.py
  - tests/fixtures/retired-python/reorder-ledger/two-lines-out-of-order-dry-run.json
  - tests/fixtures/retired-python/reorder-ledger/ties-and-moves-write.json
  - plugins/propositions/docs/OBLIGATIONS.md
  - tests/fixtures/retired-python/derive-paragraphs/a-location-on-a-blank-line.json
  - tests/fixtures/retired-python/reorder-ledger/white-space-that-python-strips-and-does-not-split-at-dry-run.json
  - tests/fixtures/retired-python/reorder-ledger/two-lines-out-of-order-write.json
  - plugins/propositions/skills/construct/SKILL.md
  - plugins/propositions/scripts/migrate-structure-v2.py
  - plugins/propositions/scripts/audit-symbols.py
  - tests/fixtures/retired-python/reorder-ledger/a-key-written-twice-write.json
  - tests/fixtures/retired-python/reorder-ledger/a-range-and-no-final-newline-dry-run.json
  - tests/fixtures/retired-python/reorder-ledger/an-empty-ledger-dry-run.json
  - plugins/propositions/README.md
  - tests/fixtures/retired-python/reorder-ledger/a-comment-whose-slashes-carry-a-combining-mark-dry-run.json
  - tests/fixtures/retired-python/reorder-ledger/a-location-that-cannot-be-parsed-write.json
  - tests/fixtures/retired-python/reorder-ledger/another-file-dry-run.json
  - tests/fixtures/retired-python/reorder-ledger/in-order--two-on-one-line-write.json
  - tests/fixtures/retired-python/reorder-ledger/an-empty-ledger-write.json
  - tests/fixtures/retired-python/reorder-ledger/white-space-that-python-strips-and-does-not-split-at-write.json
  - tests/fixtures/retired-python/derive-paragraphs/the-ledger-s-order-is-kept--not-the-reading-order.json
  - tests/fixtures/retired-python/derive-paragraphs/sections-that-is-an-object.json
  - tests/fixtures/retired-python/derive-paragraphs/a-structure-without-sections.json
  - plugins/propositions/docs/STRUCTURE.md
  - tests/fixtures/retired-python/derive-paragraphs/carriage-returns-in-the-manuscript.json
  - tests/fixtures/retired-python/reorder-ledger/a-location-that-cannot-be-parsed-dry-run.json
  - README.md
  - tests/fixtures/retired-python/derive-paragraphs/a-ledger-that-starts-with-a-byte-order-mark.json
  - tests/fixtures/retired-python/reorder-ledger/no-location-dry-run.json
  - tests/fixtures/retired-python/reorder-ledger/only-comments-write.json
  - tests/fixtures/retired-python/reorder-ledger/text-outside-ascii-write.json
  - tests/fixtures/retired-python/reorder-ledger/in-order--two-on-one-line-dry-run.json
  - CLAUDE.md
  - plugins/propositions/hooks/cli.lock
  - tests/fixtures/retired-python/derive-paragraphs/a-line-that-is-not-json.json
  - tests/fixtures/retired-python/reorder-ledger/ties-and-moves-dry-run.json
  - tests/fixtures/retired-python/derive-paragraphs/blank-lines-separate-paragraphs.json
  - tests/fixtures/retired-python/derive-paragraphs/a-row-that-is-white-space-outside-json-s-only.json
  - tests/fixtures/retired-python/derive-paragraphs/paragraphs-without-a-proposition-are-skipped.json
tests:
  - tests/test_plugin_payload_tracked.py
  - tests/test_structure_tools.py
  - tests/test_run_audit.sh
  - tests/test_audit_citations.py
  - tests/test_audit_symbols.py
  - tests/test_root_shims.py
  - tests/test_derive_paragraphs.py
-->

---
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


<!-- @trace
source: add-next-mode-move-hint
updated: 2026-11-06
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Construction requests route to the construct skill

The skill's description SHALL claim requests about an article's overall structure, its commitments to the reader, the relation between consecutive propositions, how the sentences of a paragraph relate to each other, and what to write next, and SHALL direct requests to split text into propositions to `propositions:extract`. The `propositions:extract` and `propositions:propositions` descriptions SHALL NOT claim construction requests.

#### Scenario: A next-sentence request

- **WHEN** a user asks what the next sentence of a draft section should do
- **THEN** the request matches `propositions:construct` and not `propositions:extract`

#### Scenario: A request about how sentences relate

- **WHEN** a user asks how the sentences of a paragraph relate to each other
- **THEN** the request matches `propositions:construct`

---
### Requirement: Explain mode reads out how sentences relate

When the user asks how the sentences of a paragraph or section relate, the skill SHALL run `structure-explain.py` on that paragraph or section and show its output, then say in plain language what the paragraph does and which sentence the others hang on. When the user asks about one sentence's connections, the skill SHALL run `structure-links.py sentence` on it. The skill SHALL NOT write any file in explain mode. When the requested text has no sidecars, the skill SHALL say so and offer annotation mode.

#### Scenario: Explain mode leaves files untouched

- **WHEN** explain mode finishes
- **THEN** the manuscript, `main.jsonl`, `structure.json` and `discourse.jsonl` are byte-identical to before

#### Scenario: No sidecars

- **WHEN** the user asks about a paragraph of a manuscript whose ledger directory has no `discourse.jsonl`
- **THEN** the skill says the sidecars are missing and offers annotation mode without writing anything

---
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


<!-- @trace
source: add-next-mode-move-hint
updated: 2026-11-06
code:
  - propositions-projects.code-workspace
-->

---
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

<!-- @trace
source: add-next-mode-move-hint
updated: 2026-11-06
code:
  - propositions-projects.code-workspace
-->