## Purpose

Article analysis is the `propositions:analyze` skill, a single entry point for analyzing a whole LaTeX manuscript. It determines how far the manuscript has got, runs the next unfinished step through the existing skills, and reports the result, so that a user does not have to remember their order and preconditions.

## ADDED Requirements

### Requirement: Analysis determines its state from the files

The skill SHALL determine the manuscript's state from the ledger, the manuscript and the sidecars each time it runs, and SHALL keep no progress file. The states SHALL be exactly these seven, evaluated in this order, and the first that holds SHALL be the current state: `no-ledger` when `_meta.json` is missing from the ledger directory; `ledger-invalid` when `validate-propositions.py` exits non-zero; `ledger-incomplete` when the coverage check reports uncovered body text; `no-structure` when `structure.json` or `discourse.jsonl` is missing; `structure-invalid` when `validate-structure.py --partial` exits non-zero; `no-moves` when `structure-metrics.py` reports no `moves` field, or `proposition_share` or `paragraph_share` below 1; and `ready` otherwise. The skill SHALL state the current state and the action it will take before taking it.

#### Scenario: A manuscript with no ledger

- **WHEN** the ledger directory has no `_meta.json`
- **THEN** the state is `no-ledger`

#### Scenario: A freshly scaffolded ledger

- **WHEN** the ledger directory has `_meta.json` and an empty `main.jsonl`
- **THEN** the state is `ledger-incomplete`

#### Scenario: A failing ledger outranks missing sidecars

- **WHEN** `validate-propositions.py` exits non-zero and no sidecars exist
- **THEN** the state is `ledger-invalid`

#### Scenario: Sidecars without moves

- **WHEN** the ledger and sidecars pass and `structure-metrics.py` reports no `moves` field
- **THEN** the state is `no-moves`

#### Scenario: A run after an interruption resumes

- **WHEN** an earlier run stopped after the ledger was completed
- **THEN** the next run determines the state `no-structure` from the files and continues from there

### Requirement: Each state has one action

The skill SHALL act on the state as follows and in no other way: `no-ledger` invokes Operation D of `propositions:propositions`; `ledger-invalid` stops and points to `propositions:propositions`; `ledger-incomplete` invokes `propositions:extract` on one section at a time; `no-structure` invokes `propositions:construct-batch` when the ledger holds 100 or more propositions and `propositions:construct` otherwise; `structure-invalid` stops and points to `propositions:construct`; `no-moves` invokes the moves-only path of `propositions:construct-batch` at any length; `ready` produces the read-out and the report. After an invoked skill finishes, the skill SHALL determine the state again. The skill SHALL NOT restate the procedure of an invoked skill.

#### Scenario: A long manuscript without sidecars

- **WHEN** the state is `no-structure` and the ledger holds 300 propositions
- **THEN** the skill invokes `propositions:construct-batch`

#### Scenario: A short manuscript without sidecars

- **WHEN** the state is `no-structure` and the ledger holds 40 propositions
- **THEN** the skill invokes `propositions:construct`

#### Scenario: A short manuscript without moves

- **WHEN** the state is `no-moves` and the ledger holds 40 propositions
- **THEN** the skill invokes the moves-only path of `propositions:construct-batch`, which leaves the dependency tree alone

#### Scenario: An invalid ledger is not repaired

- **WHEN** the state is `ledger-invalid`
- **THEN** the skill reports the validator's failures and invokes no other skill

### Requirement: Coverage is judged from the uncovered text

The skill SHALL run `check-extraction-coverage.py` on the lines between `\begin{document}` and `\end{document}`, on each file of a multi-file manuscript, and SHALL NOT use its exit code as the result. Only uncovered sentences of the body SHALL count as `ledger-incomplete`. LaTeX commands with no sentence, headings, front matter, author statements after the body, appendix instruments and bibliography SHALL NOT count. The skill SHALL list the location of every uncovered run it did not count, and SHALL pass those runs to `propositions:construct` or `propositions:construct-batch` when it invokes them.

#### Scenario: A complete ledger with uncovered commands

