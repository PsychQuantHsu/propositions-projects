# Article-structure fixture (synthetic)

A valid 12-proposition ledger with both structure sidecars, for the `validate-structure.py`
(S1–S6) and `structure-state.py` tests of Spectra change `add-article-construction-model`.
The article in `main.tex` is invented (spaced vs massed review and one-week recall) and contains
no text from any real manuscript. `_meta.json` declares schema 1.7, profile `empirical`;
`validate-propositions.py` exits 0 on it with no warnings.
Prop ids are `019a3c5e-7a00-7000-8000-0000000000NN`, where `NN` is the position in hex.
Sections: introduction 1–6, method 7, results 8–10, discussion 11–12; `thesis` is position 9.
Ten relations are used (`specification` and `instance` are not); all seven commitment kinds are opened.

| Pos | Section | relation | opens | discharges |
|----:|---------|----------|-------|------------|
| 1 | introduction | start | c-setup-study-time (setup) | |
| 2 | introduction | consequence | c-q-spacing (question) | |
| 3 | introduction | restatement | c-aim-compare (aim) | |
| 4 | introduction | continue | c-hyp-spacing (hypothesis) | |
| 5 | introduction | reason | | |
| 6 | introduction | shift | c-plan-method, c-plan-results, c-plan-discussion (plan) | |
| 7 | method | shift | | c-plan-method |
| 8 | results | sequence | | c-plan-results, c-aim-compare |
| 9 | results | consequence | | c-hyp-spacing, c-q-spacing |
| 10 | results | contrast | c-ann-study-time (announcement) | |
| 11 | discussion | return → 1 | | c-setup-study-time, c-ann-study-time, c-plan-discussion |
| 12 | discussion | addition | c-fw-interval (future_work) | |
