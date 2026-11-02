"""Tests for structure-metrics.py (Spectra change add-discourse-dependency-tree).

Spec: Requirement "Structure metrics report whether the tree fits". Expected
values are worked out by hand from the cases, not computed by the tool's code.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from structure_case import chain, with_changes, write_case  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "structure-metrics.py"
FIXTURE = REPO_ROOT / "tests" / "fixtures" / "structure"


def run(ledger: Path, *flags: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), "--jsonl", str(ledger), *flags], capture_output=True, text=True)


def metrics(ledger: Path) -> dict:
    result = run(ledger, "--format", "json")
    assert result.returncode == 0, result.stdout + result.stderr
    return json.loads(result.stdout)


def test_spec_example_crossing_proportion(tmp_path):
    # 1 root; 2 -> 4; 3 -> 1; 4 -> 1; 5 -> 4. Arcs (2,4) (1,3) (1,4) (4,5); only (2,4) and (1,3) cross.
    recs = [{"pos": 1}, {"pos": 2, "head": 4, "relation": "reason"}, {"pos": 3, "head": 1, "relation": "continue"},
            {"pos": 4, "head": 1, "relation": "continue"}, {"pos": 5, "head": 4, "relation": "instance"}]
    sentence = metrics(write_case(tmp_path, 5, recs))["arcs"]["sentence"]
    assert sentence == {"total": 4, "crossing": 2, "proportion": 0.5}


SCOPE_SECTIONS = [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
    {"id": "sec-3", "heading": "Results", "role": "results", "first": 4},
    {"id": "sec-3-3", "heading": "The undetermined cases", "role": "results", "first": 7, "parent": "sec-3"},
]


def test_spec_hit_under_scope_and_miss_under_kind(tmp_path):
    # c-plan-a opened at 2 (sec-1), c-plan-b opened at 5 (sec-3); b is kept at 9, a at 10.
    # Evaluated positions 2-9. kind ranks a first: hits at 2, 3, 4 (only a open) and 9 (b already kept) = 4.
    # scope ranks b first from 5 to 8 (deeper shared section): every evaluated position is a hit = 8.
    changes = {2: {"opens": [{"id": "c-plan-a", "kind": "plan"}]}, 5: {"opens": [{"id": "c-plan-b", "kind": "plan"}]},
               9: {"discharges": ["c-plan-b"]}, 10: {"discharges": ["c-plan-a"]}}
    path = write_case(tmp_path, 10, with_changes(10, changes, paragraph_starts=(1, 4, 7)), sections=SCOPE_SECTIONS)
    ordering = metrics(path)["ordering"]
    assert ordering == {"kind": {"evaluated": 8, "hits": 4}, "scope": {"evaluated": 8, "hits": 8}}


def test_frontier_lengths(tmp_path):
    # A chain 1 <- 2 <- 3 <- 4: the frontier at t holds t, t-1, ..., 1, so lengths 1, 2, 3, 4.
    frontier = metrics(write_case(tmp_path, 4))["frontier"]
    assert frontier == {"median": 2.5, "mean": 2.5, "max": 4}


def test_fixture_heads_and_relations():
    report = metrics(FIXTURE / "main.jsonl")
    assert report["heads"] == {"before": 5, "after": 1, "pending": 0, "roots": 6}
    assert {k: v for k, v in report["relations"].items() if v} == {"reason": 2, "restatement": 1, "continue": 2, "consequence": 1}
    assert set(report["relations"]) == {"continue", "restatement", "specification", "instance", "addition",
                                        "contrast", "reason", "consequence", "sequence", "basis"}
    assert report["also"] == 3
    assert report["arcs"]["sentence"]["crossing"] == 0
    assert report["arcs"]["paragraph"] == {"total": 1, "crossing": 0, "proportion": 0.0}
    assert report["s8_warnings"] == 0
    assert (report["propositions"], report["paragraphs"], report["sections"]) == (12, 6, 5)


def test_s8_warnings_are_counted(tmp_path):
    report = metrics(write_case(tmp_path, 4, with_changes(4, {3: {"relation": "basis"}})))
    assert report["s8_warnings"] == 1


def test_no_arcs_gives_proportion_zero(tmp_path):
    report = metrics(write_case(tmp_path, 1))
    assert report["arcs"]["sentence"] == {"total": 0, "crossing": 0, "proportion": 0.0}


def test_invalid_structure_exits_1(tmp_path):
    result = run(write_case(tmp_path, 3, chain([1, 3])))
    assert result.returncode == 1
    assert "validate-structure.py" in result.stderr


def test_input_error_exits_2(tmp_path):
    ledger = write_case(tmp_path, 3)
    (tmp_path / "structure.json").unlink()
    assert run(ledger).returncode == 2


def test_text_format(tmp_path):
    result = run(FIXTURE / "main.jsonl")
    assert result.returncode == 0
    assert "crossing" in result.stdout and "frontier" in result.stdout and "kind" in result.stdout
