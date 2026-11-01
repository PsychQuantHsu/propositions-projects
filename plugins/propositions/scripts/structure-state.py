#!/usr/bin/env python3
"""structure-state.py — what the article owes the reader at a position.

Reads the ledger and its structure sidecars (see
`plugins/propositions/docs/STRUCTURE.md`) and reports, for position t (t
included): t's place in the ledger, the section containing t, t's relation to
the previous proposition, the commitments opened at or before t that are not
yet discharged, the future-work commitments opened so far, and whether a
thesis proposition has appeared.

Open commitments are ordered by kind — announcement, hypothesis, plan,
question, aim, setup — and within a kind by the position that opened them,
earliest first. That order is the mechanical answer to "what should the next
proposition advance".

The sidecars must pass S1–S3 of validate-structure.py first; an invalid
section plan (S5) only removes the section from the report.

Usage:
    python3 structure-state.py --jsonl main.jsonl --at <prop uuid | end>
        [--structure structure.json] [--discourse discourse.jsonl] [--format text|json]

Exit code:
    0 — state reported
    1 — the sidecars fail S1, S2 or S3
    2 — an input file is missing or invalid, or --at is not a non-retired proposition
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

URGENCY = ("announcement", "hypothesis", "plan", "question", "aim", "setup")
GATING_RULES = ("S1", "S2", "S3")
EXIT_OK, EXIT_STRUCTURE, EXIT_USAGE = 0, 1, 2


def _load_validator():
    spec = importlib.util.spec_from_file_location("validate_structure", Path(__file__).parent / "validate-structure.py")
    module = importlib.util.module_from_spec(spec)
    # dataclasses resolve string annotations through sys.modules, so the module
    # must be registered before it executes.
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


vs = _load_validator()


class StructureError(Exception):
    """The sidecars fail S1–S3; exit 1."""


def compute_state(ledger: Path, structure_path: Path, discourse_path: Path, at: str) -> dict:
    live, _ = vs.load_ledger(ledger)
    raw = vs.load_discourse(discourse_path)
    structure = vs.load_structure(structure_path)
    positions = {pid: i for i, pid in enumerate(live, 1)}
    records = [
        vs.Record(i, line, data, positions.get(data.get("prop_id")) if isinstance(data.get("prop_id"), str) else None)
        for i, (line, data) in enumerate(raw)
    ]
    report = vs.Report()
    vs.check_s1(records, live, report)
    vs.check_s2(records, positions, report)
    commitments = vs.check_s3(records, report)
    failing = [r for r in GATING_RULES if report.status(r) == "FAIL"]
    if failing:
        count = sum(1 for r in failing for p in report.problems[r] if p.severity == "error")
        raise StructureError(
            f"the sidecars fail {', '.join(failing)} ({count} error(s)); run validate-structure.py and fix them first"
        )

    if not live:
        raise vs.InputError("the ledger has no non-retired propositions")
    if at == "end":
        t = len(live)
    elif at in positions:
        t = positions[at]
    else:
        raise vs.InputError(f"--at {at} is not a non-retired ledger proposition")

    warnings: list[str] = []
    # partial=True: whether the thesis is stated yet does not bear on which section t is in.
    plan = vs.check_s5(structure, positions, vs.Report(), partial=True)
    section = None
    if plan:
        sid = plan[vs.section_index(plan, t)][0]
        sec = next(s for s in structure["sections"] if s.get("id") == sid)
        section = {"id": sid, "heading": sec["heading"], "role": sec["role"]}
    else:
        warnings.append("section plan invalid (S5); section not reported — run validate-structure.py")

    open_items, future = [], []
    for c in commitments.values():
        opened_at = c.opened.position
        if opened_at is None or opened_at > t:
            continue
        entry = {"id": c.cid, "kind": c.kind, "opened_at": opened_at, "opened_by": c.opened.data["prop_id"]}
        if c.kind == "future_work":
            future.append(entry)
        elif not any(d.position is not None and d.position <= t for d in c.discharged_by):
            open_items.append({**entry, "since": t - opened_at})
    open_items.sort(key=lambda e: (URGENCY.index(e["kind"]), e["opened_at"]))
    future.sort(key=lambda e: e["opened_at"])

    thesis = structure.get("thesis") if isinstance(structure.get("thesis"), list) else []
    return {
        "position": t,
        "total": len(live),
        "prop_id": live[t - 1],
        "relation": records[t - 1].data.get("relation"),
        "section": section,
        "open_commitments": open_items,
        "future_work": [{k: e[k] for k in ("id", "opened_at", "opened_by")} for e in future],
        "thesis_seen": any(isinstance(x, str) and positions.get(x, t + 1) <= t for x in thesis),
        "warnings": warnings,
    }


def render_text(state: dict) -> str:
    out = [f"position: {state['position']}/{state['total']}  #{state['position']} {state['prop_id']}"]
    sec = state["section"]
    out.append(f"section: {sec['id']} \"{sec['heading']}\" ({sec['role']})" if sec else "section: (not reported)")
    out.append(f"relation: {state['relation']}")
    out.append("open commitments (most urgent first):" if state["open_commitments"] else "open commitments: none")
    for i, c in enumerate(state["open_commitments"], 1):
        out.append(f"  {i}. {c['id']}  {c['kind']}  opened at #{c['opened_at']} ({c['since']} since)")
    if state["future_work"]:
        out.append("future work (not kept in this article):")
        out.extend(f"  - {c['id']}  opened at #{c['opened_at']}" for c in state["future_work"])
    out.append(f"thesis: {'stated' if state['thesis_seen'] else 'not yet stated'}")
    out.extend(f"warning: {w}" for w in state["warnings"])
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Report what the article owes the reader at a position.")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    p.add_argument("--at", required=True, help="a proposition UUID, or `end`")
    p.add_argument("--structure", type=Path, help="structure.json (default: beside the ledger)")
    p.add_argument("--discourse", type=Path, help="discourse.jsonl (default: beside the ledger)")
    p.add_argument("--format", choices=("text", "json"), default="text")
    args = p.parse_args(argv)
    structure = args.structure or args.jsonl.parent / "structure.json"
    discourse = args.discourse or args.jsonl.parent / "discourse.jsonl"
    try:
        state = compute_state(args.jsonl, structure, discourse, args.at)
    except vs.InputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    except StructureError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_STRUCTURE
    print(json.dumps(state, ensure_ascii=False, indent=1) if args.format == "json" else render_text(state), end="")
    if args.format == "json":
        print()
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
