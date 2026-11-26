## 1. Fix round 1 of issue 110

- [x] 1.1 Tests for the Examples "a neighbouring display delimiter is not taken", "a paragraph is not widened into the next one" and "other closing lines are kept" (parametrized over the three closing lines, plus a case ending in `\end{cases}` then `\]`), with their spec-example markers; the first two fail against round 0.
- [x] 1.2 A test that the widened span never exceeds `MAX_SPAN` lines, and a test that an empty stored location is printed as empty.
- [x] 1.3 Requirement "A refreshed location covers the proposition's own delimiter lines": in `widen_to_text` of `plugins/propositions/scripts/refresh-prop-locations.py`, keep the widened span only when its stripped non-blank lines equal the proposition's; print the stored old location as it was. `pytest tests/test_refresh_prop_locations.py` passes.
