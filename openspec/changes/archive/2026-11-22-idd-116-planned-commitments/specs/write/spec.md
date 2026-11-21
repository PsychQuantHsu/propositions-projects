## ADDED Requirements

### Requirement: A paragraph written from an outline opens and discharges what its record plans

When the outline plans commitments (a record that is not dropped carries `opens` or `discharges`), `propositions write check` SHALL compare each written paragraph with its record and report every difference as a problem (exit 1), so that `write commit` writes nothing: a commitment the record plans to open that the paragraph does not open; a commitment the paragraph opens that the record does not plan; a commitment opened with a kind other than the planned one; a commitment the record plans to discharge that the paragraph does not discharge; and one the paragraph discharges that the record does not plan. Commitments are compared by id.

What a paragraph opens and discharges is read from the staged discourse sidecar: for one paragraph, the records added to it for the propositions added to the ledger; for a rewrite, the records of the live propositions from the one `outline-map.jsonl` names for the record up to the one it names next in reading order. The record is read from the copy of the outline that prepare made.

An outline that plans no commitment is not compared.

#### Scenario: A paragraph that opens something else is not written

- **WHEN** the record plans to open one commitment and the staged paragraph opens another
- **THEN** `check` reports both differences and exits with 1, and `commit` writes nothing

##### Example: a paragraph is compared with the commitments its record plans

- **GIVEN** the structure fixture and an approved outline whose record `p-1` carries `"opens": [{"id": "c-fw-scale", "kind": "future_work"}]`
- **WHEN** after `write prepare --outline … --outline-paragraph p-1`, the paragraph is drafted with a discourse record that carries `"opens": [{"id": "c-fw-scale", "kind": "future_work"}]`, and `write check` runs; and again with a discourse record that carries `"opens": [{"id": "c-fw-scale", "kind": "plan"}, {"id": "c-other", "kind": "aim"}], "discharges": ["c-fw-interval"]`
- **THEN** the first check exits with 0; the second exits with 1 and reports that `c-fw-scale` is planned as `future_work` and opened as `plan`, that the paragraph opens `c-other` and discharges `c-fw-interval`, neither of which `p-1` plans; `commit` then exits with 2

##### Example: a record with no planned commitment, in an outline that plans some

- **GIVEN** the same outline, where `p-1` carries no key and another record carries `opens`
- **WHEN** the paragraph for `p-1` is drafted with a discourse record that opens `c-other`, and `write check` runs
- **THEN** it exits with 1 and reports that the paragraph opens `c-other`, which `p-1` does not plan

##### Example: an outline that plans no commitment is not compared

- **GIVEN** the same outline with no `opens` and no `discharges` on any record
- **WHEN** the paragraph for `p-1` is drafted with a discourse record that opens `c-other`, and `write check` runs
- **THEN** it exits with 0

##### Example: a rewrite is compared paragraph by paragraph

- **GIVEN** the rewrite of the example "a manuscript is rewritten from an outline approved as a whole", where the outline's `p-1` plans every commitment the fixture's discourse sidecar opens and discharges before the last paragraph, and `p-2` plans `"opens": [{"id": "c-fw-interval", "kind": "future_work"}]`
- **WHEN** the staged discourse sidecar gives the new proposition the record `{"prop_id": …, "opens": [{"id": "c-fw-interval", "kind": "future_work"}]}` and `write check` runs; and again without that record
- **THEN** the first exits with 0; the second exits with 1 and reports that `p-2` plans to open `c-fw-interval` and its paragraph does not
