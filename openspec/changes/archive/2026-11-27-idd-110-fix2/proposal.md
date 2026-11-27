## Problem

Verify round 2 of issue 110 found that the round-1 verbatim condition is too strict: it requires every line of the widened span to equal a whole line of the proposition, so a proposition whose sentence starts partway through a source line, the common case for sentence-level propositions, has its widening reverted and its location still cut one line short. The requirement's clauses also conflict for such a proposition.

## Root Cause

The comparison treats the span's first and last lines like the inner ones, but a proposition's text begins partway through its first line and may end partway through its last. The widening also stops at a closing line that carries more text after the delimiter, and the comparison drops blank lines.

## Proposed Solution

One rule: the widening runs only towards a proposition's own lone delimiter line (its first or last line normalizes to nothing); it crosses lines that normalize to nothing and stops at the first line that equals, or (downwards) starts with, or (upwards) ends with, that delimiter line. The widened span is kept only when its lines, each stripped, match the proposition's lines in order: the first line ends with the proposition's first line, the last line starts with its last line, and every other line, blank lines included, is equal.

## Non-Goals

- Propositions whose text is not verbatim; they keep the locator's span.

## Success Criteria

- A proposition that starts mid-line and ends with a lone `\]` keeps its full location.
- A closing line that carries more text after `\]` is included.
- The round-1 and round-2 cases keep the locator's span.

## Impact

- Affected specs: location-refresh
- Affected code:
  - Modified: plugins/propositions/scripts/refresh-prop-locations.py
  - Modified: tests/test_refresh_prop_locations.py
  - Modified: plugins/propositions/.claude-plugin/plugin.json
  - Modified: .claude-plugin/marketplace.json
