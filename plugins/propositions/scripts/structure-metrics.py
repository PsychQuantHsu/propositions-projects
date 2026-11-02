#!/usr/bin/env python3
"""structure-metrics.py — does the article's dependency tree fit, and is it useful?

Spectra change add-discourse-dependency-tree. The validator answers "is the
format right"; this tool answers "does the model fit this article". It reads the
same inputs as structure-state.py and reports:

  - arcs: sentence arcs (record -> head) and paragraph arcs (paragraph -> head
    paragraph), how many take part in at least one crossing, and that proportion;
  - frontier: the length of the sentence part of the right frontier at every
    position, as median, mean and maximum;
  - heads: records whose head comes before them, after them, `pending`, roots;
  - relations: the count of each of the ten relations on records with a head,
    and the number of `also` entries;
  - s8_warnings: the number of S8 warnings;
  - ordering: for `kind` and `scope`, the number of evaluated positions and hits.
    Position t is evaluated when a commitment open at t is discharged after t;
    it is a hit when the first commitment in the ordering is among those first
    discharged at the earliest such position.

Usage:
    python3 structure-metrics.py --jsonl main.jsonl [--structure structure.json]
        [--discourse discourse.jsonl] [--format text|json]

Exit code:
    0 — metrics reported
    1 — the sidecars fail S1, S2, S3 or the section and paragraph plan of S5
    2 — an input file is missing or invalid, or structure_version is not "2.0"
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.structure_tree import (  # noqa: E402
    ORDERS, PENDING, crossing_members, crossing_pairs, frontier, ordering_key, shared_depth, unit_index,
)

EXIT_OK, EXIT_STRUCTURE, EXIT_USAGE = 0, 1, 2


def _load_state():
    spec = importlib.util.spec_from_file_location("structure_state", Path(__file__).parent / "structure-state.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


state = _load_state()
vs = state.vs


def _arc_stats(groups: list[list[tuple[int, int, object]]]) -> dict:
    total = sum(len(arcs) for arcs in groups)
    crossing = sum(len(crossing_members(crossing_pairs(arcs))) for arcs in groups)
    return {"total": total, "crossing": crossing, "proportion": round(crossing / total, 4) if total else 0.0}


def _frontier_lengths(analysis) -> list[int]:
    firsts = [p.first for p in analysis.paragraphs]
    n = len(analysis.ledger.live)
    lengths = []
    for t in range(1, n + 1):
        i = unit_index(firsts, t)
        end = firsts[i + 1] if i + 1 < len(firsts) else n + 1
        in_paragraph = {pos: analysis.heads.get(pos) for pos in range(firsts[i], end)}
        root = next((pos for pos, head in in_paragraph.items() if head is None), None)
        lengths.append(len(frontier(t, in_paragraph, root)))
    return lengths


def _ordering(analysis) -> dict:
    plan, parents = analysis.plan, analysis.parents or [None] * len(analysis.plan)
    items = []
    for c in analysis.commitments.values():
        if c.kind == "future_work" or c.opened.position is None:
            continue
        kept = [d.position for d in c.discharged_by if d.position is not None]
        items.append((c.cid, c.kind, c.opened.position, min(kept) if kept else None,
                      vs.section_index(plan, c.opened.position)))
    out = {order: {"evaluated": 0, "hits": 0} for order in ORDERS}
    for t in range(1, len(analysis.ledger.live) + 1):
        open_now = [it for it in items if it[2] <= t and (it[3] is None or it[3] > t)]
        later = [it[3] for it in open_now if it[3] is not None]
        if not later:
            continue
        first_kept = min(later)
        truth = {it[0] for it in open_now if it[3] == first_kept}
        here = vs.section_index(plan, t)
        for order in ORDERS:
            top = min(open_now, key=lambda it: ordering_key(it[1], it[2], shared_depth(it[4], here, parents), order))
            out[order]["evaluated"] += 1
            out[order]["hits"] += top[0] in truth
    return out


def compute(ledger: Path, structure_path: Path, discourse_path: Path) -> dict:
    analysis = state.load_checked(ledger, structure_path, discourse_path)
    firsts = [p.first for p in analysis.paragraphs]
    sentence_groups: dict[int, list] = {}
    before = after = pending = roots = 0
    for pos, head in analysis.heads.items():
        if head is None:
            roots += 1
        elif head == PENDING:
            pending += 1
        else:
            before += head < pos
            after += head > pos
            sentence_groups.setdefault(unit_index(firsts, pos), []).append((pos, head, pos))
    paragraph_groups: dict[object, list] = {}
    for i, par in enumerate(analysis.paragraphs):
        if par.head is not None:
            paragraph_groups.setdefault(par.section, []).append((i, par.head, i))
    relations = {r: 0 for r in vs.RELATIONS}
    also = 0
    for rec in analysis.records:
        rel = rec.data.get("relation")
        if "head" in rec.data and rel in relations:
            relations[rel] += 1
        also += len(rec.data.get("also") or [])
    lengths = _frontier_lengths(analysis)
    return {
        "propositions": len(analysis.ledger.live),
        "paragraphs": len(analysis.paragraphs),
        "sections": len(analysis.plan),
        "arcs": {"sentence": _arc_stats(list(sentence_groups.values())),
                 "paragraph": _arc_stats(list(paragraph_groups.values()))},
        "frontier": {"median": statistics.median(lengths), "mean": round(statistics.mean(lengths), 4), "max": max(lengths)},
        "heads": {"before": before, "after": after, "pending": pending, "roots": roots},
        "relations": relations,
        "also": also,
        "s8_warnings": sum(1 for p in analysis.report.problems["S8"] if p.severity == "warning"),
        "ordering": _ordering(analysis),
    }


def render_text(m: dict) -> str:
    s, p, f, h = m["arcs"]["sentence"], m["arcs"]["paragraph"], m["frontier"], m["heads"]
    out = [
        f"propositions {m['propositions']}, paragraphs {m['paragraphs']}, sections {m['sections']}",
        f"sentence arcs: {s['total']}, crossing {s['crossing']} ({s['proportion']:.1%})",
        f"paragraph arcs: {p['total']}, crossing {p['crossing']} ({p['proportion']:.1%})",
        f"right frontier (sentence part): median {f['median']}, mean {f['mean']}, max {f['max']}",
        f"heads: before {h['before']}, after {h['after']}, pending {h['pending']}, roots {h['roots']}",
        "relations: " + ", ".join(f"{k} {v}" for k, v in m["relations"].items()) + f"; also {m['also']}",
        f"S8 warnings: {m['s8_warnings']}",
    ]
    for order, r in m["ordering"].items():
        out.append(f"ordering {order}: {r['hits']}/{r['evaluated']} hits")
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Report whether the article's dependency tree fits (format 2.0).")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    p.add_argument("--structure", type=Path, help="structure.json (default: beside the ledger)")
    p.add_argument("--discourse", type=Path, help="discourse.jsonl (default: beside the ledger)")
    p.add_argument("--format", choices=("text", "json"), default="text")
    args = p.parse_args(argv)
    structure = args.structure or args.jsonl.parent / "structure.json"
    discourse = args.discourse or args.jsonl.parent / "discourse.jsonl"
    try:
        m = compute(args.jsonl, structure, discourse)
    except vs.InputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    except state.StructureError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_STRUCTURE
    print(json.dumps(m, ensure_ascii=False, indent=1) if args.format == "json" else render_text(m), end="")
    if args.format == "json":
        print()
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
