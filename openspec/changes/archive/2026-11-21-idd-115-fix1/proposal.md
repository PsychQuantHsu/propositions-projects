## Why

The first review of the rewrite found aliasing between written files and inputs, an outline and a map read several times at commit, an original ledger with duplicate or missing ids accepted, the text not checked against the ledger or the map, modes that could mix in write.json, duplicate keys accepted, a trace that grew stale over rewrites, a backup without a restore list, and lossy UTF-8 reads.

## What Changes

- Written files named once and apart from the inputs; the outline and map read once at commit; strict ledger checks; locations and paragraph starts checked; modes exclusive; the trace written anew with the old one kept; `backup/restore.jsonl`; strict UTF-8; unchanged files not written.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: the rewrite.

## Impact

- Affected specs: `write`
- Affected code:
  - Modified: Sources/PropositionsKit/WriteRewrite.swift, Sources/PropositionsKit/WriteParagraph.swift, tests/PropositionsKitTests/WriteRewriteTests.swift, plugins/propositions/docs/OUTLINE.md
