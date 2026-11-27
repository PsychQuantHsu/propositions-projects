## 1. Fix round 4 of issue 110

- [x] 1.1 Tests for the Examples "a lone $$ keeps its role", "a comment that mentions the delimiter does not block" and "a line break with an optional argument is not a delimiter", with their spec-example markers; all three fail against round 3.
- [x] 1.2 Requirement "A refreshed location covers the proposition's own delimiter lines": in `_window_matches` of `plugins/propositions/scripts/refresh-prop-locations.py`, ignore comment text and escaped delimiters in the same-line checks, and check the parity of `$$` before a `$$` side; `pytest tests/test_refresh_prop_locations.py` passes.
