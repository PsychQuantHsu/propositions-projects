#!/usr/bin/env python3
"""structure-state.py — what the article owes the reader at a position (format 2.0).

Reads the ledger and its structure sidecars (see
`plugins/propositions/docs/STRUCTURE.md`) and reports, for position t (t
included): t's place in the ledger; the section and the paragraph containing t
(with the paragraph's root, or null before the root appears); t's relation
(`root` for a paragraph root); the right frontier at t; the pending records;
the commitments opened at or before t that are not yet discharged, each with
its scope; the future-work commitments opened so far; whether a thesis
proposition has appeared; and the ordering used.

The right frontier lists t and each ancestor of t, reached by following heads,
whose position is at most t, ending at the paragraph root; then the paragraph
and its ancestor paragraphs up to the section's root paragraph; then the
section and its ancestor sections. In a tree without crossing arcs, the next
proposition that hangs on an earlier one hangs on a sentence node of this list.
Pending records are the records at or before t whose head is `pending` or comes
after t: the next proposition is usually their head.

`--order scope` (default) orders open commitments by kind — announcement,
hypothesis, plan, question, aim, setup — then, within a kind, puts first the
commitments whose opening section shares the deepest section with t, then by
opening position, earliest first. `--order kind` drops the section step (the
0.6.0 ordering). On the reference manuscript scope hits 94 of 231 positions,
kind 89.

The sidecars must pass S1-S3 and the structural checks of S2 and S5 of
validate-structure.py; `head: pending` is accepted as with --partial.

Usage:
    python3 structure-state.py --jsonl main.jsonl --at <prop uuid | end>
        [--order kind|scope] [--structure structure.json]
        [--discourse discourse.jsonl] [--format text|json]

Exit code:
    0 — state reported
    1 — the sidecars fail S1, S2, S3 or the section and paragraph plan of S5
    2 — an input file is missing or invalid, structure_version is not "2.0",
        or --at is not a non-retired proposition
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.structure_tree import ORDERS, PENDING, ancestors, frontier, ordering_key, shared_depth, unit_index  # noqa: E402

GATING_RULES = ("S1", "S2", "S3")
NON_BLOCKING_S5_TAGS = ("thesis", "abstract")
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
    """The sidecars fail the checks the query depends on; exit 1."""


def load_checked(ledger: Path, structure_path: Path, discourse_path: Path):
    """Analyse the sidecars as a draft and stop when the query cannot rely on them."""
    analysis = vs.analyse(ledger, structure_path, discourse_path, partial=True)
    report = analysis.report
    failing = [r for r in GATING_RULES if report.status(r) == "FAIL"]
    if any(p.severity == "error" and p.tag not in NON_BLOCKING_S5_TAGS for p in report.problems["S5"]):
        failing.append("S5")
    if failing or not analysis.plan or not analysis.paragraphs:
        failing = failing or ["S5"]
        count = sum(1 for r in failing for p in report.problems[r] if p.severity == "error")
        raise StructureError(
            f"the sidecars fail {', '.join(failing)} ({count} error(s)); run validate-structure.py and fix them first"
        )
    return analysis


def _paragraph_frontier(analysis, p_index: int) -> list[int]:
    paragraphs = analysis.paragraphs
    heads = {i: p.head for i, p in enumerate(paragraphs)}
    section = paragraphs[p_index].section
    root = next((i for i, p in enumerate(paragraphs) if p.section == section and p.head is None), None)
    return frontier(p_index, heads, root)


def compute_state(ledger: Path, structure_path: Path, discourse_path: Path, at: str, order: str = "scope") -> dict:
    analysis = load_checked(ledger, structure_path, discourse_path)
    live, positions = analysis.ledger.live, analysis.positions
    if not live:
        raise vs.InputError("the ledger has no non-retired propositions")
    if at == "end":
        t = len(live)
    elif at in positions:
        t = positions[at]
    else:
        raise vs.InputError(f"--at {at} is not a non-retired ledger proposition")

    structure, plan, parents = analysis.structure, analysis.plan, analysis.parents
    paragraphs, heads = analysis.paragraphs, analysis.heads
    firsts = [p.first for p in paragraphs]
    s_index = vs.section_index(plan, t)
    sec = next(s for s in structure["sections"] if s.get("id") == plan[s_index][0])
    p_index = unit_index(firsts, t)
    end = firsts[p_index + 1] if p_index + 1 < len(firsts) else len(live) + 1
    in_paragraph = {pos: heads.get(pos) for pos in range(firsts[p_index], end)}
    root = next((pos for pos, head in in_paragraph.items() if head is None), None)

    nodes = [{"level": "sentence", "position": pos, "id": live[pos - 1]} for pos in frontier(t, in_paragraph, root)]
    nodes += [{"level": "paragraph", "id": paragraphs[i].pid} for i in _paragraph_frontier(analysis, p_index)]
    nodes += [{"level": "section", "id": plan[i][0]} for i in ancestors(s_index, parents or [None] * len(plan))]

    pending = [
        {"position": pos, "prop_id": live[pos - 1]}
        for pos, head in sorted(heads.items())
        if pos <= t and (head == PENDING or isinstance(head, int) and head > t)
    ]

    open_items, future = [], []
    for c in analysis.commitments.values():
        opened_at = c.opened.position
        if opened_at is None or opened_at > t:
            continue
        entry = {"id": c.cid, "kind": c.kind, "opened_at": opened_at, "opened_by": c.opened.data["prop_id"]}
        if c.kind == "future_work":
            future.append(entry)
        elif not any(d.position is not None and d.position <= t for d in c.discharged_by):
            opener_section = vs.section_index(plan, opened_at)
            open_items.append({
                **entry,
                "since": t - opened_at,
                "scope": {"paragraph": paragraphs[unit_index(firsts, opened_at)].pid, "section": plan[opener_section][0]},
                "_depth": shared_depth(opener_section, s_index, parents or [None] * len(plan)),
            })
    open_items.sort(key=lambda e: ordering_key(e["kind"], e["opened_at"], e["_depth"], order))
    for item in open_items:
        del item["_depth"]
    future.sort(key=lambda e: e["opened_at"])

    head = heads.get(t)
    thesis = structure.get("thesis") if isinstance(structure.get("thesis"), list) else []
    return {
        "position": t,
        "total": len(live),
        "prop_id": live[t - 1],
        "relation": "root" if head is None else analysis.records[t - 1].data.get("relation"),
        "section": {"id": plan[s_index][0], "heading": sec["heading"], "role": sec["role"]},
        "paragraph": {
            "id": paragraphs[p_index].pid,
            "root": {"position": root, "prop_id": live[root - 1]} if root is not None and root <= t else None,
        },
        "frontier": nodes,
        "pending": pending,
        "open_commitments": open_items,
        "future_work": [{k: e[k] for k in ("id", "opened_at", "opened_by")} for e in future],
        "thesis_seen": any(isinstance(x, str) and positions.get(x, t + 1) <= t for x in thesis),
        "order": order,
        "warnings": [],
    }


def render_text(state: dict) -> str:
    out = [f"position: {state['position']}/{state['total']}  #{state['position']} {state['prop_id']}"]
    sec, par = state["section"], state["paragraph"]
    out.append(f"section: {sec['id']} \"{sec['heading']}\" ({sec['role']})")
    root = f"root #{par['root']['position']}" if par["root"] else "root not written yet"
    out.append(f"paragraph: {par['id']} ({root})")
    out.append(f"relation: {state['relation']}")
    sentence = [f"#{n['position']}" for n in state["frontier"] if n["level"] == "sentence"]
    upper = [n["id"] for n in state["frontier"] if n["level"] != "sentence"]
    out.append(f"right frontier: {' > '.join(sentence)} | {' > '.join(upper)}")
    if state["pending"]:
        out.append("pending (the next proposition is usually their head): " + ", ".join(f"#{p['position']}" for p in state["pending"]))
    heading = f"open commitments ({state['order']} order):"
    out.append(heading if state["open_commitments"] else "open commitments: none")
    for i, c in enumerate(state["open_commitments"], 1):
        out.append(f"  {i}. {c['id']}  {c['kind']}  opened at #{c['opened_at']} ({c['since']} since)"
                   f"  scope {c['scope']['section']}/{c['scope']['paragraph']}")
    if state["future_work"]:
        out.append("future work (not kept in this article):")
        out.extend(f"  - {c['id']}  opened at #{c['opened_at']}" for c in state["future_work"])
    out.append(f"thesis: {'stated' if state['thesis_seen'] else 'not yet stated'}")
    out.extend(f"warning: {w}" for w in state["warnings"])
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Report what the article owes the reader at a position (format 2.0).")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    p.add_argument("--at", required=True, help="a proposition UUID, or `end`")
    p.add_argument("--order", choices=ORDERS, default="scope", help="ordering of open commitments (default: scope)")
    p.add_argument("--structure", type=Path, help="structure.json (default: beside the ledger)")
    p.add_argument("--discourse", type=Path, help="discourse.jsonl (default: beside the ledger)")
    p.add_argument("--format", choices=("text", "json"), default="text")
    args = p.parse_args(argv)
    structure = args.structure or args.jsonl.parent / "structure.json"
    discourse = args.discourse or args.jsonl.parent / "discourse.jsonl"
    try:
        state = compute_state(args.jsonl, structure, discourse, args.at, args.order)
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
