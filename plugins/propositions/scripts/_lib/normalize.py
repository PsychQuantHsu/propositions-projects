"""Shared normalization for R1 and the extraction coverage check.

One ordered step table drives two entry points:

- ``normalize_for_match(s)`` — string only; the validator's R1 / R13 hot path.
- ``normalize_with_map(s)`` — the same string plus, for every output character,
  the index of the source character it came from. The coverage check uses the
  map to report uncovered text by source line.

Both read ``STEPS``, so they cannot drift apart; ``tests/test_lib_normalize.py``
pins the two outputs to be identical. Moved verbatim out of
``validate-propositions.py`` (Spectra change add-extract-skill): no regex in the
table was altered by the move.

Inserted characters (a replacement's literal text) map to the position of the
last character emitted for the same match, or to the match start when nothing
was emitted yet, so the position map never decreases.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

Positions = list[int]


@dataclass(frozen=True)
class RegexStep:
    """``re.sub(pattern, template, s)``; template = literal text + ``\\N`` refs."""

    pattern: re.Pattern[str]
    template: str
    tokens: tuple[str | int, ...]


@dataclass(frozen=True)
class LiteralStep:
    """``s.replace(old, new)``."""

    old: str
    new: str


@dataclass(frozen=True)
class StripStep:
    """``s.strip()``."""


Step = RegexStep | LiteralStep | StripStep

_GROUP_REF = re.compile(r"\\(\d)")


def _tokenize(template: str) -> tuple[str | int, ...]:
    """Split a template into literal strings and group numbers.

    Only literal characters and ``\\1``-``\\9`` are supported, with group refs in
    non-decreasing order; anything else fails at import time rather than
    producing a wrong position map at run time.
    """
    tokens: list[str | int] = []
    last = 0
    for m in _GROUP_REF.finditer(template):
        if m.start() > last:
            tokens.append(template[last:m.start()])
        tokens.append(int(m.group(1)))
        last = m.end()
    if last < len(template):
        tokens.append(template[last:])
    literal = "".join(t for t in tokens if isinstance(t, str))
    if "\\" in literal:
        raise ValueError(f"unsupported escape in template {template!r}")
    groups = [t for t in tokens if isinstance(t, int)]
    if groups != sorted(groups):
        raise ValueError(f"group refs must not decrease in template {template!r}")
    return tuple(tokens)


def _rx(pattern: str, template: str) -> RegexStep:
    return RegexStep(re.compile(pattern), template, _tokenize(template))


UNICODE_TO_MACRO: dict[str, str] = {
    # Greek lowercase
    "α": r"\alpha", "β": r"\beta", "γ": r"\gamma", "δ": r"\delta",
    "ε": r"\varepsilon", "ζ": r"\zeta", "η": r"\eta", "θ": r"\theta",
    "ι": r"\iota", "κ": r"\kappa", "λ": r"\lambda", "μ": r"\mu",
    "ν": r"\nu", "ξ": r"\xi", "π": r"\pi", "ρ": r"\rho",
    "σ": r"\sigma", "τ": r"\tau", "υ": r"\upsilon", "φ": r"\varphi",
    "χ": r"\chi", "ψ": r"\psi", "ω": r"\omega",
    # Greek uppercase
    "Γ": r"\Gamma", "Δ": r"\Delta", "Θ": r"\Theta", "Λ": r"\Lambda",
    "Ξ": r"\Xi", "Π": r"\Pi", "Σ": r"\Sigma", "Φ": r"\Phi",
    "Ψ": r"\Psi", "Ω": r"\Omega",
    # Math relations
    "≠": r"\neq", "≤": r"\leq", "≥": r"\geq", "≡": r"\equiv",
    "≈": r"\approx", "∼": r"\sim",
    # Set operators
    "∈": r"\in", "∉": r"\notin", "⊂": r"\subset", "⊃": r"\supset",
    "⊆": r"\subseteq", "⊇": r"\supseteq", "∪": r"\cup", "∩": r"\cap",
    "∅": r"\emptyset",
    # Arrows
    "→": r"\to", "←": r"\leftarrow", "↔": r"\leftrightarrow",
    "⇒": r"\Rightarrow", "⇐": r"\Leftarrow", "⇔": r"\Leftrightarrow",
    "↦": r"\mapsto",
    # Math constants
    "∞": r"\infty", "∂": r"\partial", "∇": r"\nabla",
    # Other operators
    "⋅": r"\cdot", "×": r"\times", "∘": r"\circ",
    "±": r"\pm", "∓": r"\mp", "·": r"\cdot",
}

STEPS: tuple[Step, ...] = (
    # 1. Strip ALL math-mode delimiters (display + inline) — math content stays
    #    but delimiter placement (which differs between prop's inline form and
    #    .tex's display form) is normalized out.
    _rx(r"\\\[", " "),
    _rx(r"\\\]", " "),
    _rx(r"\\begin\{equation\*?\}", " "),
    _rx(r"\\end\{equation\*?\}", " "),
    _rx(r"\$\$", " "),
    _rx(r"\$", " "),
    # 2. Strip math-mode spacing macros: \quad, \qquad, \,, \;, \!, \:
    _rx(r"\\quad\b", " "),
    _rx(r"\\qquad\b", " "),
    _rx(r"\\[,;!:]", " "),
    # 3. Inline `\text{X}` → just X (literal text without macro)
    _rx(r"\\text\{([^}]*)\}", r"\1"),
    # 3a. Strip structural macros (paragraph / section / subsection / textbf):
    #     `\paragraph{Affine.}` → `Affine`, etc. Prop text often uses bare
    #     label form ("Affine:") while .tex uses paragraph form. Normalize
    #     both to plain content. Also strip trailing `.` in label form.
    _rx(r"\\paragraph\{([^}]*?)\.?\}", r"\1"),
    _rx(r"\\subsection\{([^}]*)\}", r"\1"),
    _rx(r"\\section\*?\{([^}]*)\}", r"\1"),
    _rx(r"\\textbf\{([^}]*?)\.?\}", r"\1"),
    _rx(r"\\emph\{([^}]*)\}", r"\1"),
    _rx(r"\\textit\{([^}]*)\}", r"\1"),
    # 3a.1. Strip LaTeX line comments `% ... <newline>` — these never
    #       appear in prop.text but pollute .tex normalized form.
    #       A `%` starts a comment only when preceded by an even number of
    #       backslashes (zero included): `\%` is a literal percent sign, while
    #       `\\%` is a forced line break followed by a comment. The paired
    #       backslashes are kept via group 1. Before propositions-projects#25
    #       any `%` was treated as a comment, so every prop containing `\%`, and
    #       every prop after a `\%` on the same source line, failed R1.
    _rx(r"(?<!\\)((?:\\\\)*)%[^\n]*\n", r"\1" + "\n"),
    # 3a.2. Strip `\item` / `\noindent` markers — list/section structure.
    _rx(r"\\item\b\s*", ""),
    _rx(r"\\noindent\b\s*", ""),
    # 3a.3. Strip `\begin{...}` / `\end{...}` environment markers (after
    #       the equation versions handled above). Other envs (itemize,
    #       enumerate, lemma, theorem, proof, align*) are scaffolding.
    _rx(r"\\begin\{(itemize|enumerate|center|tabular|lemma|theorem|proof|abstract|document|align|gather|cases)\*?\}(?:\[[^\]]*\])?", ""),
    _rx(r"\\end\{(itemize|enumerate|center|tabular|lemma|theorem|proof|abstract|document|align|gather|cases)\*?\}", ""),
    # 3a.3.1. Strip align-environment markers: `&=` → `=`, `\\` line cont,
    #         `&` alone → space.
    _rx(r"&\s*=", "="),
    _rx(r"\\\\\s*", " "),
    _rx(r"\s&\s", " "),
    # 3a.4. (removed #140) A rule that stripped `Case (X)` / `Sub-case (X)` /
    #       `Note row N:` labels was removed: main.tex introduced literal
    #       `Case (X)` text, and stripping it collapsed props like
    #       "This is Case (D)." to "This is." (#139 R13 false positive).
    #       Do not reintroduce it.
    # 3a.5. Strip a leading "label: " pattern (single hyphenated word followed
    #       by colon-space) at logical sentence starts only.
    _rx(r"(^|\.\s+)([A-Za-z][\w\-]{2,30}):\s+(?=[A-Za-z\\])", r"\1\2 "),
    # 3a.6. Multi-word labels with σ/ρ macros for case_split props:
    #       "σ-constant + log u, v: u = ..." → "σ-constant + log u, v u = ..."
    _rx(r"(^|\.\s+)([σρ\\][\w\-, +\\σρ]{3,80}?):\s+(?=[a-zA-Z\\])", r"\1\2 "),
    # 4. Final whitespace collapse (also handles double-spaces from delimiter strip)
    StripStep(),
    _rx(r"\s+", " "),
    # 5. Collapse space-before-punctuation (`$ \pi $.` vs `\pi.`)
    _rx(r"\s+([.,;:])", r"\1"),
    # 6. Unicode Greek / math symbols → LaTeX command + space (mimics
    #    `$\sigma$` → `\sigma `), then re-collapse.
    *(LiteralStep(ch, macro + " ") for ch, macro in UNICODE_TO_MACRO.items()),
    _rx(r"\s+", " "),
    StripStep(),
    _rx(r"\s+([.,;:])", r"\1"),
)


def _apply_plain(step: Step, s: str) -> str:
    if isinstance(step, RegexStep):
        return step.pattern.sub(step.template, s)
    if isinstance(step, LiteralStep):
        return s.replace(step.old, step.new)
    return s.strip()


def normalize_for_match(s: str) -> str:
    """Whitespace-collapsed string for verbatim comparison (R1 / R13)."""
    for step in STEPS:
        s = _apply_plain(step, s)
    return s


def _apply_regex_tracked(step: RegexStep, s: str, pos: Positions) -> tuple[str, Positions]:
    chars: list[str] = []
    out: Positions = []
    last = 0
    for m in step.pattern.finditer(s):
        a, b = m.span()
        chars.append(s[last:a])
        out.extend(pos[last:a])
        anchor = pos[a] if a < len(pos) else (pos[-1] if pos else 0)
        for tok in step.tokens:
            if isinstance(tok, int):
                ga, gb = m.span(tok)
                if ga >= 0 and gb > ga:
                    chars.append(s[ga:gb])
                    out.extend(pos[ga:gb])
                    anchor = max(anchor, pos[gb - 1])
            else:
                chars.append(tok)
                out.extend([anchor] * len(tok))
        last = b
    chars.append(s[last:])
    out.extend(pos[last:])
    return "".join(chars), out


def _apply_literal_tracked(step: LiteralStep, s: str, pos: Positions) -> tuple[str, Positions]:
    chars: list[str] = []
    out: Positions = []
    last = 0
    i = s.find(step.old)
    while i != -1:
        chars.append(s[last:i])
        out.extend(pos[last:i])
        chars.append(step.new)
        out.extend([pos[i]] * len(step.new))
        last = i + len(step.old)
        i = s.find(step.old, last)
    chars.append(s[last:])
    out.extend(pos[last:])
    return "".join(chars), out


def _apply_tracked(step: Step, s: str, pos: Positions) -> tuple[str, Positions]:
    if isinstance(step, RegexStep):
        return _apply_regex_tracked(step, s, pos)
    if isinstance(step, LiteralStep):
        return _apply_literal_tracked(step, s, pos)
    lo = len(s) - len(s.lstrip())
    hi = len(s.rstrip())
    return s[lo:hi], pos[lo:hi]


def normalize_with_map(s: str) -> tuple[str, Positions]:
    """``normalize_for_match(s)`` plus the source index of every output char."""
    pos: Positions = list(range(len(s)))
    for step in STEPS:
        s, pos = _apply_tracked(step, s, pos)
    return s, pos
