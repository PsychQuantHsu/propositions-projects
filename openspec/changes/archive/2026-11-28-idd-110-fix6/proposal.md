## Problem

Verify round 6 of issue 110 found that the regex masking added in round 5 still miscounts: a verbatim begin inside `\verb`, one-line verbatim environments, prefix matches of `\end{…}`, a `%` inside a URL, `\lstinline`, `\path`, `\href`, `\url` with another delimiter, and adjacent inline formulas `$a$$b$`. Each round of masking fixes has opened new boundaries.

## Root Cause

The masking applies several independent regexes in an order, so every pair of constructs that can nest needs its own ordering rule; and `$$` is counted as a token, not read as TeX reads math mode.

## Proposed Solution

Replace the masking, the escape check and the `$$` count with one left-to-right scan per manuscript file that reads comments, control symbols, the listed literal commands and environments, and math mode as TeX does, and records where control sequences start, which characters are live and the role of every `$$`. A side's delimiter is accepted when the scan says it is live (and, for `$$`, has the right role).

## Non-Goals

- A literal `\string\[` (issue 157) and text that differs from the manuscript (issue 156).
- Literal commands outside the closed list.

## Success Criteria

- The round-6 cases keep their full verbatim location, and adjacent inline formulas no longer flip the count.
- Every earlier Example still holds.

## Impact

- Affected specs: location-refresh
- Affected code:
  - Modified: plugins/propositions/scripts/refresh-prop-locations.py
  - Modified: tests/test_refresh_prop_locations.py
