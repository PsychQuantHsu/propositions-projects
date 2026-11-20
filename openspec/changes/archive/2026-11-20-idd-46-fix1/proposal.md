## Why

The first review of the change that lets the plugin fetch the binary found that the skill could run a binary other than the pinned one: it took whatever executable was at one of two paths, one of them a fixed path under the home directory. It also found a lock grammar looser than its description, a hook that could print more than one line and hold a session start for a minute, and tests that could not tell "nothing installed" from "something unreadable there".

## What Changes

- A launcher, `hooks/run-cli.sh`, compares the binary's SHA-256 with the lock each time and runs nothing but the pinned binary; otherwise it prints `propositions: NOT RUN` and exits with 3. The skill calls the binary only through it. The fixed path under the home directory is gone.
- The hook checks Apple's Developer ID requirement for the pinned team, reads the lock as exactly three lines, replaces a matching file that cannot be executed, refuses a linked `bin`, hides the messages of the tools it runs, and downloads within 30 seconds and 50 MB.
- The requirement states what the hook guards against and what it does not.

## Non-Goals

- Guarding against a process that can write in the user's home directory (it can change the skill itself). Not done: staging outside the data directory, digest-named artifacts, locks between sessions, fixed tool paths.
- Fetching in the background. The hook stays a blocking SessionStart hook with a bounded time.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `citation-order`: the requirement on fetching the binary.

## Impact

- Affected specs: `citation-order`
- Affected code:
  - New: plugins/propositions/hooks/run-cli.sh
  - Modified: plugins/propositions/hooks/fetch-cli.sh, plugins/propositions/hooks/hooks.json, plugins/propositions/skills/propositions/SKILL.md, tests/PropositionsKitTests/FetchHookTests.swift, docs/RELEASE-FLOW.md, .claude/rules/swift-is-the-implementation-language.md, CLAUDE.md, plugins/propositions/docs/OBLIGATIONS.md
