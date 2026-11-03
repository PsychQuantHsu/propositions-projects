#!/usr/bin/env python3
"""structure-batch.py — annotate a long manuscript's dependency tree in batches.

`split` cuts the staged sidecars into input-NN.json files at paragraph
boundaries, so that one annotator holds whole paragraphs and every sentence
head stays inside its batch. `merge` reads the matching output-NN.json files
and writes discourse.jsonl and structure.json into --out-dir, keeping
commitments and everything else the staged sidecars already hold. It writes
nothing unless every batch answers every proposition and paragraph it was
given. Run validate-structure.py on the result: merge checks the answers'
shape, not the tree.

An output file is:
    {"propositions": {"<position>": {"head": <position>|null, "relation": str|null,
                                     ["also": [{"to": <position>, "relation": str}]],
                                     ["note": "runner-up: ...; lost because ..."]}},
     "paragraphs": {"<id>": {"head": "<paragraph id>"|null, "relation": str|null}}}
Fields in [brackets] are optional. Give a `note` only on a close call, written
as "runner-up: <the other choice>; lost because <reason>", and leave it out
otherwise: most propositions have none (references/vocabulary.md of the
construct skill, "Recording the decision").

With --moves-only the tree is left alone and only moves are annotated. `split`
adds to each proposition its `head` (the head's position, null for a paragraph
root, or the string "pending") and its `relation`, so the annotator sees the
tree. `merge` then accepts answers of the form
    {"propositions": {"<position>": {"move": str}},
     "paragraphs": {"<id>": {"type": str}}}
and sets only `move` on records and `type` on paragraphs; every other field of
the staged sidecars is unchanged. Values are not checked against the
vocabulary: validate-structure.py (S9) does that.

Usage:
    python3 structure-batch.py split --jsonl main.jsonl --structure s.json --discourse d.jsonl --out-dir DIR [--max-props 60] [--moves-only]
    python3 structure-batch.py merge --jsonl main.jsonl --structure s.json --discourse d.jsonl --out-dir DIR [--moves-only]

Exit code:
    0 — done
    2 — an input is missing or invalid, or an answer is incomplete
"""
from __future__ import annotations

import argparse
import bisect
import json
import sys
from pathlib import Path

EXIT_OK, EXIT_USAGE = 0, 2


class InputError(Exception):
    """Exit 2."""


