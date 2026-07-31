# math-tools (domain pack) — scaffold

Thin **math-only** layer on top of the `propositions` core (migration pending). Intended content — only what is genuinely mathematics-specific:

- sympy substitution verification (currently in downstream manuscript Makefiles)
- theorem/lemma boundary audit lenses
- future Lean bridging

Everything currently in `psychquant-claude-plugins/plugins/math-tools/` that is domain-general (clarity-audit, proofread, manuscript-audit, propositions skills + the validator scripts) migrates to the sibling `propositions` core plugin instead, and the old marketplace entry gets a deprecation pointer.
