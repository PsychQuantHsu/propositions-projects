# article-construction Specification

## Purpose

Article construction is the `propositions:prop-construct` skill. It annotates an existing manuscript with its article structure, and for a draft in progress it reports what the article still owes the reader and proposes what the next proposition could do. It exists so that the ledger can support writing a whole article, not only checking finished sentences.

## Requirements

### Requirement: Annotation starts from a validated, fully covered ledger

In annotation mode the skill SHALL first run `validate-propositions.py` on the ledger and `check-extraction-coverage.py` on every range it will annotate. If the validator exits non-zero or any range has uncovered text, the skill SHALL stop, report the failures, and direct the user to `propositions:prop-extract`, without writing any sidecar.

#### Scenario: Uncovered text stops annotation

- **WHEN** the coverage check reports an uncovered run in the introduction
- **THEN** the skill stops before drafting sidecars and names `propositions:prop-extract` as the next step

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

---

<!-- @trace
source: retire-python-ports
updated: 2026-11-21
code:
  - plugins/propositions/scripts/audit-citations.py
  - plugins/propositions/skills/prop-construct/references/vocabulary.md
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
  - plugins/propositions/skills/prop-construct-batch/SKILL.md
  - tests/fixtures/retired-python/derive-paragraphs/an-input-of-the-main-file-that-leads-nowhere.json
  - tests/fixtures/retired-python/derive-paragraphs/a-structure-that-is-not-json.json
  - tests/fixtures/retired-python/reorder-ledger/a-line-that-is-not-json-dry-run.json
  - plugins/propositions/skills/prop-manuscript-audit/SKILL.md
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
  - plugins/propositions/skills/prop-construct/SKILL.md
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

---

<!-- @trace
source: add-next-mode-move-hint
updated: 2026-11-06
code:
  - propositions-projects.code-workspace
-->

### Requirement: Construction requests route to the construct skill

The skill's description SHALL claim requests about an article's overall structure, its commitments to the reader, the relation between consecutive propositions, how the sentences of a paragraph relate to each other, and what to write next, and SHALL direct requests to split text into propositions to `propositions:prop-extract`. The `propositions:prop-extract` and `propositions:prop-ledger` descriptions SHALL NOT claim construction requests.

#### Scenario: A next-sentence request

- **WHEN** a user asks what the next sentence of a draft section should do
- **THEN** the request matches `propositions:prop-construct` and not `propositions:prop-extract`

#### Scenario: A request about how sentences relate

- **WHEN** a user asks how the sentences of a paragraph relate to each other
- **THEN** the request matches `propositions:prop-construct`

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

---

<!-- @trace
source: add-next-mode-move-hint
updated: 2026-11-06
code:
  - propositions-projects.code-workspace
-->

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

---

<!-- @trace
source: add-next-mode-move-hint
updated: 2026-11-06
code:
  - propositions-projects.code-workspace
-->

### Requirement: Write mode writes one paragraph through the write commands, behind one confirmation

The construct skill SHALL have a write mode that adds one paragraph at the end of a draft, after the paragraph that holds the last live proposition in reading order. Next mode is unchanged and still writes nothing; a request that does not say a paragraph is to be written is next mode.

Write mode runs, in this order: the preconditions of next mode and a check that the pinned tool runs; an agreement with the author, in one question, on what the paragraph does; `propositions write prepare`; the paragraph written in the staged manuscript file, after the line `prepare` names; its propositions, by steps 1 and 5 to 7 of the extraction skill on the staged copy, added at the end of the staged ledger; one record per new proposition added at the end of the staged discourse sidecar, and the paragraph added to the staged structure sidecar; the gates on the copies (`propositions write check`, the ledger validator, the structure validator with `--partial`, `propositions cite-order`); the new paragraph, propositions, records, placeholders and the diff of each of the four files shown to the author, who is asked once; and `propositions write commit` only on that confirmation. A change to the copies after the question runs the gates and asks again.

The paragraph never invents a result, a number or a citation: each is written `{PENDING: <what is to be supplied>}`, and a citation key may be used only when it is in the manuscript's bibliography file. A claim that changes what the paper argues is the author's. When the launcher runs nothing, write mode stops and offers next mode. When `commit` reports files already written, the skill reports them and where the originals are kept and stops; putting the originals back is the author's decision. The report lists every placeholder with its line, and says that the paragraph was checked mechanically and not proofread.

No executable check: the mode is instructions that a model follows; the commands it runs are tested under the capability `write`. The mode was run once by hand on the structure fixture with binary 0.4.0, from `prepare` to `commit`, and the ledger validator and the structure validator passed on the written files.

#### Scenario: The next paragraph is written into a draft

- **WHEN** the author asks to write the next paragraph into the draft and confirms what is shown
- **THEN** the skill writes it through `propositions write commit` and reports what was written, where the originals are, and every placeholder left

---

<!-- @trace
source: idd-49-skill-mode
updated: 2026-11-21
code:
  - propositions-projects.code-workspace
  - .claude-plugin/marketplace.json
  - CLAUDE.md
  - plugins/propositions/.claude-plugin/plugin.json
  - plugins/propositions/skills/prop-construct/SKILL.md
  - plugins/propositions/hooks/cli.lock
