"""Loading the ledger and the article-structure sidecars (format 2.0).

Spectra change add-discourse-dependency-tree. Shared by validate-structure.py
and, through it, structure-state.py and structure-metrics.py. Every failure is an
InputError (exit 2 in each tool).
"""
from __future__ import annotations

import importlib.util
import json
from dataclasses import dataclass
from pathlib import Path

STRUCTURE_VERSION = "2.0"
VALIDATE_PROPOSITIONS = Path(__file__).resolve().parent.parent / "validate-propositions.py"


class InputError(Exception):
    """A file is missing, unreadable or not valid JSON, or the format is not 2.0; exit 2."""


@dataclass(frozen=True)
class Ledger:
    live: list[str]  # non-retired ids in ledger order
    cites: dict[str, frozenset[str]]  # id -> ids it cites


def load_ledger(path: Path) -> Ledger:
    """The ledger via validate-propositions' loader."""
    if not path.is_file():
        raise InputError(f"ledger not found: {path}")
    spec = importlib.util.spec_from_file_location(
        "validate_propositions", VALIDATE_PROPOSITIONS
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    try:
        _, props, _ = module.load_props_jsonl(path)
    except ValueError as exc:
        raise InputError(f"{path}: {exc}") from exc
    live = [p["id"] for p in props if "retired" not in p]
    cites = {p["id"]: frozenset(c for c in p.get("cites") or [] if isinstance(c, str)) for p in props}
    return Ledger(live, cites)


def load_discourse(path: Path) -> list[tuple[int, dict]]:
    if not path.is_file():
        raise InputError(f"discourse sidecar not found: {path}")
    records = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise InputError(f"{path.name} line {lineno}: invalid JSON ({exc.msg})") from exc
        if not isinstance(obj, dict):
            raise InputError(f"{path.name} line {lineno}: not a JSON object")
        records.append((lineno, obj))
    return records


def load_structure(path: Path) -> dict:
    if not path.is_file():
        raise InputError(f"structure sidecar not found: {path}")
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise InputError(f"{path.name}: invalid JSON at line {exc.lineno} ({exc.msg})") from exc
    if not isinstance(obj, dict):
        raise InputError(f"{path.name}: not a JSON object")
    version = obj.get("structure_version")
    if version != STRUCTURE_VERSION:
        raise InputError(
            f"{path.name}: structure_version {version!r} is not {STRUCTURE_VERSION!r}; "
            "migrate version 1.0 sidecars with migrate-structure-v2.py"
        )
    return obj
