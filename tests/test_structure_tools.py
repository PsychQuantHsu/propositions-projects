"""Tests for reorder-ledger.py and structure-batch.py (helpers of #30)."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SCRIPTS = REPO_ROOT / "plugins" / "propositions" / "scripts"
REORDER = SCRIPTS / "reorder-ledger.py"
BATCH = SCRIPTS / "structure-batch.py"
VALIDATE = SCRIPTS / "validate-structure.py"
FIXTURE = REPO_ROOT / "tests" / "fixtures" / "structure"


def run(script: Path, *args: object) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(script), *map(str, args)], capture_output=True, text=True)


def ledger(tmp: Path, rows: list[dict]) -> Path:
    path = tmp / "main.jsonl"
    path.write_text("".join(json.dumps(r) + "\n" for r in rows))
    return path


# ---------- reorder-ledger.py ----------


def test_reorder_dry_run(tmp_path: Path) -> None:
    path = ledger(tmp_path, [{"id": "b", "location": "main.tex:L9"}, {"id": "a", "location": "main.tex:L2"}])
    before = path.read_bytes()
    result = run(REORDER, "--jsonl", path)
    assert result.returncode == 1
    assert "2 line(s) move" in result.stdout
    assert path.read_bytes() == before


def test_reorder_write_keeps_lines_byte_identical(tmp_path: Path) -> None:
    path = ledger(tmp_path, [{"id": "b", "location": "main.tex:L9"}, {"id": "a", "location": "main.tex:L2-L3"}])
    lines = set(path.read_text().splitlines())
    assert run(REORDER, "--jsonl", path, "--write").returncode == 0
    assert [json.loads(l)["id"] for l in path.read_text().splitlines()] == ["a", "b"]
    assert set(path.read_text().splitlines()) == lines


def test_reorder_write_keeps_mode_and_leaves_no_temp_file(tmp_path: Path) -> None:
    path = ledger(tmp_path, [{"id": "b", "location": "main.tex:L9"}, {"id": "a", "location": "main.tex:L2"}])
    path.chmod(0o640)
    assert run(REORDER, "--jsonl", path, "--write").returncode == 0
    assert path.stat().st_mode & 0o777 == 0o640
    assert [p.name for p in tmp_path.iterdir()] == ["main.jsonl"]


def test_reorder_in_order_exits_zero(tmp_path: Path) -> None:
    path = ledger(tmp_path, [{"id": "a", "location": "main.tex:L2"}, {"id": "b", "location": "main.tex:L2"}])
    result = run(REORDER, "--jsonl", path)
    assert result.returncode == 0
    assert "same line" in result.stdout  # ties are reported for a human look


def test_reorder_retired_line_follows_its_predecessor(tmp_path: Path) -> None:
    path = ledger(tmp_path, [
        {"id": "b", "location": "main.tex:L9"},
        {"id": "r", "retired": {"reason": "x"}},
        {"id": "a", "location": "main.tex:L2"},
    ])
    assert run(REORDER, "--jsonl", path, "--write").returncode == 0
    assert [json.loads(l)["id"] for l in path.read_text().splitlines()] == ["a", "b", "r"]


def test_reorder_refuses_other_files_and_bad_locations(tmp_path: Path) -> None:
    path = ledger(tmp_path, [{"id": "a", "location": "sections/a.tex:L2"}])
    assert run(REORDER, "--jsonl", path).returncode == 2
    path = ledger(tmp_path, [{"id": "a", "location": "nowhere"}])
    assert run(REORDER, "--jsonl", path).returncode == 2


# ---------- structure-batch.py ----------

def fixture_args() -> list[object]:
    return ["--jsonl", FIXTURE / "main.jsonl", "--structure", FIXTURE / "structure.json", "--discourse", FIXTURE / "discourse.jsonl"]


def outputs_from_fixture(out: Path) -> None:
    """Answer every batch with what the fixture already records."""
    live = [json.loads(l)["id"] for l in (FIXTURE / "main.jsonl").read_text().splitlines() if l.strip()]
    pos = {p: i for i, p in enumerate(live, 1)}
    recs = {json.loads(l)["prop_id"]: json.loads(l) for l in (FIXTURE / "discourse.jsonl").read_text().splitlines() if l.strip()}
    paragraphs = {p["id"]: p for p in json.loads((FIXTURE / "structure.json").read_text())["paragraphs"]}
    for path in out.glob("input-*.json"):
        batch = json.loads(path.read_text())
        answer: dict = {"propositions": {}, "paragraphs": {}}
        for prop in batch["propositions"]:
            rec = recs[live[prop["position"] - 1]]
            head = rec.get("head")
            item = {"head": pos[head] if head else None, "relation": rec.get("relation"), "note": rec.get("note", "")}
            if rec.get("also"):
                item["also"] = [{"to": pos[a["to"]], "relation": a["relation"]} for a in rec["also"]]
            answer["propositions"][str(prop["position"])] = item
        for par in batch["paragraphs"]:
            found = paragraphs[par["id"]]
            answer["paragraphs"][par["id"]] = {"head": found.get("head"), "relation": found.get("relation")}
        path.with_name(path.name.replace("input-", "output-")).write_text(json.dumps(answer))


def test_split_never_cuts_a_paragraph_and_covers_everything(tmp_path: Path) -> None:
    assert run(BATCH, "split", *fixture_args(), "--out-dir", tmp_path, "--max-props", 4).returncode == 0
    batches = [json.loads(p.read_text()) for p in sorted(tmp_path.glob("input-*.json"))]
    assert len(batches) > 1
    positions = [p["position"] for b in batches for p in b["propositions"]]
    assert positions == list(range(1, len(positions) + 1))
    seen = [p["id"] for b in batches for p in b["paragraphs"]]
    assert len(seen) == len(set(seen))
    for batch in batches:
        ids = {p["id"] for p in batch["paragraphs"]}
        assert {p["paragraph"] for p in batch["propositions"]} == ids


def test_merge_round_trip_passes_the_validator(tmp_path: Path) -> None:
    run(BATCH, "split", *fixture_args(), "--out-dir", tmp_path, "--max-props", 4)
    outputs_from_fixture(tmp_path)
    result = run(BATCH, "merge", *fixture_args(), "--out-dir", tmp_path)
    assert result.returncode == 0, result.stderr
    check = run(VALIDATE, "--jsonl", FIXTURE / "main.jsonl", "--structure", tmp_path / "structure.json", "--discourse", tmp_path / "discourse.jsonl")
    assert check.returncode == 0, check.stdout
    original = [json.loads(l) for l in (FIXTURE / "discourse.jsonl").read_text().splitlines() if l.strip()]
    merged = [json.loads(l) for l in (tmp_path / "discourse.jsonl").read_text().splitlines() if l.strip()]
    assert [r.get("opens") for r in merged] == [r.get("opens") for r in original]
    assert [r.get("head") for r in merged] == [r.get("head") for r in original]


@pytest.mark.parametrize("damage", ["missing_output", "missing_prop", "bad_head"])
def test_merge_refuses_incomplete_answers(tmp_path: Path, damage: str) -> None:
    run(BATCH, "split", *fixture_args(), "--out-dir", tmp_path, "--max-props", 4)
    outputs_from_fixture(tmp_path)
    output = sorted(tmp_path.glob("output-*.json"))[0]
    if damage == "missing_output":
        output.unlink()
    else:
        data = json.loads(output.read_text())
        key = sorted(data["propositions"], key=int)[0]
        if damage == "missing_prop":
            del data["propositions"][key]
        else:
            data["propositions"][key]["head"] = 99999
        output.write_text(json.dumps(data))
    result = run(BATCH, "merge", *fixture_args(), "--out-dir", tmp_path)
    assert result.returncode == 2
    assert not (tmp_path / "discourse.jsonl").exists()


# ---------- structure-batch.py --moves-only ----------

def moves_answers(out: Path) -> None:
    for path in out.glob("input-*.json"):
        batch = json.loads(path.read_text())
        answer = {
            "propositions": {str(p["position"]): {"move": "claim"} for p in batch["propositions"]},
            "paragraphs": {p["id"]: {"type": "background"} for p in batch["paragraphs"]},
        }
        path.with_name(path.name.replace("input-", "output-")).write_text(json.dumps(answer))


def read_records(path: Path) -> list[dict]:
    return [json.loads(l) for l in path.read_text().splitlines() if l.strip()]


def test_moves_only_split_carries_head_and_relation(tmp_path: Path) -> None:
    assert run(BATCH, "split", *fixture_args(), "--out-dir", tmp_path, "--moves-only").returncode == 0
    props = [p for f in sorted(tmp_path.glob("input-*.json")) for p in json.loads(f.read_text())["propositions"]]
    live = [json.loads(l)["id"] for l in (FIXTURE / "main.jsonl").read_text().splitlines() if l.strip()]
    pos = {p: i for i, p in enumerate(live, 1)}
    for prop, rec in zip(props, read_records(FIXTURE / "discourse.jsonl")):
        assert "head" in prop and "relation" in prop
        assert prop["head"] == (pos[rec["head"]] if rec.get("head") else None)
        assert prop["relation"] == rec.get("relation")
    assert any(p["head"] is None for p in props) and any(isinstance(p["head"], int) for p in props)


def test_moves_only_split_keeps_pending_heads(tmp_path: Path) -> None:
    records = read_records(FIXTURE / "discourse.jsonl")
    records[-1] = {"prop_id": records[-1]["prop_id"], "head": "pending"}
    discourse = tmp_path / "pending.jsonl"
    discourse.write_text("".join(json.dumps(r) + "\n" for r in records))
    args = ["--jsonl", FIXTURE / "main.jsonl", "--structure", FIXTURE / "structure.json", "--discourse", discourse]
    out = tmp_path / "out"
    assert run(BATCH, "split", *args, "--out-dir", out, "--moves-only").returncode == 0
    last = json.loads(sorted(out.glob("input-*.json"))[-1].read_text())["propositions"][-1]
    assert last["head"] == "pending" and last["relation"] is None


def test_plain_split_is_unchanged_by_the_flag_existing(tmp_path: Path) -> None:
    run(BATCH, "split", *fixture_args(), "--out-dir", tmp_path)
    for f in tmp_path.glob("input-*.json"):
        assert all("head" not in p and "relation" not in p for p in json.loads(f.read_text())["propositions"])


def test_moves_only_merge_changes_nothing_but_move_and_type(tmp_path: Path) -> None:
    run(BATCH, "split", *fixture_args(), "--out-dir", tmp_path, "--max-props", 4, "--moves-only")
    moves_answers(tmp_path)
    result = run(BATCH, "merge", *fixture_args(), "--out-dir", tmp_path, "--moves-only")
    assert result.returncode == 0, result.stderr
    merged = read_records(tmp_path / "discourse.jsonl")
    assert all(r.pop("move") == "claim" for r in merged)
    assert merged == read_records(FIXTURE / "discourse.jsonl")
    structure = json.loads((tmp_path / "structure.json").read_text())
    assert all(p.pop("type") == "background" for p in structure["paragraphs"])
    assert structure == json.loads((FIXTURE / "structure.json").read_text())


@pytest.mark.parametrize("damage", ["missing_prop", "missing_paragraph", "non_string_move", "empty_type"])
def test_moves_only_merge_refuses_bad_answers(tmp_path: Path, damage: str) -> None:
    run(BATCH, "split", *fixture_args(), "--out-dir", tmp_path, "--max-props", 4, "--moves-only")
    moves_answers(tmp_path)
    output = sorted(tmp_path.glob("output-*.json"))[0]
    data = json.loads(output.read_text())
    key, pid = sorted(data["propositions"], key=int)[0], sorted(data["paragraphs"])[0]
    if damage == "missing_prop":
        del data["propositions"][key]
    elif damage == "missing_paragraph":
        del data["paragraphs"][pid]
    elif damage == "non_string_move":
        data["propositions"][key]["move"] = 3
    else:
        data["paragraphs"][pid]["type"] = ""
    output.write_text(json.dumps(data))
    result = run(BATCH, "merge", *fixture_args(), "--out-dir", tmp_path, "--moves-only")
    assert result.returncode == 2
    assert output.name in result.stderr
    assert not (tmp_path / "discourse.jsonl").exists() and not (tmp_path / "structure.json").exists()
