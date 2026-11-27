## 1. Fix round 2 of issue 110

- [x] 1.1 Tests for the Examples "a proposition that starts partway through a line", "a closing line that carries more text" (also with `\] % end`) and "a blank line the text does not contain is not crossed", with their spec-example markers; the first two fail against round 1.
- [x] 1.2 Requirement "A refreshed location covers the proposition's own delimiter lines": in `widen_to_text` of `plugins/propositions/scripts/refresh-prop-locations.py`, widen only towards the proposition's own delimiter lines, stop at a line equal to, starting with (downwards) or ending with (upwards) that line, and keep the span only when the first line ends with, the last line starts with, and the other lines (blank lines included) equal the proposition's lines. `pytest tests/test_refresh_prop_locations.py` passes.
- [x] 1.3 Plugin version 0.22.2 in `plugins/propositions/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
