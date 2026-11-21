## Why

`audit-symbols.py` reads only `main.tex` in the manuscript directory, and `audit-citations.py` only `main.tex` and `refs.bib`. A manuscript of several files, or with a bibliography of another name, is not audited, and its citations are reported as missing (issue 69). The two scripts also miss entry types, citation commands with two optional arguments or several groups of keys, and paths outside `\texttt`.

## What Changes

- Two subcommands, `propositions audit symbols` and `propositions audit citations`, the successors of the two scripts. They read the whole input tree, read the bibliography the manuscript declares, recognise every entry type but the three directives and the citation commands of natbib and biblatex, look for paths wherever the manuscript shows one, and list the files they read.
- The maintainer decided on 2026-11-21 that the Python versions are retired, not kept, and that whoever runs one is told to use the Swift one. The retirement is done in the change that switches the skills to the released binary.

## Non-Goals

- Retiring the Python scripts and the root shims, and switching `run-audit.sh` and the skill: they wait for the binary release, with the other commands of this batch.

## Capabilities

### New Capabilities

- `manuscript-audit`: the symbols and citations audits.

### Modified Capabilities

(none)

## Impact

- Affected specs: `manuscript-audit` (new)
- Affected code:
  - New: Sources/PropositionsKit/AuditSource.swift, Sources/PropositionsKit/AuditSymbols.swift, Sources/PropositionsKit/AuditCitations.swift, Sources/PropositionsKit/AuditRun.swift, tests/PropositionsKitTests/AuditTests.swift
  - Modified: Sources/PropositionsKit/CLI.swift, .claude/rules/swift-is-the-implementation-language.md, CLAUDE.md
