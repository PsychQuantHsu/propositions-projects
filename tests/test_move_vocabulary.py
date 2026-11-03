"""Tests for _lib/move_vocabulary.py (Spectra change add-paragraph-moves).

Spec: Requirement "A closed vocabulary defines moves and paragraph types". The
closed key set is what keeps manuscript text out of the file, so it is tested
with the key most likely to invite it.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from structure_case import VOCABULARY, write_vocabulary  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(REPO_ROOT / "plugins" / "propositions" / "scripts"))
from _lib.move_vocabulary import DEFAULT_VOCABULARY, load_vocabulary  # noqa: E402
from _lib.structure_io import InputError  # noqa: E402


def entry(extra: str = "", id_: str = "state-goal", does: str = "does: A sentence., ", zh: str = "zh: 甲") -> str:
    return f"moves:\n  - {{id: {id_}, {does}{zh}{extra}}}\nparagraph_types: []\n"


def test_loads_moves_and_types(tmp_path: Path) -> None:
    vocabulary = load_vocabulary(write_vocabulary(tmp_path))
    assert list(vocabulary.moves) == ["state-goal", "state-baseline", "state-concern"]
    assert vocabulary.moves["state-goal"].zh == "說目的"
    assert vocabulary.paragraph_types["goal-summary"].zh == "目的總結段"


def test_not_is_optional(tmp_path: Path) -> None:
    path = write_vocabulary(tmp_path, entry(", not: Not a preview."))
    assert load_vocabulary(path).moves["state-goal"].not_ == "Not a preview."


def test_unknown_key_is_refused(tmp_path: Path) -> None:
    with pytest.raises(InputError, match=r"state-goal.*example"):
        load_vocabulary(write_vocabulary(tmp_path, entry(", example: In summary the goal is")))


def test_repeated_id_is_refused(tmp_path: Path) -> None:
    text = "moves:\n  - {id: state-goal, does: a., zh: 甲}\n  - {id: state-goal, does: b., zh: 乙}\nparagraph_types: []\n"
    with pytest.raises(InputError, match="state-goal"):
        load_vocabulary(write_vocabulary(tmp_path, text))


@pytest.mark.parametrize("bad", ["State-Goal", "state_goal", "-state", "state goal"])
def test_id_format_is_checked(tmp_path: Path, bad: str) -> None:
    with pytest.raises(InputError, match="id"):
        load_vocabulary(write_vocabulary(tmp_path, entry(id_=f'"{bad}"')))


@pytest.mark.parametrize("text", [entry(does=""), entry(zh="zh: ''")])
def test_does_and_zh_are_required(tmp_path: Path, text: str) -> None:
    with pytest.raises(InputError, match="does|zh"):
        load_vocabulary(write_vocabulary(tmp_path, text))


def test_top_level_keys_are_closed(tmp_path: Path) -> None:
    with pytest.raises(InputError, match="notes"):
        load_vocabulary(write_vocabulary(tmp_path, VOCABULARY + "notes: anything\n"))


def test_missing_file_is_an_input_error(tmp_path: Path) -> None:
    with pytest.raises(InputError, match="absent.yaml"):
        load_vocabulary(tmp_path / "absent.yaml")


def test_invalid_yaml_is_an_input_error(tmp_path: Path) -> None:
    with pytest.raises(InputError, match="vocabulary.yaml"):
        load_vocabulary(write_vocabulary(tmp_path, "moves: [unclosed\n"))


def test_missing_parser_names_pyyaml(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    path = write_vocabulary(tmp_path)
    monkeypatch.setitem(sys.modules, "yaml", None)
    with pytest.raises(InputError, match="PyYAML"):
        load_vocabulary(path)


def test_shipped_vocabulary_is_valid() -> None:
    vocabulary = load_vocabulary(DEFAULT_VOCABULARY)
    assert vocabulary.moves and vocabulary.paragraph_types
    assert all(e.does.endswith(".") and e.zh for e in (*vocabulary.moves.values(), *vocabulary.paragraph_types.values()))
