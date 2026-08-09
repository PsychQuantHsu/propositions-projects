"""Tests for v1.6 multi-file manuscript support (spectra: add-manuscript-onboarding).

Covers spec `multifile-manuscript-support`:
- Input-tree resolution from the main file (`\\input`/`\\include`, comment/verbatim
  immunity, missing target, cycle)
- File-qualified location syntax (prefixed R1/R13, backward-compatible unprefixed,
  prefix on sub-v1.6 ledger fails loudly)
- Location prefix outside the input tree fails
- `_meta.json` `source.parts` non-authoritative snapshot refresh
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


def run_validator(jsonl_path: Path, meta_path: Path, tex_path: Path):
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


# ---------- source.parts snapshot ----------


def test_parts_snapshot_refreshed_after_run(tmp_path):
    main = make_multifile_repo(tmp_path)
    jsonl, meta = write_ledger(tmp_path, [base_prop()])
    run_validator(jsonl, meta, main)
    refreshed = json.loads(meta.read_text())
    assert refreshed["source"]["parts"] == [
        "parts/part1.tex",
        "parts/part2-theory.tex",
    ]


def test_single_file_run_adds_no_parts_key(tmp_path):
    """No churn on single-file ledgers (Hsu case): absent parts stays absent."""
    main = tmp_path / "main.tex"
    main.write_text(f"{MAIN_SENTENCE}\n")
    jsonl, meta = write_ledger(
        tmp_path,
        [base_prop(text=MAIN_SENTENCE, location="L1", asserts=["paper scope"])],
    )
    res = run_validator(jsonl, meta, main)
    assert res.returncode == 0, res.stdout + res.stderr
    refreshed = json.loads(meta.read_text())
    assert "parts" not in refreshed["source"]


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
