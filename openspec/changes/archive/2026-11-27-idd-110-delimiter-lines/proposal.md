## Problem

`refresh-prop-locations.py` writes a location one line short when a proposition ends with a display-math block whose closing `\]` stands on its own line, and one line late when it opens with a lone `\[` (issue 110). Its `✓ old → new` line also prints the new location on both sides.

## Root Cause

The locator returns the smallest span whose normalized text contains the proposition. `normalize_for_match` removes a delimiter that stands alone on its line, so such a line never makes a window contain more and is left out of the span. The message is printed after the location has been replaced.

## Proposed Solution

After the locator, widen the span across lines that normalize to nothing, but only up to a line equal (ignoring surrounding white space) to the proposition's own last non-blank line (downwards) or first non-blank line (upwards); when no such line is reached, keep the span. Print the old location before replacing it.

## Non-Goals

- Propositions whose text is not verbatim (rewrapped): they keep today's span.
- The Swift `propositions revise relocate`, which matches text verbatim and is not affected.

## Success Criteria

- The issue's example keeps `main.tex:L4-L8`.
- A proposition that opens with a lone `\[` starts on that line.
- A proposition whose text does not contain the delimiter lines keeps its span (the existing display-math test).

## Impact

- Affected specs: location-refresh (new)
- Affected code:
  - Modified: plugins/propositions/scripts/refresh-prop-locations.py
  - Modified: tests/test_refresh_prop_locations.py
  - Modified: plugins/propositions/.claude-plugin/plugin.json
  - Modified: .claude-plugin/marketplace.json