- **WHEN** the coverage check exits 1 and the only uncovered runs are a bare `\footnote{` and back matter
- **THEN** the state is not `ledger-incomplete`, and the report lists those locations

#### Scenario: An unextracted section

- **WHEN** the coverage check reports the sentences of one section as uncovered
- **THEN** the state is `ledger-incomplete` and `propositions:extract` runs on that section

### Requirement: What the article owes is a finding

The skill SHALL run `validate-structure.py` without `--partial` once the state is `ready`, and SHALL report its failures as findings about the article. Those failures SHALL NOT stop the analysis and SHALL NOT change the state.

#### Scenario: An undischarged commitment

- **WHEN** the check without `--partial` fails because a commitment was never discharged
- **THEN** the report lists that commitment and the analysis still completes

### Requirement: The entry point writes nothing itself

The skill SHALL NOT write to the manuscript, the ledger or the sidecars, and SHALL NOT answer a confirmation on the user's behalf. Every write SHALL happen inside the invoked skill, under that skill's own dry-run and confirmation. The report SHALL list the files written during the run. When no write was confirmed, the fingerprints of the manuscript, `main.jsonl`, `structure.json` and `discourse.jsonl` SHALL match those taken at the start.

#### Scenario: A run that writes nothing

- **WHEN** the state is `ready` at the start
- **THEN** all four fingerprints are unchanged at the end

#### Scenario: A confirmation stays with the user

- **WHEN** an invoked skill asks to confirm a write to `main.jsonl`
- **THEN** the skill leaves the answer to the user

### Requirement: Analysis stops rather than works around

The skill SHALL stop and report the current state when the user declines a confirmation, when an invoked skill stops or fails, or when a tool exits with an error. The skill SHALL NOT retry, SHALL NOT work around the failure, and SHALL say that running it again resumes from the files.

#### Scenario: The user declines

- **WHEN** the user declines the write of `extract` for one section
- **THEN** the skill stops and reports the state and that running it again resumes

#### Scenario: A tool error

- **WHEN** `structure-metrics.py` exits 2
- **THEN** the skill stops and reports the error, and no state is assumed

### Requirement: Three steps run only on request

The default depth SHALL end at the `ready` read-out. `propositions:proofread`, `propositions:manuscript-audit` and `propositions:clarity-audit` SHALL run only when the user asks for them. `proofread` and `manuscript-audit` SHALL require a ledger that passes `validate-propositions.py`; `clarity-audit` SHALL run in any state. The report SHALL say what each step not run would answer.

#### Scenario: Default depth

- **WHEN** the user asks to analyze an article and names no optional step
- **THEN** none of the three steps runs and the report names them

#### Scenario: Readability only on a manuscript with no ledger

- **WHEN** the state is `no-ledger` and the user asks only for a readability pass
- **THEN** `propositions:clarity-audit` runs and no ledger is created

### Requirement: The analysis ends with a read-out and a report

In state `ready` the skill SHALL write the output of `structure-explain.py --all` to a staging file outside the ledger directory and SHALL show the section the user named, or the first section when none was named. The report SHALL contain exactly these items: the state reached and the steps run; the validator result; the uncovered runs not counted, by location; the sections with their roles and the paragraph count; the counts of moves and paragraph types; the findings from the check without `--partial`; the path of the read-out; the files written; the optional steps not run; and the next step.

#### Scenario: The report on a finished analysis

- **WHEN** the state is `ready`
- **THEN** the report contains every listed item and the read-out path exists outside the ledger directory

### Requirement: Whole-article requests route to the entry point

The skill's description SHALL claim requests to analyze or go through a whole article, and SHALL direct requests about one passage, the next sentence, one sentence's readability or validating a ledger to `propositions:extract`, `propositions:construct`, `propositions:clarity-audit` and `propositions:propositions`. The existing seven skills SHALL stay directly invocable, and apart from the scaffold list of Operation D their content SHALL NOT change.

#### Scenario: A whole-article request

- **WHEN** a user asks to analyze this paper
- **THEN** the request matches `propositions:analyze`

#### Scenario: A next-sentence request

- **WHEN** a user asks what to write next in a draft section
- **THEN** the request matches `propositions:construct` and not `propositions:analyze`
