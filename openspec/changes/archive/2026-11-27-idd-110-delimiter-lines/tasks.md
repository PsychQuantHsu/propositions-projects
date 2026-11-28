## 1. Issue 110

- [x] 1.1 Tests for the Examples "the closing delimiter line is kept" and "the opening delimiter line is kept" in `tests/test_refresh_prop_locations.py`, with the markers `spec-example: location-refresh / the closing delimiter line is kept` and `spec-example: location-refresh / the opening delimiter line is kept`; both fail against current main.
- [x] 1.2 Add the marker `spec-example: location-refresh / text without the delimiter lines keeps its span` to the existing `test_display_math_block_prop_locates`, which already states that Example.
- [x] 1.3 Requirement "A refreshed location covers the proposition's own delimiter lines": add the widening after `find_prop_span` in `refresh_jsonl` of `plugins/propositions/scripts/refresh-prop-locations.py`, and print the old location before replacing it; `pytest tests/test_refresh_prop_locations.py` passes.
- [x] 1.4 Plugin version 0.22.1 in `plugins/propositions/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (renumber at merge if issue 146's 0.22.1 lands first).
