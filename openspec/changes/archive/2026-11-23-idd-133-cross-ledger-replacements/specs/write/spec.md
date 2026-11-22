## ADDED Requirements

### Requirement: A rewrite may retire a passage moved to another document

When a passage moves from one document to another, the rewrites SHALL be run in two steps, each still writing one document: the document that receives the passage first, so that its ledger holds the new propositions, and then the document that gives it up, whose retirements name them as `{"ledger", "id"}` replacements (the capability `revise`). `write check` on a rewrite SHALL report, as a problem, each such replacement of a proposition the rewrite retires whose ledger, read from the directory of the original ledger (not of its staged copy), cannot be read, does not hold its id as exactly one live line, or is this ledger. Retirements already in the original ledger are not judged again.

#### Scenario: The second rewrite names the propositions the first one wrote

- **WHEN** a rewrite retires a proposition with a replacement in another ledger
- **THEN** `check` looks the replacement up in that ledger

##### Example: a rewrite retires a passage moved to another document

- **GIVEN** the rewrite fixture, and `paper/supp/supp.jsonl` holding the live proposition `s1`
- **WHEN** the retired proposition of the staged ledger names `{"ledger": "../supp/supp.jsonl", "id": "s1"}` instead of the new proposition, and `write check` runs; and then it names `s9` instead
- **THEN** the first `check` exits with 0; the second reports that it `is replaced by ../supp/supp.jsonl#s9, which is no proposition of that ledger` and exits with 1
