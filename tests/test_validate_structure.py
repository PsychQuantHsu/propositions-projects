"""Tests for validate-structure.py, format 2.0 (Spectra change add-discourse-dependency-tree).

Spec: openspec/changes/add-discourse-dependency-tree/specs/article-structure/spec.md
(the S1, S3, S4 and S6 requirements are unchanged from add-article-construction-model).

The structure sidecars (`structure.json`, `discourse.jsonl`) sit beside the
ledger. Each test builds the smallest ledger the rule needs in tmp_path, so the
cases map one-to-one onto the spec's example tables; only the fixture tests use
`tests/fixtures/structure/`.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from structure_case import UUIDS, chain, pid, with_changes, write_case, write_vocabulary  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPTS = REPO_ROOT / "plugins" / "propositions" / "scripts"
SCRIPT = SCRIPTS / "validate-structure.py"
VALIDATE_PROPS = REPO_ROOT / "scripts" / "validate-propositions.py"
FIXTURE = REPO_ROOT / "tests" / "fixtures" / "structure"
ALL_RULES = ("S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9")

RELATIONS = "continue, restatement, specification, instance, addition, contrast, reason, consequence, sequence, basis"
ROLES = "abstract, introduction, background, formal_setup, method, results, proofs, discussion, conclusion, appendix"


def run(ledger: Path, *flags: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--jsonl", str(ledger), *flags],
        capture_output=True,
        text=True,
    )


def status(stdout: str, rule: str) -> str:
    """PASS / FAIL / WARN from the summary line of `rule` (e.g. 'S1')."""
    for line in stdout.splitlines():
        for st in ("PASS", "FAIL", "WARN"):
            if line.startswith(f"[{st}] {rule} "):
                return st
    raise AssertionError(f"no summary line for {rule}:\n{stdout}")


def problems(stdout: str, rule: str) -> list[str]:
    return [l for l in stdout.splitlines() if l.lstrip().startswith(f"[{rule}]")]


# ---------- Requirement: Discourse records cover the ledger in reading order ----------

S1_ROWS = [
    # ledger A,B,C = positions 1,2,3; D = position 4 (not in the ledger)
    ("same order", [1, 2, 3], "PASS", None),
    ("missing B", [1, 3], "FAIL", "missing"),
    ("extra D", [1, 2, 3, 4], "FAIL", "extra"),
    ("duplicate B", [1, 2, 2, 3], "FAIL", "duplicate"),
    ("out of order", [1, 3, 2], "FAIL", "order"),
]


@pytest.mark.parametrize("name,order,expected,word", S1_ROWS, ids=[r[0] for r in S1_ROWS])
def test_s1_example_table(tmp_path, name, order, expected, word):
    ledger = write_case(tmp_path, 3, chain(order))
    result = run(ledger)
    assert status(result.stdout, "S1") == expected, result.stdout
    if word:
        assert any(word in l for l in problems(result.stdout, "S1")), result.stdout
        assert result.returncode == 1


def test_s1_missing_record_names_the_proposition(tmp_path):
    result = run(write_case(tmp_path, 3, chain([1, 3])))
    assert any(pid(2) in l and "missing" in l for l in problems(result.stdout, "S1")), result.stdout


def test_s1_retired_propositions_need_no_record(tmp_path):
    result = run(write_case(tmp_path, 3, chain([1, 3]), retired=(2,)))
    assert status(result.stdout, "S1") == "PASS", result.stdout


# ---------- Requirement: Relations form a closed vocabulary ----------

S2_RELATION_ROWS = [
    # record 3 of a four-proposition paragraph; its head is position 1
    ("consequence", {"head": 1, "relation": "consequence"}, "PASS"),
    ("basis", {"head": 1, "relation": "basis"}, "PASS"),
    ("capitalised", {"head": 1, "relation": "Consequence"}, "FAIL"),
    ("derived label return", {"head": 1, "relation": "return"}, "FAIL"),
    ("refers_to present", {"head": 1, "relation": "consequence", "refers_to": 1}, "FAIL"),
    ("head without relation", {"head": 1, "relation": None}, "FAIL"),
]


@pytest.mark.parametrize("name,change,expected", S2_RELATION_ROWS, ids=[r[0] for r in S2_RELATION_ROWS])
def test_s2_relation_example_table(tmp_path, name, change, expected):
    recs = with_changes(4, {3: change})
    if change.get("relation", "") is None:
        recs[2].pop("relation", None)
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S2") == expected, result.stdout
    if expected == "FAIL":
        assert result.returncode == 1
        assert any("#3 " in l for l in problems(result.stdout, "S2")), result.stdout


def test_s2_unlisted_relation_lists_the_ten_values(tmp_path):
    result = run(write_case(tmp_path, 4, with_changes(4, {3: {"relation": "elaboration"}})))
    assert status(result.stdout, "S2") == "FAIL"
    assert "{" + RELATIONS + "}" in result.stdout


def test_s2_derived_shift_is_not_a_relation(tmp_path):
    result = run(write_case(tmp_path, 4, with_changes(4, {3: {"relation": "shift"}})))
    assert status(result.stdout, "S2") == "FAIL"
    assert any("#3 " in l for l in problems(result.stdout, "S2")), result.stdout


def test_s2_a_root_carries_no_relation(tmp_path):
    result = run(write_case(tmp_path, 4, with_changes(4, {1: {"relation": "continue"}})))
    assert status(result.stdout, "S2") == "FAIL"
    assert any("#1 " in l for l in problems(result.stdout, "S2")), result.stdout


# ---------- Requirement: Propositions form a dependency tree within each paragraph ----------

S2_TREE_ROWS = [
    # one paragraph of positions 1-4; heads as {position: head position}, absent = root
    ("tree", {2: 1, 3: 2, 4: 2}, "PASS", None),
    ("forward head", {2: 3, 3: 1, 4: 3}, "PASS", None),
    ("two roots", {3: 2, 4: 1}, "FAIL", "root"),
    ("cycle", {2: 3, 3: 2, 4: 1}, "FAIL", "cycle"),
    ("names itself", {2: 2, 3: 1, 4: 1}, "FAIL", "itself"),
]


@pytest.mark.parametrize("name,heads,expected,word", S2_TREE_ROWS, ids=[r[0] for r in S2_TREE_ROWS])
def test_s2_tree_example_table(tmp_path, name, heads, expected, word):
    recs = [{"pos": p, **({"head": heads[p], "relation": "continue"} if p in heads else {})} for p in range(1, 5)]
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S2") == expected, result.stdout
    if word:
        assert any(word in l for l in problems(result.stdout, "S2")), result.stdout


TWO_PARAGRAPHS = [{"id": "p-1", "first": 1}, {"id": "p-2", "first": 4, "head": "p-1", "relation": "continue"}]


def test_s2_head_outside_the_paragraph_fails(tmp_path):
    recs = with_changes(6, {5: {"head": 3}}, paragraph_starts=(1, 4))
    result = run(write_case(tmp_path, 6, recs, paragraphs=TWO_PARAGRAPHS))
    assert status(result.stdout, "S2") == "FAIL", result.stdout
    assert any("#5 " in l for l in problems(result.stdout, "S2")), result.stdout


def test_s2_forward_head_passes(tmp_path):
    recs = with_changes(10, {7: {"head": 8, "relation": "reason"}, 8: {"head": 6}})
    result = run(write_case(tmp_path, 10, recs))
    assert status(result.stdout, "S2") == "PASS", result.stdout


def _pending_last(n: int = 5) -> list[dict]:
    recs = with_changes(n, {n: {"head": "pending"}})
    recs[-1].pop("relation", None)
    return recs


def test_s2_pending_fails_without_partial(tmp_path):
    result = run(write_case(tmp_path, 5, _pending_last()))
    assert status(result.stdout, "S2") == "FAIL", result.stdout
    assert any("#5 " in l and "pending" in l for l in problems(result.stdout, "S2")), result.stdout


def test_s2_pending_in_the_last_paragraph_passes_with_partial(tmp_path):
    result = run(write_case(tmp_path, 5, _pending_last()), "--partial")
    assert status(result.stdout, "S2") == "PASS", result.stdout
    assert result.returncode == 0, result.stdout


def test_s2_pending_outside_the_last_paragraph_fails(tmp_path):
    recs = with_changes(6, {2: {"head": "pending"}, 3: {"head": 1}}, paragraph_starts=(1, 4))
    recs[1].pop("relation", None)
    result = run(write_case(tmp_path, 6, recs, paragraphs=TWO_PARAGRAPHS), "--partial")
    assert status(result.stdout, "S2") == "FAIL", result.stdout
    assert any("#2 " in l for l in problems(result.stdout, "S2")), result.stdout


def test_s2_last_paragraph_whose_root_is_not_written_yet_passes_with_partial(tmp_path):
    # p-2 holds 4 and 5: 4 waits for its head, 5 hangs on 4; no root has been written yet.
    recs = with_changes(5, {4: {"head": "pending"}}, paragraph_starts=(1, 4))
    recs[3].pop("relation", None)
    recs[4].update({"head": 4, "relation": "continue"})
    paragraphs = [{"id": "p-1", "first": 1}, {"id": "p-2", "first": 4, "head": "p-1", "relation": "continue"}]
    result = run(write_case(tmp_path, 5, recs, paragraphs=paragraphs), "--partial")
    assert status(result.stdout, "S2") == "PASS", result.stdout


@pytest.mark.parametrize(
    "also,word",
    [
        ([{"to": 3, "relation": "contrast"}], "itself"),
        ([{"to": 2, "relation": "contrast"}], "head"),
        ([{"to": 1, "relation": "elaboration"}], "not in"),
        ([{"to": UUIDS[30], "relation": "contrast"}], "not a non-retired"),
    ],
    ids=["to-self", "to-head", "bad-relation", "unknown-target"],
)
def test_s2_also_entries_are_checked(tmp_path, also, word):
    result = run(write_case(tmp_path, 4, with_changes(4, {3: {"also": also}})))
    assert status(result.stdout, "S2") == "FAIL", result.stdout
    assert any(word in l for l in problems(result.stdout, "S2")), result.stdout


def test_s2_valid_also_passes(tmp_path):
    result = run(write_case(tmp_path, 4, with_changes(4, {4: {"also": [{"to": 1, "relation": "contrast"}]}})))
    assert status(result.stdout, "S2") == "PASS", result.stdout


# ---------- Requirement: Commitments are opened before they are discharged ----------


def test_s3_discharge_before_opening_fails(tmp_path):
    recs = with_changes(10, {3: {"discharges": ["c-aim-1"]}, 8: {"opens": [{"id": "c-aim-1", "kind": "aim"}]}})
    result = run(write_case(tmp_path, 10, recs))
    assert status(result.stdout, "S3") == "FAIL"
    assert any("#3 " in l for l in problems(result.stdout, "S3")), result.stdout


def test_s3_a_proposition_cannot_keep_its_own_promise(tmp_path):
    recs = with_changes(4, {2: {"opens": [{"id": "c-ann-1", "kind": "announcement"}], "discharges": ["c-ann-1"]}})
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S3") == "FAIL"
    assert any("#2 " in l for l in problems(result.stdout, "S3")), result.stdout


def test_s3_future_work_is_never_discharged(tmp_path):
    recs = with_changes(4, {2: {"opens": [{"id": "c-fw-1", "kind": "future_work"}]}, 4: {"discharges": ["c-fw-1"]}})
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S3") == "FAIL"
    assert any("#4 " in l for l in problems(result.stdout, "S3")), result.stdout


@pytest.mark.parametrize(
    "opens",
    [
        [{"id": "C_Aim", "kind": "aim"}],  # id breaks the pattern
        [{"id": "c-1", "kind": "goal"}],  # kind outside the seven
        [{"id": "c-1", "kind": "aim"}, {"id": "c-1", "kind": "question"}],  # duplicate id
        [{"id": "c-1"}],  # kind missing
    ],
    ids=["bad-id", "unknown-kind", "duplicate-id", "missing-kind"],
)
def test_s3_malformed_commitments_fail(tmp_path, opens):
    recs = with_changes(4, {2: {"opens": opens}, 3: {"discharges": [o["id"] for o in opens[:1]]}})
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S3") == "FAIL", result.stdout


def test_s3_unknown_kind_lists_the_seven_kinds(tmp_path):
    recs = with_changes(4, {2: {"opens": [{"id": "c-1", "kind": "goal"}]}, 3: {"discharges": ["c-1"]}})
    result = run(write_case(tmp_path, 4, recs))
    assert "{question, aim, hypothesis, plan, announcement, setup, future_work}" in result.stdout


# ---------- Requirement: A complete article keeps every commitment ----------

S4_ROWS = [
    # kind, complete-mode S4 status, exit code complete
    ("question", "FAIL", 1),
    ("aim", "FAIL", 1),
    ("hypothesis", "FAIL", 1),
    ("plan", "FAIL", 1),
    ("announcement", "FAIL", 1),
    ("setup", "WARN", 0),
]


@pytest.mark.parametrize("kind,expected,code", S4_ROWS, ids=[r[0] for r in S4_ROWS])
def test_s4_severity_by_kind_complete(tmp_path, kind, expected, code):
    recs = with_changes(4, {2: {"opens": [{"id": "c-x-1", "kind": kind}]}})
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S4") == expected, result.stdout
    assert result.returncode == code, result.stdout
    assert "c-x-1" in result.stdout


@pytest.mark.parametrize("kind", [r[0] for r in S4_ROWS])
def test_s4_partial_reports_open_commitments_as_info(tmp_path, kind):
    recs = with_changes(4, {2: {"opens": [{"id": "c-x-1", "kind": kind}]}})
    result = run(write_case(tmp_path, 4, recs), "--partial")
    assert status(result.stdout, "S4") == "PASS", result.stdout
    assert result.returncode == 0, result.stdout
    assert any("[INFO]" in l and "c-x-1" in l for l in result.stdout.splitlines()), result.stdout


@pytest.mark.parametrize("flags", [(), ("--partial",)], ids=["complete", "partial"])
def test_s4_future_work_is_not_reported(tmp_path, flags):
    recs = with_changes(4, {2: {"opens": [{"id": "c-fw-1", "kind": "future_work"}]}})
    result = run(write_case(tmp_path, 4, recs), *flags)
    assert status(result.stdout, "S4") == "PASS", result.stdout
    assert "c-fw-1" not in result.stdout
    assert result.returncode == 0


def test_s4_unanswered_question_names_the_opening_proposition(tmp_path):
    recs = with_changes(5, {1: {"opens": [{"id": "c-q-1", "kind": "question"}]}})
    result = run(write_case(tmp_path, 5, recs))
    assert any("c-q-1" in l and pid(1) in l for l in problems(result.stdout, "S4")), result.stdout
    assert result.returncode == 1


def test_s4_kept_commitment_passes(tmp_path):
    recs = with_changes(5, {1: {"opens": [{"id": "c-q-1", "kind": "question"}]}, 5: {"discharges": ["c-q-1"]}})
    result = run(write_case(tmp_path, 5, recs))
    assert status(result.stdout, "S4") == "PASS", result.stdout


# ---------- Requirement: The section plan follows ledger order ----------

TWO_SECTIONS = [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
    {"id": "sec-2", "heading": "Method", "role": "method", "first": 4},
]


def test_s5_valid_plan_passes(tmp_path):
    result = run(write_case(tmp_path, 6, sections=TWO_SECTIONS))
    assert status(result.stdout, "S5") == "PASS", result.stdout


def test_s5_sections_out_of_order_fail(tmp_path):
    sections = [
        {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
        {"id": "sec-2", "heading": "Method", "role": "method", "first": 5},
        {"id": "sec-3", "heading": "Results", "role": "results", "first": 3},
    ]
    paragraphs = [{"id": "p-1", "first": 1}, {"id": "p-2", "first": 3}, {"id": "p-3", "first": 5}]
    result = run(write_case(tmp_path, 6, sections=sections, paragraphs=paragraphs))
    assert status(result.stdout, "S5") == "FAIL"
    assert any("sec-2" in l and "sec-3" in l for l in problems(result.stdout, "S5")), result.stdout


def test_s5_unlisted_role_lists_the_ten_roles(tmp_path):
    sections = [{"id": "sec-1", "heading": "Literature", "role": "literature", "first": 1}]
    result = run(write_case(tmp_path, 3, sections=sections))
    assert status(result.stdout, "S5") == "FAIL"
    assert "{" + ROLES + "}" in result.stdout


@pytest.mark.parametrize(
    "sections,thesis",
    [
        ([{"id": "sec-1", "heading": "Intro", "role": "introduction", "first": 2}], [2]),  # not from prop 1
        (TWO_SECTIONS[:1] + [{"id": "sec-1", "heading": "Method", "role": "method", "first": 4}], [1]),  # dup id
        (TWO_SECTIONS, []),  # empty thesis
    ],
    ids=["first-section-late", "duplicate-section-id", "empty-thesis"],
)
def test_s5_plan_shape_failures(tmp_path, sections, thesis):
    result = run(write_case(tmp_path, 6, sections=sections, thesis=thesis))
    assert status(result.stdout, "S5") == "FAIL", result.stdout


def test_s5_first_prop_must_be_in_the_ledger(tmp_path):
    ledger = write_case(tmp_path, 6, sections=TWO_SECTIONS)
    structure = json.loads((tmp_path / "structure.json").read_text())
    structure["sections"][1]["first_prop"] = UUIDS[30]
    (tmp_path / "structure.json").write_text(json.dumps(structure))
    result = run(ledger)
    assert status(result.stdout, "S5") == "FAIL", result.stdout


def test_s5_thesis_must_not_be_retired(tmp_path):
    result = run(write_case(tmp_path, 4, chain([1, 3, 4]), thesis=[2], retired=(2,)))
    assert status(result.stdout, "S5") == "FAIL", result.stdout


def test_s5_parent_naming_an_earlier_section_passes(tmp_path):
    sections = TWO_SECTIONS[:1] + [{**TWO_SECTIONS[1], "parent": "sec-1"}]
    result = run(write_case(tmp_path, 6, sections=sections))
    assert status(result.stdout, "S5") == "PASS", result.stdout


def test_s5_parent_must_come_earlier(tmp_path):
    sections = [
        {"id": "sec-3", "heading": "Results", "role": "results", "first": 1, "parent": "sec-3-1"},
        {"id": "sec-3-1", "heading": "Scores", "role": "results", "first": 4},
    ]
    result = run(write_case(tmp_path, 6, sections=sections))
    assert status(result.stdout, "S5") == "FAIL"
    assert any("sec-3" in l and "parent" in l for l in problems(result.stdout, "S5")), result.stdout


def test_s5_parent_must_name_a_section(tmp_path):
    sections = TWO_SECTIONS[:1] + [{**TWO_SECTIONS[1], "parent": "sec-9"}]
    result = run(write_case(tmp_path, 6, sections=sections))
    assert status(result.stdout, "S5") == "FAIL", result.stdout


# ---------- Requirement: Paragraphs form a dependency tree within each section ----------


def test_s5_paragraph_that_crosses_a_section_boundary_fails(tmp_path):
    paragraphs = [{"id": "p-1", "first": 1}, {"id": "p-2", "first": 3, "head": "p-1", "relation": "continue"}]
    result = run(write_case(tmp_path, 6, sections=TWO_SECTIONS, paragraphs=paragraphs))
    assert status(result.stdout, "S5") == "FAIL"
    assert any("sec-2" in l and "p-2" in l for l in problems(result.stdout, "S5")), result.stdout


EIGHT_TWO_SECTIONS = [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
    {"id": "sec-2", "heading": "Method", "role": "method", "first": 5},
]


def test_s5_paragraph_head_in_another_section_fails(tmp_path):
    paragraphs = [
        {"id": "p-1", "first": 1},
        {"id": "p-2", "first": 3, "head": "p-1", "relation": "continue"},
        {"id": "p-3", "first": 5},
        {"id": "p-4", "first": 7, "head": "p-2", "relation": "continue"},
    ]
    result = run(write_case(tmp_path, 8, sections=EIGHT_TWO_SECTIONS, paragraphs=paragraphs))
    assert status(result.stdout, "S5") == "FAIL"
    assert any("p-4" in l for l in problems(result.stdout, "S5")), result.stdout


@pytest.mark.parametrize(
    "paragraphs,word",
    [
        ([{"id": "p-1", "first": 1}, {"id": "p-2", "first": 3}], "root"),
        ([{"id": "p-1", "first": 1, "head": "p-2", "relation": "continue"},
          {"id": "p-2", "first": 3, "head": "p-1", "relation": "continue"}], "cycle"),
        ([{"id": "p-1", "first": 1}, {"id": "p-2", "first": 3, "head": "p-1"}], "relation"),
        ([{"id": "p-1", "first": 1}, {"id": "p-2", "first": 3, "head": "p-1", "relation": "elaboration"}], "not in"),
        ([{"id": "p-1", "first": 1, "relation": "continue"}, {"id": "p-2", "first": 3, "head": "p-1", "relation": "continue"}], "root"),
        ([{"id": "p-1", "first": 2}], "first"),
        ([{"id": "p-1", "first": 1}, {"id": "p-2", "first": 5, "head": "p-1", "relation": "continue"},
          {"id": "p-3", "first": 3, "head": "p-1", "relation": "continue"}], "order"),
        ([{"id": "p-1", "first": 1}, {"id": "p-1", "first": 3, "head": "p-1", "relation": "continue"}], "duplicate"),
    ],
    ids=["two-roots", "cycle", "head-without-relation", "bad-relation", "root-with-relation",
         "late-start", "out-of-order", "duplicate-id"],
)
def test_s5_paragraph_plan_failures(tmp_path, paragraphs, word):
    result = run(write_case(tmp_path, 6, paragraphs=paragraphs))
    assert status(result.stdout, "S5") == "FAIL", result.stdout
    assert any(word in l for l in problems(result.stdout, "S5")), result.stdout


def test_s5_valid_paragraph_tree_passes(tmp_path):
    result = run(write_case(tmp_path, 6, paragraphs=TWO_PARAGRAPHS))
    assert status(result.stdout, "S5") == "PASS", result.stdout


# ---------- Requirement: Announcements are kept nearby ----------

FOUR_SECTIONS = [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
    {"id": "sec-2", "heading": "Method", "role": "method", "first": 4},
    {"id": "sec-3", "heading": "Results", "role": "results", "first": 7},
    {"id": "sec-4", "heading": "Discussion", "role": "discussion", "first": 10},
]
FOUR_STARTS = (1, 4, 7, 10)


def test_s6_announcement_kept_in_next_section_passes(tmp_path):
    # Position 3 is the last proposition of sec-1; position 4 opens sec-2.
    recs = with_changes(12, {3: {"opens": [{"id": "c-ann-1", "kind": "announcement"}]}, 4: {"discharges": ["c-ann-1"]}},
                        paragraph_starts=FOUR_STARTS)
    result = run(write_case(tmp_path, 12, recs, sections=FOUR_SECTIONS))
    assert status(result.stdout, "S6") == "PASS", result.stdout


def test_s6_announcement_kept_two_sections_later_warns(tmp_path):
    recs = with_changes(12, {5: {"opens": [{"id": "c-ann-1", "kind": "announcement"}]}, 11: {"discharges": ["c-ann-1"]}},
                        paragraph_starts=FOUR_STARTS)
    result = run(write_case(tmp_path, 12, recs, sections=FOUR_SECTIONS))
    assert status(result.stdout, "S6") == "WARN", result.stdout
    assert result.returncode == 0, result.stdout


# ---------- Requirement: Crossing arcs are reported as warnings ----------


def test_s7_crossing_arcs_are_flagged(tmp_path):
    # 1 root; 2 -> 4; 3 -> 1; 4 -> 1: arcs (2, 4) and (1, 3) cross.
    recs = [{"pos": 1}, {"pos": 2, "head": 4, "relation": "reason"},
            {"pos": 3, "head": 1, "relation": "continue"}, {"pos": 4, "head": 1, "relation": "continue"}]
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S7") == "WARN", result.stdout
    assert result.returncode == 0, result.stdout
    s7 = problems(result.stdout, "S7")
    assert any("(2, 4)" in l and "(1, 3)" in l for l in s7), result.stdout


def test_s7_nested_arcs_are_not_crossing(tmp_path):
    # 1 root; 2 -> 3; 3 -> 1; 4 -> 1: arcs (2, 3) and (1, 4) nest.
    recs = [{"pos": 1}, {"pos": 2, "head": 3, "relation": "reason"},
            {"pos": 3, "head": 1, "relation": "continue"}, {"pos": 4, "head": 1, "relation": "continue"}]
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S7") == "PASS", result.stdout


def test_s7_crossing_paragraph_arcs_are_flagged(tmp_path):
    paragraphs = [
        {"id": "p-1", "first": 1},
        {"id": "p-2", "first": 3, "head": "p-4", "relation": "reason"},
        {"id": "p-3", "first": 5, "head": "p-1", "relation": "continue"},
        {"id": "p-4", "first": 7, "head": "p-1", "relation": "continue"},
    ]
    result = run(write_case(tmp_path, 8, paragraphs=paragraphs))
    assert status(result.stdout, "S7") == "WARN", result.stdout
    assert any("p-2" in l and "p-3" in l for l in problems(result.stdout, "S7")), result.stdout


# ---------- Requirement: Basis edges agree with the ledger's cites ----------


def test_s8_basis_without_a_cite_is_flagged(tmp_path):
    result = run(write_case(tmp_path, 4, with_changes(4, {3: {"relation": "basis"}})))
    assert status(result.stdout, "S8") == "WARN", result.stdout
    assert result.returncode == 0, result.stdout
    assert any(pid(3) in l and pid(2) in l for l in problems(result.stdout, "S8")), result.stdout


def test_s8_basis_with_a_cite_passes(tmp_path):
    result = run(write_case(tmp_path, 4, with_changes(4, {3: {"relation": "basis"}}), cites={3: [2]}))
    assert status(result.stdout, "S8") == "PASS", result.stdout


def test_s8_also_basis_is_checked(tmp_path):
    recs = with_changes(4, {4: {"also": [{"to": 1, "relation": "basis"}]}})
    assert status(run(write_case(tmp_path, 4, recs)).stdout, "S8") == "WARN"


# ---------- Requirement: Structure validation reports per rule with fixed exit codes ----------


def test_summary_line_for_every_rule(tmp_path):
    result = run(write_case(tmp_path, 3))
    for rule in ALL_RULES:
        assert status(result.stdout, rule) == "PASS", result.stdout
    assert result.returncode == 0


def test_warnings_alone_do_not_fail_validation(tmp_path):
    recs = with_changes(4, {2: {"opens": [{"id": "c-setup-1", "kind": "setup"}]}})
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S4") == "WARN"
    assert result.returncode == 0


def test_invalid_json_line_is_an_input_error(tmp_path):
    ledger = write_case(tmp_path, 5)
    lines = (tmp_path / "discourse.jsonl").read_text().splitlines()
    lines[3] = "{not json"
    (tmp_path / "discourse.jsonl").write_text("\n".join(lines) + "\n")
    result = run(ledger)
    assert result.returncode == 2
    assert "line 4" in result.stderr


@pytest.mark.parametrize("version", ["1.0", None, "2"], ids=["1.0", "missing", "other"])
def test_version_other_than_2_0_is_refused(tmp_path, version):
    result = run(write_case(tmp_path, 3, version=version))
    assert result.returncode == 2, result.stdout + result.stderr
    assert "migrate-structure-v2.py" in result.stderr


@pytest.mark.parametrize("missing", ["discourse.jsonl", "structure.json"])
def test_missing_sidecar_is_an_input_error(tmp_path, missing):
    ledger = write_case(tmp_path, 3)
    (tmp_path / missing).unlink()
    result = run(ledger)
    assert result.returncode == 2
    assert missing in result.stderr


def test_missing_ledger_is_an_input_error(tmp_path):
    result = run(tmp_path / "main.jsonl")
    assert result.returncode == 2
    assert "main.jsonl" in result.stderr


def test_explicit_sidecar_paths(tmp_path):
    ledger = write_case(tmp_path, 3)
    elsewhere = tmp_path / "staging"
    elsewhere.mkdir()
    for name in ("structure.json", "discourse.jsonl"):
        (tmp_path / name).rename(elsewhere / name)
    result = run(ledger, "--structure", str(elsewhere / "structure.json"), "--discourse", str(elsewhere / "discourse.jsonl"))
    assert result.returncode == 0, result.stdout + result.stderr


def test_json_format_reports_every_rule(tmp_path):
    recs = with_changes(4, {2: {"opens": [{"id": "c-setup-1", "kind": "setup"}]}})
    result = run(write_case(tmp_path, 4, recs), "--format", "json")
    report = json.loads(result.stdout)
    statuses = {r["rule"]: r["status"] for r in report["rules"]}
    assert statuses == {r: "PASS" for r in ALL_RULES} | {"S4": "WARN"}
    assert result.returncode == 0


# ---------- Fixture: the synthetic article passes every rule ----------


def test_fixture_passes_every_rule():
    result = run(FIXTURE / "main.jsonl")
    for rule in ALL_RULES:
        assert status(result.stdout, rule) == "PASS", result.stdout
    assert result.returncode == 0


# ---------- Requirement: Structure sidecars sit beside the ledger without changing it ----------


def _validate_props(directory: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(VALIDATE_PROPS), "--jsonl", "main.jsonl", "--meta", "_meta.json", "--tex", "main.tex"],
        capture_output=True,
        text=True,
        cwd=directory,
    )


def test_sidecars_do_not_change_validate_propositions_output(tmp_path):
    with_sidecars = tmp_path / "with"
    without = tmp_path / "without"
    shutil.copytree(FIXTURE, with_sidecars)
    shutil.copytree(FIXTURE, without)
    for name in ("structure.json", "discourse.jsonl"):
        (without / name).unlink()
    a, b = _validate_props(with_sidecars), _validate_props(without)
    assert a.stdout == b.stdout
    assert a.returncode == b.returncode == 0


# ---------- Vocabulary documents match the validator's constants ----------

import importlib.util  # noqa: E402
import re  # noqa: E402

DOCS = {
    "STRUCTURE.md": REPO_ROOT / "plugins" / "propositions" / "docs" / "STRUCTURE.md",
    "vocabulary.md": REPO_ROOT / "plugins" / "propositions" / "skills" / "construct" / "references" / "vocabulary.md",
}
VOCAB_HEADINGS = {"RELATIONS": "Relations (10)", "KINDS": "Commitment kinds (7)", "ROLES": "Section roles (10)"}


def _validator_module():
    spec = importlib.util.spec_from_file_location("validate_structure_consts", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _table_values(text: str, heading: str) -> list[str]:
    """First-column backticked values of the table under the heading that ends with `heading`."""
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith("#") and l.rstrip().endswith(heading))
    values = []
    for line in lines[start + 1:]:
        if line.startswith("#"):
            break
        m = re.match(r"^\|\s*`([^`]+)`\s*\|", line)
        if m:
            values.append(m.group(1))
    return values


@pytest.mark.parametrize("doc", list(DOCS), ids=list(DOCS))
@pytest.mark.parametrize("const", list(VOCAB_HEADINGS), ids=list(VOCAB_HEADINGS))
def test_vocabulary_documents_match_validator_constants(doc, const):
    expected = list(getattr(_validator_module(), const))
    assert _table_values(DOCS[doc].read_text(encoding="utf-8"), VOCAB_HEADINGS[const]) == expected


# ---------- Partial drafts may not have stated their thesis yet ----------


def test_s5_partial_draft_without_thesis_passes(tmp_path):
    result = run(write_case(tmp_path, 4, thesis=[]), "--partial")
    assert status(result.stdout, "S5") == "PASS", result.stdout
    assert any("[INFO]" in l and "thesis" in l for l in result.stdout.splitlines()), result.stdout
    assert result.returncode == 0


def test_s6_still_runs_when_only_the_thesis_is_wrong(tmp_path):
    recs = with_changes(12, {5: {"opens": [{"id": "c-ann-1", "kind": "announcement"}]}, 11: {"discharges": ["c-ann-1"]}},
                        paragraph_starts=FOUR_STARTS)
    result = run(write_case(tmp_path, 12, recs, sections=FOUR_SECTIONS, thesis=[]))
    assert status(result.stdout, "S5") == "FAIL"
    assert status(result.stdout, "S6") == "WARN"
    assert "not evaluated" not in result.stdout


# ---------- The abstract role ----------

ABSTRACT_FIRST = [
    {"id": "sec-abstract", "heading": "Abstract", "role": "abstract", "first": 1},
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 4},
]


def test_s5_abstract_as_first_section_passes(tmp_path):
    result = run(write_case(tmp_path, 6, sections=ABSTRACT_FIRST))
    assert status(result.stdout, "S5") == "PASS", result.stdout


def test_s5_abstract_after_another_section_fails(tmp_path):
    sections = [
        {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
        {"id": "sec-abstract", "heading": "Abstract", "role": "abstract", "first": 4},
    ]
    result = run(write_case(tmp_path, 6, sections=sections))
    assert status(result.stdout, "S5") == "FAIL"
    assert any("sec-abstract" in l for l in problems(result.stdout, "S5")), result.stdout


def test_s5_abstract_may_not_open_commitments(tmp_path):
    recs = with_changes(6, {2: {"opens": [{"id": "c-aim-1", "kind": "aim"}]}, 5: {"discharges": ["c-aim-1"]}},
                        paragraph_starts=(1, 4))
    result = run(write_case(tmp_path, 6, recs, sections=ABSTRACT_FIRST))
    assert status(result.stdout, "S5") == "FAIL"
    assert any("#2 " in l and "c-aim-1" in l for l in problems(result.stdout, "S5")), result.stdout


def test_s5_body_commitments_are_unaffected_by_the_abstract_rule(tmp_path):
    recs = with_changes(6, {4: {"opens": [{"id": "c-aim-1", "kind": "aim"}]}, 6: {"discharges": ["c-aim-1"]}},
                        paragraph_starts=(1, 4))
    result = run(write_case(tmp_path, 6, recs, sections=ABSTRACT_FIRST))
    assert status(result.stdout, "S5") == "PASS", result.stdout


# ---------- S9: moves and paragraph types (Spectra change add-paragraph-moves) ----------


def run_without_yaml(ledger: Path, *flags: str) -> subprocess.CompletedProcess:
    code = (
        "import runpy, sys\n"
        "sys.modules['yaml'] = None\n"
        f"sys.argv = ['validate-structure.py', '--jsonl', {str(ledger)!r}, *{list(flags)!r}]\n"
        f"runpy.run_path({str(SCRIPT)!r}, run_name='__main__')\n"
    )
    return subprocess.run([sys.executable, "-c", code], capture_output=True, text=True)


def test_s9_unknown_move_fails(tmp_path: Path) -> None:
    ledger = write_case(tmp_path, 3, with_changes(3, {2: {"move": "state-gaol"}}))
    result = run(ledger, "--vocabulary", str(write_vocabulary(tmp_path)))
    assert result.returncode == 1, result.stdout
    assert status(result.stdout, "S9") == "FAIL"
    assert any(pid(2) in l and "state-gaol" in l for l in problems(result.stdout, "S9"))


def test_s9_unknown_paragraph_type_fails(tmp_path: Path) -> None:
    ledger = write_case(tmp_path, 3, paragraphs=[{"id": "p-1", "first": 1, "type": "summary"}])
    result = run(ledger, "--vocabulary", str(write_vocabulary(tmp_path)))
    assert result.returncode == 1, result.stdout
    assert any("p-1" in l and "summary" in l for l in problems(result.stdout, "S9"))


def test_s9_known_values_pass(tmp_path: Path) -> None:
    ledger = write_case(
        tmp_path, 3, with_changes(3, {1: {"move": "state-goal"}, 2: {"move": "state-baseline"}}),
        paragraphs=[{"id": "p-1", "first": 1, "type": "goal-summary"}],
    )
    result = run(ledger, "--vocabulary", str(write_vocabulary(tmp_path)))
    assert result.returncode == 0, result.stdout
    assert status(result.stdout, "S9") == "PASS"


def test_s9_move_must_be_a_string(tmp_path: Path) -> None:
    ledger = write_case(tmp_path, 3, with_changes(3, {2: {"move": 7}}))
    result = run(ledger, "--vocabulary", str(write_vocabulary(tmp_path)))
    assert result.returncode == 1
    assert status(result.stdout, "S9") == "FAIL"


def test_s9_sidecars_without_moves_need_no_vocabulary(tmp_path: Path) -> None:
    ledger = write_case(tmp_path, 3)
    result = run_without_yaml(ledger, "--vocabulary", str(tmp_path / "absent.yaml"))
    assert result.returncode == 0, result.stdout + result.stderr
    assert status(result.stdout, "S9") == "PASS"


def test_s9_missing_parser_is_an_input_error(tmp_path: Path) -> None:
    ledger = write_case(tmp_path, 3, with_changes(3, {2: {"move": "state-goal"}}))
    result = run_without_yaml(ledger, "--vocabulary", str(write_vocabulary(tmp_path)))
    assert result.returncode == 2, result.stdout + result.stderr
    assert "PyYAML" in result.stderr


def test_s9_unusual_order_is_not_reported(tmp_path: Path) -> None:
    ledger = write_case(
        tmp_path, 3, with_changes(3, {1: {"move": "state-concern"}, 2: {"move": "state-goal"}, 3: {"move": "state-concern"}}),
    )
    result = run(ledger, "--vocabulary", str(write_vocabulary(tmp_path)))
    assert result.returncode == 0, result.stdout
    assert problems(result.stdout, "S9") == []


def test_s9_broken_vocabulary_is_an_input_error(tmp_path: Path) -> None:
    broken = (
        "moves:\n  - {id: state-goal, does: a., zh: 甲}\n  - {id: state-goal, does: b., zh: 乙}\n"
        "paragraph_types: []\n"
    )
    ledger = write_case(tmp_path, 3, with_changes(3, {2: {"move": "state-goal"}}))
    result = run(ledger, "--vocabulary", str(write_vocabulary(tmp_path, broken)))
    assert result.returncode == 2
    assert "state-goal" in result.stderr


def test_s9_default_vocabulary_ships_with_the_plugin(tmp_path: Path) -> None:
    ledger = write_case(tmp_path, 3, with_changes(3, {1: {"move": "state-goal"}}))
    result = run(ledger)
    assert status(result.stdout, "S9") == "PASS", result.stdout + result.stderr


def test_fixture_notes_mark_close_calls_only() -> None:
    """The shipped fixture is the example annotators copy: a `note` names a runner-up (#34)."""
    records = [json.loads(line) for line in (FIXTURE / "discourse.jsonl").read_text().splitlines() if line.strip()]
    notes = [r["note"] for r in records if r.get("note")]
    assert 0 < len(notes) < len(records) / 2, f"{len(notes)} of {len(records)} records carry a note"
    assert all(n.startswith("runner-up: ") and "lost because" in n for n in notes), notes


NOTE_CONTRACT = "runner-up: <the other choice>; lost because <reason>"
NOTE_CONTRACT_SOURCES = (
    "plugins/propositions/skills/construct/references/vocabulary.md",
    "plugins/propositions/docs/STRUCTURE.md",
    "plugins/propositions/scripts/structure-batch.py",
    "plugins/propositions/skills/construct/SKILL.md",
    "plugins/propositions/skills/construct-batch/SKILL.md",
)


@pytest.mark.parametrize("source", NOTE_CONTRACT_SOURCES)
def test_note_contract_is_stated_where_prompts_are_written_from(source: str) -> None:
    """Every place an annotator's prompt is built from states the same note contract (#34)."""
    assert NOTE_CONTRACT in (REPO_ROOT / source).read_text(encoding="utf-8")


def test_batch_format_shows_note_as_optional() -> None:
    """The answer shape in the batch docstring must not draw `note` as a field every entry has (#34)."""
    doc = (SCRIPTS / "structure-batch.py").read_text(encoding="utf-8").split('"""')[1]
    shape = doc[doc.index("An output file is:"):doc.index("With --moves-only")]
    assert '["note":' in shape and '"note": str' not in shape, shape
