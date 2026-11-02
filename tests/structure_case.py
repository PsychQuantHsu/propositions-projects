"""Build small synthetic ledgers with structure sidecars for the structure tests.

Position n (1-based) of every ledger has id ``pid(n)``. Records and sections are
written with positions and converted to UUIDs, so a test reads like the spec's
example tables.
"""
from __future__ import annotations

import json
from pathlib import Path

# Position n (1-based) of every synthetic ledger has id UUIDS[n - 1].
UUIDS = [f"01910b9c-d4f0-7{n:03x}-8000-{n:012x}" for n in range(1, 40)]


def pid(pos: int) -> str:
    return UUIDS[pos - 1]


def default_records(n: int) -> list[dict]:
    """One record per position: `start` first, `continue` afterwards."""
    return [{"pos": p, "relation": "start" if p == 1 else "continue"} for p in range(1, n + 1)]


def write_case(
    tmp: Path,
    n: int,
    records: list[dict] | None = None,
    sections: list[dict] | None = None,
    thesis: list[int] | None = None,
    retired: tuple[int, ...] = (),
) -> Path:
    """Write main.jsonl (n props), discourse.jsonl and structure.json; return the ledger path.

    Records use `pos` for prop_id and, in `refers_to`, a position; both are
    converted to UUIDs. Sections use `first` for first_prop.
    """
    ledger = tmp / "main.jsonl"
    lines = []
    for p in range(1, n + 1):
        prop = {"id": pid(p), "text": f"Sentence {p}."}
        if p in retired:
            prop["retired"] = {"since": "2026-11-02", "mechanism": "deleted", "match": "absent", "reason": "test"}
        lines.append(json.dumps(prop))
    ledger.write_text("\n".join(lines) + "\n")

    records = default_records(n) if records is None else records
    out = []
    for r in records:
        rec = {k: v for k, v in r.items() if k not in ("pos", "refers_to")}
        rec = {"prop_id": pid(r["pos"]), **rec}
        if "refers_to" in r:
            rec["refers_to"] = pid(r["refers_to"])
        out.append(json.dumps(rec))
    (tmp / "discourse.jsonl").write_text("\n".join(out) + "\n")

    first_live = next(p for p in range(1, n + 1) if p not in retired)
    sections = sections or [{"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": first_live}]
    structure = {
        "structure_version": "1.0",
        "thesis": [pid(t) for t in (thesis if thesis is not None else [first_live])],
        "sections": [
            {"id": s["id"], "heading": s["heading"], "role": s["role"], "first_prop": pid(s["first"])}
            for s in sections
        ],
    }
    (tmp / "structure.json").write_text(json.dumps(structure, indent=1) + "\n")
    return ledger


def with_changes(n: int, changes: dict[int, dict]) -> list[dict]:
    """Default records with the record at each position replaced/extended by `changes`."""
    recs = default_records(n)
    for pos, change in changes.items():
        recs[pos - 1] = {"pos": pos, **{k: v for k, v in recs[pos - 1].items() if k != "pos"}, **change}
    return recs
