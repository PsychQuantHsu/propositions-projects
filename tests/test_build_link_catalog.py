"""Tests for build-link-catalog.py (Spectra change add-paragraph-moves).

Spec: Requirement "The link catalog is generated from annotated sidecars".
"""
from __future__ import annotations

import csv
import subprocess
import sys
from pathlib import Path

import pytest

pytest.importorskip("yaml")

sys.path.insert(0, str(Path(__file__).parent))
from link_case import RECORDS, write_article, write_vocabulary  # noqa: E402
from structure_case import pid, write_case  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "build-link-catalog.py"
HEADER = "kind,paragraph_type,from,to,relation,scope,label,count"


def build(tmp: Path, *sources: tuple[str, Path], extra: tuple[str, ...] = ()) -> tuple[subprocess.CompletedProcess, Path]:
    out = tmp / "links.csv"
    args = [sys.executable, str(SCRIPT), "--vocabulary", str(write_vocabulary(tmp)), "--out", str(out), *extra]
    for label, directory in sources:
        args += ["--sidecars", f"{label}={directory}"]
    return subprocess.run(args, capture_output=True, text=True), out


def rows(path: Path) -> set[tuple[str, ...]]:
    with path.open(encoding="utf-8", newline="") as fh:
        return {tuple(r) for r in list(csv.reader(fh))[1:]}


def article(tmp: Path, name: str = "a") -> Path:
    write_article(tmp / name)
    return tmp / name


def test_reading_order_and_dependency_are_separate_kinds(tmp_path: Path) -> None:
    directory = tmp_path / "a"
    directory.mkdir()
    write_case(directory, 2, [{"pos": 1, "move": "state-goal"}, {"pos": 2, "head": 1, "relation": "specification", "move": "state-baseline"}],
               paragraphs=[{"id": "p-1", "first": 1, "type": "goal-summary"}])
    result, out = build(tmp_path, ("empirical", directory))
    assert result.returncode == 0, result.stderr
    assert {
        ("next", "goal-summary", "START", "state-goal", "ROOT", "paragraph", "empirical", "1"),
        ("next", "goal-summary", "state-goal", "state-baseline", "specification", "paragraph", "empirical", "1"),
        ("head", "goal-summary", "state-baseline", "state-goal", "specification", "paragraph", "empirical", "1"),
    } <= rows(out)


def test_every_kind_of_link(tmp_path: Path) -> None:
    result, out = build(tmp_path, ("empirical", article(tmp_path)))
    assert result.returncode == 0, result.stderr
    assert rows(out) == {
        ("next", "goal-summary", "START", "preview", "ROOT", "paragraph", "empirical", "1"),
        ("next", "goal-summary", "preview", "state-goal", "specification", "paragraph", "empirical", "1"),
        ("next", "goal-summary", "state-goal", "state-baseline", "continue", "paragraph", "empirical", "1"),
        ("next", "goal-summary", "state-baseline", "END", "", "paragraph", "empirical", "1"),
        ("next", "gap", "START", "define", "ROOT", "paragraph", "empirical", "1"),
        ("next", "gap", "define", "state-concern", "restatement", "paragraph", "empirical", "1"),
        ("next", "gap", "state-concern", "END", "", "paragraph", "empirical", "1"),
        ("next", "", "START", "state-result", "ROOT", "paragraph", "empirical", "1"),
        ("head", "goal-summary", "state-goal", "preview", "specification", "paragraph", "empirical", "1"),
        ("head", "goal-summary", "state-baseline", "state-goal", "continue", "paragraph", "empirical", "1"),
        ("head", "gap", "state-concern", "define", "restatement", "paragraph", "empirical", "1"),
        ("also", "goal-summary", "state-goal", "state-baseline", "contrast", "paragraph", "empirical", "1"),
        ("cites", "gap", "state-concern", "define", "", "paragraph", "empirical", "1"),
        ("cites", "", "state-result", "define", "", "article", "empirical", "1"),
        ("discharge", "", "state-result", "preview", "announcement", "article", "empirical", "1"),
        ("paragraph", "", "gap", "goal-summary", "contrast", "section", "empirical", "1"),
    }


def test_links_with_an_unlabelled_end_are_left_out_and_counted(tmp_path: Path) -> None:
    result, _ = build(tmp_path, ("empirical", article(tmp_path)))
    # sentence 7 has no move: next 6 -> 7, next 7 -> END and head 7 -> 6 are left out.
    assert "empirical 3" in result.stdout


