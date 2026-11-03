"""Tests for structure-explain.py (Spectra change add-paragraph-moves).

Spec: Requirement "The explain tool reads out how sentences relate". The spec's
positions are the worked example from the reference manuscript: 139 and 140 hang
on the root 138, 141 hangs on 140. Here they are positions 2, 3 and 4 of a paragraph
starting at 1.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from structure_case import pid, write_case, write_vocabulary  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "structure-explain.py"
FAN = [
    {"pos": 1, "move": "state-goal"},
    {"pos": 2, "head": 1, "relation": "specification", "move": "state-baseline"},
    {"pos": 3, "head": 1, "relation": "specification", "move": "state-concern"},
    {"pos": 4, "head": 3, "relation": "continue"},
]


def explain(ledger: Path, *flags: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--jsonl", str(ledger), "--vocabulary", str(ledger.parent / "vocabulary.yaml"), *flags],
        capture_output=True, text=True,
    )


def case(tmp: Path, records: list[dict] | None = None, **kw: object) -> Path:
    write_vocabulary(tmp)
    return write_case(tmp, 4, records if records is not None else FAN, **kw)


def line_for(stdout: str, position: int) -> str:
    return next(l for l in stdout.splitlines() if f"#{position} " in l or l.strip().startswith(f"#{position}"))


def indent(line: str) -> int:
    return len(line) - len(line.lstrip())


def test_a_sentence_says_what_it_does_and_what_it_hangs_on(tmp_path: Path) -> None:
    out = explain(case(tmp_path), "--paragraph", "p-1")
    assert out.returncode == 0, out.stderr
    line = line_for(out.stdout, 2)
    assert "說對照基準" in line and "#1" in line and "具體說明" in line and "specification" in line


def test_a_root_says_so(tmp_path: Path) -> None:
    assert "段根" in line_for(explain(case(tmp_path), "--paragraph", "p-1").stdout, 1)


def test_depth_is_visible(tmp_path: Path) -> None:
    stdout = explain(case(tmp_path), "--paragraph", "p-1").stdout
    assert indent(line_for(stdout, 4)) > indent(line_for(stdout, 3)) > indent(line_for(stdout, 1))


def test_an_unlabelled_sentence_is_shown_as_unlabelled(tmp_path: Path) -> None:
    line = line_for(explain(case(tmp_path), "--paragraph", "p-1").stdout, 4)
    assert "未標" in line and "#3" in line and "continue" in line


def test_text_can_be_left_out(tmp_path: Path) -> None:
    ledger = case(tmp_path)
    assert "Sentence 2." in explain(ledger, "--paragraph", "p-1").stdout
    without = explain(ledger, "--paragraph", "p-1", "--no-text").stdout
    assert "Sentence" not in without and "說對照基準" in without


def test_an_unknown_paragraph_is_an_input_error(tmp_path: Path) -> None:
    out = explain(case(tmp_path), "--paragraph", "p-999")
    assert out.returncode == 2 and "p-999" in out.stderr


def test_an_unknown_section_is_an_input_error(tmp_path: Path) -> None:
    out = explain(case(tmp_path), "--section", "sec-9")
    assert out.returncode == 2 and "sec-9" in out.stderr


def test_exactly_one_scope_is_required(tmp_path: Path) -> None:
    ledger = case(tmp_path)
    assert explain(ledger).returncode == 2
    assert explain(ledger, "--all", "--paragraph", "p-1").returncode == 2


def test_also_names_its_target(tmp_path: Path) -> None:
    records = [*FAN[:3], {**FAN[3], "also": [{"to": 2, "relation": "contrast"}]}]
    block = explain(case(tmp_path, records), "--paragraph", "p-1").stdout
    assert any("#2" in l and "contrast" in l and "對照" in l for l in block.splitlines() if "另" in l)


def test_the_paragraph_line_gives_type_and_head(tmp_path: Path) -> None:
    write_vocabulary(tmp_path)
    ledger = write_case(
        tmp_path, 4,
        [{"pos": 1}, {"pos": 2, "head": 1, "relation": "continue"}, {"pos": 3}, {"pos": 4, "head": 3, "relation": "continue"}],
        paragraphs=[{"id": "p-1", "first": 1, "type": "goal-summary"},
                    {"id": "p-2", "first": 3, "head": "p-1", "relation": "contrast"}],
    )
    out = explain(ledger, "--all").stdout
    assert "p-1" in out and "目的總結段" in out
    line = next(l for l in out.splitlines() if l.startswith("p-2"))
    assert "p-1" in line and "contrast" in line


def test_a_section_scope_prints_only_its_paragraphs(tmp_path: Path) -> None:
    write_vocabulary(tmp_path)
    ledger = write_case(
        tmp_path, 4,
        [{"pos": 1}, {"pos": 2, "head": 1, "relation": "continue"}, {"pos": 3}, {"pos": 4, "head": 3, "relation": "continue"}],
        sections=[{"id": "sec-1", "heading": "A", "role": "introduction", "first": 1},
                  {"id": "sec-2", "heading": "B", "role": "method", "first": 3}],
    )
    out = explain(ledger, "--section", "sec-2", "--no-text").stdout
    assert "#3" in out and "#1 " not in out


def test_json_output_carries_the_same_facts(tmp_path: Path) -> None:
    out = explain(case(tmp_path), "--paragraph", "p-1", "--format", "json")
    data = json.loads(out.stdout)
    second = data["paragraphs"][0]["propositions"][1]
    assert second == {
        "position": 2, "prop_id": pid(2), "depth": 1, "move": "state-baseline", "move_zh": "說對照基準",
        "head": 1, "relation": "specification", "relation_gloss": "具體說明", "also": [], "text": "Sentence 2.",
    }


def test_a_pending_head_is_shown(tmp_path: Path) -> None:
    write_vocabulary(tmp_path)
    ledger = write_case(tmp_path, 2, [{"pos": 1}, {"pos": 2, "head": "pending"}])
    assert "等待" in line_for(explain(ledger, "--all").stdout, 2)


def test_a_head_after_the_sentence_is_read_correctly(tmp_path: Path) -> None:
    write_vocabulary(tmp_path)
    ledger = write_case(tmp_path, 2, [{"pos": 1, "head": 2, "relation": "specification"}, {"pos": 2}])
    stdout = explain(ledger, "--all").stdout
    assert "#2" in line_for(stdout, 1) and indent(line_for(stdout, 1)) > indent(line_for(stdout, 2))


def test_no_file_is_written(tmp_path: Path) -> None:
    ledger = case(tmp_path)
    before = {p: p.read_bytes() for p in tmp_path.iterdir()}
    explain(ledger, "--all")
    assert {p: p.read_bytes() for p in tmp_path.iterdir()} == before


def test_sidecars_without_moves_need_no_vocabulary(tmp_path: Path) -> None:
    ledger = write_case(tmp_path, 2)
    out = subprocess.run(
        [sys.executable, str(SCRIPT), "--jsonl", str(ledger), "--vocabulary", str(tmp_path / "absent.yaml"), "--all"],
        capture_output=True, text=True,
    )
    assert out.returncode == 0, out.stderr
    assert "未標" in out.stdout


def test_a_missing_sidecar_is_an_input_error(tmp_path: Path) -> None:
    ledger = case(tmp_path)
    (tmp_path / "discourse.jsonl").unlink()
    assert explain(ledger, "--all").returncode == 2


def test_a_multi_line_text_stays_on_its_line(tmp_path: Path) -> None:
    ledger = case(tmp_path)
    rows = [json.loads(l) for l in ledger.read_text().splitlines()]
    rows[1]["text"] = "First line\n  second line."
    ledger.write_text("".join(json.dumps(r) + "\n" for r in rows))
    stdout = explain(ledger, "--paragraph", "p-1").stdout
    assert "First line second line." in line_for(stdout, 2)
    data = json.loads(explain(ledger, "--paragraph", "p-1", "--format", "json").stdout)
    assert data["paragraphs"][0]["propositions"][1]["text"] == "First line\n  second line."
