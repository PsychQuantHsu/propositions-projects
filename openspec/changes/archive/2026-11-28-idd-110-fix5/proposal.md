## Problem

Verify round 5 of issue 110 found four ways a verbatim proposition is still left short or the refresh is slow: a delimiter line with a trailing comment is judged non-silent; a `$$` inside `\verb`, `\url` or a verbatim environment flips the `$$` count for the rest of the file; the "same delimiter again on the line" rule rejects a closing line that holds a second display; and the `$$` count rescans the file from the top on every check.

## Root Cause

A single line is normalized without its newline, so its comment is not stripped; the count does not know about literal text; the same-line rule predates the parity check that now covers its purpose; the count is not cached.

## Proposed Solution

Judge silence on the line with a newline; mask comments, escaped dollars, `\verb` and `\url` arguments and verbatim-like environments before counting, once per file, with a prefix count; drop the same-line rule and keep the comment and escape checks on the matched delimiter.

## Non-Goals

- A literal `\string\[` (issue 157) and text that differs from the manuscript (issue 156).

## Success Criteria

- The cases of verify round 5 keep their full verbatim location.
- Every earlier Example still holds.

## Impact

- Affected specs: location-refresh
- Affected code:
  - Modified: plugins/propositions/scripts/refresh-prop-locations.py
  - Modified: tests/test_refresh_prop_locations.py
