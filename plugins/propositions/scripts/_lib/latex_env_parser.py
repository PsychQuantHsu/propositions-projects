"""Shared LaTeX theorem-env parser (#115 M-5 dedup).

Single source of truth previously inline-copied across:
- ``scripts/audit-theorem-boundaries.py`` (#98 cross-check mode)
- ``scripts/validate-propositions.py`` R9 section (#100 containing_block-env check)

Drift surface eliminated: prior to dedup, ``_R9_TYPE_PREFIX_RE`` covered 7 env types
while audit-script ``TYPE_PREFIX_RE`` covered 4; M-1 (greedy ``\\ref``) and M-2
(inverted ``L<start>-L<end>``) had to be fixed symmetrically in both copies via
#100 Path B (commit ``f3512e3``). This module is the structural prevention.

Edge cases (documented limits — same as the originals)
------------------------------------------------------
- Only handles plain ``\\begin{X}`` (no starred ``\\begin{X*}``); grep-confirmed
  manuscript/main.tex never uses starred forms (#98 R-1).
- Treats ``proof`` as sibling of theorem/lemma/etc., not nested. main.tex
  confirms ``\\end{theorem}`` precedes ``\\begin{proof}`` for every numbered
  theorem (#98 R-1).
- ``\\label{...}`` association: each env binds to the nearest preceding label
  within 3 lines of its ``\\begin`` (covers the common pattern
  ``\\begin{theorem}\\n\\label{thm:foo}\\n...``).
- ``containing_block`` two formats coexist (#113):
  ``theorem:thm:eta-s`` (with type prefix, ``_stage2/theorem1.jsonl`` and pre-
  Phase-C ``main.jsonl``) and ``thm:eta-s`` (canonical, label-only post-#113).
  Cross-check normalizes by stripping
  ``^(theorem|lemma|proposition|corollary|proof|definition|remark|conjecture):``
  prefix, then matches the ``thm:`` / ``lem:`` part. Sub-paths like
  ``thm:gamma-g/proof/step2b`` use the segment **before** the first ``/``.
- ``TYPE_PREFIX_RE`` covers all 8 env types declared in main.tex L22-L28
  (#115 M-5 DP1: 7-type superset rather than audit-script's previous 4-type
  narrower form; forward-compat for Stage 3 extraction even though no current
  prop's ``containing_block`` uses the def/remark/conjecture prefixes).
"""

from __future__ import annotations

import re
import sys

# Synced with main.tex \newtheorem declarations (L22-L28).
# 7 declared envs + proof. Parser must recognize all declared types or future
# Stage 3 extraction into definition/remark/conjecture would silently bypass
# audit (DA F1 / Codex confirmed in /idd-verify #98).
ENV_TYPES: tuple[str, ...] = (
    "theorem", "lemma", "proposition", "corollary",
    "definition", "remark", "conjecture",
    "proof",
)
BEGIN_RE = re.compile(r"^\s*\\begin\{(" + "|".join(ENV_TYPES) + r")\}")
END_RE = re.compile(r"^\s*\\end\{(" + "|".join(ENV_TYPES) + r")\}")
LABEL_RE = re.compile(r"\\label\{([^}]+)\}")
# Non-greedy `[^\]]*?` captures the FIRST `\ref` in the proof title, not the
# last (#115 M-1 / #100 Path B fix — greedy `[^\]]*` would bind
# `[Proof of Theorem~\ref{thm:a}, using Lemma~\ref{lem:b}]` to lem:b).
PROOF_TARGET_RE = re.compile(r"\\begin\{proof\}\[[^\]]*?\\ref\{([^}]+)\}[^\]]*\]")
LOC_RE = re.compile(r"main\.tex:L(\d+)(?:-L(\d+))?")
# 7-type superset per #115 M-5 DP1 (unified with validator R9's wider form).
TYPE_PREFIX_RE = re.compile(
    r"^(theorem|lemma|proposition|corollary|proof|definition|remark|conjecture):"
)


