## ADDED Requirements

### Requirement: The length report reads each part from its own ledger

`propositions outline length <directory> --written` SHALL look up the trace records of a part in the ledger and main file that part's destination names, also when two parts name the same main file with different ledgers.

#### Scenario: Two parts share a main file and not a ledger

- **WHEN** the appendix is in the main text's input tree and has a ledger of its own
- **THEN** a record of the appendix is found in the appendix's ledger

##### Example: two parts, one main file, two ledgers

- **GIVEN** the structure fixture, a second ledger that holds one proposition located on the fixture's last paragraph, an outline with section `s-a` and section `s-x` (`part` `appendix`), `destinations` that name the fixture's main file for both parts, with the fixture's ledger for `main` and the second ledger for `appendix`, and a trace with one record of `s-x`, `"part": "appendix"`, that names that proposition
- **WHEN** `propositions outline length <directory> --written` runs
- **THEN** the line of `s-x` holds `written 13	1 of 1 record(s)` and no line says a record was not found