def test_the_header_is_exact_and_rows_are_sorted_by_kind(tmp_path: Path) -> None:
    _, out = build(tmp_path, ("empirical", article(tmp_path)))
    lines = out.read_text(encoding="utf-8").splitlines()
    assert lines[0] == HEADER
    kinds = [line.split(",")[0] for line in lines[1:]]
    order = ["next", "head", "also", "cites", "discharge", "paragraph"]
    assert kinds == sorted(kinds, key=order.index)


def test_counts_add_up_per_label(tmp_path: Path) -> None:
    _, out = build(tmp_path, ("empirical", article(tmp_path, "a")), ("empirical", article(tmp_path, "b")),
                   ("default", article(tmp_path, "c")))
    found = rows(out)
    assert ("paragraph", "", "gap", "goal-summary", "contrast", "section", "empirical", "2") in found
    assert ("paragraph", "", "gap", "goal-summary", "contrast", "section", "default", "1") in found


def test_the_catalog_carries_no_manuscript_content(tmp_path: Path) -> None:
    directory = article(tmp_path, "secret-directory")
    _, out = build(tmp_path, ("empirical", directory))
    text = out.read_text(encoding="utf-8")
    for forbidden in ("Sentence", pid(1), pid(4), "p-1", "p-2", "c-a", "sec-1", "secret-directory", str(tmp_path)):
        assert forbidden not in text, forbidden


def test_the_same_input_gives_the_same_bytes(tmp_path: Path) -> None:
    a, b = article(tmp_path, "a"), article(tmp_path, "b")
    _, out = build(tmp_path, ("empirical", a), ("default", b))
    first = out.read_bytes()
    build(tmp_path, ("default", b), ("empirical", a))
    assert out.read_bytes() == first


def test_check_passes_on_a_fresh_catalog_and_writes_nothing(tmp_path: Path) -> None:
    directory = article(tmp_path)
    _, out = build(tmp_path, ("empirical", directory))
    before = out.read_bytes()
    result, _ = build(tmp_path, ("empirical", directory), extra=("--check",))
    assert result.returncode == 0 and out.read_bytes() == before


def test_the_check_mode_finds_a_stale_catalog(tmp_path: Path) -> None:
    directory = article(tmp_path)
    _, out = build(tmp_path, ("empirical", directory))
    before = out.read_bytes()
    discourse = directory / "discourse.jsonl"
    discourse.write_text(discourse.read_text().replace('"state-baseline"', '"state-concern"'))
    result, _ = build(tmp_path, ("empirical", directory), extra=("--check",))
    assert result.returncode == 1 and "stale" in result.stdout + result.stderr
    assert out.read_bytes() == before


def test_check_without_a_file_is_stale(tmp_path: Path) -> None:
    result, out = build(tmp_path, ("empirical", article(tmp_path)), extra=("--check",))
    assert result.returncode == 1 and not out.exists()


def test_a_pending_head_is_refused(tmp_path: Path) -> None:
    directory = tmp_path / "a"
    directory.mkdir()
    write_case(directory, 2, [{"pos": 1, "move": "state-goal"}, {"pos": 2, "head": "pending", "move": "state-goal"}])
    result, out = build(tmp_path, ("empirical", directory))
    assert result.returncode == 2 and "pending" in result.stderr and not out.exists()


def test_a_value_outside_the_vocabulary_is_an_input_error(tmp_path: Path) -> None:
    records = [dict(r) for r in RECORDS]
    records[0]["move"] = "state-gaol"
    write_article(tmp_path / "a", records)
    result, out = build(tmp_path, ("empirical", tmp_path / "a"))
    assert result.returncode == 2 and "state-gaol" in result.stderr and not out.exists()


@pytest.mark.parametrize("source", ["no-equals-sign", "=dir", "Bad Label=dir"])
def test_a_bad_sidecars_argument_is_an_input_error(tmp_path: Path, source: str) -> None:
    args = [sys.executable, str(SCRIPT), "--vocabulary", str(write_vocabulary(tmp_path)), "--out", str(tmp_path / "c.csv"), "--sidecars", source]
    assert subprocess.run(args, capture_output=True, text=True).returncode == 2


def test_a_missing_directory_is_an_input_error(tmp_path: Path) -> None:
    result, _ = build(tmp_path, ("empirical", tmp_path / "absent"))
    assert result.returncode == 2
