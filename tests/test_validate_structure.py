"""Tests for validate-structure.py (Spectra change add-article-construction-model).

Spec: openspec/changes/add-article-construction-model/specs/article-structure/spec.md

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
from structure_case import UUIDS, default_records, pid, with_changes, write_case  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPTS = REPO_ROOT / "plugins" / "propositions" / "scripts"
SCRIPT = SCRIPTS / "validate-structure.py"
VALIDATE_PROPS = REPO_ROOT / "scripts" / "validate-propositions.py"
FIXTURE = REPO_ROOT / "tests" / "fixtures" / "structure"

RELATIONS = (
    "start, shift, continue, restatement, specification, instance, addition, "
    "contrast, reason, consequence, sequence, return"
)
ROLES = "introduction, background, formal_setup, method, results, proofs, discussion, conclusion, appendix"


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
    # The ledger has three props (A, B, C); position 4 (D) exists only in the sidecar.
    records = [{"pos": p, "relation": "start" if i == 0 else "continue"} for i, p in enumerate(order)]
    ledger = write_case(tmp_path, 3, records)
    result = run(ledger)
    assert status(result.stdout, "S1") == expected, result.stdout
    if word:
        problems = [l for l in result.stdout.splitlines() if l.lstrip().startswith("[S1]")]
        assert any(word in l for l in problems), result.stdout
        assert result.returncode == 1


def test_s1_missing_record_names_the_proposition(tmp_path):
    ledger = write_case(tmp_path, 3, [{"pos": 1, "relation": "start"}, {"pos": 3, "relation": "continue"}])
    result = run(ledger)
    s1 = [l for l in result.stdout.splitlines() if l.lstrip().startswith("[S1]")]
    assert any(pid(2) in l and "missing" in l for l in s1), result.stdout


def test_s1_retired_propositions_need_no_record(tmp_path):
    ledger = write_case(
        tmp_path, 3, [{"pos": 1, "relation": "start"}, {"pos": 3, "relation": "continue"}], retired=(2,)
    )
    result = run(ledger)
    assert status(result.stdout, "S1") == "PASS", result.stdout


# ---------- Requirement: Relations form a closed vocabulary ----------

S2_ROWS = [
    # (position, relation, refers_to position or None, expected)
    ("start at 1", 1, "start", None, "PASS"),
    ("continue at 1", 1, "continue", None, "FAIL"),
    ("start at 5", 5, "start", None, "FAIL"),
    ("return to 4", 9, "return", 4, "PASS"),
    ("return without target", 9, "return", None, "FAIL"),
    ("refers_to on consequence", 9, "consequence", 4, "FAIL"),
    ("capitalised value", 9, "Consequence", None, "FAIL"),
]


@pytest.mark.parametrize("name,pos,relation,target,expected", S2_ROWS, ids=[r[0] for r in S2_ROWS])
def test_s2_example_table(tmp_path, name, pos, relation, target, expected):
    change = {"relation": relation}
    if target is not None:
        change["refers_to"] = target
    ledger = write_case(tmp_path, 10, with_changes(10, {pos: change}))
    result = run(ledger)
    assert status(result.stdout, "S2") == expected, result.stdout
    if expected == "FAIL":
        assert result.returncode == 1
        assert any(l.lstrip().startswith("[S2]") and f"#{pos} " in l for l in result.stdout.splitlines()), result.stdout


def test_s2_unlisted_relation_lists_the_twelve_values(tmp_path):
    ledger = write_case(tmp_path, 4, with_changes(4, {3: {"relation": "elaboration"}}))
    result = run(ledger)
    assert status(result.stdout, "S2") == "FAIL"
    assert "{" + RELATIONS + "}" in result.stdout


def test_s2_return_must_point_backwards(tmp_path):
    ledger = write_case(tmp_path, 10, with_changes(10, {7: {"relation": "return", "refers_to": 9}}))
    result = run(ledger)
    assert status(result.stdout, "S2") == "FAIL"
    assert any(l.lstrip().startswith("[S2]") and "#7 " in l for l in result.stdout.splitlines()), result.stdout


# ---------- Requirement: Commitments are opened before they are discharged ----------


def test_s3_discharge_before_opening_fails(tmp_path):
    recs = with_changes(10, {3: {"discharges": ["c-aim-1"]}, 8: {"opens": [{"id": "c-aim-1", "kind": "aim"}]}})
    result = run(write_case(tmp_path, 10, recs))
    assert status(result.stdout, "S3") == "FAIL"
    assert any(l.lstrip().startswith("[S3]") and "#3 " in l for l in result.stdout.splitlines()), result.stdout


def test_s3_a_proposition_cannot_keep_its_own_promise(tmp_path):
    recs = with_changes(4, {2: {"opens": [{"id": "c-ann-1", "kind": "announcement"}], "discharges": ["c-ann-1"]}})
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S3") == "FAIL"
    assert any(l.lstrip().startswith("[S3]") and "#2 " in l for l in result.stdout.splitlines()), result.stdout


def test_s3_future_work_is_never_discharged(tmp_path):
    recs = with_changes(4, {2: {"opens": [{"id": "c-fw-1", "kind": "future_work"}]}, 4: {"discharges": ["c-fw-1"]}})
    result = run(write_case(tmp_path, 4, recs))
    assert status(result.stdout, "S3") == "FAIL"
    assert any(l.lstrip().startswith("[S3]") and "#4 " in l for l in result.stdout.splitlines()), result.stdout


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
    s4 = [l for l in result.stdout.splitlines() if l.lstrip().startswith("[S4]")]
    assert any("c-q-1" in l and pid(1) in l for l in s4), result.stdout
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
    result = run(write_case(tmp_path, 6, sections=sections))
    assert status(result.stdout, "S5") == "FAIL"
    s5 = [l for l in result.stdout.splitlines() if l.lstrip().startswith("[S5]")]
    assert any("sec-2" in l and "sec-3" in l for l in s5), result.stdout


def test_s5_unlisted_role_lists_the_nine_roles(tmp_path):
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
    result = run(write_case(tmp_path, 4, thesis=[2], retired=(2,), records=[
        {"pos": 1, "relation": "start"}, {"pos": 3, "relation": "continue"}, {"pos": 4, "relation": "continue"}]))
    assert status(result.stdout, "S5") == "FAIL", result.stdout


def test_s5_missing_structure_version_fails(tmp_path):
    ledger = write_case(tmp_path, 3)
    structure = json.loads((tmp_path / "structure.json").read_text())
    del structure["structure_version"]
    (tmp_path / "structure.json").write_text(json.dumps(structure))
    assert status(run(ledger).stdout, "S5") == "FAIL"


# ---------- Requirement: Announcements are kept nearby ----------

FOUR_SECTIONS = [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
    {"id": "sec-2", "heading": "Method", "role": "method", "first": 4},
    {"id": "sec-3", "heading": "Results", "role": "results", "first": 7},
    {"id": "sec-4", "heading": "Discussion", "role": "discussion", "first": 10},
]


def test_s6_announcement_kept_in_next_section_passes(tmp_path):
    # Position 3 is the last proposition of sec-1; position 4 opens sec-2.
    recs = with_changes(12, {3: {"opens": [{"id": "c-ann-1", "kind": "announcement"}]}, 4: {"discharges": ["c-ann-1"]}})
    result = run(write_case(tmp_path, 12, recs, sections=FOUR_SECTIONS))
    assert status(result.stdout, "S6") == "PASS", result.stdout


def test_s6_announcement_kept_two_sections_later_warns(tmp_path):
    recs = with_changes(12, {5: {"opens": [{"id": "c-ann-1", "kind": "announcement"}]}, 11: {"discharges": ["c-ann-1"]}})
    result = run(write_case(tmp_path, 12, recs, sections=FOUR_SECTIONS))
    assert status(result.stdout, "S6") == "WARN", result.stdout
    assert result.returncode == 0, result.stdout


# ---------- Requirement: Structure validation reports per rule with fixed exit codes ----------


def test_summary_line_for_every_rule(tmp_path):
    result = run(write_case(tmp_path, 3))
    for rule in ("S1", "S2", "S3", "S4", "S5", "S6"):
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
    assert statuses == {"S1": "PASS", "S2": "PASS", "S3": "PASS", "S4": "WARN", "S5": "PASS", "S6": "PASS"}
    assert result.returncode == 0


# ---------- Fixture: the synthetic article passes every rule ----------


def test_fixture_passes_every_rule():
    result = run(FIXTURE / "main.jsonl")
    for rule in ("S1", "S2", "S3", "S4", "S5", "S6"):
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


# ---------- Vocabulary documents match the validator's constants (task 4.1) ----------

import importlib.util  # noqa: E402
import re  # noqa: E402

DOCS = {
    "STRUCTURE.md": REPO_ROOT / "plugins" / "propositions" / "docs" / "STRUCTURE.md",
    "vocabulary.md": REPO_ROOT / "plugins" / "propositions" / "skills" / "construct" / "references" / "vocabulary.md",
}
VOCAB_HEADINGS = {"RELATIONS": "Relations (12)", "KINDS": "Commitment kinds (7)", "ROLES": "Section roles (9)"}


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


# ---------- Partial drafts may not have stated their thesis yet (found while doing task 4.3) ----------


def test_s5_partial_draft_without_thesis_passes(tmp_path):
    result = run(write_case(tmp_path, 4, thesis=[]), "--partial")
    assert status(result.stdout, "S5") == "PASS", result.stdout
    assert any("[INFO]" in l and "thesis" in l for l in result.stdout.splitlines()), result.stdout
    assert result.returncode == 0


def test_s6_still_runs_when_only_the_thesis_is_wrong(tmp_path):
    recs = with_changes(12, {5: {"opens": [{"id": "c-ann-1", "kind": "announcement"}]}, 11: {"discharges": ["c-ann-1"]}})
    result = run(write_case(tmp_path, 12, recs, sections=FOUR_SECTIONS, thesis=[]))
    assert status(result.stdout, "S5") == "FAIL"
    assert status(result.stdout, "S6") == "WARN"
    assert "not evaluated" not in result.stdout
