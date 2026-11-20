## Why

The third review found no way for a skill to report an unchecked citation direction as checked. It found that a lock file with a NUL byte could be read as usable, that a lock that cannot be opened could show a shell message, that the launcher's failure to start a file was not described, and that four tests held less than their examples say.

## What Changes

- Both scripts refuse a lock file that holds a NUL byte or cannot be opened, with their own line.
- The requirement says what happens when the system cannot start the pinned file.
- Tests: each curl argument and the file handed to codesign are checked; the skill's text is checked inside code fences, with texts that call the tool a second way; the launcher is tried with every unusable lock but the two with another hash; the repository's lock may end without a newline; the unreadable lock is not tried as root.

## Non-Goals

- Turning a failure to start the file into exit 3: the launcher cannot tell it from a status of the binary.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `citation-order`: the requirement on fetching the binary.

## Impact

- Affected specs: `citation-order`
- Affected code:
  - Modified: plugins/propositions/hooks/fetch-cli.sh, plugins/propositions/hooks/run-cli.sh, tests/PropositionsKitTests/FetchHookTests.swift
