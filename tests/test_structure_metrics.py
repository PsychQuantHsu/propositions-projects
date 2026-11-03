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


# ---------- moves (Spectra change add-paragraph-moves) ----------
# Spec: Requirement "Metrics report whether moves add anything".


def claims(tmp: Path, by_position: dict[int, str]) -> None:
    """Give the synthetic ledger's propositions a claim_type."""
    ledger = tmp / "main.jsonl"
    lines = [json.loads(l) for l in ledger.read_text().splitlines()]
    for i, prop in enumerate(lines, 1):
        if i in by_position:
            prop["claim_type"] = by_position[i]
    ledger.write_text("".join(json.dumps(p) + "\n" for p in lines))


def test_sidecars_without_moves_report_nothing_new(tmp_path):
    ledger = write_case(tmp_path, 3)
    assert "moves" not in metrics(ledger)
    assert "move" not in run(ledger).stdout


def test_coverage_counts_and_types(tmp_path):
    recs = with_changes(4, {1: {"move": "a"}, 2: {"move": "b"}, 3: {"move": "a"}})
    moves = metrics(write_case(tmp_path, 4, recs, paragraphs=[{"id": "p-1", "first": 1, "type": "t"}]))["moves"]
    assert moves["labelled_propositions"] == 3 and moves["proposition_share"] == 0.75
    assert moves["labelled_paragraphs"] == 1 and moves["paragraph_share"] == 1.0
    assert moves["counts"] == {"a": 2, "b": 1} and moves["type_counts"] == {"t": 1}


def test_cramers_v_is_one_when_move_determines_claim_type(tmp_path):
    recs = with_changes(4, {1: {"move": "a"}, 2: {"move": "b"}, 3: {"move": "a"}, 4: {"move": "b"}})
    ledger = write_case(tmp_path, 4, recs)
    claims(tmp_path, {1: "x", 2: "y", 3: "x", 4: "y"})
    assert metrics(ledger)["moves"]["association"]["claim_type"] == 1.0


def test_cramers_v_is_zero_when_move_and_claim_type_are_independent(tmp_path):
    recs = with_changes(4, {1: {"move": "a"}, 2: {"move": "a"}, 3: {"move": "b"}, 4: {"move": "b"}})
    ledger = write_case(tmp_path, 4, recs)
    claims(tmp_path, {1: "x", 2: "y", 3: "x", 4: "y"})
    assert metrics(ledger)["moves"]["association"]["claim_type"] == 0.0


def test_cramers_v_is_null_with_only_one_category(tmp_path):
    recs = with_changes(2, {1: {"move": "a"}, 2: {"move": "a"}})
    ledger = write_case(tmp_path, 2, recs)
    claims(tmp_path, {1: "x", 2: "y"})
    assert metrics(ledger)["moves"]["association"]["claim_type"] is None


def test_association_with_relation_leaves_roots_out(tmp_path):
    # positions 2 and 4 have relations; 1 and 3 are roots of their paragraphs.
    recs = [{"pos": 1, "move": "a"}, {"pos": 2, "head": 1, "relation": "reason", "move": "b"},
            {"pos": 3, "move": "a"}, {"pos": 4, "head": 3, "relation": "contrast", "move": "c"}]
    ledger = write_case(tmp_path, 4, recs, paragraphs=[{"id": "p-1", "first": 1}, {"id": "p-2", "first": 3, "head": "p-1", "relation": "addition"}])
    assert metrics(ledger)["moves"]["association"]["relation"] == 1.0


