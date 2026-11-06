## MODIFIED Requirements

### Requirement: Coverage is judged from the uncovered text

The skill SHALL run `check-extraction-coverage.py` on the lines between `\begin{document}` and `\end{document}`, on each file of a multi-file manuscript, and SHALL NOT use its exit code as the result. Only uncovered sentences of the body SHALL count as `ledger-incomplete`. LaTeX commands with no sentence, headings, front matter, author statements after the body, appendix instruments and bibliography SHALL NOT count. The skill SHALL list the location of every uncovered run it did not count, and SHALL pass those runs to `propositions:construct` or `propositions:construct-batch` when it invokes them.

#### Scenario: A complete ledger with uncovered commands

- **WHEN** the coverage check exits 1 and the only uncovered runs are a bare `\vspace{1em}` and back matter
- **THEN** the state is not `ledger-incomplete`, and the report lists those locations

#### Scenario: An unextracted section

- **WHEN** the coverage check reports the sentences of one section as uncovered
- **THEN** the state is `ledger-incomplete` and `propositions:extract` runs on that section


<!-- @trace
source: add-analyze-entry-skill
updated: 2026-11-06
code:
  - propositions-projects.code-workspace
-->
