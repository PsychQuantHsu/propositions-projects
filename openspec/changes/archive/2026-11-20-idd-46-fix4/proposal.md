## Why

The fourth review found that the skill passed the two paths as separate arguments, so a path that starts with a hyphen could be read as an option, and that three tests still held less than their examples say.

## What Changes

- The skill's call writes the paths as `--jsonl=` and `--tex=`.
- Tests: the download is one call with exactly the expected arguments; a refusal of the launcher is checked by whether the file was started, not by what was printed; the check of the skill's text reads fences of tildes and indented fences and a bare `propositions` line.
- The skill and the rule file no longer say that a missing network or missing hooks stop an installed binary, or that how a plugin obtains the binary is undecided.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `citation-order`: the requirement on fetching the binary.

## Impact

- Affected specs: `citation-order`
- Affected code:
  - Modified: plugins/propositions/skills/propositions/SKILL.md, tests/PropositionsKitTests/FetchHookTests.swift, .claude/rules/swift-is-the-implementation-language.md
