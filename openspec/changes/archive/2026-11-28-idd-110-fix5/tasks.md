## 1. Fix round 5 of issue 110

- [x] 1.1 Tests for the Examples "a delimiter line with a trailing comment keeps its side", "a $$ in verbatim text does not change the count" (parametrized over `\verb`, a `verbatim` environment and `\url`) and "a second display on the closing line does not block", with their spec-example markers; they fail against round 4.
- [x] 1.2 Requirement "A refreshed location covers the proposition's own delimiter lines": in `plugins/propositions/scripts/refresh-prop-locations.py`, judge silence with a trailing newline, mask literal text before counting `$$` with a per-file prefix count, and remove the same-line rule; `pytest tests/test_refresh_prop_locations.py` passes.
