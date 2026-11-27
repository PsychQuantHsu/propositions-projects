## Problem

Verify round 4 of issue 110 found that window enumeration can take a `$$` that belongs to another display when both of a stale proposition's sides are lone `$$` lines, and that the same-line check is a plain substring test, so a comment mentioning the delimiter (`\] % see \]`) or a line break `\\[2pt]` rejects the correct window and leaves a verbatim proposition short.

## Root Cause

`$$` opens and closes with the same token, so line text alone cannot tell which role a `$$` line has; and the same-line check reads comments and escaped backslashes as delimiters.

## Proposed Solution

Count the `$$` before a window's `$$` line, outside comments and not escaped: an opening one must have an even count before it, a closing one an odd count. The same-line check ignores text after an unescaped `%`, and a delimiter preceded by an odd number of backslashes is not a delimiter.

## Non-Goals

- A literal `\string\[` (issue 157) and text wrapped differently from the manuscript (issue 156).

## Success Criteria

- The three manuscripts of verify round 4 give `main.tex:L4`, `main.tex:L1-L4` and `main.tex:L1-L3`.
- Every earlier Example still holds.

## Impact

- Affected specs: location-refresh
- Affected code:
  - Modified: plugins/propositions/scripts/refresh-prop-locations.py
  - Modified: tests/test_refresh_prop_locations.py
