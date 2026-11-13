## MODIFIED Requirements

### Requirement: Applicability is a list of field values

`applies` is optional. When present it SHALL be a mapping whose keys come from this closed set: `profile`, `claim_type`, `evidence_class`, `cites`, `opens`, `section_role`. Each value SHALL be a non-empty list. A proposition satisfies `applies` when, for every key present, its own value is in the list:

- `profile`: the profile of its ledger;
- `claim_type`, `evidence_class`: its fields in the ledger;
- `cites`: `present` when its `cites` list is not empty, otherwise `absent`; an id in the list that names no proposition still makes it `present`;
- `opens`: it opens at least one commitment of a listed kind;
- `section_role`: the role of the section that contains it.

When the value a key needs cannot be read for a unit, the entry SHALL be `unverified` for that unit and not `not_applicable`, unless another key whose value can be read already rules the unit out. A value is read from the ledger and the sidecars themselves: no run of a validator is needed to read it, and a run that was not given a file, or that stopped before it reported anything, changes nothing about what can be read. A value can be read only under the conditions below; in every other case it cannot be read, and a condition that cannot be established counts as not holding. In these conditions a proposition is live when its ledger entry carries no `retired` key, which is the structure validator's test and is narrower than the test for a unit; and the ledger's ids are usable when each line of the ledger is a JSON object, apart from a line that is empty or starts with `//` once the white space around it is removed; every proposition in the ledger, retired or not, has an `id` that is a non-empty string, where a line that holds the `id` key twice is read with the last value, as the validators read it; and no two live propositions share an id. Two propositions that share an id leave the ids usable when at most one of them is live.

- `profile`: the ledger has no `_meta.json`, or its `_meta.json` is a JSON object without a `profile` key, and the profile is then `default`; or its `_meta.json` is a JSON object with a `profile` that the ledger validator accepts, and the profile is then the one declared. The validator rejects a `profile` key that holds `null`, a name that is not one of its profiles, and a profile declared under a schema version that does not allow one; in all three the profile cannot be read.
- `claim_type`, `evidence_class`: the field holds a value of its vocabulary for the ledger's profile; when the profile cannot be read, a value of the vocabulary of either profile can be read. A field that is left out, one that holds `null` and a misspelled value cannot be read. `SCHEMA.md` requires `claim_type` and leaves `evidence_class` optional, and no validator reports a proposition that leaves either out; issue 70 settles what a field that is left out means, and until then such a field cannot be read.
- `cites`: the field is absent, which reads as `absent`, or it holds a list.
- `opens`: all of these hold: the ledger's ids are usable; the proposition is live; the discourse sidecar exists and each of its lines that is not blank is a JSON object; exactly one of its records names the proposition; and that record has no `opens` key, or its `opens` is a list in which every item is an object whose `id` and `kind` the structure validator both accepts. The value is the kinds in that list: a record without `opens`, or with an empty list, opens nothing, and that is a value. Whether the commitments are otherwise in order, for instance an id opened twice or a commitment opened inside the abstract, is asked by other entries and does not change what is read.
- `section_role`: all of these hold: the ledger's ids are usable; the proposition is live; `structure.json` can be parsed as a JSON object and carries the structure version that the structure validator reads; and its section list is usable. The section of a proposition follows from the list and the ledger's order, so a discourse record is not needed to read `section_role`.

The section list is unusable exactly when one of these eleven holds, which are the errors that the structure validator reports under S5 about the list itself: `sections` is not a non-empty list; an item is not an object; an item's `id` is not a non-empty string; two items share an id; an item's `heading` is not a string, or is empty or holds only white space; an item's `role` is not a value of the vocabulary; an item's `first_prop` is not the id of a live proposition; an item with the role `abstract` is not the first item; an item's `first_prop` does not come after the `first_prop` of the item before it in the ledger's order; the ledger has no live proposition; the first item's `first_prop` is not the first live proposition. Nothing else that the structure validator reports under S5 makes the section list unusable: an error about the thesis, about a section's `parent`, about a commitment opened inside the abstract or about the paragraph plan.

