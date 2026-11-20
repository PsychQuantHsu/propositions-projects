## Why

The second review found that sessions of two plugin versions shared one file name for the binary, so that a session of the older version could compare the hash and then run the newer binary. It also found that the launcher accepted a lock file the hook refuses, that a missing or unreadable lock file gave no line or a shell message, and that several tests would pass with the behaviour they are named for removed.

## What Changes

- The binary is installed at `bin/propositions-<sha256>`: each pin has its own path, and the hook leaves the binaries of other pins alone.
- The launcher reads the lock by the hook's rule, the `team` line included. Both read the lock as three fixed lines and say so when it is missing or cannot be read.
- The tests check the arguments handed to `curl` and `codesign`, the number of arguments and the exit status the launcher passes on, links with a matching executable behind them, and the lock file's form byte for byte.
- The requirement says that the name check on the data directory is a check of the name, and what the size limit depends on.

## Non-Goals

- Removing binaries of earlier pins. They stay until the user removes them.
- A test with two sessions at once.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `citation-order`: the requirement on fetching the binary.

## Impact

- Affected specs: `citation-order`
- Affected code:
  - Modified: plugins/propositions/hooks/fetch-cli.sh, plugins/propositions/hooks/run-cli.sh, tests/PropositionsKitTests/FetchHookTests.swift, docs/RELEASE-FLOW.md, .claude/rules/swift-is-the-implementation-language.md
