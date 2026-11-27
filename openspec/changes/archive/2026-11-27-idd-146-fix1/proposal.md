## Problem

Verify round 1 of issue 146 found that the read-only snapshot check warns on every multi-file ledger without a `source.parts` key, and nothing ever writes that key: the Operation D template has none, so a newly scaffolded multi-file ledger warns on every run and fails `--strict`. The requirement also fixed the coordinates of `source.parts`, which is issue 147's to decide.

## Root Cause

The comparison treated a missing key as a stale list. Before issue 146 the validator filled the key in on its first run, so a missing key was never seen for long; after it, nothing writes the key.

## Proposed Solution

A missing or `null` `source.parts` is no snapshot and gives no warning, for every tree. A warning fires only when a snapshot exists and differs from the resolved tree. The requirement says the author maintains the field by hand and no longer states its coordinate system.

## Non-Goals

- Writing `source.parts` from Operation D or any other tool.
- The coordinate system of `source.parts` (issue 147).

## Success Criteria

- A multi-file ledger whose `_meta.json` has no `source.parts` gives no `[WARN] source.parts` line and passes `--strict` when nothing else warns.
- The five Examples of round 0 still hold.

## Impact

- Affected specs: multifile-manuscript-support
- Affected code:
  - Modified: plugins/propositions/scripts/validate-propositions.py
  - Modified: tests/test_multifile_support.py
  - Modified: docs/SCHEMA.md
  - Modified: plugins/propositions/README.md
  - Modified: .claude/rules/swift-is-the-implementation-language.md
