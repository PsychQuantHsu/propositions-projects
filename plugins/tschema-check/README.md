# tschema-check

Source-fidelity review for a document written from source material — meeting minutes against a transcript, interview notes against a recording, a draft against the emails and statutes it cites. Migrated from `PsychQuant/truth-conditions` (#4).

- **Skill** (`skills/tschema-check/`): the method — the principle "stay semantically close to the original", three layers in fixed order (sentence truth conditions → relations → logic), the distortion taxonomies, and the reviewer's own invariant.
- **Validator** (`scripts/validate-tschema.py`): checks a `tschema.jsonl` record file — statements really are in the checked document (T2/T3), quoted evidence really is in the external source file (T4), plus shape, vocabulary, cross-references and verification-failure phrases. Judging support stays with the reviewer.
- **Format** (`docs/SCHEMA.md`): record fields, vocabularies, T1–T7.

It is the propositions core's R1 generalized: R1 checks that a ledger's text is in the manuscript it indexes; T4 checks that evidence is in a source outside the document. The validator is self-contained (installed plugins cannot import each other) and matches CJK text with NFKC and all whitespace removed.
