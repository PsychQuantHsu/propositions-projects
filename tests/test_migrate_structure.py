"""Tests for migrate-structure-v2.py (Spectra change add-discourse-dependency-tree).

Spec: Requirement "Version 1.0 sidecars are migrated, not read". The migration
reads version 1.0 sidecars beside the ledger, writes version 2.0 sidecars and a
review report into --out-dir, and never touches the ledger or the 1.0 files.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from structure_case import pid  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPTS = REPO_ROOT / "plugins" / "propositions" / "scripts"
SCRIPT = SCRIPTS / "migrate-structure-v2.py"
VALIDATOR = SCRIPTS / "validate-structure.py"
FIXTURE_V1 = REPO_ROOT / "tests" / "fixtures" / "structure-v1"


def run(ledger: Path, tex: Path, out_dir: Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), "--jsonl", str(ledger), "--tex", str(tex), "--out-dir", str(out_dir)],
                          capture_output=True, text=True)


def validate(ledger: Path, out_dir: Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(VALIDATOR), "--jsonl", str(ledger),
                           "--structure", str(out_dir / "structure.json"), "--discourse", str(out_dir / "discourse.jsonl")],
                          capture_output=True, text=True)


def review(out_dir: Path) -> list[dict]:
    return json.loads((out_dir / "migration-review.json").read_text())["items"]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_v1(tmp: Path, tex_lines: dict[int, str], total_lines: int, relations: list, sections: list[dict]) -> Path:
    """A 1.0 case: proposition n sits on the TeX line given by `relations[n-1][0]`."""
    lines = [tex_lines.get(i, "") for i in range(1, total_lines + 1)]
    (tmp / "main.tex").write_text("\n".join(lines) + "\n")
    rows, records = [], []
    for n, (line, rel, *rest) in enumerate(relations, 1):
        rows.append(json.dumps({"id": pid(n), "text": f"Sentence {n}.", "location": f"L{line}"}))
        rec = {"prop_id": pid(n), "relation": rel}
        if rest:
            rec["refers_to"] = pid(rest[0])
        records.append(json.dumps(rec))
    (tmp / "main.jsonl").write_text("\n".join(rows) + "\n")
    (tmp / "discourse.jsonl").write_text("\n".join(records) + "\n")
    (tmp / "structure.json").write_text(json.dumps({
        "structure_version": "1.0", "thesis": [pid(1)],
        "sections": [{"id": s["id"], "heading": s["heading"], "role": s["role"], "first_prop": pid(s["first"])} for s in sections],
    }))
    return tmp / "main.jsonl"


@pytest.fixture()
def v1(tmp_path) -> Path:
    src = tmp_path / "v1"
    shutil.copytree(FIXTURE_V1, src)
    return src


def test_fixture_output_passes_the_validator(v1, tmp_path):
    out = tmp_path / "out"
    result = run(v1 / "main.jsonl", v1 / "main.tex", out)
    assert result.returncode == 0, result.stdout + result.stderr
    checked = validate(v1 / "main.jsonl", out)
    assert checked.returncode == 0, checked.stdout
    assert json.loads((out / "structure.json").read_text())["structure_version"] == "2.0"


def test_fixture_review_lists_start_shift_and_return(v1, tmp_path):
    out = tmp_path / "out"
    run(v1 / "main.jsonl", v1 / "main.tex", out)
    listed = {(i["position"], i["original_relation"]) for i in review(out) if i["kind"] == "record"}
    assert listed == {(1, "start"), (6, "shift"), (7, "shift"), (11, "return")}


def test_spec_a_return_is_listed_for_review(tmp_path):
    case = tmp_path / "case"
    case.mkdir()
    relations = [(n, "start" if n == 1 else "continue") for n in range(1, 12)] + [(12, "return", 4)]
    ledger = write_v1(case, {n: f"Sentence {n}." for n in range(1, 13)}, 12, relations,
                      [{"id": "sec-1", "heading": "A", "role": "introduction", "first": 1}])
    out = tmp_path / "out"
    assert run(ledger, tmp_path / "case" / "main.tex", out).returncode == 0
    items = [i for i in review(out) if i["kind"] == "record" and i["position"] == 12]
    assert items and items[0]["original_relation"] == "return"


def test_spec_the_ledger_and_the_1_0_sidecars_are_untouched(v1, tmp_path):
    files = ["main.jsonl", "structure.json", "discourse.jsonl"]
    before = {f: digest(v1 / f) for f in files}
    assert run(v1 / "main.jsonl", v1 / "main.tex", tmp_path / "out").returncode == 0
    assert {f: digest(v1 / f) for f in files} == before


def test_spec_version_2_0_input_is_refused(tmp_path):
    src = tmp_path / "v2"
    shutil.copytree(REPO_ROOT / "tests" / "fixtures" / "structure", src)
    out = tmp_path / "out"
    result = run(src / "main.jsonl", src / "main.tex", out)
    assert result.returncode == 2
    assert not out.exists() or not any(out.iterdir())


def test_out_dir_beside_the_ledger_is_refused(v1):
    result = run(v1 / "main.jsonl", v1 / "main.tex", v1)
    assert result.returncode == 2
    assert json.loads((v1 / "structure.json").read_text())["structure_version"] == "1.0"


def test_existing_output_is_not_overwritten(v1, tmp_path):
    out = tmp_path / "out"
    out.mkdir()
    (out / "discourse.jsonl").write_text("annotation in progress\n")
    result = run(v1 / "main.jsonl", v1 / "main.tex", out)
    assert result.returncode == 2
    assert (out / "discourse.jsonl").read_text() == "annotation in progress\n"


def test_paragraph_relations_come_from_the_first_record(tmp_path):
    # One section, three TeX paragraphs: 1-2, 4-5, 7-8. Record 3 (line 4) was `consequence`,
    # record 5 (line 7) was `shift`.
    case = tmp_path / "case"
    case.mkdir()
    relations = [(1, "start"), (2, "continue"), (4, "consequence"), (5, "addition"), (7, "shift"), (8, "contrast")]
    ledger = write_v1(case, {1: "a", 2: "b", 4: "c", 5: "d", 7: "e", 8: "f"}, 8, relations,
                      [{"id": "sec-1", "heading": "A", "role": "introduction", "first": 1}])
    out = tmp_path / "out"
    assert run(ledger, case / "main.tex", out).returncode == 0
    paragraphs = json.loads((out / "structure.json").read_text())["paragraphs"]
    assert [(p["id"], p.get("head"), p.get("relation")) for p in paragraphs] == [
        ("p-1", None, None), ("p-2", "p-1", "consequence"), ("p-3", "p-2", "continue")]
    assert any(i["kind"] == "paragraph" and i["id"] == "p-3" for i in review(out))
    records = [json.loads(l) for l in (out / "discourse.jsonl").read_text().splitlines()]
    assert [(r.get("head"), r.get("relation")) for r in records] == [
        (None, None), (pid(1), "continue"), (None, None), (pid(3), "addition"), (None, None), (pid(5), "contrast")]
    assert validate(ledger, out).returncode == 0


def test_section_parents_come_from_the_sectioning_commands(tmp_path):
    case = tmp_path / "case"
    case.mkdir()
    tex = {1: r"\section{Intro}", 2: "a", 4: r"\subsection{Detail}", 5: "b",
           7: r"\section{Method}", 9: r"\subsection{Sampling}", 10: "c"}
    relations = [(2, "start"), (5, "shift"), (10, "shift")]
    sections = [{"id": "sec-1", "heading": "Intro", "role": "introduction", "first": 1},
                {"id": "sec-1-1", "heading": "Detail", "role": "introduction", "first": 2},
                {"id": "sec-2-1", "heading": "Sampling", "role": "method", "first": 3}]
    ledger = write_v1(case, tex, 10, relations, sections)
    out = tmp_path / "out"
    assert run(ledger, case / "main.tex", out).returncode == 0
    parents = {s["id"]: s.get("parent") for s in json.loads((out / "structure.json").read_text())["sections"]}
    assert parents == {"sec-1": None, "sec-1-1": "sec-1", "sec-2-1": None}
    assert any(i["kind"] == "section" and i["id"] == "sec-2-1" for i in review(out))
    assert not any(i["kind"] == "section" and i["id"] in ("sec-1", "sec-1-1") for i in review(out))
