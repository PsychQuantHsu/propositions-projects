#!/usr/bin/env python3
"""structure-links.py — every link of one sentence, and the observed paths of one value.

Spectra change add-paragraph-moves. Two subcommands, neither writes a file.

`sentence` reads one article's ledger and sidecars and lists every link of the
sentence at --at, with the kinds and directions of the link catalog: `out` when
the sentence is the link's `from` end, `in` when it is the `to` end. So the
output of one sentence can be read against the catalog's rows.

`catalog` reads the CSV list written by build-link-catalog.py. Given one value
(--from or --to), it lists the observed links with counts per label and in total,
most frequent first. With --unseen (and --kind) it also lists every value the
vocabulary allows at the other end that no matching row has. Unseen paths are
computed here and never stored: a stored list would drift from the vocabulary.
Nothing marks a path as impossible.

Usage:
    python3 structure-links.py sentence --jsonl main.jsonl --at <position | proposition id>
        [--structure s.json] [--discourse d.jsonl] [--vocabulary v.yaml] [--no-text] [--format text|json]
    python3 structure-links.py catalog (--from VALUE | --to VALUE) [--kind KIND] [--type TYPE]
        [--label LABEL] [--unseen] [--catalog links.csv] [--vocabulary v.yaml] [--format text|json]

Exit code:
    0 — reported
    2 — an input is missing or invalid, the sentence does not exist, a value,
        kind or paragraph type is not in the vocabulary, or the sidecars fail
        S1, S2, S3 or the plan of S5
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.link_catalog import (  # noqa: E402
    DEFAULT_CATALOG, END, KINDS, LABEL, RELATION_GLOSSES, SCOPE_GLOSSES, START, article_links, read_catalog,
)
from _lib.move_vocabulary import Vocabulary, load_vocabulary  # noqa: E402
from _lib.structure_io import ledger_field  # noqa: E402
from _lib.structure_tree import unit_index  # noqa: E402

EXIT_OK, EXIT_USAGE = 0, 2


def _load_state():
    spec = importlib.util.spec_from_file_location("structure_state", Path(__file__).parent / "structure-state.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


state = _load_state()
vs = state.vs


# ---------- sentence ----------


def _position(analysis, at: str) -> int:
    if at in analysis.positions:
        return analysis.positions[at]
    if at.isdigit() and 1 <= int(at) <= len(analysis.ledger.live):
        return int(at)
    raise vs.InputError(f"--at {at} is neither a position nor a non-retired proposition id")


def _describe(analysis, position: int | str, vocabulary: Vocabulary | None, texts: dict | None) -> dict:
    if not isinstance(position, int):
        return {"position": position, "move": None, "move_zh": None, **({"text": ""} if texts is not None else {})}
    data = analysis.records[position - 1].data
    move = data.get("move")
    entry = vocabulary.moves.get(move) if vocabulary and isinstance(move, str) else None
    out = {"position": position, "move": move, "move_zh": entry.zh if entry else None}
    if texts is not None:
        out["text"] = str(texts.get(analysis.ledger.live[position - 1], ""))
    return out


def sentence_links(ledger: Path, structure: Path, discourse: Path, vocabulary_path: Path | None, at: str,
                   with_text: bool) -> dict:
    analysis = state.load_checked(ledger, structure, discourse)
    position = _position(analysis, at)
    raw = {p["id"]: p for p in analysis.structure["paragraphs"]}
    labelled = any("move" in r.data for r in analysis.records) or any("type" in p for p in raw.values())
    vocabulary = load_vocabulary(vocabulary_path) if labelled else None
    texts = ledger_field(ledger, "text") if with_text else None
    par = analysis.paragraphs[unit_index([p.first for p in analysis.paragraphs], position)]
    kind = raw[par.pid].get("type")
    found = []
    for link in article_links(analysis):
        if link.kind == "paragraph" or position not in (link.source, link.target):
            continue
        direction, other = ("out", link.target) if link.source == position else ("in", link.source)
        found.append({"kind": link.kind, "direction": direction, **_describe(analysis, other, vocabulary, texts),
                      "relation": link.relation, "scope": link.scope})
    found.sort(key=lambda l: (KINDS.index(l["kind"]), l["direction"] != "out", str(l["position"])))
    entry = vocabulary.paragraph_types.get(kind) if vocabulary and isinstance(kind, str) else None
    return {**_describe(analysis, position, vocabulary, texts), "prop_id": analysis.ledger.live[position - 1],
            "paragraph": par.pid, "paragraph_type": kind, "paragraph_type_zh": entry.zh if entry else None,
            "section": analysis.plan[par.section][0] if par.section is not None else None, "links": found}


KIND_WORDS = {
    "out": {"next": "下一句", "head": "本句掛在", "also": "本句另有關係", "cites": "本句引用", "discharge": "本句兌現"},
    "in": {"next": "上一句", "head": "掛在本句", "also": "另有關係指向本句", "cites": "引用本句", "discharge": "兌現本句開的承諾"},
}
END_WORDS = {START: "段落開頭", END: "段落結束"}


def _relation_words(link: dict) -> str:
    relation = link["relation"]
    if link["kind"] == "cites":
        return ""
    if link["kind"] == "discharge":
        return f"承諾種類 {relation}"
    gloss = RELATION_GLOSSES.get(relation)
    words = f"{gloss}（{relation}）" if gloss else relation
    if link["kind"] != "next":
        return words
    if link["position"] == END:
        return ""
    who = "本句" if link["direction"] == "in" else "它"
    return f"{who}是段根" if relation == "ROOT" else f"{who}以{words}相接"


def _label(zh: str | None, raw: object) -> str:
    return f"{zh}（{raw}）" if zh else (str(raw) if raw else "未標")


def render_sentence(result: dict) -> str:
    head = f"#{result['position']}  {_label(result['move_zh'], result['move'])}  {result['paragraph']} " \
           f"{_label(result['paragraph_type_zh'], result['paragraph_type'])}  {result['section']}"
    out = [head]
    if result.get("text"):
        out.append("    " + " ".join(result["text"].split()))
    titles = {"out": "連出（下一句，以及本句依賴的）：", "in": "連入（上一句，以及依賴本句的）："}
    for direction in ("out", "in"):
        rows = [l for l in result["links"] if l["direction"] == direction]
        out.append(titles[direction] if rows else titles[direction] + " 無")
        for l in rows:
            sentence = isinstance(l["position"], int)
            end = f"#{l['position']}" if sentence else END_WORDS[l["position"]]
            fields = [f"  {l['kind']:<9} {KIND_WORDS[direction][l['kind']]}", end, _label(l["move_zh"], l["move"]) if sentence else "",
                      _relation_words(l), SCOPE_GLOSSES[l["scope"]]]
            if l.get("text"):
                fields.append(" ".join(l["text"].split()))
            out.append("  ".join(f for f in fields if f))
    return "\n".join(out) + "\n"


# ---------- catalog ----------


def _allowed(kind: str | None, end: str, vocabulary: Vocabulary) -> set[str]:
    moves, types = set(vocabulary.moves), set(vocabulary.paragraph_types)
    if kind == "paragraph":
        return types
    if kind == "next":
        return moves | ({START} if end == "from" else {END})
    if kind is None:
        return moves | types | {START, END}
    return moves


def _check_query(args: argparse.Namespace, vocabulary: Vocabulary) -> tuple[str, str, str]:
    end, value = ("from", args.from_value) if args.from_value is not None else ("to", args.to_value)
    if value not in _allowed(args.kind, end, vocabulary):
        raise vs.InputError(f"--{end} {value!r} is not a value the vocabulary allows for kind {args.kind or 'any'}")
    if args.type is not None and args.type not in vocabulary.paragraph_types:
        raise vs.InputError(f"--type {args.type!r} is not a paragraph type in the vocabulary")
    if args.label is not None and not LABEL.fullmatch(args.label):
        raise vs.InputError(f"--label {args.label!r} is not lowercase letters, digits and hyphens")
    if args.unseen and args.kind is None:
        raise vs.InputError("--unseen needs --kind: the values allowed at the other end depend on the kind")
    return end, ("to" if end == "from" else "from"), value


def catalog_query(args: argparse.Namespace) -> dict:
    vocabulary = load_vocabulary(args.vocabulary)
    end, other, value = _check_query(args, vocabulary)
    groups: dict[tuple, dict[str, int]] = {}
    for row in read_catalog(args.catalog):
        if row[end] != value or (args.kind and row["kind"] != args.kind) or (args.type and row["paragraph_type"] != args.type) \
                or (args.label and row["label"] != args.label):
            continue
        counts = groups.setdefault((row["kind"], row[other], row["relation"], row["scope"]), {})
        counts[row["label"]] = counts.get(row["label"], 0) + row["count"]
    seen = [{"kind": k, other: o, "relation": r, "scope": s, "counts": dict(sorted(c.items())), "total": sum(c.values())}
            for (k, o, r, s), c in groups.items()]
    seen.sort(key=lambda x: (-x["total"], KINDS.index(x["kind"]), x[other], x["relation"], x["scope"]))
    result = {"query": {end: value, "kind": args.kind, "type": args.type, "label": args.label}, "seen": seen}
    if args.unseen:
        result["unseen"] = sorted(_allowed(args.kind, other, vocabulary) - {s[other] for s in seen})
    return result


def render_catalog(result: dict) -> str:
    q = result["query"]
    end, other = ("from", "to") if "from" in q else ("to", "from")
    labels = sorted({label for s in result["seen"] for label in s["counts"]})
    out = [f"{q['kind'] or 'all kinds'} {end} {q[end]}（類型：{q['type'] or '全部'}；標籤：{q['label'] or '全部'}）："
           f"{sum(s['total'] for s in result['seen'])} 次觀察"]
    out.append("  " + "  ".join(["total", *labels, "kind", other, "relation", "scope"]))
    for s in result["seen"]:
        out.append("  " + "  ".join([str(s["total"]), *(str(s["counts"].get(l, 0)) for l in labels), s["kind"], s[other],
                                     s["relation"] or "-", s["scope"]]))
    if "unseen" in result:
        out.append(f"沒看過（{len(result['unseen'])}）：" + (", ".join(result["unseen"]) or "無"))
    return "\n".join(out) + "\n"


# ---------- driver ----------


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Every link of one sentence, or the observed paths of one value.")
    sub = p.add_subparsers(dest="command", required=True)
    s = sub.add_parser("sentence", help="every link of one sentence of an article")
    s.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    s.add_argument("--at", required=True, help="a position or a proposition id")
    s.add_argument("--structure", type=Path, help="structure.json (default: beside the ledger)")
    s.add_argument("--discourse", type=Path, help="discourse.jsonl (default: beside the ledger)")
    s.add_argument("--no-text", action="store_true", help="leave out the propositions' text")
    c = sub.add_parser("catalog", help="observed and unseen paths of one value in the link catalog")
    end = c.add_mutually_exclusive_group(required=True)
    end.add_argument("--from", dest="from_value", help="the value at the link's from end")
    end.add_argument("--to", dest="to_value", help="the value at the link's to end")
    c.add_argument("--kind", choices=KINDS)
    c.add_argument("--type", help="only links in paragraphs of this type")
    c.add_argument("--label", help="only links from manuscripts with this label")
    c.add_argument("--unseen", action="store_true", help="also list the values never observed at the other end (needs --kind)")
    c.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG, help="links.csv (default: the one shipped with the plugin)")
    for parser in (s, c):
        parser.add_argument("--vocabulary", type=Path, help="vocabulary.yaml (default: the one shipped with the plugin)")
        parser.add_argument("--format", choices=("text", "json"), default="text")
    return p


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "sentence":
            structure = args.structure or args.jsonl.parent / "structure.json"
            discourse = args.discourse or args.jsonl.parent / "discourse.jsonl"
            result = sentence_links(args.jsonl, structure, discourse, args.vocabulary, args.at, not args.no_text)
            text = render_sentence(result)
        else:
            result = catalog_query(args)
            text = render_catalog(result)
    except (vs.InputError, state.StructureError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    print(json.dumps(result, ensure_ascii=False, indent=1) if args.format == "json" else text, end="" if args.format == "text" else "\n")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
