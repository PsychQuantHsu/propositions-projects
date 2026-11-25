## Problem

Running `validate-propositions.py` with `--meta` rewrites the ledger's `_meta.json`: it replaces `source.parts` with the file list resolved from the manuscript's `\input` tree. Someone who only wants to measure a ledger (count its violations) gets a changed working tree and has to restore the file by hand (issue 146).

## Root Cause

The write is the specified behaviour. The requirement "Meta records the resolved parts as a non-authoritative snapshot" of `multifile-manuscript-support` says the validator SHALL refresh `source.parts`; `docs/SCHEMA.md` §Multi-file says the same, and `tests/test_multifile_support.py` pins it. The validator's `main()` compares the snapshot with the resolved tree and rewrites the whole file when they differ.

## Proposed Solution

The validator never writes `_meta.json`. It keeps the comparison it makes now, in the same coordinates (paths relative to the main file's directory), and reports a difference as one warning, `[WARN] source.parts`, that lists the files resolved now. The warning joins the validator's other warnings, so `--strict` fails on it. Only Operation D, which creates `_meta.json` after the author confirms a dry run, may record `source.parts`.

Decided by the maintainer in the session that ran issue 146: no new option for writing the snapshot. The repository rule on Swift forbids adding a command-line option to a grandfathered Python script, and a stale snapshot is fixed by editing the file. The comparison is the existing one; only its outcome changes from a write to a warning.

## Non-Goals

- An option or subcommand that rewrites `source.parts` (the issue's `--write-meta`).
- The difference between SCHEMA's coordinates for `source.parts` (repository root) and the code's (main file directory): issue 147.
- Porting the validator to Swift.

## Success Criteria

- After a run with `--meta`, `_meta.json` is unchanged byte for byte, whether its snapshot is stale or current.
- A stale snapshot prints one `[WARN] source.parts` line listing the files resolved now, and adds one warning to the summary; with `--strict` the exit code is 1.
- A current snapshot, or a single-file ledger without the key or with an empty list, prints no such warning.
- A `_meta.json` that is not valid JSON stops the run as a parse error (exit 2) and is left unchanged; a `source` that is not an object gives no warning.

## Impact

- Affected specs: multifile-manuscript-support
- Affected code:
  - Modified: plugins/propositions/scripts/validate-propositions.py
  - Modified: tests/test_multifile_support.py
  - Modified: docs/SCHEMA.md
  - Modified: plugins/propositions/.claude-plugin/plugin.json (version 0.22.1)
  - Modified: .claude-plugin/marketplace.json (version 0.22.1)
