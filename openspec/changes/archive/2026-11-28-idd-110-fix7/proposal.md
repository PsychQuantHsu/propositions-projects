## Problem

Verify round 7 of issue 110 found gaps in the single-pass TeX scan: `\lstinline[…]` reads `[` as its delimiter (which can move a location onto other displays' delimiters), `\verb{…}` is not read in its braced form, a braced argument ends at the first `}`, spaces after a control word are not skipped, and a `\` at the end of a line takes the newline, so a blank line after it does not end math mode. Two spec-example tests also put a blank line before the display, which resets math mode and makes them pass with no literal handling.

## Root Cause

The scan's argument reader handles one form per command and does not follow TeX's rules for spaces after control words, nested groups or a control symbol at the end of a line; the tests' blank line hides any of this.

## Proposed Solution

Read arguments as TeX does in these points (an optional `[…]` for `\lstinline`, braced `\verb`, balanced groups, spaces skipped after a control word, `\` at a line end not taking the newline), and remove the blank line from the tests and the Example.

## Non-Goals

- Literal commands outside the closed list; one list shared with the Swift input tree (issue 158).

## Success Criteria

- The round-7 reproductions keep their full verbatim location, and the parametrized tests fail when the literal is read as code.

## Impact

- Affected specs: location-refresh
- Affected code:
  - Modified: plugins/propositions/scripts/refresh-prop-locations.py
  - Modified: tests/test_refresh_prop_locations.py