An entry without `applies` applies to every unit. An entry with `unit: article` SHALL use no key other than `profile`, and for the article `profile` is the profile of the manuscript's ledger. The file SHALL have no other way to state applicability: no negation and no alternative between keys. Every listed value SHALL belong to the vocabulary of its field: the accepted profiles and the claim types and evidence classes of every profile in the ledger validator, and the commitment kinds and section roles in the structure validator. The relation of a record SHALL NOT be a key: the root of a paragraph has none, and no entry's requirement differs by the relation of the other records except that a `basis` edge needs a citation, which one entry asks of every proposition. The move and the paragraph type SHALL NOT be keys: the sidecars leave them optional, so an unannotated proposition would be treated as not applicable. `opens` is optional too and is a key, which is why the table holds the precondition `index.structure-faithful`.

Every entry whose `check` is one of `proofread:E1` to `proofread:E7`, and each of the three entries whose `owner` is 57, SHALL have `applies` with exactly two keys: `profile: [empirical]` and `evidence_class: [measured, tested, descriptive, not_computable]`. Those four classes mark a claim made about data. The proofread skill says that its layers E1 to E8 do not apply to an `external` proposition, which has no artifact to re-run, and the table gives the entries for E9 and E10 the same limit. `not_computable` is one of the four because it marks a quantity the data cannot produce, which the entry for E2 is there to fail. Without the `profile` key, a proposition of a ledger with the default profile that leaves `evidence_class` out would be `unverified` under those entries and not `not_applicable`; without the evidence classes, every proposition of an empirical ledger that has no artifact would stay `unverified`. A proposition of an empirical ledger that carries any other evidence class is outside these entries, also when its text interprets data. That a proposition which reports a number or a result from the manuscript's own data carries one of the four is asked by a precondition of its own, which is a gap; it asks nothing of a sentence that reports no number and no result from the manuscript's own data, that is, one that only reports another work's result, which is `external`, or one that only interprets a result; a sentence that reports both a result of its own and another work's is asked. To report a result is to present it as coming from the manuscript's data, whether or not the data can produce it; the manuscript's own data includes the output of its own models and simulations; and a number computed from the manuscript's own numbers is a number from its data. The layer L5 states a test for `derived` and for `verified` and none for the four (issue 57). Some criteria concern only propositions with a feature that no key selects, such as an assignment to a theorem-like block, a `basis` edge, a cited figure or a cited work; such an entry is not narrowed to those propositions: it applies to every proposition that its `applies` admits, and to every proposition when it has none. How a check reports a unit of which the criterion asks nothing belongs to issue 68.

#### Scenario: An entry applies only where every key matches

- **WHEN** an entry has `applies` with `profile: [empirical]` and `claim_type: [result]`
- **THEN** it applies to a `result` proposition in an empirical ledger and to no proposition in a ledger with the default profile

#### Scenario: A proposition without the field is not exempt

- **WHEN** an entry has `applies` with `evidence_class: [external]` and a proposition's ledger entry has no `evidence_class`
- **THEN** the entry is `unverified` for that proposition

#### Scenario: A misspelled value is not a reason to exempt a proposition

- **WHEN** an entry has `applies` with `profile: [empirical]` and `evidence_class: [measured, tested, descriptive, not_computable]`, and a proposition of an empirical ledger holds `evidence_class: Measured`
- **THEN** the value cannot be read, and the entry is `unverified` for that proposition

#### Scenario: A proposition with two records is not read from either

- **WHEN** an entry has `applies` with `opens: [hypothesis]` and the discourse sidecar holds two records for a proposition
- **THEN** the entry is `unverified` for that proposition

#### Scenario: An error outside the section list leaves the role readable

- **WHEN** one section's `parent` names a later section and the structure validator reports no other error under S5
- **THEN** the section list is usable, and an entry that applies by `section_role` is decided from the role of each proposition's section

#### Scenario: A value outside the vocabulary is refused

- **WHEN** an entry lists `claim_type: [lemma]`
- **THEN** the guard fails and its message names the entry id and `lemma`

#### Scenario: An empirical layer without the profile limit is refused

- **WHEN** an entry with `check: proofread:E3` has no `applies`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An empirical layer that reaches a proposition without data is refused