def parse_envs(tex_text: str, *, warn_on_residue: bool = True) -> list[dict]:
    """Return ordered list of envs as ``{type, begin_line, end_line, label,
    proof_target}``.

    Uses a stack to match nested ``\\begin`` / ``\\end`` of the same type.
    For our manuscript the stack stays shallow (proof is sibling not nested
    in theorem) but the algorithm is correct under shallow-nesting anyway.

    Parameters
    ----------
    tex_text : str
        Raw LaTeX source.
    warn_on_residue : bool, default True
        If True, emit one stderr line per unmatched ``\\begin{...}`` entry
        remaining in the open stack after the main loop (#115 M-4 — silent
        drop previously masked real LaTeX errors). Audit-script ``--jsonl``
        CI gate keeps the default so authors see warnings; validator R9
        passes ``False`` to keep its ``[PASS]/[WARN]`` line clean.
    """
    lines = tex_text.splitlines()
    open_stack: list[dict] = []
    envs: list[dict] = []

    for idx, line in enumerate(lines, start=1):
        m_begin = BEGIN_RE.match(line)
        if m_begin:
            env_type = m_begin.group(1)
            entry: dict = {
                "type": env_type,
                "begin_line": idx,
                "label": None,
                "proof_target": None,
            }
            # Proof env carries [Proof of Theorem~\ref{<label>}] explicit binding
            if env_type == "proof":
                m_target = PROOF_TARGET_RE.search(line)
                if m_target:
                    entry["proof_target"] = m_target.group(1)
            # Search begin line itself + next 2 lines for first \label{}.
            # Begin-line scan (idx-1 in 0-indexed lines) catches the
            # `\begin{theorem}\label{thm:foo}` same-line pattern that the
            # original (idx, idx+3) range missed (Logic H-1 / Codex
            # /idd-verify #98).
            scan_start = max(0, idx - 1)
            scan_end = min(idx + 2, len(lines))
            for j in range(scan_start, scan_end):
                m_label = LABEL_RE.search(lines[j])
                if m_label:
                    entry["label"] = m_label.group(1)
                    break
            open_stack.append(entry)
            continue
        m_end = END_RE.match(line)
        if m_end:
            end_type = m_end.group(1)
            # Pop the most recent matching open
            for k in range(len(open_stack) - 1, -1, -1):
                if open_stack[k]["type"] == end_type:
                    entry = open_stack.pop(k)
                    entry["end_line"] = idx
                    envs.append(entry)
                    break

    # #115 M-4: surface unmatched \begin residue. Silent drop previously
    # masked malformed LaTeX (typo'd \end, mid-edit state, etc.). Non-blocking
    # — parser returns the matched inventory and lets caller decide severity.
    if warn_on_residue and open_stack:
        for entry in open_stack:
            print(
                f"WARN: parse_envs() — unmatched \\begin{{{entry['type']}}} "
                f"at line {entry['begin_line']} (no matching \\end)",
                file=sys.stderr,
            )

    # Sort by begin_line so output is deterministic
    envs.sort(key=lambda e: e["begin_line"])
    return envs


def normalize_containing_block(cb: str) -> str:
    """Strip type prefix (#113) and sub-path (proof/step segments).

    Examples
    --------
    >>> normalize_containing_block("theorem:thm:eta-s")
    'thm:eta-s'
    >>> normalize_containing_block("theorem:thm:eta-s/proof/s1")
    'thm:eta-s'
    >>> normalize_containing_block("thm:gamma-g/proof/step2b")
    'thm:gamma-g'
    >>> normalize_containing_block("thm:main")
    'thm:main'
    """
    cb = TYPE_PREFIX_RE.sub("", cb)
    return cb.split("/", 1)[0]


def parse_location(loc: str) -> tuple[int, int] | None:
    """Parse ``main.tex:L<start>[-L<end>]`` -> ``(start, end)`` or ``None``.

    Rejects inverted (``end < start``) and zero/negative-base ranges
    (#115 M-2 / #100 Path B fix). An inverted range could coincidentally pass
    a containment check, masking a real boundary mismatch.
    """
    m = LOC_RE.search(loc or "")
    if not m:
        return None
    start = int(m.group(1))
    end = int(m.group(2)) if m.group(2) else start
    if start < 1 or end < start:
        return None  # malformed: zero/negative base or inverted range
    return start, end


def parse_location_v16(loc: str) -> tuple[str | None, int, int] | None:
    """Parse v1.6 file-qualified ``[<relpath>.tex:]L<a>[-L<b>]``.

    Returns ``(relpath_or_None, start, end)`` — ``relpath`` is None for an
    unprefixed location (meaning: the main file). Same malformed-range
    rejection as :func:`parse_location`. A prefix of literally ``main.tex``
    maps to None so pre-v1.6 ledgers keep one canonical meaning.
    """
    m = _LOC_V16_RE.match((loc or "").strip())
    if not m:
        return None
    relpath = m.group("file")
    start = int(m.group("start"))
    end = int(m.group("end")) if m.group("end") else start
    if start < 1 or end < start:
        return None
    if relpath in (None, "main.tex"):
        return None, start, end
    return relpath, start, end


_LOC_V16_RE = re.compile(
    r"^(?:(?P<file>[^:{}\s]+\.tex):)?L(?P<start>\d+)(?:-L(?P<end>\d+))?$"
)

# ---------------------------------------------------------------------------
# Input-tree resolution (v1.6 multi-file manuscripts)
# ---------------------------------------------------------------------------

_INPUT_MACRO_RE = re.compile(r"\\(?:input|include)\s*\{([^}]+)\}")
_NONSTD_INPUT_RE = re.compile(r"\\(?:subimport|subfile|import)\s*\{")
# Verbatim-like environments whose body must not be scanned for input macros.
_VERBATIM_ENVS = ("verbatim", "Verbatim", "lstlisting", "comment", "filecontents")
_VERB_BEGIN_RE = re.compile(r"\\begin\{(" + "|".join(_VERBATIM_ENVS) + r")\*?\}")
_VERB_END_RE = re.compile(r"\\end\{(" + "|".join(_VERBATIM_ENVS) + r")\*?\}")

