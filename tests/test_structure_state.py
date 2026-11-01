"""Tests for structure-state.py (Spectra change add-article-construction-model).

Spec: openspec/changes/add-article-construction-model/specs/article-structure/spec.md,
Requirement "The state query reports what the article owes at a position".

At position t (t included) the query reports the section, t's relation, the
commitments still open, the future-work list and whether the thesis has
appeared. The open commitments are ordered by kind (announcement, hypothesis,
plan, question, aim, setup), then by opening position.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from structure_case import UUIDS, pid, with_changes, write_case  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "structure-state.py"
FIXTURE = REPO_ROOT / "tests" / "fixtures" / "structure"


def run(ledger: Path, at: str, *flags: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--jsonl", str(ledger), "--at", at, *flags],
        capture_output=True,
        text=True,
    )


def state(ledger: Path, at: str) -> dict:
    result = run(ledger, at, "--format", "json")
    assert result.returncode == 0, result.stdout + result.stderr
    return json.loads(result.stdout)


def open_ids(report: dict) -> list[str]:
    return [c["id"] for c in report["open_commitments"]]


# The spec's example: 10 propositions.
SPEC_EXAMPLE = {
    1: {"opens": [{"id": "c-q-1", "kind": "question"}]},
    2: {"opens": [{"id": "c-plan-1", "kind": "plan"}, {"id": "c-plan-2", "kind": "plan"}]},
    4: {"discharges": ["c-plan-1"]},
    6: {"opens": [{"id": "c-ann-1", "kind": "announcement"}, {"id": "c-fw-1", "kind": "future_work"}]},
}


def test_spec_example_order_and_gaps(tmp_path):
    report = state(write_case(tmp_path, 10, with_changes(10, SPEC_EXAMPLE)), pid(6))
    assert [(c["id"], c["opened_at"], c["since"]) for c in report["open_commitments"]] == [
        ("c-ann-1", 6, 0),
        ("c-plan-2", 2, 4),
        ("c-q-1", 1, 5),
    ]
    assert [c["id"] for c in report["future_work"]] == ["c-fw-1"]
    assert report["open_commitments"][0]["kind"] == "announcement"
    assert report["open_commitments"][1]["opened_by"] == pid(2)


def test_an_open_announcement_comes_first(tmp_path):
    changes = {2: {"opens": [{"id": "c-q-1", "kind": "question"}]}, 5: {"opens": [{"id": "c-ann-1", "kind": "announcement"}]}}
    report = state(write_case(tmp_path, 6, with_changes(6, changes)), pid(5))
    assert open_ids(report) == ["c-ann-1", "c-q-1"]


def test_kind_order_is_fixed(tmp_path):
    # Opened in the reverse of the urgency order, so position alone would give the wrong answer.
    kinds = ["setup", "aim", "question", "plan", "hypothesis", "announcement"]
    changes = {p: {"opens": [{"id": f"c-{k}", "kind": k}]} for p, k in enumerate(kinds, 1)}
    report = state(write_case(tmp_path, 7, with_changes(7, changes)), "end")
    assert open_ids(report) == ["c-announcement", "c-hypothesis", "c-plan", "c-question", "c-aim", "c-setup"]


def test_same_kind_ordered_by_opening_position(tmp_path):
    changes = {
        2: {"opens": [{"id": "c-q-late", "kind": "question"}]},
        1: {"opens": [{"id": "c-q-early", "kind": "question"}]},
        3: {"opens": [{"id": "c-q-middle", "kind": "question"}]},
    }
    report = state(write_case(tmp_path, 4, with_changes(4, changes)), "end")
    assert open_ids(report) == ["c-q-early", "c-q-late", "c-q-middle"]


def test_a_discharge_at_t_counts(tmp_path):
    report = state(write_case(tmp_path, 10, with_changes(10, SPEC_EXAMPLE)), pid(4))
    assert open_ids(report) == ["c-plan-2", "c-q-1"]


def test_a_commitment_opened_after_t_is_not_listed(tmp_path):
    report = state(write_case(tmp_path, 10, with_changes(10, SPEC_EXAMPLE)), pid(3))
    assert "c-ann-1" not in open_ids(report)
    assert report["future_work"] == []


SECTIONS = [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
    {"id": "sec-2", "heading": "Method", "role": "method", "first": 4},
    {"id": "sec-3", "heading": "Results", "role": "results", "first": 8},
]


@pytest.mark.parametrize("pos,section", [(1, "sec-1"), (3, "sec-1"), (4, "sec-2"), (7, "sec-2"), (8, "sec-3"), (10, "sec-3")])
def test_section_containing_t(tmp_path, pos, section):
    report = state(write_case(tmp_path, 10, sections=SECTIONS), pid(pos))
    assert report["section"]["id"] == section


def test_section_reports_heading_and_role(tmp_path):
    report = state(write_case(tmp_path, 10, sections=SECTIONS), pid(5))
    assert report["section"] == {"id": "sec-2", "heading": "Method", "role": "method"}


def test_position_total_and_relation(tmp_path):
    recs = with_changes(10, {7: {"relation": "consequence"}})
    report = state(write_case(tmp_path, 10, recs), pid(7))
    assert (report["position"], report["total"], report["prop_id"], report["relation"]) == (7, 10, pid(7), "consequence")


def test_at_end_is_the_last_live_proposition(tmp_path):
    recs = [{"pos": p, "relation": "start" if p == 1 else "continue"} for p in (1, 2, 3, 4)]
    report = state(write_case(tmp_path, 5, recs, retired=(5,)), "end")
    assert (report["position"], report["total"], report["prop_id"]) == (4, 4, pid(4))


@pytest.mark.parametrize("pos,seen", [(2, False), (3, True), (5, True)])
def test_thesis_seen(tmp_path, pos, seen):
    report = state(write_case(tmp_path, 5, thesis=[3]), pid(pos))
    assert report["thesis_seen"] is seen


def test_invalid_section_plan_degrades_to_no_section(tmp_path):
    sections = [{"id": "sec-1", "heading": "Literature", "role": "literature", "first": 1}]
    report = state(write_case(tmp_path, 4, sections=sections), pid(2))
    assert report["section"] is None
    assert any("S5" in w for w in report["warnings"])


def test_text_format_lists_open_commitments_in_order(tmp_path):
    result = run(write_case(tmp_path, 10, with_changes(10, SPEC_EXAMPLE)), pid(6))
    assert result.returncode == 0, result.stderr
    out = result.stdout
    assert out.index("c-ann-1") < out.index("c-plan-2") < out.index("c-q-1")
    assert "c-fw-1" in out


# ---------- failure paths ----------


def test_unknown_position_is_an_input_error(tmp_path):
    result = run(write_case(tmp_path, 4), UUIDS[30])
    assert result.returncode == 2
    assert UUIDS[30] in result.stderr


def test_retired_position_is_an_input_error(tmp_path):
    recs = [{"pos": p, "relation": "start" if p == 1 else "continue"} for p in (1, 3)]
    result = run(write_case(tmp_path, 3, recs, retired=(2,)), pid(2))
    assert result.returncode == 2
    assert pid(2) in result.stderr


@pytest.mark.parametrize(
    "records",
    [
        [{"pos": 1, "relation": "start"}, {"pos": 3, "relation": "continue"}],  # S1: #2 missing
        [{"pos": 1, "relation": "start"}, {"pos": 2, "relation": "elaboration"}, {"pos": 3, "relation": "continue"}],  # S2
        [{"pos": 1, "relation": "start", "discharges": ["c-x"]}, {"pos": 2, "relation": "continue",
          "opens": [{"id": "c-x", "kind": "aim"}]}, {"pos": 3, "relation": "continue"}],  # S3
    ],
    ids=["S1", "S2", "S3"],
)
def test_structure_errors_block_the_query(tmp_path, records):
    result = run(write_case(tmp_path, 3, records), "end")
    assert result.returncode == 1
    assert "validate-structure.py" in result.stderr


def test_missing_sidecar_is_an_input_error(tmp_path):
    ledger = write_case(tmp_path, 3)
    (tmp_path / "discourse.jsonl").unlink()
    result = run(ledger, "end")
    assert result.returncode == 2
    assert "discourse.jsonl" in result.stderr


# ---------- fixture ----------


def test_fixture_end_state():
    report = state(FIXTURE / "main.jsonl", "end")
    assert report["open_commitments"] == []
    assert [c["id"] for c in report["future_work"]] == ["c-fw-interval"]
    assert report["thesis_seen"] is True
    assert report["section"]["role"] == "discussion"
