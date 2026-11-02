"""Tests for structure-state.py, format 2.0 (Spectra change add-discourse-dependency-tree).

Spec: openspec/changes/add-discourse-dependency-tree/specs/article-structure/spec.md,
Requirement "The state query reports what the article owes at a position".

At position t (t included) the query reports the section and paragraph, t's
relation, the right frontier, the pending records, the commitments still open
(with their scope), the future-work list and whether the thesis has appeared.
`--order scope` (default, task 8.6) puts commitments from a deeper shared section first within a kind;
`--order kind` orders them by kind, then opening position.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from structure_case import UUIDS, chain, pid, with_changes, write_case  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "structure-state.py"
FIXTURE = REPO_ROOT / "tests" / "fixtures" / "structure"


def run(ledger: Path, at: str, *flags: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--jsonl", str(ledger), "--at", at, *flags],
        capture_output=True,
        text=True,
    )


def state(ledger: Path, at: str, *flags: str) -> dict:
    result = run(ledger, at, "--format", "json", *flags)
    assert result.returncode == 0, result.stdout + result.stderr
    return json.loads(result.stdout)


def open_ids(report: dict) -> list[str]:
    return [c["id"] for c in report["open_commitments"]]


def sentence_nodes(report: dict) -> list[int]:
    return [n["position"] for n in report["frontier"] if n["level"] == "sentence"]


def level_ids(report: dict, level: str) -> list[str]:
    return [n["id"] for n in report["frontier"] if n["level"] == level]


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
    assert report["open_commitments"][1]["opened_by"] == pid(2)
    assert report["order"] == "scope"


@pytest.mark.parametrize("order", ["kind", "scope"])
def test_an_open_announcement_comes_first(tmp_path, order):
    changes = {2: {"opens": [{"id": "c-q-1", "kind": "question"}]}, 5: {"opens": [{"id": "c-ann-1", "kind": "announcement"}]}}
    report = state(write_case(tmp_path, 6, with_changes(6, changes)), pid(5), "--order", order)
    assert open_ids(report) == ["c-ann-1", "c-q-1"]


def test_kind_order_is_fixed(tmp_path):
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


def test_a_paragraph_root_reports_relation_root(tmp_path):
    assert state(write_case(tmp_path, 4), pid(1))["relation"] == "root"


def test_at_end_is_the_last_live_proposition(tmp_path):
    report = state(write_case(tmp_path, 5, chain([1, 2, 3, 4]), retired=(5,)), "end")
    assert (report["position"], report["total"], report["prop_id"]) == (4, 4, pid(4))


@pytest.mark.parametrize("pos,seen", [(2, False), (3, True), (5, True)])
def test_thesis_seen(tmp_path, pos, seen):
    report = state(write_case(tmp_path, 5, thesis=[3]), pid(pos))
    assert report["thesis_seen"] is seen


# ---------- frontier ----------


def test_spec_example_right_frontier_inside_a_paragraph(tmp_path):
    recs = [{"pos": 1}, {"pos": 2, "head": 1, "relation": "continue"},
            {"pos": 3, "head": 2, "relation": "continue"}, {"pos": 4, "head": 2, "relation": "continue"}]
    report = state(write_case(tmp_path, 4, recs), pid(4))
    assert sentence_nodes(report) == [4, 2, 1]


def test_frontier_passes_through_later_ancestors(tmp_path):
    # 1 root; 2 -> 1; 3 -> 5; 4 -> 5; 5 -> 2. At 4, the head 5 is still to come.
    recs = [{"pos": 1}, {"pos": 2, "head": 1, "relation": "continue"}, {"pos": 3, "head": 5, "relation": "reason"},
            {"pos": 4, "head": 5, "relation": "reason"}, {"pos": 5, "head": 2, "relation": "consequence"}]
    report = state(write_case(tmp_path, 5, recs), pid(4))
    assert sentence_nodes(report) == [4, 2, 1]


def test_frontier_ends_at_the_root_after_a_pending_head(tmp_path):
    recs = [{"pos": 1}, {"pos": 2, "head": 1, "relation": "continue"},
            {"pos": 3, "head": 1, "relation": "continue"}, {"pos": 4, "head": "pending"}]
    report = state(write_case(tmp_path, 4, recs), pid(4))
    assert sentence_nodes(report) == [4, 1]


def test_frontier_paragraph_and_section_levels(tmp_path):
    sections = [
        {"id": "sec-1", "heading": "Results", "role": "results", "first": 1},
        {"id": "sec-1-1", "heading": "Scores", "role": "results", "first": 5, "parent": "sec-1"},
    ]
    paragraphs = [
        {"id": "p-1", "first": 1}, {"id": "p-2", "first": 3, "head": "p-1", "relation": "continue"},
        {"id": "p-3", "first": 5}, {"id": "p-4", "first": 7, "head": "p-3", "relation": "instance"},
    ]
    report = state(write_case(tmp_path, 8, sections=sections, paragraphs=paragraphs), pid(8))
    assert sentence_nodes(report) == [8, 7]
    assert level_ids(report, "paragraph") == ["p-4", "p-3"]
    assert level_ids(report, "section") == ["sec-1-1", "sec-1"]
    assert report["paragraph"] == {"id": "p-4", "root": {"position": 7, "prop_id": pid(7)}}


# ---------- pending ----------


def test_spec_scenario_a_pending_record_is_reported(tmp_path):
    recs = with_changes(9, {9: {"head": "pending"}})
    recs[-1].pop("relation", None)
    report = state(write_case(tmp_path, 9, recs), pid(9))
    assert [p["position"] for p in report["pending"]] == [9]


def test_a_head_after_t_counts_as_pending(tmp_path):
    recs = [{"pos": 1}, {"pos": 2, "head": 3, "relation": "reason"},
            {"pos": 3, "head": 1, "relation": "continue"}, {"pos": 4, "head": 1, "relation": "continue"}]
    path = write_case(tmp_path, 4, recs)
    assert [p["position"] for p in state(path, pid(2))["pending"]] == [2]
    assert state(path, pid(3))["pending"] == []


def test_paragraph_root_is_null_before_it_appears(tmp_path):
    recs = with_changes(5, {4: {"head": "pending"}}, paragraph_starts=(1, 4))
    recs[3].pop("relation", None)
    recs[4].update({"head": 4, "relation": "continue"})
    paragraphs = [{"id": "p-1", "first": 1}, {"id": "p-2", "first": 4, "head": "p-1", "relation": "continue"}]
    report = state(write_case(tmp_path, 5, recs, paragraphs=paragraphs), pid(5))
    assert report["paragraph"] == {"id": "p-2", "root": None}
    assert [p["position"] for p in report["pending"]] == [4]


# ---------- scope ----------

SCOPE_SECTIONS = [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
    {"id": "sec-3", "heading": "Results", "role": "results", "first": 4},
    {"id": "sec-3-3", "heading": "The undetermined cases", "role": "results", "first": 7, "parent": "sec-3"},
]
SCOPE_CHANGES = {
    2: {"opens": [{"id": "c-plan-a", "kind": "plan"}]},
    5: {"opens": [{"id": "c-plan-b", "kind": "plan"}]},
    10: {"discharges": ["c-plan-a", "c-plan-b"]},
}


def test_spec_example_scope_ordering_prefers_the_inner_section(tmp_path):
    path = write_case(tmp_path, 10, with_changes(10, SCOPE_CHANGES, paragraph_starts=(1, 4, 7)), sections=SCOPE_SECTIONS)
    assert open_ids(state(path, pid(8), "--order", "kind")) == ["c-plan-a", "c-plan-b"]
    scoped = state(path, pid(8), "--order", "scope")
    assert open_ids(scoped) == ["c-plan-b", "c-plan-a"]
    assert scoped["order"] == "scope"


def test_open_commitments_carry_their_scope(tmp_path):
    path = write_case(tmp_path, 10, with_changes(10, SCOPE_CHANGES, paragraph_starts=(1, 4, 7)), sections=SCOPE_SECTIONS)
    scopes = {c["id"]: c["scope"] for c in state(path, pid(8))["open_commitments"]}
    assert scopes == {"c-plan-a": {"paragraph": "p-1", "section": "sec-1"},
                      "c-plan-b": {"paragraph": "p-2", "section": "sec-3"}}


def test_unknown_order_is_a_usage_error(tmp_path):
    assert run(write_case(tmp_path, 3), "end", "--order", "urgency").returncode == 2


def test_text_format_lists_open_commitments_in_order(tmp_path):
    result = run(write_case(tmp_path, 10, with_changes(10, SPEC_EXAMPLE)), pid(6))
    assert result.returncode == 0, result.stderr
    out = result.stdout
    assert out.index("c-ann-1") < out.index("c-plan-2") < out.index("c-q-1")
    assert "c-fw-1" in out
    assert "frontier" in out


# ---------- failure paths ----------


def test_unknown_position_is_an_input_error(tmp_path):
    result = run(write_case(tmp_path, 4), UUIDS[30])
    assert result.returncode == 2
    assert UUIDS[30] in result.stderr


def test_retired_position_is_an_input_error(tmp_path):
    result = run(write_case(tmp_path, 3, chain([1, 3]), retired=(2,)), pid(2))
    assert result.returncode == 2
    assert pid(2) in result.stderr


@pytest.mark.parametrize(
    "records",
    [
        chain([1, 3]),  # S1: #2 missing
        [{"pos": 1}, {"pos": 2, "head": 1, "relation": "elaboration"}, {"pos": 3, "head": 2, "relation": "continue"}],  # S2
        [{"pos": 1, "discharges": ["c-x"]}, {"pos": 2, "head": 1, "relation": "continue",
          "opens": [{"id": "c-x", "kind": "aim"}]}, {"pos": 3, "head": 2, "relation": "continue"}],  # S3
    ],
    ids=["S1", "S2", "S3"],
)
def test_structure_errors_block_the_query(tmp_path, records):
    result = run(write_case(tmp_path, 3, records), "end")
    assert result.returncode == 1
    assert "validate-structure.py" in result.stderr


def test_invalid_section_plan_blocks_the_query(tmp_path):
    sections = [{"id": "sec-1", "heading": "Literature", "role": "literature", "first": 1}]
    result = run(write_case(tmp_path, 4, sections=sections), pid(2))
    assert result.returncode == 1
    assert "validate-structure.py" in result.stderr


def test_version_1_0_is_an_input_error(tmp_path):
    result = run(write_case(tmp_path, 3, version="1.0"), "end")
    assert result.returncode == 2
    assert "migrate-structure-v2.py" in result.stderr


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
    assert report["paragraph"]["id"] == "p-6"


def test_fixture_frontier_in_the_introduction():
    # p-1: 1 -> 2 (root), 3 -> 2, 4 -> 3, 5 -> 4, 6 -> 2. At 5 the frontier is 5, 4, 3, 2.
    report = state(FIXTURE / "main.jsonl", "019a3c5e-7a00-7000-8000-000000000005")
    assert sentence_nodes(report) == [5, 4, 3, 2]


def test_state_reports_the_section_for_a_draft_without_thesis(tmp_path):
    report = state(write_case(tmp_path, 10, sections=SECTIONS, thesis=[]), pid(5))
    assert report["section"]["id"] == "sec-2"
    assert report["thesis_seen"] is False