MAX_INPUT_DEPTH = 3


class InputTreeError(Exception):
    """Loud failure for input-tree resolution (missing file / cycle / depth /
    absolute path). Never degrade to a silent partial tree."""


def _strip_line_comment(line: str) -> str:
    """Drop everything from an unescaped ``%`` to end of line."""
    out = []
    prev = ""
    for ch in line:
        if ch == "%" and prev != "\\":
            break
        out.append(ch)
        prev = ch
    return "".join(out)


def resolve_input_tree(main_path, max_depth: int = MAX_INPUT_DEPTH) -> list:
    """Resolve the ``\\input``/``\\include`` tree from the main file.

    Returns files in document order (main file first), as ``pathlib.Path``
    objects. Targets resolve relative to the MAIN file's directory (LaTeX
    compilation-root semantics), with ``.tex`` appended when the target has
    no extension. Commented-out macros and verbatim-environment bodies are
    ignored; non-standard import macros produce a warning to stderr and are
    skipped (not silently dropped). Repeated inclusion of an already-resolved
    file is allowed (shared preamble diamond); a file inputting itself through
    the current descent stack raises :class:`InputTreeError` (cycle), as do
    missing targets, absolute paths, and nesting beyond ``max_depth``.
    """
    from pathlib import Path

    main_path = Path(main_path).resolve()
    root_dir = main_path.parent
    ordered: list = []
    seen: set = set()

    def visit(path, depth: int, stack: tuple) -> None:
        if path in stack:
            chain = " -> ".join(p.name for p in (*stack, path))
            raise InputTreeError(f"cyclic \\input chain: {chain}")
        if depth > max_depth:
            raise InputTreeError(
                f"\\input nesting exceeds max depth {max_depth} at {path}"
            )
        if path not in seen:
            seen.add(path)
            ordered.append(path)
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            raise InputTreeError(f"cannot read {path}: {exc}") from exc

        in_verbatim = False
        for lineno, raw in enumerate(text.splitlines(), start=1):
            if in_verbatim:
                if _VERB_END_RE.search(raw):
                    in_verbatim = False
                continue
            if _VERB_BEGIN_RE.search(raw):
                in_verbatim = True
                continue
            line = _strip_line_comment(raw)
            if _NONSTD_INPUT_RE.search(line):
                print(
                    f"[warn] non-standard import macro skipped at "
                    f"{path.name}:{lineno} (\\subimport/\\subfile unsupported)",
                    file=sys.stderr,
                )
                continue
            for m in _INPUT_MACRO_RE.finditer(line):
                target = m.group(1).strip()
                if target.startswith("/") or target.startswith("\\\\"):
                    raise InputTreeError(
                        f"absolute \\input path refused at {path.name}:{lineno}: "
                        f"{target}"
                    )
                rel = target if target.endswith(".tex") else target + ".tex"
                child = (root_dir / rel).resolve()
                if not child.is_file():
                    raise InputTreeError(
                        f"\\input target not found: {rel} "
                        f"(referenced at {path.name}:{lineno})"
                    )
                if child in (*stack, path):
                    chain = " -> ".join(
                        p.name for p in (*stack, path, child)
                    )
                    raise InputTreeError(f"cyclic \\input chain: {chain}")
                if child in seen:
                    continue  # diamond re-inclusion (shared preamble) is fine
                visit(child, depth + 1, (*stack, path))

    visit(main_path, 0, ())
    return ordered


def build_associated(envs: list[dict]) -> dict[str, list[dict]]:
    """label -> [statement_env, ...associated_proof_envs] map.

    Proof env associates via priority order:

    1. Explicit binding via ``\\begin{proof}[Proof of Theorem~\\ref{<label>}]``
       argument
    2. Fallback proximity: most-recent statement whose ``end_line`` < proof
       ``begin_line``, gap <= 12 (gap can be 10 when a sibling corollary
       intervenes)
    """
    statement_envs = [
        e for e in envs if e["type"] != "proof" and e.get("label")
    ]
    proof_envs = [e for e in envs if e["type"] == "proof"]
    associated: dict[str, list[dict]] = {
        e["label"]: [e] for e in statement_envs
    }
    for p in proof_envs:
        target = p.get("proof_target")
        if target and target in associated:
            associated[target].append(p)
            continue
        candidates = [
            s for s in statement_envs if s["end_line"] < p["begin_line"]
        ]
        if not candidates:
            continue
        s = max(candidates, key=lambda x: x["end_line"])
        if p["begin_line"] - s["end_line"] <= 12:
            associated[s["label"]].append(p)
    return associated
