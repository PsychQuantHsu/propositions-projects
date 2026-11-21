## ADDED Requirements

### Requirement: A paragraph record can plan the commitments its paragraph opens and discharges

A paragraph record MAY carry `opens`, a list of one or more objects, each with an `id` and a `kind`, and `discharges`, a list of one or more commitment ids. A commitment id SHALL be written as the structure sidecars write it (a lower-case letter or digit, then up to 63 lower-case letters, digits or hyphens), and a `kind` SHALL be one of `question`, `aim`, `hypothesis`, `plan`, `announcement`, `setup`, `future_work`. Both keys are part of the record: a change to either means its section no longer stands as approved.

`propositions outline check` SHALL report: `opens` or `discharges` that is not such a list; a commitment opened more than once, by one record or by two records that are not dropped; a commitment one record discharges twice; a `discharges` entry that no record that is not dropped opens on the same line or an earlier one; a record that carries `dropped` and either key; and a record whose section has the role `abstract` and that carries `opens`.

An outline plans commitments when a record that is not dropped carries either key. A record of such an outline that carries neither plans that its paragraph opens and discharges none.

#### Scenario: A discharge has to follow its opening

- **WHEN** a record discharges a commitment that a later record opens, or that only a dropped record opens
- **THEN** `outline check` reports the record and the commitment

##### Example: planned commitments pass the check

- **GIVEN** an outline whose record `p-1` carries `"opens": [{"id": "c-q-spacing", "kind": "question"}]` and whose later record `p-3` carries `"discharges": ["c-q-spacing"]`
- **WHEN** `propositions outline check` runs
- **THEN** it reports nothing; and a record that both opens and discharges `c-q-spacing` passes too

##### Example: what the check reports about commitments

- **GIVEN** records that carry, one at a time: `"opens": []`; `"opens": [{"id": "c-x", "kind": "promise"}]`; `"opens": [{"id": "C x", "kind": "aim"}]`; `"discharges": ["c-none"]`; `"discharges": ["c-q", "c-q"]` after a record that opens `c-q`; `opens` of `c-q` on two records; `"dropped": "cut"` with `"discharges": ["c-q"]`; `opens` on a record of a section whose role is `abstract`; a discharge on `p-1` of a commitment that `p-2` opens
- **WHEN** `propositions outline check` runs on each
- **THEN** each is reported: the list or entry that is not in the format, the commitment opened more than once, the commitment discharged twice, the discharge that nothing earlier opens, the dropped record, and the record of the abstract
