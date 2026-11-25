## 1. Tests first (issue 146)

- [x] 1.1 Test for the Example "a stale snapshot is reported and not rewritten": in `tests/test_multifile_support.py`, replace `test_parts_snapshot_refreshed_after_run` with a test that compares the bytes of `_meta.json` before and after a run and checks the `[WARN] source.parts` line names both part files; it carries the marker `spec-example: multifile-manuscript-support / a stale snapshot is reported and not rewritten`. It fails against the current validator.
- [x] 1.2 Test for "strict fails on a stale snapshot": the same setup with `--strict` exits 1 and leaves the bytes unchanged; marker `spec-example: multifile-manuscript-support / strict fails on a stale snapshot`.
- [x] 1.3 Test for "a current snapshot gives no warning"; marker `spec-example: multifile-manuscript-support / a current snapshot gives no warning`.
- [x] 1.4 Test for "a single-file ledger without the key stays quiet": rework `test_single_file_run_adds_no_parts_key` to also check the bytes and the absence of the warning; marker `spec-example: multifile-manuscript-support / a single-file ledger without the key stays quiet`.
- [x] 1.5 Test for "a single-file ledger with leftover parts is warned"; marker `spec-example: multifile-manuscript-support / a single-file ledger with leftover parts is warned`.

## 2. Validator

- [x] 2.1 Requirement "Meta records the resolved parts as a non-authoritative snapshot": in `main()` of `plugins/propositions/scripts/validate-propositions.py`, keep the snapshot comparison, remove the `write_text` of `_meta.json`, and record the difference as one warning (`source.parts`, `_meta.json`, message naming the resolved part files or saying there are none) that is added to `all_warnings` and printed as a `[WARN] source.parts` line; an unreadable `_meta.json` stays a stderr note. Done when the five tests pass and `pytest tests/` is green.

## 3. Documents and version

- [x] 3.1 `docs/SCHEMA.md` §Multi-file: `source.parts` is written only by Operation D; the validator reads it and warns when it differs from the tree. Leave the coordinate sentence for issue 147.
- [x] 3.2 Plugin version 0.22.1 in `plugins/propositions/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`; `pytest tests/test_marketplace_entries.py` passes.
