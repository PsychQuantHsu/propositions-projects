## ADDED Requirements

### Requirement: A revised manuscript is brought up through the revise commands

The extraction skill SHALL have a revision mode for a manuscript revised after its ledger was extracted. It runs, in this order: `propositions revise relocate`; a look at the missing propositions with the ledger validator, so that one the validator still matches after its normalisation is not retired; extraction of the text the coverage check reports as uncovered, by the steps of the skill; `propositions revise retire` with the replacements of each missing proposition, or none for a deletion; `propositions revise redirect`; `propositions ledger-order --tex`; the gates (the validator, the coverage check over the revised ranges, `propositions revise check`); and a second reading of the claim types of the new propositions by a reader who does not see them, whose differences the user decides. The commands run through the plugin's launcher, which runs only the pinned binary; when the launcher runs nothing, the skill stops and says that the mode needs the tool. Every step that writes the ledger is shown as a dry run first and written only after the user confirms it. An ambiguous proposition is placed by the user before any retirement.

The mode is done when the validator passes, the coverage check reports no uncovered text in the revised ranges, `revise check` reports no problem, and every retirement made in the mode has a `replaced_by`. The skill reports the counts of each step.

No executable check: the mode is instructions that a model follows; the commands it runs are tested under the capability `revise`.

#### Scenario: A revised manuscript is brought up

- **WHEN** the user asks to re-extract a revised manuscript
- **THEN** the skill runs the revision mode and ends with the four conditions of done, or says which one is not met
