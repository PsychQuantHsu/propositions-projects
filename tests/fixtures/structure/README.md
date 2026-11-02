# Article-structure fixture (synthetic, format 2.0)

A valid 12-proposition ledger with both structure sidecars in format 2.0 (Spectra change
`add-discourse-dependency-tree`), for the `validate-structure.py` (S1–S8), `structure-state.py`,
`derive-paragraphs.py` and `structure-metrics.py` tests. The article in `main.tex` is invented
(spaced vs massed review and one-week recall) and contains no text from any real manuscript.
`_meta.json` declares schema 1.7, profile `empirical`; `validate-propositions.py` exits 0 on it
with no warnings. The format 1.0 version of the same article, kept byte-for-byte for the migration
tests, is in `../structure-v1/`.

Prop ids are `019a3c5e-7a00-7000-8000-0000000000NN`, where `NN` is the position in hex.
`thesis` is position 9.

Sections (5): introduction 1–6, method 7, results 8–9, `sec-alternative` 10 (a subsection of
results, `parent: sec-results`), discussion 11–12.

Paragraphs (6, one per run of non-blank lines in `main.tex`): p-1 = 1–6, p-2 = 7, p-3 = 8–9,
p-4 = 10, p-5 = 11, p-6 = 12. Every section's root paragraph has no head; p-6 has head p-5,
relation `addition`.

| Pos | Paragraph | head | relation | also | opens | discharges |
|----:|-----------|------|----------|------|-------|------------|
| 1 | p-1 | 2 (later) | reason | | c-setup-study-time (setup) | |
| 2 | p-1 | root | | | c-q-spacing (question) | |
| 3 | p-1 | 2 | restatement | | c-aim-compare (aim) | |
| 4 | p-1 | 3 | continue | | c-hyp-spacing (hypothesis) | |
| 5 | p-1 | 4 | reason | | | |
| 6 | p-1 | 2 | continue | | c-plan-method, c-plan-results, c-plan-discussion (plan) | |
| 7 | p-2 | root | | | | c-plan-method |
| 8 | p-3 | root | | | | c-plan-results, c-aim-compare |
| 9 | p-3 | 8 | consequence | | | c-hyp-spacing, c-q-spacing |
| 10 | p-4 | root | | 9: contrast | c-ann-study-time (announcement) | |
| 11 | p-5 | root | | 1: contrast; 7: basis | | c-setup-study-time, c-ann-study-time, c-plan-discussion |
| 12 | p-6 | root | | | c-fw-interval (future_work) | |

Position 1 has its head after it; position 6 returns to the paragraph root (a derived `return`).
No arcs cross. The `basis` edge from 11 to 7 is matched by 11's `cites`, so S8 has no warning.
All seven commitment kinds are opened.