-->

### Requirement: Write mode writes from an approved outline record, read back by a reader

The write mode of the construct skill SHALL, when the author asks to write from the outline, take its plan from one paragraph record of the outline: by default the first record in the paragraph file that does not carry `dropped`, whose section stands as approved (`propositions outline status`), and that `outline-trace.jsonl` does not name (`propositions outline trace`); another record only when the author names it. When there is none, the skill stops and says that the section has to be approved with the outline skill. The paragraph says the record's points in order and nothing the points do not say; a point with `pending` gets `{PENDING: <its pending text>}`; a record that carries `carry` is the block its `from` names, copied with only the changes its `edits` lists; the first record of a section whose heading is not in the draft comes with that heading line (`write prepare --heading`). `write prepare` runs with `--outline` and `--outline-paragraph`.

After the gates of write mode pass and before the author is asked, the skill SHALL write the paragraph record and the new paragraph to two files in the staging directory and dispatch the agent `propositions:outline-point-reader` (Read only) with those two paths and nothing else. The agent reports, as a closed list of two kinds, a point the paragraph does not say (or says in part, or contradicts) and a result, number or citation the points do not state. Its findings are shown to the author with the rest, as a reader's judgment; they are not entered in the obligations table. The skill does not write `outline-trace.jsonl`; `write commit` appends to it, and the skill runs `outline trace` after the commit.

No executable check: the mode is instructions that a model follows; the commands it runs are tested under the capabilities `write` and `article-outline`.

#### Scenario: A paragraph is written from the outline

- **WHEN** the author asks to write from an outline whose first untraced record is in an approved section, and confirms what is shown
- **THEN** the skill writes it through `write commit` with `--outline`, shows the reader's findings before asking, and `outline trace` lists the record afterwards

---

<!-- @trace
source: idd-51-skill-mode
updated: 2026-11-21
code:
  - plugins/propositions/hooks/cli.lock
  - propositions-projects.code-workspace
  - .claude-plugin/marketplace.json
  - plugins/propositions/agents/outline-point-reader.md
  - plugins/propositions/.claude-plugin/plugin.json
  - plugins/propositions/skills/prop-construct/SKILL.md
  - CLAUDE.md
-->

### Requirement: Reorganize mode rewrites a finished manuscript from its revised outline

The construct skill SHALL have a reorganize mode that rewrites a finished manuscript from an outline revised and approved as a whole with the outline skill, through `propositions write prepare --rewrite`, behind one confirmation. It stops unless `propositions outline status` shows every section and the order of sections standing as approved. In the staged copies it writes the sections in the outline's order, each paragraph from one record: a record that carries `carry` is its `from` block copied with only its `edits`; any other says its points, keeping as written each sentence of its `from` passages that still says a point; `pending` points get placeholders; what is not a paragraph (preamble, title, bibliography) stays. It brings the staged ledger up with the extraction skill's revision mode, retiring a proposition that is not found again with the new propositions of the record whose `from` names its passage as replacements (none when no record names it); rebuilds the two structure sidecars by annotate mode; writes `outline-map.jsonl`; runs `write check`, the ledger validator, the structure validator, `revise check` and `cite-order` on the copies; dispatches `propositions:outline-point-reader` for each paragraph written from a record that does not carry `carry`; shows the author the diff of every changed file, the counts of propositions found again, retired and added, the placeholders and the readers' findings; asks once; and runs `write commit` on confirmation, reporting where the originals are (`backup/restore.jsonl`) and running `outline trace` after it. A change to the copies after the question runs the gates and the readers again and asks again.

No executable check: the mode is instructions that a model follows; the commands it runs are tested under the capabilities `write`, `revise` and `article-outline`. The core of the mode (prepare with `--rewrite`, `revise relocate --write` and `ledger-order --tex` on the staged copies, rebuilt sidecars, the map, the gates and the commit) was run by hand on the structure fixture with binary 0.6.0.

#### Scenario: A finished draft is reorganized

- **WHEN** the author asks to reorganize a finished draft whose revised outline stands as approved as a whole, and confirms what is shown
- **THEN** the skill writes the rewritten manuscript, the ledger and the sidecars through `write commit`, and `outline trace` lists one record per paragraph record

---

<!-- @trace
source: idd-115-skill-mode
updated: 2026-11-21
code:
  - .claude-plugin/marketplace.json
  - propositions-projects.code-workspace
  - plugins/propositions/hooks/cli.lock
  - plugins/propositions/skills/prop-construct/SKILL.md
  - CLAUDE.md
  - plugins/propositions/.claude-plugin/plugin.json
-->

### Requirement: Write mode and reorganize mode follow the article file, the plan of commitments and the destinations

In write mode, the construct skill SHALL read the `banned` list of the staged `article.json`, when `write prepare` copied one, before it writes the paragraph, and not write those phrasings; when `write check` reports one, it rewords the paragraph and does not change `article.json`.

