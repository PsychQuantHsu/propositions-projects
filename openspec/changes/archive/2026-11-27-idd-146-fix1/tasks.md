## 1. Fix round 1 of issue 146

- [x] 1.1 Test for the Example "a multi-file ledger without the key stays quiet" in `tests/test_multifile_support.py`, with the marker `spec-example: multifile-manuscript-support / a multi-file ledger without the key stays quiet`; it fails against round 0's validator. Also a test that a single-file `source.parts` of `null` gives no warning.
- [x] 1.2 Requirement "Meta records the resolved parts as a non-authoritative snapshot": in `main()` of `plugins/propositions/scripts/validate-propositions.py`, compare only when `source.parts` is present and not null; all tests in `tests/test_multifile_support.py` pass.
- [x] 1.3 `docs/SCHEMA.md` §Multi-file says no tool writes the field and the author maintains it; the v1.6 row of `plugins/propositions/README.md` says the validator only reads it and warns on a difference.
- [x] 1.4 Add the named exception for this warning to `.claude/rules/swift-is-the-implementation-language.md` (exceptions category 6, with the reason and the exit condition, and a row in the incident table).
