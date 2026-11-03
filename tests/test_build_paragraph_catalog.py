"""Tests for build-paragraph-catalog.py (Spectra change add-paragraph-moves).

Spec: Requirement "The paragraph catalog is generated from annotated sidecars".
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

sys.path.insert(0, str(Path(__file__).parent))
from structure_case import pid, write_case, write_vocabulary  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "build-paragraph-catalog.py"
RECORDS = [
    {"pos": 1, "move": "state-goal"},
    {"pos": 2, "head": 1, "relation": "specification", "move": "state-baseline"},
    {"pos": 3, "head": 2, "relation": "continue", "move": "state-concern"},
]


def manuscript(tmp: Path, name: str, records: list[dict] = RECORDS, typed: bool = True) -> Path:
    directory = tmp / name
    directory.mkdir()
    paragraph = {"id": "p-1", "first": 1, **({"type": "goal-summary"} if typed else {})}
    write_case(directory, len(records), records, paragraphs=[paragraph])
    return directory


def build(tmp: Path, *sources: tuple[str, Path], extra: tuple[str, ...] = ()) -> tuple[subprocess.CompletedProcess, Path]:
    vocabulary = write_vocabulary(tmp)
    out = tmp / "catalog.yaml"
    args = [sys.executable, str(SCRIPT), "--vocabulary", str(vocabulary), "--out", str(out), *extra]
    for label, directory in sources:
        args += ["--sidecars", f"{label}={directory}"]
    return subprocess.run(args, capture_output=True, text=True), out


def test_a_transition_is_counted_per_label(tmp_path: Path) -> None:
    result, out = build(tmp_path, ("empirical", manuscript(tmp_path, "a")))
    assert result.returncode == 0, result.stderr
    catalog = yaml.safe_load(out.read_text())
    options = catalog["paragraph_types"]["goal-summary"]["moves"]["state-goal"]["next"]
    assert options == [{"move": "state-baseline", "relation": "specification", "head_move": "state-goal", "counts": {"empirical": 1}}]


def test_counts_add_up_across_manuscripts_and_labels(tmp_path: Path) -> None:
    _, out = build(tmp_path, ("empirical", manuscript(tmp_path, "a")), ("empirical", manuscript(tmp_path, "b")),
                   ("default", manuscript(tmp_path, "c")))
    catalog = yaml.safe_load(out.read_text())
    kind = catalog["paragraph_types"]["goal-summary"]
    assert catalog["sources"] == {"default": 1, "empirical": 2}
    assert kind["paragraphs"] == {"default": 1, "empirical": 2}
    assert kind["opening_moves"]["state-goal"] == {"default": 1, "empirical": 2}
    assert kind["moves"]["state-goal"]["next"][0]["counts"] == {"default": 1, "empirical": 2}


def test_the_last_sentence_goes_to_end(tmp_path: Path) -> None:
    _, out = build(tmp_path, ("empirical", manuscript(tmp_path, "a")))
    options = yaml.safe_load(out.read_text())["paragraph_types"]["goal-summary"]["moves"]["state-concern"]["next"]
    assert options == [{"move": "END", "counts": {"empirical": 1}}]


def test_a_root_after_its_child_has_relation_root(tmp_path: Path) -> None:
    records = [{"pos": 1, "head": 2, "relation": "specification", "move": "state-goal"}, {"pos": 2, "move": "state-baseline"}]
    _, out = build(tmp_path, ("empirical", manuscript(tmp_path, "a", records)))
    option = yaml.safe_load(out.read_text())["paragraph_types"]["goal-summary"]["moves"]["state-goal"]["next"][0]
    assert option == {"move": "state-baseline", "relation": "ROOT", "head_move": None, "counts": {"empirical": 1}}


def test_unlabelled_sentences_and_untyped_paragraphs_are_excluded_and_reported(tmp_path: Path) -> None:
    records = [{"pos": 1, "move": "state-goal"}, {"pos": 2, "head": 1, "relation": "continue"}, {"pos": 3, "head": 2, "relation": "continue", "move": "state-concern"}]
    _, out = build(tmp_path, ("empirical", manuscript(tmp_path, "a", records)), ("default", manuscript(tmp_path, "b", typed=False)))
    catalog = yaml.safe_load(out.read_text())
    assert catalog["excluded"] == {"propositions_without_move": {"default": 0, "empirical": 1},
                                   "paragraphs_without_type": {"default": 1, "empirical": 0}}
    moves = catalog["paragraph_types"]["goal-summary"]["moves"]
    assert "next" not in moves.get("state-goal", {}) or moves["state-goal"]["next"] == []
    assert moves["state-concern"]["next"] == [{"move": "END", "counts": {"empirical": 1}}]


def test_the_catalog_carries_no_manuscript_content(tmp_path: Path) -> None:
    directory = manuscript(tmp_path, "secret-directory")
    _, out = build(tmp_path, ("empirical", directory))
    text = out.read_text()
    for forbidden in ("Sentence", pid(1), pid(2), "p-1", "secret-directory", str(tmp_path)):
        assert forbidden not in text, forbidden


def test_the_same_input_gives_the_same_bytes(tmp_path: Path) -> None:
    a, b = manuscript(tmp_path, "a"), manuscript(tmp_path, "b")
    _, out = build(tmp_path, ("empirical", a), ("default", b))
    first = out.read_bytes()
    build(tmp_path, ("default", b), ("empirical", a))
    assert out.read_bytes() == first


def test_check_passes_on_a_fresh_catalog_and_writes_nothing(tmp_path: Path) -> None:
    directory = manuscript(tmp_path, "a")
    _, out = build(tmp_path, ("empirical", directory))
    before = out.read_bytes()
    result, _ = build(tmp_path, ("empirical", directory), extra=("--check",))
    assert result.returncode == 0 and out.read_bytes() == before


def test_the_check_mode_finds_a_stale_catalog(tmp_path: Path) -> None:
    directory = manuscript(tmp_path, "a")
    _, out = build(tmp_path, ("empirical", directory))
    before = out.read_bytes()
    discourse = directory / "discourse.jsonl"
    discourse.write_text(discourse.read_text().replace("state-baseline", "state-concern"))
    result, _ = build(tmp_path, ("empirical", directory), extra=("--check",))
    assert result.returncode == 1 and "stale" in result.stdout + result.stderr
    assert out.read_bytes() == before


def test_check_without_a_file_is_stale(tmp_path: Path) -> None:
    result, out = build(tmp_path, ("empirical", manuscript(tmp_path, "a")), extra=("--check",))
    assert result.returncode == 1 and not out.exists()


def test_a_value_outside_the_vocabulary_is_an_input_error(tmp_path: Path) -> None:
    records = [{"pos": 1, "move": "state-gaol"}]
    result, out = build(tmp_path, ("empirical", manuscript(tmp_path, "a", records)))
    assert result.returncode == 2 and "state-gaol" in result.stderr and not out.exists()


@pytest.mark.parametrize("source", ["no-equals-sign", "=dir", "Bad Label=dir"])
def test_a_bad_sidecars_argument_is_an_input_error(tmp_path: Path, source: str) -> None:
    vocabulary = write_vocabulary(tmp_path)
    args = [sys.executable, str(SCRIPT), "--vocabulary", str(vocabulary), "--out", str(tmp_path / "c.yaml"), "--sidecars", source]
    assert subprocess.run(args, capture_output=True, text=True).returncode == 2


def test_a_missing_directory_is_an_input_error(tmp_path: Path) -> None:
    result, _ = build(tmp_path, ("empirical", tmp_path / "absent"))
    assert result.returncode == 2
