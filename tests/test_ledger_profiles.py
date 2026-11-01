"""Tests for ledger profiles (schema v1.7, Spectra change add-extract-skill).

Spec: openspec/changes/add-extract-skill/specs/ledger-profiles/spec.md

A ledger declares `profile` in `_meta.json`; the validator selects the R11
(`evidence_class`) and R12 (`claim_type`) vocabularies from it. `default` is the
pre-v1.7 vocabulary; `empirical` adds the proofread Mode B values plus
`external`. Ledgers without the field must see byte-identical output.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "scripts" / "validate-propositions.py"  # root shim (pinned contract)
GOLDEN = REPO_ROOT / "tests" / "fixtures" / "validator-golden"
SMOKE = REPO_ROOT / "tests" / "fixtures" / "_smoke_tests"

UUID_A = "01910b9c-d4f0-7000-8000-0123456789ab"
TEX_LINE = "There were 40 students in this study."

DEFAULT_CLAIM_TYPES = (
    "axiom, definition, hypothesis, claim, case_split, display_equation, "
    "restatement, commentary, example, connective, reference, scope_qualifier"
)


def make_ledger(
    tmp_path: Path,
    claim_type: str = "claim",
    evidence_class: str | None = "derived",
    schema_version: str = "1.7",
    profile: str | None = None,
) -> tuple[Path, Path, Path]:
    """One-prop ledger whose text anchors verbatim on line 1 of main.tex."""
    meta: dict = {"schema_version": schema_version, "source": {"file": "main.tex"}}
    if profile is not None:
        meta["profile"] = profile
    prop: dict = {
        "id": UUID_A,
        "text": TEX_LINE,
        "location": "main.tex:L1",
        "containing_block": "sec:method",
        "claim_type": claim_type,
        "asserts": ["N = 40 students"],
        "cites": [],
    }
    if evidence_class is not None:
        prop["evidence_class"] = evidence_class
    jsonl, meta_path, tex = tmp_path / "main.jsonl", tmp_path / "_meta.json", tmp_path / "main.tex"
    jsonl.write_text(json.dumps(prop) + "\n")
    meta_path.write_text(json.dumps(meta, indent=1) + "\n")
    tex.write_text(TEX_LINE + "\n")
    return jsonl, meta_path, tex


def run(jsonl: Path, meta: Path, tex: Path, cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--jsonl", str(jsonl), "--meta", str(meta), "--tex", str(tex)],
        capture_output=True,
        text=True,
        cwd=cwd,
    )


def rule_status(stdout: str, rule: str) -> str:
    """Return PASS / FAIL / SKIP for the summary line of `rule` (e.g. 'R11')."""
    for line in stdout.splitlines():
        for status in ("PASS", "FAIL", "SKIP"):
            if line.startswith(f"[{status}] {rule} "):
                return status
    raise AssertionError(f"no summary line for {rule}:\n{stdout}")


# ---------- Requirement: Ledger declares its profile in metadata ----------


def test_absent_profile_applies_default_vocabulary(tmp_path):
    result = run(*make_ledger(tmp_path, "result", "measured"))
    assert rule_status(result.stdout, "R11") == "FAIL"
    assert rule_status(result.stdout, "R12") == "FAIL"
    assert result.returncode == 1


def test_declared_empirical_profile_applies_empirical_vocabulary(tmp_path):
    result = run(*make_ledger(tmp_path, "result", "measured", profile="empirical"))
    assert rule_status(result.stdout, "R11") == "PASS", result.stdout
    assert rule_status(result.stdout, "R12") == "PASS", result.stdout
    assert result.returncode == 0, result.stdout + result.stderr


def test_declared_default_profile_behaves_as_absent(tmp_path):
    result = run(*make_ledger(tmp_path, "result", "measured", profile="default"))
    assert rule_status(result.stdout, "R12") == "FAIL"
    assert result.returncode == 1


# ---------- Requirement: Profile values form a closed set ----------


def test_unknown_profile_is_an_error(tmp_path):
    result = run(*make_ledger(tmp_path, profile="psychology"))
    out = result.stdout + result.stderr
    assert result.returncode == 1
    assert "psychology" in out
    assert "{default, empirical}" in out


@pytest.mark.parametrize("value", ["Empirical", "empirical ", "", "default,empirical"])
def test_lookalike_profile_values_are_not_inferred(tmp_path, value):
    result = run(*make_ledger(tmp_path, "result", "measured", profile=value))
    assert result.returncode == 1
    assert "{default, empirical}" in result.stdout + result.stderr


def test_non_string_profile_is_an_error(tmp_path):
    jsonl, meta, tex = make_ledger(tmp_path)
    data = json.loads(meta.read_text())
    data["profile"] = ["empirical"]
    meta.write_text(json.dumps(data))
    result = run(jsonl, meta, tex)
    assert result.returncode == 1
    assert "{default, empirical}" in result.stdout + result.stderr


# ---------- Requirement: Profile declaration requires schema version 1.7 ----------


def test_profile_under_older_schema_is_an_error_without_fallback(tmp_path):
    # The prop is valid under the default vocabulary, so exit 1 can only come
    # from the schema gate — a silent fallback to `default` would exit 0.
    result = run(*make_ledger(tmp_path, "claim", "derived", schema_version="1.6", profile="empirical"))
    out = result.stdout + result.stderr
    assert result.returncode == 1, out
    assert "1.7" in out


def test_default_profile_under_older_schema_is_also_an_error(tmp_path):
    result = run(*make_ledger(tmp_path, schema_version="1.6", profile="default"))
    assert result.returncode == 1
    assert "1.7" in result.stdout + result.stderr


def test_pre_1_2_ledger_without_profile_keeps_skipping_enum_rules(tmp_path):
    result = run(*make_ledger(tmp_path, "result", "measured", schema_version="1.1"))
    assert rule_status(result.stdout, "R11") == "SKIP"
    assert rule_status(result.stdout, "R12") == "SKIP"


# ---------- Requirement: Profile selects the R11 and R12 vocabularies ----------

# Example table from the spec ("R11/R12 outcome by profile"), one case per row.
EXAMPLE_ROWS = [
    (None, "claim", "derived", "PASS", "PASS"),
    (None, "result", "measured", "FAIL", "FAIL"),
    ("empirical", "result", "measured", "PASS", "PASS"),
    ("empirical", "interpretation", "descriptive", "PASS", "PASS"),
    ("empirical", "claim", "external", "PASS", "PASS"),
    (None, "claim", "external", "FAIL", "PASS"),
    ("empirical", "finding", "measured", "PASS", "FAIL"),
    ("empirical", "claim", "strong", "FAIL", "PASS"),
]


@pytest.mark.parametrize("profile,claim_type,evidence_class,r11,r12", EXAMPLE_ROWS)
def test_example_table(tmp_path, profile, claim_type, evidence_class, r11, r12):
    result = run(*make_ledger(tmp_path, claim_type, evidence_class, profile=profile))
    assert rule_status(result.stdout, "R11") == r11, result.stdout
    assert rule_status(result.stdout, "R12") == r12, result.stdout


@pytest.mark.parametrize(
    "evidence_class", ["measured", "tested", "descriptive", "not_computable", "external"]
)
def test_every_empirical_evidence_class_is_accepted(tmp_path, evidence_class):
    result = run(*make_ledger(tmp_path, "claim", evidence_class, profile="empirical"))
    assert rule_status(result.stdout, "R11") == "PASS", result.stdout


def test_default_vocabulary_still_accepted_under_empirical(tmp_path):
    result = run(*make_ledger(tmp_path, "definition", "conventional", profile="empirical"))
    assert rule_status(result.stdout, "R11") == "PASS"
    assert rule_status(result.stdout, "R12") == "PASS"
    assert result.returncode == 0


def test_empirical_error_lists_the_empirical_set(tmp_path):
    result = run(*make_ledger(tmp_path, "finding", "measured", profile="empirical"))
    r12_errors = [l for l in result.stdout.splitlines() if "R12:" in l]
    assert r12_errors, result.stdout
    assert "result" in r12_errors[0] and "interpretation" in r12_errors[0]


def test_default_error_lists_the_unchanged_default_set(tmp_path):
    result = run(*make_ledger(tmp_path, "result", "measured"))
    r12_errors = [l for l in result.stdout.splitlines() if "R12:" in l]
    assert r12_errors, result.stdout
    assert "{" + DEFAULT_CLAIM_TYPES + "}" in r12_errors[0]


def test_prop_without_evidence_class_is_not_checked_under_empirical(tmp_path):
    result = run(*make_ledger(tmp_path, "commentary", None, profile="empirical"))
    assert rule_status(result.stdout, "R11") == "PASS"


# ---------- Requirement: Undeclared ledgers see unchanged validator output ----------


def test_declared_profile_is_announced(tmp_path):
    result = run(*make_ledger(tmp_path, profile="empirical"))
    assert "[INFO] profile: empirical" in result.stdout.splitlines()


def test_undeclared_profile_prints_no_profile_line(tmp_path):
    result = run(*make_ledger(tmp_path))
    assert "[INFO] profile" not in result.stdout


# Tracked fixtures only. tests/fixtures/hsu-regression/ is a gitignored local
# copy of a third-party manuscript, so no output derived from it may be
# committed; its before/after comparison runs outside the repository.
GOLDEN_CASES = [
    (n, SMOKE / f"{n}.jsonl", SMOKE / f"{n}_meta.json", SMOKE / f"{n}.tex")
    for n in ("conditional_60_path_c", "duplicate_id", "missing_cite", "rollback_60", "rollback_60_real")
]


@pytest.mark.parametrize("name,jsonl,meta,tex", GOLDEN_CASES, ids=[c[0] for c in GOLDEN_CASES])
def test_undeclared_ledger_output_matches_pre_profile_golden(name, jsonl, meta, tex):
    """Byte-identical stdout and equal exit status versus the output captured
    before profiles existed. Paths are passed relative to the repo root, as
    when the golden files were recorded."""
    rel = lambda p: p.relative_to(REPO_ROOT)
    result = run(rel(jsonl), rel(meta), rel(tex), cwd=REPO_ROOT)
    assert result.stdout == (GOLDEN / f"{name}.stdout").read_text()
    assert str(result.returncode) == (GOLDEN / f"{name}.exit").read_text().strip()