When it writes from an outline record, the skill SHALL: make the paragraph open and discharge exactly what the record's `opens` and `discharges` plan, with those ids and kinds in the records it adds, and nothing when another record of the outline plans commitments and this one does not; tell the author, before writing, each `[unread]` line that `write prepare` printed; when `write prepare` says the section goes to a part and names the files of another document, run it again with those files and the sidecars beside that ledger, and stop when `article.json` names no destination for the part; and, after the commit, when the outline or `article.json` carries a `length`, run `propositions outline length` (with `--written` when there are destinations) and report the section's line, the parts and the limit.

In reorganize mode the skill SHALL, with destinations, rewrite one document in a run: only the sections that go to it, with `outline-map.jsonl` listing only their records; and, when the revised outline moves content from one document to another, rewrite in two runs: first the document that receives it, then the document that gives it up, whose retirements name the new propositions as `{"ledger", "id"}` replacements and whose `revise` commands on the staged ledger get `--ledger-dir` with the directory of the original ledger (the capabilities `write` and `revise`).

No executable check: the modes are instructions that a model follows; the commands they run are tested under the capabilities `write` and `article-outline`.

#### Scenario: A paragraph of the supplement is written into the supplement

- **WHEN** the next record's section has `part` `supplement`, `article.json` names a destination for it, and the author asks to write from the outline
- **THEN** the skill prepares with the supplement's main file, ledger and sidecars, and the trace record carries `"part": "supplement"`

---

<!-- @trace
source: idd-120-skills
updated: 2026-11-22
code:
  - propositions-projects.code-workspace
-->

<!-- @trace
source: idd-133-fix2
updated: 2026-11-23
code:
  - Sources/PropositionsKit/ReviseLedger.swift
  - plugins/propositions/skills/prop-construct/SKILL.md
  - plugins/propositions/skills/prop-extract/SKILL.md
  - Sources/PropositionsKit/Version.swift
  - Sources/PropositionsKit/ReviseOtherLedger.swift
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/CLI.swift
  - tests/PropositionsKitTests/ReviseOtherLedgerTests.swift
  - Sources/PropositionsKit/ReviseRun.swift
  - CLAUDE.md
-->

### Requirement: Write mode puts each example, definition and result after its question

In write mode (including when it writes from an outline record) and in reorganize mode, the skill SHALL, for each example, definition or result it writes, do one of two things: place it after text that raises the question it answers, earlier in the paragraph or anywhere before it (the obligation group `motivation`, axiom `academic-writing/A2_motivated_by_prefix`); or, when nothing before it raises that question, write the sentence that raises it first or tell the author that nothing does. A sentence written to raise a question SHALL only restate what the agreed paragraph already argues; one that would state a choice, a gap or a claim the author has not made is a placeholder. When writing from an outline record, whose points fix the order, the skill SHALL tell the author instead of reordering the points. What it tells the author, and each sentence it wrote to raise such a question, is shown with the paragraph (in reorganize mode, with the rewrite), before the author confirms the write.

No executable check: whether a sentence raises the question an example answers is a judgment of meaning. The check for the obligation is issue 141.

#### Scenario: A paragraph planned to open on an example

- **WHEN** the paragraph agreed with the author would open on a worked example whose question no earlier text raises
- **THEN** the skill writes the sentence that raises the question first, or tells the author that nothing before the example raises it

<!-- @trace
source: idd-139-motivation-group
updated: 2026-11-23
code:
  - CLAUDE.md
  - propositions-projects.code-workspace
  - plugins/propositions/docs/OBLIGATIONS.md
  - plugins/propositions/skills/prop-construct/SKILL.md
  - plugins/propositions/catalog/obligations.yaml
  - plugins/propositions/README.md
  - plugins/propositions/skills/prop-outline/SKILL.md
tests:
  - tests/test_plugin_payload_tracked.py
-->

<!-- @trace
source: idd-139-fix1
updated: 2026-11-23
code:
  - plugins/propositions/docs/OBLIGATIONS.md
  - plugins/propositions/catalog/obligations.yaml
  - plugins/propositions/skills/prop-construct/SKILL.md
  - plugins/propositions/skills/prop-outline/SKILL.md
  - propositions-projects.code-workspace
tests:
  - tests/test_plugin_payload_tracked.py
-->

<!-- @trace
source: idd-139-fix2
updated: 2026-11-23
code:
  - plugins/propositions/docs/OBLIGATIONS.md
  - plugins/propositions/catalog/obligations.yaml
  - plugins/propositions/skills/prop-outline/SKILL.md
  - propositions-projects.code-workspace
  - plugins/propositions/skills/prop-construct/SKILL.md
tests:
  - tests/test_plugin_payload_tracked.py
-->

<!-- @trace
source: idd-139-fix3
updated: 2026-11-23
code:
  - plugins/propositions/skills/prop-construct/SKILL.md
  - plugins/propositions/docs/OBLIGATIONS.md
  - propositions-projects.code-workspace
  - plugins/propositions/catalog/obligations.yaml
tests:
  - tests/test_plugin_payload_tracked.py
-->
