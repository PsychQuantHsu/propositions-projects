## 1. Fix round 3 of issue 110

- [x] 1.1 Tests for the Examples "a delimiter inside a comment is not taken", "a delimiter that closes other text is not taken" and "a repeated closing line does not cut the span short", with their spec-example markers; all three fail against round 2.
- [x] 1.2 Split the instances that had the wrong markers: "a display that ends in two silent lines" and "a closing line with a trailing comment" become their own tests with their own markers; the parametrized tests keep only the instances their Examples state.
- [x] 1.3 Requirement "A refreshed location covers the proposition's own delimiter lines": replace the walk in `widen_to_text` of `plugins/propositions/scripts/refresh-prop-locations.py` with the window enumeration and the same-line checks; `pytest tests/test_refresh_prop_locations.py` passes.
