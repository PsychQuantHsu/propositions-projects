"""The closed vocabulary of sentence moves and paragraph types.

Spectra change add-paragraph-moves. `plugins/propositions/catalog/vocabulary.yaml`
says what a sentence (a move) or a paragraph (a type) can be doing. The key set
of an entry is closed so that manuscript text has no field to go into.

PyYAML is imported inside load_vocabulary: every other script in this plugin
needs only the standard library, and sidecars without `move` or `type` never
reach this code.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from _lib.structure_io import InputError

DEFAULT_VOCABULARY = Path(__file__).resolve().parents[2] / "catalog" / "vocabulary.yaml"
ENTRY_ID = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
TOP_KEYS = frozenset({"moves", "paragraph_types"})
ENTRY_KEYS = frozenset({"id", "does", "zh", "not"})


@dataclass(frozen=True)
class Entry:
    id: str
    does: str
    zh: str
    not_: str | None = None


@dataclass(frozen=True)
class Vocabulary:
    moves: dict[str, Entry]
    paragraph_types: dict[str, Entry]


def require_yaml():
    """The yaml module, or an InputError naming PyYAML."""
    try:
        import yaml
    except ImportError as exc:
        raise InputError(
            "reading moves or paragraph types needs PyYAML, which is not installed: python3 -m pip install pyyaml"
        ) from exc
    return yaml


def _read_yaml(path: Path) -> object:
    yaml = require_yaml()
    if not path.is_file():
        raise InputError(f"vocabulary not found: {path}")
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise InputError(f"{path.name}: invalid YAML ({exc})") from exc


def _entries(name: str, raw: object, source: str) -> dict[str, Entry]:
    if not isinstance(raw, list):
        raise InputError(f"{source}: `{name}` must be a list")
    entries: dict[str, Entry] = {}
    for i, item in enumerate(raw, 1):
        if not isinstance(item, dict):
            raise InputError(f"{source}: {name} entry {i} is not a mapping")
        entry_id = item.get("id")
        if not isinstance(entry_id, str) or not ENTRY_ID.fullmatch(entry_id):
            raise InputError(f"{source}: {name} entry {i} has an invalid id {entry_id!r}")
        label = f"{source}: {name} `{entry_id}`"
        unknown = sorted(set(item) - ENTRY_KEYS)
        if unknown:
            raise InputError(f"{label} has unknown key(s) {', '.join(unknown)}")
        if entry_id in entries:
            raise InputError(f"{label} is repeated")
        for key in ("does", "zh"):
            if not isinstance(item.get(key), str) or not item[key].strip():
                raise InputError(f"{label} needs a non-empty `{key}`")
        not_ = item.get("not")
        if not_ is not None and not isinstance(not_, str):
            raise InputError(f"{label}: `not` must be a string")
        entries[entry_id] = Entry(entry_id, item["does"], item["zh"], not_)
    return entries


def load_vocabulary(path: Path | None = None) -> Vocabulary:
    """Read and check the vocabulary; every failure is an InputError naming the value."""
    path = path or DEFAULT_VOCABULARY
    data = _read_yaml(path)
    if not isinstance(data, dict):
        raise InputError(f"{path.name}: not a mapping")
    unknown = sorted(set(data) - TOP_KEYS)
    if unknown:
        raise InputError(f"{path.name}: unknown top-level key(s) {', '.join(unknown)}")
    return Vocabulary(
        _entries("moves", data.get("moves"), path.name),
        _entries("paragraph_types", data.get("paragraph_types"), path.name),
    )
