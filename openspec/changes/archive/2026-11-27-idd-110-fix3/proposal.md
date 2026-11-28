## Problem

Verify round 3 of issue 110 found that the step-by-step widening still picks wrong lines or gives up: a comment line that ends with `\[` is taken as the opening delimiter, a delimiter that closes other text on the same line (`First $$a$$`) is taken as the proposition's own, and with two `\end{equation}` lines in a row the widening stops at the first, fails the comparison, and leaves a verbatim proposition short. Two tests carry spec-example markers for instances their Examples do not state.

## Root Cause

The widening walks line by line and stops at the first line that looks like the boundary; the comparison afterwards only rejects, it cannot try the next candidate. The "ends with" / "starts with" test also accepts a delimiter whose line holds other text before or after it.

## Proposed Solution

Enumerate instead of walking: a widened span must match the proposition line by line, so it has exactly as many lines as the proposition. Try the windows of that length that contain the locator's span, extending only a side whose own line normalizes to nothing, nearest first, and keep the first that matches; on a side matched by "ends with" / "starts with", the rest of the manuscript line must hold neither a TeX comment before the delimiter nor the same delimiter again.

## Non-Goals

- Propositions whose text differs from the manuscript in what normalization ignores (issue 156).

## Success Criteria

- The three manuscripts of verify round 3 give the locator's span, or the full verbatim span for the repeated closing line.
- Every earlier Example still holds.

## Impact

- Affected specs: location-refresh
- Affected code:
  - Modified: plugins/propositions/scripts/refresh-prop-locations.py
  - Modified: tests/test_refresh_prop_locations.py
