"""Tests for v1.6 multi-file manuscript support (spectra: add-manuscript-onboarding).

Covers spec `multifile-manuscript-support`:
- Input-tree resolution from the main file (`\\input`/`\\include`, comment/verbatim
  immunity, missing target, cycle)
- File-qualified location syntax (prefixed R1/R13, backward-compatible unprefixed,
  prefix on sub-v1.6 ledger fails loudly)
- Location prefix outside the input tree fails
- `_meta.json` `source.parts` snapshot: read-only, a difference is a warning (issue 146)
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "scripts" / "validate-propositions.py"  # root shim (pinned contract)

sys.path.insert(0, str(REPO_ROOT / "plugins" / "propositions" / "scripts"))

from _lib import latex_env_parser as parser  # noqa: E402

SAMPLE_UUID_A = "01910b9c-d4f0-7000-8000-0123456789ab"
SAMPLE_UUID_B = "01910b9c-d4f0-7001-8000-0123456789ab"

PART2_SENTENCE = "The bootstrap estimator converges to the information bound."
MAIN_SENTENCE = "This paper studies parametric bootstrap standard errors."


def make_multifile_repo(tmp_path: Path) -> Path:
    """Materialize a minimal multi-file manuscript: main.tex + parts/{part1,part2-theory}."""
    (tmp_path / "parts").mkdir()
    main = tmp_path / "main.tex"
    main.write_text(
        "\\documentclass{article}\n"
        "\\newtheorem{theorem}{Theorem}\n"
        "\\begin{document}\n"
        f"{MAIN_SENTENCE}\n"
        "\\input{parts/part1}\n"
        "\\input{parts/part2-theory}\n"
        "% \\input{parts/ghost}\n"
        "\\begin{verbatim}\n"
        "\\input{parts/fake}\n"
        "\\end{verbatim}\n"
        "\\end{document}\n"
    )
    (tmp_path / "parts" / "part1.tex").write_text("Intro text sentence.\n")
    (tmp_path / "parts" / "part2-theory.tex").write_text(
        "\\begin{theorem}\n"
        f"{PART2_SENTENCE}\n"
        "\\end{theorem}\n"
    )
    return main


def write_ledger(
    tmp_path: Path, props: list[dict], schema_version: str = "1.6"
) -> tuple[Path, Path]:
    jsonl_path = tmp_path / "props.jsonl"
    meta_path = tmp_path / "_meta.json"
    meta = {"schema_version": schema_version, "source": {"file": "main.tex"}}
    meta_path.write_text(json.dumps(meta, indent=2) + "\n")
    with jsonl_path.open("w") as fp:
        for p in props:
            fp.write(json.dumps(p, ensure_ascii=False) + "\n")
    return jsonl_path, meta_path


def run_validator(jsonl_path: Path, meta_path: Path, tex_path: Path, *extra: str):
    return subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--jsonl",
            str(jsonl_path),
            "--meta",
            str(meta_path),
            "--tex",
            str(tex_path),
            *extra,
        ],
        capture_output=True,
        text=True,
    )


def base_prop(**overrides) -> dict:
    p = {
        "id": SAMPLE_UUID_A,
        "text": PART2_SENTENCE,
        "location": "parts/part2-theory.tex:L2",
        "containing_block": "sec:theory",
        "claim_type": "claim",
        "asserts": ["bootstrap estimator converges"],
        "evidence_class": "derived",
        "cites": [],
    }
    p.update(overrides)
    return p


# ---------- input-tree resolution (resolver unit level) ----------


def test_input_tree_resolution_document_order(tmp_path):
    """Main + \\input parts resolved in document order; comment/verbatim ignored."""
    main = make_multifile_repo(tmp_path)
    tree = parser.resolve_input_tree(main)
    rel = [str(p.relative_to(tmp_path)) for p in tree]
    assert rel == ["main.tex", "parts/part1.tex", "parts/part2-theory.tex"]


def test_missing_input_target_aborts(tmp_path):
    main = tmp_path / "main.tex"
    main.write_text("\\input{parts/part5-missing}\n")
    with pytest.raises(parser.InputTreeError) as exc:
        parser.resolve_input_tree(main)
    msg = str(exc.value)
    assert "part5-missing" in msg
    assert "main.tex" in msg  # referencing file named


def test_circular_input_aborts(tmp_path):
    (tmp_path / "a.tex").write_text("\\input{b}\n")
    (tmp_path / "b.tex").write_text("\\input{a}\n")
    main = tmp_path / "main.tex"
    main.write_text("\\input{a}\n")
    with pytest.raises(parser.InputTreeError) as exc:
        parser.resolve_input_tree(main)
    assert "cycl" in str(exc.value).lower()  # "cycle"/"cyclic"


def test_absolute_input_path_refused(tmp_path):
    """Audit lens: absolute \\input paths are refused loudly (escape hatch closed)."""
    main = tmp_path / "main.tex"
    main.write_text("\\input{/etc/passwd}\n")
    with pytest.raises(parser.InputTreeError):
        parser.resolve_input_tree(main)


# ---------- file-qualified locations through the validator ----------


def test_prefixed_location_passes_r1_r13(tmp_path):
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(tmp_path, [base_prop()])
    res = run_validator(jsonl, meta, main)
    assert res.returncode == 0, res.stdout + res.stderr


def test_unprefixed_location_still_means_main_file(tmp_path):
    """Backward compat: unprefixed location anchors in the main file itself."""
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(
        tmp_path,
        [base_prop(text=MAIN_SENTENCE, location="L4", asserts=["paper scope"])],
    )
    res = run_validator(jsonl, meta, main)
    assert res.returncode == 0, res.stdout + res.stderr


def test_prefix_on_sub_v16_ledger_fails_with_upgrade_hint(tmp_path):
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(tmp_path, [base_prop()], schema_version="1.5")
    res = run_validator(jsonl, meta, main)
    assert res.returncode == 1
    out = res.stdout + res.stderr
    assert "R13" in out
    assert "1.6" in out  # upgrade hint names the version


def test_prefix_outside_input_tree_fails(tmp_path):
    main = make_multifile_repo(tmp_path)
    (tmp_path / "notes").mkdir()
    (tmp_path / "notes" / "scratch.tex").write_text(f"{PART2_SENTENCE}\n")
    jsonl, meta = write_ledger(
        tmp_path, [base_prop(location="notes/scratch.tex:L1")]
    )
    res = run_validator(jsonl, meta, main)
    assert res.returncode == 1
    out = res.stdout + res.stderr
    assert "not in input tree" in out


def test_r1_matches_across_file_union(tmp_path):
    """R1: prefixed prop text is found in its part file, not the main file."""
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(tmp_path, [base_prop()])
    res = run_validator(jsonl, meta, main)
    out = res.stdout + res.stderr
    assert res.returncode == 0, out
    assert "R1" not in [line for line in out.splitlines() if "[FAIL]" in line]


# ---------- source.parts snapshot (read-only, issue 146) ----------

SNAPSHOT_WARN = "[WARN] source.parts"


def set_parts(meta: Path, parts) -> bytes:
    """Give `_meta.json` a `source.parts` (None: no key) and return its bytes."""
    doc = json.loads(meta.read_text())
    if parts is not None:
        doc["source"]["parts"] = parts
    meta.write_text(json.dumps(doc, indent=2) + "\n")
    return meta.read_bytes()


def snapshot_lines(res) -> list[str]:
    return [line for line in res.stdout.splitlines() if line.startswith(SNAPSHOT_WARN)]


def test_stale_snapshot_is_reported_not_rewritten(tmp_path):
    # spec-example: multifile-manuscript-support / a stale snapshot is reported and not rewritten
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(tmp_path, [base_prop()])
    before = set_parts(meta, ["parts/part1.tex"])
    res = run_validator(jsonl, meta, main)
    assert res.returncode == 0, res.stdout + res.stderr
    assert meta.read_bytes() == before
    lines = snapshot_lines(res)
    assert len(lines) == 1, res.stdout
    assert "parts/part1.tex" in lines[0] and "parts/part2-theory.tex" in lines[0]


# An axiom is not an orphan (R3), so under --strict the only warning left is the snapshot's.
QUIET_PROP = {"claim_type": "axiom"}


def test_strict_fails_on_stale_snapshot(tmp_path):
    # spec-example: multifile-manuscript-support / strict fails on a stale snapshot
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(tmp_path, [base_prop(**QUIET_PROP)])
    before = set_parts(meta, ["parts/part1.tex"])
    res = run_validator(jsonl, meta, main, "--strict")
    assert res.returncode == 1, res.stdout + res.stderr
    assert "=== 1 WARNING(s) ===" in res.stdout, res.stdout
    assert meta.read_bytes() == before


def test_current_snapshot_gives_no_warning(tmp_path):
    # spec-example: multifile-manuscript-support / a current snapshot gives no warning
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(tmp_path, [base_prop(**QUIET_PROP)])
    before = set_parts(meta, ["parts/part1.tex", "parts/part2-theory.tex"])
    res = run_validator(jsonl, meta, main, "--strict")
    assert res.returncode == 0, res.stdout + res.stderr
    assert snapshot_lines(res) == []
    assert meta.read_bytes() == before


def single_file(tmp_path: Path) -> tuple[Path, Path, Path]:
    main = tmp_path / "main.tex"
    main.write_text(f"{MAIN_SENTENCE}\n")
    jsonl, meta = write_ledger(
        tmp_path,
        [base_prop(text=MAIN_SENTENCE, location="L1", asserts=["paper scope"])],
    )
    return main, jsonl, meta


def test_single_file_without_parts_stays_quiet(tmp_path):
    # spec-example: multifile-manuscript-support / a single-file ledger without the key stays quiet
    main, jsonl, meta = single_file(tmp_path)
    before = meta.read_bytes()
    res = run_validator(jsonl, meta, main)
    assert res.returncode == 0, res.stdout + res.stderr
    assert snapshot_lines(res) == []
    assert meta.read_bytes() == before


def test_single_file_with_leftover_parts_is_warned(tmp_path):
    # spec-example: multifile-manuscript-support / a single-file ledger with leftover parts is warned
    main, jsonl, meta = single_file(tmp_path)
    before = set_parts(meta, ["parts/old.tex"])
    res = run_validator(jsonl, meta, main)
    lines = snapshot_lines(res)
    assert len(lines) == 1, res.stdout
    assert "no part files" in lines[0]
    assert meta.read_bytes() == before
    assert json.loads(meta.read_text())["source"]["parts"] == ["parts/old.tex"]


def test_source_not_an_object_gives_no_warning(tmp_path):
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(tmp_path, [base_prop()])
    doc = json.loads(meta.read_text()); doc["source"] = "main.tex"
    meta.write_text(json.dumps(doc) + "\n")
    before = meta.read_bytes()
    res = run_validator(jsonl, meta, main)
    assert snapshot_lines(res) == []
    assert meta.read_bytes() == before


def test_invalid_meta_json_is_a_parse_error_and_unchanged(tmp_path):
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(tmp_path, [base_prop()])
    meta.write_text('{"source": {"parts": [}\n')
    before = meta.read_bytes()
    res = run_validator(jsonl, meta, main)
    assert res.returncode == 2, res.stdout + res.stderr
    assert "parse error" in res.stderr
    assert meta.read_bytes() == before


# ---------- Operation B (refresh) file-aware ----------


def test_refresh_dry_run_is_file_aware(tmp_path):
    """Refresh dry-run resolves a stale prefixed location within its own file."""
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(
        tmp_path, [base_prop(location="parts/part2-theory.tex:L9")]
    )
    refresh = REPO_ROOT / "scripts" / "refresh-prop-locations.py"
    res = subprocess.run(
        [sys.executable, str(refresh), "--jsonl", str(jsonl), "--tex", str(main), "--dry-run"],
        capture_output=True,
        text=True,
    )
    out = res.stdout + res.stderr
    assert res.returncode == 0, out
    assert "parts/part2-theory.tex:L9 → parts/part2-theory.tex:L2" in out
    # dry-run must not write
    assert "parts/part2-theory.tex:L9" in jsonl.read_text()