def test_leave_one_paragraph_out_hit_rate_worked_by_hand(tmp_path):
    # Three two-sentence paragraphs, every one a -> b by `reason`, then a fourth a -> c by `contrast`.
    # Current move a, target next relation: paragraphs 1-3 are predicted from the others (reason first, hit);
    # paragraph 4 is predicted from three `reason`, and `contrast` was never seen there, so top-3 under the move
    # holds only `reason`: miss. END follows every b or c: predicted by the others, hit, except c, whose only
    # occurrence is left out: the no-condition table is the fallback, and END is in its top 3: hit.
    recs, pars = [], []
    for k, (second, rel) in enumerate((("b", "reason"), ("b", "reason"), ("b", "reason"), ("c", "contrast"))):
        first = 2 * k + 1
        recs += [{"pos": first, "move": "a"}, {"pos": first + 1, "head": first, "relation": rel, "move": second}]
        pars.append({"id": f"p-{k + 1}", "first": first, **({"head": "p-1", "relation": "addition"} if k else {})})
    moves = metrics(write_case(tmp_path, 8, recs, paragraphs=pars))["moves"]
    assert moves["next_relation"]["evaluated"] == 8
    assert moves["next_relation"]["current_move"] == 0.875
    # No condition: targets are reason x3, contrast, END x4. `contrast` occurs only in paragraph 4, so leaving that
    # paragraph out leaves reason x3, END x3: the one row whose target is `contrast` misses, the other seven hit.
    assert moves["next_relation"]["no_condition"] == 0.875


def test_unlabelled_positions_are_not_evaluated(tmp_path):
    recs = with_changes(3, {1: {"move": "a"}, 2: {"move": "b"}})
    moves = metrics(write_case(tmp_path, 3, recs))["moves"]
    # Position 1 -> b, position 2 -> unlabelled (next move unknown), position 3 has no move.
    assert moves["next_move"]["evaluated"] == 1


def second_labelling(tmp: Path, moves: list[str], types: dict[str, str] | None = None) -> Path:
    other = tmp / "second"
    other.mkdir()
    n = len(moves)
    recs = with_changes(n, {i + 1: {"move": m} for i, m in enumerate(moves)})
    write_case(other, n, recs, paragraphs=[{"id": "p-1", "first": 1, **({"type": types["p-1"]} if types else {})}])
    return other


def test_agreement_is_reported(tmp_path):
    first = ["a"] * 5 + ["b"] * 5
    second = ["a", "a", "a", "a", "b", "b", "b", "b", "b", "a"]
    (tmp_path / "first").mkdir()
    recs = with_changes(10, {i + 1: {"move": m} for i, m in enumerate(first)})
    ledger = write_case(tmp_path / "first", 10, recs, paragraphs=[{"id": "p-1", "first": 1, "type": "t"}])
    other = second_labelling(tmp_path, second, {"p-1": "t"})
    result = run(ledger, "--format", "json", "--compare-moves", str(other))
    agreement = json.loads(result.stdout)["moves"]["agreement"]
    # po = 0.8; both margins are 0.5/0.5, so pe = 0.5 and kappa = (0.8 - 0.5) / 0.5 = 0.6.
    assert agreement["moves"] == {"n": 10, "raw": 0.8, "kappa": 0.6}
    assert agreement["types"]["n"] == 1 and agreement["types"]["raw"] == 1.0
    assert "0.80" in run(ledger, "--compare-moves", str(other)).stdout


def test_agreement_uses_only_what_both_labelled(tmp_path):
    (tmp_path / "first").mkdir()
    recs = with_changes(4, {1: {"move": "a"}, 2: {"move": "b"}, 3: {"move": "a"}})
    ledger = write_case(tmp_path / "first", 4, recs)
    other = tmp_path / "second"
    other.mkdir()
    write_case(other, 4, with_changes(4, {2: {"move": "b"}, 3: {"move": "a"}, 4: {"move": "a"}}))
    agreement = json.loads(run(ledger, "--format", "json", "--compare-moves", str(other)).stdout)["moves"]["agreement"]
    assert agreement["moves"]["n"] == 2 and agreement["moves"]["raw"] == 1.0


def test_agreement_threshold_never_changes_the_exit_status(tmp_path):
    (tmp_path / "first").mkdir()
    ledger = write_case(tmp_path / "first", 2, with_changes(2, {1: {"move": "a"}, 2: {"move": "b"}}))
    other = second_labelling(tmp_path, ["b", "a"])
    assert run(ledger, "--compare-moves", str(other)).returncode == 0


def test_a_missing_comparison_is_an_input_error(tmp_path):
    ledger = write_case(tmp_path, 2, with_changes(2, {1: {"move": "a"}}))
    assert run(ledger, "--compare-moves", str(tmp_path / "absent")).returncode == 2