- **WHEN** an entry with `check: proofread:E3` has `applies` with `profile: [empirical]` and no `evidence_class`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An optional sidecar field is refused as a key

- **WHEN** an entry's `applies` has the key `move`
- **THEN** the guard fails and its message names the entry id and `move`

##### Example: a claim type that no profile accepts

- **GIVEN** a table in which the entry `index.text-in-manuscript` has `applies` with `claim_type: [lemma]`
- **WHEN** the format check runs
- **THEN** it reports a problem that names `index.text-in-manuscript` and `lemma`

### Requirement: A guard checks the table

The repository SHALL have automated tests that fail when the data file or the document breaks one of the following: the closed keys, the two classes and their prefixes, the groups, applicability, the inventory and owners, the accounting of checks and vocabulary values, `verified_by` and `on_warning`, the entries that need an outside source, the entries the maintainer reviewed, the limit on entry ids in the document, the four outcomes, the issue numbers, the key `external_source` and the two statements that the document has to carry (why the layers E8 to E10 are gaps, and what the `owner` of a gap is), and what `docs/VERIFICATION.md` has to say. What else the requirements above ask of the document is not checked by the guard. A key that is present SHALL hold what the key requires: the guard SHALL refuse `applies` or `axiom` written with no value. When the file is not a mapping, or a value has a type its key does not allow, the guard SHALL report a problem that says so and SHALL NOT end in an unhandled error. The guard SHALL refuse a data file in which one mapping holds the same key twice, because a YAML loader keeps the last value and drops the first without a message. Each failure message SHALL name the entry, value or check concerned. The tests are cases in `tests/test_plugin_payload_tracked.py` whose names start with `test_obligations_`; a change to this capability SHALL add no test file and no script module. A change is accepted only when these cases pass; a skipped case does not count.

In the document the guard SHALL look for an entry id, an outcome, an issue number and the statement on the layers E8 to E10 as whole terms, not as parts of longer ones: `#210` does not name issue 21, `E1-E8` does not say why the layer E8 is a gap, `E100` is not the layer E10, and the word `owner` alone does not say what the `owner` of a gap is. One test SHALL sweep the cases of the guard's two lists of refusals, the format refusals and the values of the wrong type: for each case the unchanged table gives no message that holds all of the case's needles, and the changed table gives exactly one. The sweep covers these two lists only. Of the guard's other refusals some have a case of their own and some have none; that gap is recorded on issue 46.

The guard is written in Python while the vocabularies it reads are defined in the Python validators. The project rule on the implementation language records this as an exception that ends when the Swift package of issue 46 exists and the vocabularies have a Swift source; the guard then moves to that package's test target.

#### Scenario: The guard runs with the suite

- **WHEN** the repository's test suite runs
- **THEN** the cases whose names start with `test_obligations_` run and pass on the committed data file and document

#### Scenario: The guard reads the vocabularies from their source

- **WHEN** the structure validator gains a section role
- **THEN** the guard fails until an entry names the new role or `unconstrained` lists it, without the guard itself being edited

##### Example: a table that is not a mapping

- **GIVEN** a data file that parses to nothing, to a list, or to a mapping whose `entries` is a string
- **WHEN** the guard's checks run on it
- **THEN** each returns its problems, and one of them says what is not a mapping or not a list

##### Example: a value of the wrong type

- **GIVEN** a table in which the first entry has a list as its `id`
- **WHEN** the format check runs
- **THEN** it reports a problem that names `entry 1` and says that `id` is not of the required form, and the same check reports no such problem for the unchanged table

##### Example: an issue number inside a longer one

- **GIVEN** a document that mentions `#210` and never `#21`
- **WHEN** the document check runs
- **THEN** it reports that the document does not name issue `#21`

##### Example: an entry with the same key twice

- **GIVEN** the text of a data file in which one entry has two `check:` lines
- **WHEN** the guard loads it
- **THEN** loading fails and the message names `check`

##### Example: a section role added to the structure validator

- **GIVEN** the vocabulary of `section_role` with one more value, `afterword`, that no entry names and `unconstrained` does not list
- **WHEN** the accounting check runs
- **THEN** it reports a problem that names `section_role` and `afterword`
