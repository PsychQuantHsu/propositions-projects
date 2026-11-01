"""Tests for ``scripts/_lib/normalize.py`` (Spectra change add-extract-skill).

Spec: openspec/changes/add-extract-skill/specs/proposition-extraction/spec.md,
Requirement "Coverage normalization is the R1 normalization".

The coverage check needs to map normalized text back to source positions, so
`_lib.normalize` exposes `normalize_with_map`. Both it and the validator's
`normalize_for_match` must apply one ordered step table; these tests pin the
two outputs to be identical and pin the position map's invariants.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SCRIPTS = REPO_ROOT / "plugins" / "propositions" / "scripts"
sys.path.insert(0, str(SCRIPTS))

from _lib.normalize import normalize_with_map  # noqa: E402

_spec = importlib.util.spec_from_file_location("validate_propositions", SCRIPTS / "validate-propositions.py")
_validator = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_validator)
normalize_for_match = _validator.normalize_for_match

FIXTURES = REPO_ROOT / "tests" / "fixtures"
TEX_FILES = sorted(FIXTURES.rglob("*.tex"))
PROP_TEXTS = [
    json.loads(line)["text"]
    for jsonl in sorted(FIXTURES.rglob("*.jsonl"))
    for line in jsonl.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.startswith("//") and "text" in json.loads(line)
]

# Synthetic inputs that exercise every kind of step: display/inline math,
# spacing macros, \text/\emph/\textbf/\section wrappers, comments, \item,
# environment markers, align markers, leading labels, Unicode → macro rewrites.
SYNTHETIC = [
    "",
    "   ",
    "Plain sentence.",
    "Let $x \\in S$ and \\[ y = x \\quad z \\] hold.",
    "\\begin{equation}\na = b\n\\end{equation}",
    "\\section{Setup} We use \\emph{this} and \\textbf{Bold.} and \\textit{it}.",
    "\\paragraph{Affine.} The map is affine.",
    "\\subsection{Results}There were 40 students.",
    "Alpha beta.\n% hidden comment\nGamma delta.",
    "\\begin{itemize}\n\\item First.\n\\item Second.\n\\end{itemize}",
    "\\begin{theorem}[Main]\\noindent Suppose $u$.\\end{theorem}",
    "\\begin{align*} a &= b \\\\ c & d \\end{align*}",
    "Log-root: u(y) = a. Then σ-constant + log u, v: u = b.",
    "Note σ ≤ ρ and λ → ∞ with α·β ± γ.",
    "Text \\text{inside} math and $ \\pi $ .",
    "Spaces  before ,punctuation ; here :",
]


@pytest.mark.parametrize("tex_path", TEX_FILES, ids=[p.name for p in TEX_FILES])
def test_fixture_tex_normalizes_identically(tex_path):
    text = tex_path.read_text(encoding="utf-8")
    normalized, _ = normalize_with_map(text)
    assert normalized == normalize_for_match(text)


def test_fixture_prop_texts_normalize_identically():
    assert PROP_TEXTS, "expected fixture props to exercise"
    mismatches = [t for t in PROP_TEXTS if normalize_with_map(t)[0] != normalize_for_match(t)]
    assert mismatches == []


@pytest.mark.parametrize("text", SYNTHETIC)
def test_synthetic_inputs_normalize_identically(text):
    assert normalize_with_map(text)[0] == normalize_for_match(text)


def _check_map_invariants(text: str) -> None:
    normalized, positions = normalize_with_map(text)
    assert len(positions) == len(normalized)
    assert all(a <= b for a, b in zip(positions, positions[1:])), "positions must not decrease"
    if text:
        assert all(0 <= p < len(text) for p in positions)
    else:
        assert positions == []
    # Characters copied from the source map back to themselves. The only
    # characters that may differ are inserted by a rewrite: spaces, `=`, and
    # macro letters produced from a non-ASCII source character (σ → \sigma).
    for ch, pos in zip(normalized, positions):
        src = text[pos]
        if ch.isascii() and ch.isalnum() and src.isascii():
            assert ch == src, (ch, pos, src)


@pytest.mark.parametrize("tex_path", TEX_FILES, ids=[p.name for p in TEX_FILES])
def test_map_invariants_on_fixture_tex(tex_path):
    _check_map_invariants(tex_path.read_text(encoding="utf-8"))


@pytest.mark.parametrize("text", SYNTHETIC)
def test_map_invariants_on_synthetic_inputs(text):
    _check_map_invariants(text)


def test_map_points_across_a_stripped_comment_line():
    text = "Alpha beta.\n% hidden comment\nGamma delta."
    normalized, positions = normalize_with_map(text)
    assert normalized == "Alpha beta. Gamma delta."
    assert positions[normalized.index("Gamma")] == text.index("Gamma")
    assert positions[normalized.index("beta")] == text.index("beta")


def test_map_points_into_a_wrapper_argument():
    text = "\\section{Setup} We use \\emph{this}."
    normalized, positions = normalize_with_map(text)
    assert positions[normalized.index("this")] == text.index("this")
    assert positions[normalized.index("Setup")] == text.index("Setup")


def test_unicode_rewrite_maps_to_the_source_character():
    text = "Let σ vary."
    normalized, positions = normalize_with_map(text)
    assert "\\sigma" in normalized
    assert positions[normalized.index("\\sigma")] == text.index("σ")


# ---------- Requirement: Escaped percent signs are literal text (#25) ----------

import json as _json  # noqa: E402
import subprocess  # noqa: E402

VALIDATOR_SHIM = REPO_ROOT / "scripts" / "validate-propositions.py"


def _r1_status(tmp_path: Path, tex: str, prop_text: str) -> str:
    (tmp_path / "main.tex").write_text(tex)
    (tmp_path / "_meta.json").write_text(_json.dumps({"schema_version": "1.6", "source": {"file": "main.tex"}}))
    prop = {
        "id": "01910b9c-d4f0-7000-8000-0123456789ab", "text": prop_text, "location": "main.tex:L1",
        "containing_block": "sec:results", "claim_type": "claim", "asserts": ["x"], "cites": [],
    }
    (tmp_path / "main.jsonl").write_text(_json.dumps(prop) + "\n")
    out = subprocess.run(
        [sys.executable, str(VALIDATOR_SHIM), "--jsonl", str(tmp_path / "main.jsonl"),
         "--meta", str(tmp_path / "_meta.json"), "--tex", str(tmp_path / "main.tex")],
        capture_output=True, text=True,
    ).stdout
    # R1 prints a summary line only when it passes; failures appear in the
    # error list as "  [R1] <pid>: ...".
    if "[PASS] R1 prop-subset-check" in out:
        return "PASS"
    if any(l.lstrip().startswith("[R1] ") for l in out.splitlines()):
        return "FAIL"
    raise AssertionError(f"no R1 outcome in validator output:\n{out}")


def test_verbatim_prop_with_escaped_percent_passes_r1(tmp_path):
    sentence = "We computed the 95\\% confidence intervals for the mean."
    assert _r1_status(tmp_path, sentence + "\nNext line.\n", sentence) == "PASS"


def test_sentence_after_escaped_percent_on_same_line_passes_r1(tmp_path):
    tex = "The rate was 95\\% overall. These indices indicate agreement.\n"
    assert _r1_status(tmp_path, tex, "These indices indicate agreement.") == "PASS"


def test_comment_after_forced_line_break_is_still_stripped():
    normalized, _ = normalize_with_map("first part \\\\% a comment\nsecond part\n")
    assert "first part" in normalized
    assert "a comment" not in normalized
    assert "second part" in normalized


def test_text_after_escaped_percent_is_kept_for_coverage():
    normalized, positions = normalize_with_map("About 30\\% of participants finished early.\n")
    assert "of participants finished early" in normalized


@pytest.mark.parametrize(
    "source,kept,dropped",
    [
        ("a \\% b\n", "b", None),            # one backslash: escaped
        ("a \\\\\\% b\n", "b", None),        # three backslashes: \\ then \%
        ("a \\\\% b\nc\n", "c", "b"),        # two backslashes: \\ then comment
        ("a \\\\\\\\% b\nc\n", "c", "b"),    # four backslashes: comment
        ("a % b\nc\n", "c", "b"),            # bare %: comment
    ],
)
def test_backslash_parity_decides_comment(source, kept, dropped):
    normalized = normalize_for_match(source)
    assert kept in normalized.split()
    if dropped is not None:
        assert dropped not in normalized.split()
