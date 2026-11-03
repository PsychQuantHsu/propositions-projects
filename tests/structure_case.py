"""Build small synthetic ledgers with structure sidecars (format 2.0) for the structure tests.

Position n (1-based) of every ledger has id ``pid(n)``. Records, paragraphs and
sections are written with positions and converted to UUIDs, so a test reads like
the spec's example tables.

Defaults (Spectra change add-discourse-dependency-tree): one paragraph per
section, starting at the section's first proposition; inside each paragraph the
first live record is the root and every other record has the previous record as
its head, with relation ``continue``.
"""
from __future__ import annotations

import json
from pathlib import Path

# Position n (1-based) of every synthetic ledger has id UUIDS[n - 1].
UUIDS = [f"01910b9c-d4f0-7{n:03x}-8000-{n:012x}" for n in range(1, 40)]


def pid(pos: int) -> str:
    return UUIDS[pos - 1]


def chain(order: list[int]) -> list[dict]:
    """Records for `order` in one paragraph: the first is the root, each later one heads to the one before."""
    return [{"pos": p} if i == 0 else {"pos": p, "head": order[i - 1], "relation": "continue"} for i, p in enumerate(order)]


def default_records(n: int, paragraph_starts: tuple[int, ...] = (1,), retired: tuple[int, ...] = ()) -> list[dict]:
    """One record per live position; a chain inside each paragraph."""
    live = [p for p in range(1, n + 1) if p not in retired]
    starts = sorted(set(paragraph_starts))
    records = []
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else n + 1
        records += chain([p for p in live if start <= p < end])
    return records


def _record_out(r: dict) -> dict:
    rec = {"prop_id": pid(r["pos"])}
    for key, value in r.items():
        if key == "pos":
            continue
        if key == "head":
            rec["head"] = pid(value) if isinstance(value, int) else value
        elif key == "also":
            rec["also"] = [{**a, "to": pid(a["to"]) if isinstance(a.get("to"), int) else a.get("to")} for a in value]
        elif key == "refers_to" and isinstance(value, int):
            rec["refers_to"] = pid(value)
        else:
            rec[key] = value
    return rec


def write_case(
    tmp: Path,
    n: int,
    records: list[dict] | None = None,
    sections: list[dict] | None = None,
    thesis: list[int] | None = None,
    retired: tuple[int, ...] = (),
    paragraphs: list[dict] | None = None,
    cites: dict[int, list[int]] | None = None,
    version: str | None = "2.0",
) -> Path:
    """Write main.jsonl (n props), discourse.jsonl and structure.json; return the ledger path.

    Records use `pos`, and positions in `head` and `also[].to`; sections and
    paragraphs use `first` for first_prop. Paragraph `head` is a paragraph id.
    `cites` maps a position to the positions its proposition cites.
    """
    cites = cites or {}
    ledger = tmp / "main.jsonl"
    lines = []
    for p in range(1, n + 1):
        prop = {"id": pid(p), "text": f"Sentence {p}."}
        if p in cites:
            prop["cites"] = [pid(c) for c in cites[p]]
        if p in retired:
            prop["retired"] = {"since": "2026-11-02", "mechanism": "deleted", "match": "absent", "reason": "test"}
        lines.append(json.dumps(prop))
    ledger.write_text("\n".join(lines) + "\n")

    first_live = next(p for p in range(1, n + 1) if p not in retired)
    sections = sections or [{"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": first_live}]
    if paragraphs is None:
        paragraphs = [{"id": f"p-{i}", "first": s["first"]} for i, s in enumerate(sections, 1)]
    if records is None:
        records = default_records(n, tuple(p["first"] for p in paragraphs), retired)
    (tmp / "discourse.jsonl").write_text("\n".join(json.dumps(_record_out(r)) for r in records) + "\n")

    structure: dict = {}
    if version is not None:
        structure["structure_version"] = version
    structure["thesis"] = [pid(t) for t in (thesis if thesis is not None else [first_live])]
    structure["sections"] = [
        {"id": s["id"], "heading": s["heading"], "role": s["role"], "first_prop": pid(s["first"]),
         **({"parent": s["parent"]} if "parent" in s else {})}
        for s in sections
    ]
    structure["paragraphs"] = [
        {"id": p["id"], "first_prop": pid(p["first"]), **{k: p[k] for k in ("head", "relation", "type") if k in p}}
        for p in paragraphs
    ]
    (tmp / "structure.json").write_text(json.dumps(structure, indent=1) + "\n")
    return ledger


def with_changes(n: int, changes: dict[int, dict], paragraph_starts: tuple[int, ...] = (1,)) -> list[dict]:
    """Default records with the record at each position extended or overridden by `changes`.

    A change may set ``"head": None`` to make the record a root; that removes
    both `head` and `relation`.
    """
    recs = default_records(n, paragraph_starts)
    by_pos = {r["pos"]: i for i, r in enumerate(recs)}
    for pos, change in changes.items():
        merged = {**recs[by_pos[pos]], **change}
        if change.get("head", "absent") is None:
            merged.pop("head", None)
            merged.pop("relation", None)
        recs[by_pos[pos]] = merged
    return recs


VOCABULARY = """\
moves:
  - {id: state-goal, does: States what the article sets out to do., zh: 說目的}
  - {id: state-baseline, does: Says what serves as the comparison., zh: 說對照基準}
  - {id: state-concern, does: Says what the study is most concerned with., zh: 說關注點}
paragraph_types:
  - {id: goal-summary, does: Sums up the study's goal., zh: 目的總結段}
"""


def write_vocabulary(tmp: Path, text: str = VOCABULARY) -> Path:
    path = tmp / "vocabulary.yaml"
    path.write_text(text, encoding="utf-8")
    return path
