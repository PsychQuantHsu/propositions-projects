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
    discharged at the earliest such position;
  - moves, only when records have a `move` (Spectra change add-paragraph-moves):
    how much is labelled; the count of each move and paragraph type; Cramér's V
    between move and `claim_type`, and between move and relation (paragraph roots
    have no relation and are left out); the leave-one-paragraph-out top-3 hit rate
    for the next proposition's relation and for its move, given the current move
    and given no condition, over the labelled positions (END when the paragraph
    ends, ROOT when the next proposition is the root). With --compare-moves, raw
    agreement and Cohen's kappa over what both labellings labelled. These are
    reports: no value changes the exit status.

Usage:
    python3 structure-metrics.py --jsonl main.jsonl [--structure structure.json]
        [--discourse discourse.jsonl] [--compare-moves LEDGER_DIR] [--format text|json]

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
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.move_metrics import agreement, cramers_v, leave_one_group_out  # noqa: E402
from _lib.structure_io import ledger_field  # noqa: E402
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


def _next_rows(analysis) -> tuple[list, list, list, list]:
    """Rows (paragraph, condition, target) for next relation and next move, each with and without the condition."""
    records, pars = analysis.records, analysis.paragraphs
    total = len(records)
    relation_rows, relation_flat, move_rows, move_flat = [], [], [], []
    for i, par in enumerate(pars):
        end = pars[i + 1].first if i + 1 < len(pars) else total + 1
        for pos in range(par.first, end):
            move = records[pos - 1].data.get("move")
            if not isinstance(move, str):
                continue
            nxt = records[pos].data if pos + 1 < end else None
            relation = "END" if nxt is None else nxt.get("relation", "ROOT") if "head" in nxt else "ROOT"
            relation_rows.append((i, move, relation))
            relation_flat.append((i, "", relation))
            target = "END" if nxt is None else nxt.get("move")
            if isinstance(target, str):
                move_rows.append((i, move, target))
                move_flat.append((i, "", target))
    return relation_rows, relation_flat, move_rows, move_flat


def _sidecar_labels(directory: Path) -> tuple[dict, dict]:
    """(prop id -> move, paragraph id -> type) of another labelling, without validating it."""
    records = vs.load_discourse(directory / "discourse.jsonl")
    structure = vs.load_structure(directory / "structure.json")
    moves = {d.get("prop_id"): d["move"] for _, d in records if isinstance(d.get("move"), str)}
    types = {p.get("id"): p["type"] for p in structure.get("paragraphs", []) if isinstance(p.get("type"), str)}
    return moves, types


def _move_report(analysis, ledger: Path, compare: Path | None) -> dict | None:
    labelled = [r for r in analysis.records if isinstance(r.data.get("move"), str)]
    if not labelled:
        return None
    raw_pars = analysis.structure["paragraphs"]
    typed = {p["id"]: p["type"] for p in raw_pars if isinstance(p.get("type"), str)}
    claims = ledger_field(ledger, "claim_type")
    relation_rows, relation_flat, move_rows, move_flat = _next_rows(analysis)
    claim_pairs = [(r.data["move"], claims[r.data["prop_id"]]) for r in labelled if r.data.get("prop_id") in claims]
    relation_pairs = [(r.data["move"], r.data["relation"]) for r in labelled if isinstance(r.data.get("relation"), str)]
    report = {
        "labelled_propositions": len(labelled),
        "proposition_share": round(len(labelled) / len(analysis.records), 4),
        "labelled_paragraphs": len(typed),
        "paragraph_share": round(len(typed) / len(raw_pars), 4),
        "counts": dict(sorted(Counter(r.data["move"] for r in labelled).items())),
        "type_counts": dict(sorted(Counter(typed.values()).items())),
        "association": {"claim_type": cramers_v(claim_pairs), "relation": cramers_v(relation_pairs)},
        "next_relation": {"evaluated": len(relation_rows), "current_move": leave_one_group_out(relation_rows),
                          "no_condition": leave_one_group_out(relation_flat)},
        "next_move": {"evaluated": len(move_rows), "current_move": leave_one_group_out(move_rows),
                      "no_condition": leave_one_group_out(move_flat)},
    }
    if compare is not None:
        other_moves, other_types = _sidecar_labels(compare)
        own_moves = {r.data["prop_id"]: r.data["move"] for r in labelled}
        report["agreement"] = {
            "moves": agreement([(own_moves[k], other_moves[k]) for k in own_moves if k in other_moves]),
            "types": agreement([(typed[k], other_types[k]) for k in typed if k in other_types]),
        }
    return report


def compute(ledger: Path, structure_path: Path, discourse_path: Path, compare: Path | None = None) -> dict:
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
    moves = _move_report(analysis, ledger, compare)
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
        **({"moves": moves} if moves else {}),
    }


def _pct(value: float | None) -> str:
    return "n/a" if value is None else f"{value:.0%}"


def _agreement_line(name: str, a: dict) -> str:
    if not a["n"]:
        return f"{name}: nothing labelled in both"
    kappa = "n/a" if a["kappa"] is None else f"{a['kappa']:.2f}"
    return f"{name}: n {a['n']}, raw agreement {a['raw']:.2f}, Cohen's kappa {kappa}"


def _render_moves(mv: dict) -> list[str]:
    a, nr, nm = mv["association"], mv["next_relation"], mv["next_move"]
    out = [
        f"moves labelled: {mv['labelled_propositions']} propositions ({mv['proposition_share']:.1%}), "
        f"{mv['labelled_paragraphs']} paragraphs ({mv['paragraph_share']:.1%})",
        "move counts: " + ", ".join(f"{k} {v}" for k, v in mv["counts"].items()),
        "type counts: " + (", ".join(f"{k} {v}" for k, v in mv["type_counts"].items()) or "none"),
        f"Cramér's V: move and claim_type {a['claim_type']}, move and relation {a['relation']}",
        f"next relation, top-3 leaving one paragraph out (n {nr['evaluated']}): "
        f"given the move {_pct(nr['current_move'])}, no condition {_pct(nr['no_condition'])}",
        f"next move, top-3 leaving one paragraph out (n {nm['evaluated']}): "
        f"given the move {_pct(nm['current_move'])}, no condition {_pct(nm['no_condition'])}",
    ]
    if "agreement" in mv:
        out += [_agreement_line("agreement on moves", mv["agreement"]["moves"]),
                _agreement_line("agreement on types", mv["agreement"]["types"])]
    return out


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
    if "moves" in m:
        out += _render_moves(m["moves"])
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Report whether the article's dependency tree fits (format 2.0).")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    p.add_argument("--structure", type=Path, help="structure.json (default: beside the ledger)")
    p.add_argument("--discourse", type=Path, help="discourse.jsonl (default: beside the ledger)")
    p.add_argument("--compare-moves", type=Path, metavar="LEDGER_DIR",
                   help="another labelling's directory (discourse.jsonl, structure.json): report agreement on moves and types")
    p.add_argument("--format", choices=("text", "json"), default="text")
    args = p.parse_args(argv)
    structure = args.structure or args.jsonl.parent / "structure.json"
    discourse = args.discourse or args.jsonl.parent / "discourse.jsonl"
    try:
        m = compute(args.jsonl, structure, discourse, args.compare_moves)
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
