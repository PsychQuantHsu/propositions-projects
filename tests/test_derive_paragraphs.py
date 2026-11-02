"""Tests for derive-paragraphs.py (Spectra change add-discourse-dependency-tree).

Spec: Requirement "Paragraph plans are derived from the TeX source". Each
maximal run of non-blank TeX lines is one paragraph; propositions go to the
paragraph holding the first line of their location; paragraphs without a
proposition are skipped; a section start inside a paragraph splits it.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from structure_case import pid  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "derive-paragraphs.py"
FIXTURE = REPO_ROOT / "tests" / "fixtures" / "structure"


def write(tmp: Path, tex_lines: list[str], locations: list[str], retired: tuple[int, ...] = ()) -> tuple[Path, Path]:
    tex = tmp / "main.tex"
    tex.write_text("\n".join(tex_lines) + "\n")
    ledger = tmp / "main.jsonl"
    rows = []
    for n, loc in enumerate(locations, 1):
        prop = {"id": pid(n), "text": f"Sentence {n}.", "location": loc}
        if n in retired:
            prop["retired"] = {"since": "2026-11-02", "mechanism": "deleted", "match": "absent", "reason": "test"}
        rows.append(json.dumps(prop))
    ledger.write_text("\n".join(rows) + "\n")
    return ledger, tex


def run(ledger: Path, tex: Path, *flags: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), "--jsonl", str(ledger), "--tex", str(tex), *flags],
                          capture_output=True, text=True)


def paragraphs(result: subprocess.CompletedProcess) -> list[tuple[str, str]]:
    assert result.returncode == 0, result.stdout + result.stderr
    return [(p["id"], p["first_prop"]) for p in json.loads(result.stdout)]


def lines_with(texts: dict[int, str], total: int) -> list[str]:
    return [texts.get(i, "") for i in range(1, total + 1)]


def test_spec_blank_lines_separate_paragraphs(tmp_path):
    tex = lines_with({10: "One.", 11: "Two.", 13: "Three."}, 13)
    ledger, tex_path = write(tmp_path, tex, ["L10", "L11", "L13"])
    assert paragraphs(run(ledger, tex_path)) == [("p-1", pid(1)), ("p-2", pid(3))]


def test_spec_a_section_start_splits_a_paragraph(tmp_path):
    tex = lines_with({10: "One.", 11: "Two.", 12: "Three."}, 12)
    ledger, tex_path = write(tmp_path, tex, ["L10", "L11", "L12"])
    structure = tmp_path / "structure.json"
    structure.write_text(json.dumps({"sections": [
        {"id": "sec-1", "heading": "A", "role": "introduction", "first_prop": pid(1)},
        {"id": "sec-2", "heading": "B", "role": "method", "first_prop": pid(2)},
    ]}))
    assert paragraphs(run(ledger, tex_path, "--structure", str(structure))) == [("p-1", pid(1)), ("p-2", pid(2))]


def test_paragraphs_without_propositions_are_skipped(tmp_path):
    tex = lines_with({1: r"\section{Intro}", 3: "One.", 5: r"% a comment block", 6: r"\begin{table}", 8: "Two."}, 8)
    ledger, tex_path = write(tmp_path, tex, ["L3", "L8"])
    assert paragraphs(run(ledger, tex_path)) == [("p-1", pid(1)), ("p-2", pid(2))]


def test_a_multiline_location_counts_by_its_first_line(tmp_path):
    tex = lines_with({3: "One", 4: "continues.", 6: "Two."}, 6)
    ledger, tex_path = write(tmp_path, tex, ["L3-L4", "L6"])
    assert paragraphs(run(ledger, tex_path)) == [("p-1", pid(1)), ("p-2", pid(2))]


def test_retired_propositions_are_ignored(tmp_path):
    tex = lines_with({3: "One.", 5: "Gone.", 7: "Two."}, 7)
    ledger, tex_path = write(tmp_path, tex, ["L3", "L5", "L7"], retired=(2,))
    assert paragraphs(run(ledger, tex_path)) == [("p-1", pid(1)), ("p-2", pid(3))]


def test_a_main_tex_prefix_is_the_main_file(tmp_path):
    tex = lines_with({3: "One.", 5: "Two."}, 5)
    ledger, tex_path = write(tmp_path, tex, ["main.tex:L3", "main.tex:L5"])
    assert paragraphs(run(ledger, tex_path)) == [("p-1", pid(1)), ("p-2", pid(2))]


def test_spec_multi_file_locations_are_refused(tmp_path):
    tex = lines_with({3: "One."}, 3)
    ledger, tex_path = write(tmp_path, tex, ["L3", "sections/intro.tex:L5"])
    result = run(ledger, tex_path)
    assert result.returncode == 2
    assert "sections/intro.tex:L5" in result.stderr


def test_a_location_outside_any_paragraph_is_refused(tmp_path):
    tex = lines_with({3: "One."}, 4)
    ledger, tex_path = write(tmp_path, tex, ["L3", "L4"])
    result = run(ledger, tex_path)
    assert result.returncode == 2
    assert "L4" in result.stderr


def test_missing_tex_is_an_input_error(tmp_path):
    ledger, _ = write(tmp_path, ["One."], ["L1"])
    result = run(ledger, tmp_path / "absent.tex")
    assert result.returncode == 2
    assert "absent.tex" in result.stderr


def test_fixture_paragraphs_are_derived():
    expected = [(p["id"], p["first_prop"]) for p in json.loads((FIXTURE / "structure.json").read_text())["paragraphs"]]
    result = run(FIXTURE / "main.jsonl", FIXTURE / "main.tex", "--structure", str(FIXTURE / "structure.json"))
    assert paragraphs(result) == expected
