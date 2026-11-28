## Problem

Verify round 1 of issue 110 found that the widening checks only the line it reaches, not the span: a proposition whose text is not verbatim can be widened onto a neighbouring delimiter (a `$$` of the previous display, the `\]` of the next paragraph across a blank line), silently.

## Root Cause

`widen_to_text` compares one line, the first or last of the proposition, with the line the widening reaches. Lines that normalize to nothing between them, and blank lines, are not compared with anything.

## Proposed Solution

Keep a widened span only when its non-blank lines, stripped, are exactly the proposition's own non-blank lines; otherwise keep the span the locator returned. Print the stored old location as it was.

## Non-Goals

- Anchoring a proposition whose text is not verbatim; it keeps today's span.

## Success Criteria

- The three manuscripts of verify round 1 keep the locator's span.
- The closing lines the issue's note lists are covered by tests.

## Impact

- Affected specs: location-refresh
- Affected code:
  - Modified: plugins/propositions/scripts/refresh-prop-locations.py
  - Modified: tests/test_refresh_prop_locations.py
