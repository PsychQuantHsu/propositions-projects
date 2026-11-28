## 1. Fix round 6 of issue 110

- [x] 1.1 Tests for the Examples "a delimiter in a \verb argument does not start a verbatim block", "a percent sign in a URL is not a comment", "literal text of other commands and one-line environments does not change the count" (parametrized over each first line) and "adjacent inline formulas are not a display delimiter", with their spec-example markers; they fail against round 5.
- [x] 1.2 Requirement "A refreshed location covers the proposition's own delimiter lines": in `plugins/propositions/scripts/refresh-prop-locations.py`, replace the masking, escape and `$$` count with one cached left-to-right scan per file and accept a side's delimiter when the scan finds it live with the right `$$` role; `pytest tests/test_refresh_prop_locations.py` passes.
