## Problem

Verify round 8 of issue 110 found more gaps in the TeX scan. A line end after a control word is not skipped before its argument. The optional argument of `\lstinline` ends at the first `]` anywhere later in the file, which can move a location onto other displays' delimiters. `\href[…]` is not read. `\text{$a$$b$}` inside a display closes the display. A braced-`\verb` test passes without the fix. The scan cache is never cleared.

## Root Cause

The argument reader does not follow TeX's state S at a line end, reads brackets without regard to braces or lines, and has no rule for text boxes inside math.

## Proposed Solution

Skip one line end after a control word unless a blank line follows. End `\lstinline`'s options at the first `]` on the line outside braces. Skip `\href`'s optional argument. Skip the braced argument of the text-box commands in math mode. Add the braced-`\verb` reproduction as a test. Clear the cache when `refresh_jsonl` returns.

## Non-Goals

- Literal and text-box commands outside the closed lists; one list shared with the Swift input tree (issue 158).

## Success Criteria

- The round-8 reproductions keep their full verbatim location, and the new tests fail against round 7 where the code was wrong.

## Impact

- Affected specs: location-refresh
- Affected code:
  - Modified: plugins/propositions/scripts/refresh-prop-locations.py
  - Modified: tests/test_refresh_prop_locations.py