def read_json(path: Path) -> dict:
    if not path.is_file():
        raise InputError(f"not found: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise InputError(f"{path.name}: invalid JSON ({exc.msg})") from exc


def read_jsonl(path: Path) -> list[dict]:
    if not path.is_file():
        raise InputError(f"not found: {path}")
    rows = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw.strip() and not raw.lstrip().startswith("//"):
            try:
                rows.append(json.loads(raw))
            except json.JSONDecodeError as exc:
                raise InputError(f"{path.name}: invalid JSON ({exc.msg})") from exc
    return rows


def load(args: argparse.Namespace) -> tuple[list[dict], dict, list[dict]]:
    live = [p for p in read_jsonl(args.jsonl) if "retired" not in p]
    structure, records = read_json(args.structure), read_jsonl(args.discourse)
    if [r.get("prop_id") for r in records] != [p["id"] for p in live]:
        raise InputError("the discourse records do not match the ledger's non-retired propositions (S1)")
    return live, structure, records


def _tree_position(record: dict, pos: dict[str, int]) -> dict:
    """The head and relation of one record, with the head as a position."""
    head = record.get("head")
    if head is not None and head != "pending":
        head = pos.get(head)
    return {"head": head, "relation": record.get("relation")}


def split(args: argparse.Namespace) -> int:
    live, structure, records = load(args)
    if args.max_props < 1:
        raise InputError("--max-props must be at least 1")
    pos = {p["id"]: i for i, p in enumerate(live, 1)}
    try:
        firsts = [pos[p["first_prop"]] for p in structure["paragraphs"]]
        section_firsts = [pos[s["first_prop"]] for s in structure["sections"]]
    except KeyError as exc:
        raise InputError(f"structure.json names an unknown proposition or lacks a field: {exc}") from exc
    if firsts != sorted(firsts) or not firsts or firsts[0] != 1:
        raise InputError("paragraphs must start at the first proposition and follow reading order")
    bounds = firsts + [len(live) + 1]
    sections = [dict(id=s["id"], first=section_firsts[i], role=s.get("role"), heading=s.get("heading"), parent=s.get("parent"))
                for i, s in enumerate(structure["sections"])]
    batches: list[list[int]] = [[]]
    for i in range(len(firsts)):
        size = bounds[i + 1] - bounds[i]
        current = sum(bounds[j + 1] - bounds[j] for j in batches[-1])
        if batches[-1] and current + size > args.max_props:
            batches.append([])
        batches[-1].append(i)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    for n, members in enumerate(batches, 1):
        props = []
        for i in members:
            for position in range(bounds[i], bounds[i + 1]):
                prop = live[position - 1]
                entry = {
                    "position": position,
                    "paragraph": structure["paragraphs"][i]["id"],
                    "section": structure["sections"][bisect.bisect_right(section_firsts, position) - 1]["id"],
                    "claim_type": prop.get("claim_type"),
                    "containing_block": prop.get("containing_block"),
                    "text": prop.get("text"),
                    "cites": [pos[c] for c in prop.get("cites") or [] if c in pos],
                }
                if args.moves_only:
                    entry.update(_tree_position(records[position - 1], pos))
                props.append(entry)
        batch = {
            "range": [props[0]["position"], props[-1]["position"]],
            "sections": sections,
            "paragraphs": [{"id": structure["paragraphs"][i]["id"], "first": firsts[i]} for i in members],
            "propositions": props,
        }
        (args.out_dir / f"input-{n:02d}.json").write_text(json.dumps(batch, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(batches)} batch(es), {len(firsts)} paragraphs, {len(live)} propositions: {args.out_dir}")
    return EXIT_OK


def _to_id(value: object, live: list[dict], where: str) -> str:
    if not isinstance(value, int) or isinstance(value, bool) or not 1 <= value <= len(live):
        raise InputError(f"{where}: {value!r} is not a position in the ledger")
    return live[value - 1]["id"]


def _batch_answer(path: Path) -> tuple[dict, str, dict, dict]:
    """Read one batch and its answer; refuse an answer that is not complete."""
    batch, name = read_json(path), path.name.replace("input-", "output-")
    answer = read_json(path.with_name(name))
    props, pars = answer.get("propositions"), answer.get("paragraphs")
    if not isinstance(props, dict) or not isinstance(pars, dict):
        raise InputError(f"{name}: needs `propositions` and `paragraphs` objects")
    expected = {str(p["position"]) for p in batch["propositions"]}
    if set(props) != expected:
        raise InputError(f"{name}: answers differ from the batch: missing {sorted(expected - set(props))}, extra {sorted(set(props) - expected)}")
    if set(pars) != {p["id"] for p in batch["paragraphs"]}:
        raise InputError(f"{name}: paragraph answers differ from the batch")
    return batch, name, props, pars


def _apply_tree(name: str, props: dict, pars: dict, live: list[dict], records: list[dict], paragraphs: dict[str, dict]) -> None:
    for key, item in props.items():
        rec = records[int(key) - 1]
        for field in ("head", "relation", "also", "note"):
            rec.pop(field, None)
        if item.get("head") is not None:
            rec["head"] = _to_id(item["head"], live, f"{name} #{key} head")
            rec["relation"] = item.get("relation")
        if item.get("also"):
            rec["also"] = [{"to": _to_id(a.get("to"), live, f"{name} #{key} also"), "relation": a.get("relation")} for a in item["also"]]
        if item.get("note"):
            rec["note"] = item["note"]
    for pid, item in pars.items():
        par = paragraphs[pid]
        par.pop("head", None)
        par.pop("relation", None)
        if item.get("head") is not None:
            if item["head"] not in paragraphs:
                raise InputError(f"{name} {pid}: unknown head paragraph {item['head']!r}")
            par["head"], par["relation"] = item["head"], item.get("relation")


def _text(value: object, where: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise InputError(f"{where}: {value!r} is not a non-empty string")
    return value


def _apply_moves(name: str, props: dict, pars: dict, records: list[dict], paragraphs: dict[str, dict]) -> None:
    """Set only `move` on records and `type` on paragraphs."""
    moves = {key: _text(item.get("move") if isinstance(item, dict) else None, f"{name} #{key} move") for key, item in props.items()}
    types = {pid: _text(item.get("type") if isinstance(item, dict) else None, f"{name} {pid} type") for pid, item in pars.items()}
    for key, move in moves.items():
        records[int(key) - 1]["move"] = move
    for pid, kind in types.items():
        paragraphs[pid]["type"] = kind


def merge(args: argparse.Namespace) -> int:
    live, structure, records = load(args)
    records = [dict(r) for r in records]
    paragraphs = {p["id"]: dict(p) for p in structure["paragraphs"]}
    inputs = sorted(args.out_dir.glob("input-*.json"))
    if not inputs:
        raise InputError(f"no input-*.json in {args.out_dir}")
    for path in inputs:
        _, name, props, pars = _batch_answer(path)
        if args.moves_only:
            _apply_moves(name, props, pars, records, paragraphs)
        else:
            _apply_tree(name, props, pars, live, records, paragraphs)
    merged = {**structure, "paragraphs": [paragraphs[p["id"]] for p in structure["paragraphs"]]}
    (args.out_dir / "discourse.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in records), encoding="utf-8")
    (args.out_dir / "structure.json").write_text(json.dumps(merged, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"merged {len(inputs)} batch(es) into {args.out_dir}; run validate-structure.py on the result")
    return EXIT_OK


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Split and merge batches of dependency-tree annotation.")
    p.add_argument("command", choices=("split", "merge"))
    p.add_argument("--jsonl", type=Path, required=True)
    p.add_argument("--structure", type=Path, required=True)
    p.add_argument("--discourse", type=Path, required=True)
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--max-props", type=int, default=60)
    p.add_argument("--moves-only", action="store_true", help="annotate only move and type; leave the tree alone")
    args = p.parse_args(argv)
    try:
        return split(args) if args.command == "split" else merge(args)
    except InputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main())
