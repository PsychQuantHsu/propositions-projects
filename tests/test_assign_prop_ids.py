"""Tests for plugins/propositions/scripts/assign-prop-ids.py.

The script swaps temporary ids (tmp:<name>) written by LLM extraction for
real UUID v7 ids, rewriting `cites` consistently.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "assign-prop-ids.py"
VALIDATOR = REPO_ROOT / "scripts" / "validate-propositions.py"

EXISTING = "0190a000-0000-7000-8000-000000000001"
UUID7_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
)


def prop(pid: str, n: int = 1, cites: list | None = None) -> dict:
    p = {
        "id": pid,
        "text": f"Claim number {n}.",
        "location": f"main.tex:L{n}",
        "containing_block": "sec:a",
        "claim_type": "claim",
        "asserts": ["x"],
    }
    if cites is not None:
        p["cites"] = cites
    return p


def write_jsonl(path: Path, props: list[dict]) -> Path:
    path.write_text("".join(json.dumps(p, ensure_ascii=False) + "\n" for p in props))
    return path


def run(*args) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *map(str, args)],
        capture_output=True,
        text=True,
    )


def parse(stdout: str) -> list[dict]:
    return [json.loads(l) for l in stdout.splitlines() if l.strip()]


def test_scenario1_assigns_increasing_uuid7_and_rewrites_cites(tmp_path):
    src = write_jsonl(
        tmp_path / "in.jsonl",
        [
            prop("tmp:a", 1),
            prop("tmp:b", 2),
            prop("tmp:c", 3, cites=["tmp:a", EXISTING]),
        ],
    )
    r = run(src)
    assert r.returncode == 0, r.stderr
    out = parse(r.stdout)
    ids = [p["id"] for p in out]
    assert len(set(ids)) == 3
    assert all(UUID7_RE.match(i) for i in ids)
    assert ids == sorted(ids)
    assert out[2]["cites"] == [ids[0], EXISTING]


def test_scenario1_output_passes_validator_r2_r7_r8(tmp_path):
    props = [
        prop("tmp:a", 1),
        prop("tmp:b", 2),
        prop("tmp:c", 3, cites=["tmp:a"]),
    ]
    src = write_jsonl(tmp_path / "in.jsonl", props)
    out_path = tmp_path / "out.jsonl"
    r = run(src, "--out", out_path)
    assert r.returncode == 0, r.stderr
    tex = tmp_path / "main.tex"
    tex.write_text("".join(p["text"] + "\n" for p in props))
    meta = tmp_path / "_meta.json"
    meta.write_text(
        json.dumps({"schema_version": "1.7", "source": {"file": "main.tex"}})
    )
    v = subprocess.run(
        [
            sys.executable, str(VALIDATOR),
            "--jsonl", str(out_path), "--meta", str(meta), "--tex", str(tex),
        ],
        capture_output=True, text=True, cwd=REPO_ROOT,
    )
    for rule in ("R2", "R7", "R8"):
        assert f"[PASS] {rule}" in v.stdout, v.stdout + v.stderr


def test_scenario2_unresolved_tmp_cite(tmp_path):
    src = write_jsonl(tmp_path / "in.jsonl", [prop("tmp:a", 1, cites=["tmp:z"])])
    r = run(src)
    assert r.returncode == 1
    assert r.stdout == ""
    assert "tmp:z" in r.stderr


def test_scenario2_with_out_writes_nothing(tmp_path):
    src = write_jsonl(tmp_path / "in.jsonl", [prop("tmp:a", 1, cites=["tmp:z"])])
    out = tmp_path / "out.jsonl"
    r = run(src, "--out", out)
    assert r.returncode == 1
    assert not out.exists()


def test_scenario3_duplicate_tmp_id(tmp_path):
    src = write_jsonl(tmp_path / "in.jsonl", [prop("tmp:a", 1), prop("tmp:a", 2)])
    r = run(src)
    assert r.returncode == 1
    assert r.stdout == ""
    assert "tmp:a" in r.stderr


def test_scenario4_out_exists_exit2_unchanged(tmp_path):
    src = write_jsonl(tmp_path / "in.jsonl", [prop("tmp:a", 1)])
    out = tmp_path / "out.jsonl"
    out.write_text("precious\n")
    r = run(src, "--out", out)
    assert r.returncode == 2
    assert "--out already exists" in r.stderr
    assert out.read_text() == "precious\n"


def test_scenario4_out_is_input_exit2_unchanged(tmp_path):
    src = write_jsonl(tmp_path / "in.jsonl", [prop("tmp:a", 1)])
    before = src.read_bytes()
    r = run(src, "--out", src)
    assert r.returncode == 2
    assert "--out must not be the input file" in r.stderr
    assert src.read_bytes() == before


def test_out_is_input_via_different_spelling(tmp_path):
    src = write_jsonl(tmp_path / "in.jsonl", [prop("tmp:a", 1)])
    before = src.read_bytes()
    r = run(src, "--out", tmp_path / "." / "in.jsonl")
    assert r.returncode == 2
    assert "--out must not be the input file" in r.stderr
    assert src.read_bytes() == before


def test_missing_input_exit2(tmp_path):
    r = run(tmp_path / "nope.jsonl")
    assert r.returncode == 2
    assert "input file does not exist" in r.stderr


def test_out_file_written_and_input_untouched(tmp_path):
    src = write_jsonl(tmp_path / "in.jsonl", [prop("tmp:a", 1)])
    before = src.read_bytes()
    out = tmp_path / "out.jsonl"
    r = run(src, "--out", out)
    assert r.returncode == 0
    assert r.stdout == ""
    assert UUID7_RE.match(parse(out.read_text())[0]["id"])
    assert src.read_bytes() == before


def test_existing_uuid_ids_preserved(tmp_path):
    src = write_jsonl(
        tmp_path / "in.jsonl",
        [prop(EXISTING, 1), prop("tmp:a", 2, cites=[EXISTING])],
    )
    out = parse(run(src).stdout)
    assert out[0]["id"] == EXISTING
    assert out[1]["cites"] == [EXISTING]


def test_all_uuid_input_round_trips_byte_identically(tmp_path):
    props = [
        prop(EXISTING, 1),
        prop("0190a000-0000-7000-8000-000000000002", 2, cites=[EXISTING]),
    ]
    props[0]["text"] = "Unicode 漢字 and \\citep{x} $\\alpha$"
    src = write_jsonl(tmp_path / "in.jsonl", props)
    r = run(src)
    assert r.returncode == 0
    assert r.stdout == src.read_text()


def test_other_fields_and_order_preserved(tmp_path):
    a, b = prop("tmp:a", 1), prop("tmp:b", 2)
    b["extra"] = {"k": [1, 2]}
    src = write_jsonl(tmp_path / "in.jsonl", [a, b])
    out = parse(run(src).stdout)
    for orig, new in zip([a, b], out):
        assert {k: v for k, v in new.items() if k != "id"} == {
            k: v for k, v in orig.items() if k != "id"
        }
        assert list(new.keys()) == list(orig.keys())
    assert out[1]["text"] == "Claim number 2."


def test_blank_and_comment_lines_pass_through(tmp_path):
    p = json.dumps(prop("tmp:a", 1), ensure_ascii=False)
    src = tmp_path / "in.jsonl"
    src.write_text(f"// header comment\n\n{p}\n   \n// tail\n")
    r = run(src)
    assert r.returncode == 0, r.stderr
    lines = r.stdout.split("\n")
    assert lines[0] == "// header comment"
    assert lines[1] == ""
    assert UUID7_RE.match(json.loads(lines[2])["id"])
    assert lines[3] == "   "
    assert lines[4] == "// tail"


def test_cite_of_later_tmp_id_resolves(tmp_path):
    src = write_jsonl(
        tmp_path / "in.jsonl",
        [prop("tmp:a", 1, cites=["tmp:b"]), prop("tmp:b", 2)],
    )
    out = parse(run(src).stdout)
    assert out[0]["cites"] == [out[1]["id"]]
    assert out[0]["id"] < out[1]["id"]


def test_malformed_tmp_values_fail(tmp_path):
    for bad in ("tmp:", "tmp:a b"):
        src = write_jsonl(tmp_path / "in1.jsonl", [prop(bad, 1)])
        r = run(src)
        assert r.returncode == 1, bad
        assert r.stdout == ""
        assert bad in r.stderr
        src = write_jsonl(
            tmp_path / "in2.jsonl", [prop("tmp:a", 1, cites=[bad])]
        )
        r = run(src)
        assert r.returncode == 1, bad
        assert bad in r.stderr


def test_invalid_json_line_fails(tmp_path):
    src = tmp_path / "in.jsonl"
    src.write_text("{not json}\n")
    r = run(src)
    assert r.returncode == 1
    assert r.stdout == ""


def test_non_object_line_fails(tmp_path):
    src = tmp_path / "in.jsonl"
    src.write_text("[1, 2]\n")
    r = run(src)
    assert r.returncode == 1


def test_cites_not_a_list_fails(tmp_path):
    p = prop("tmp:a", 1)
    p["cites"] = "tmp:a"
    src = write_jsonl(tmp_path / "in.jsonl", [p])
    r = run(src)
    assert r.returncode == 1
    assert r.stdout == ""


def test_strict_monotonicity_over_large_batch(tmp_path):
    n = 5000
    src = write_jsonl(tmp_path / "in.jsonl", [prop(f"tmp:p{i}", i + 1) for i in range(n)])
    r = run(src)
    assert r.returncode == 0, r.stderr
    ids = [p["id"] for p in parse(r.stdout)]
    assert len(ids) == n
    assert len(set(ids)) == n
    assert all(UUID7_RE.match(i) for i in ids)
    assert all(a < b for a, b in zip(ids, ids[1:]))
