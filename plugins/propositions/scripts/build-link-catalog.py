#!/usr/bin/env python3
"""build-link-catalog.py — every kind of link observed between moves, as one CSV list.

Spectra change add-paragraph-moves. From annotated sidecars it counts the links
of each article between moves (and between paragraph types for `paragraph`) and
writes one row per kind, paragraph type, pair of values, relation, scope and
label:

    kind,paragraph_type,from,to,relation,scope,label,count

Kinds, closed: `next` (START -> first move, move -> next move, last move -> END,
with the next sentence's relation, ROOT for the paragraph root), `head`, `also`,
`cites` (no relation), `discharge` (relation = the commitment's kind) and
`paragraph` (types of a paragraph and its head paragraph). `next` points forward;
the others point from the dependent end to what it depends on. `paragraph_type`
is the type of the paragraph holding the `from` sentence (empty when it has no
type, and for `paragraph`). `scope` is paragraph, section or article: the
smallest unit holding both ends.

The list is a directed graph that may have cycles; it records paths that were
observed and is not a rule. It holds no ledger text, proposition ids, paragraph
ids or paths, because it ships in a public plugin and the sidecars may not.

Usage:
    python3 build-link-catalog.py --sidecars empirical=DIR [--sidecars default=DIR ...]
        --out links.csv [--vocabulary vocabulary.yaml] [--check]

DIR is a ledger directory holding main.jsonl, structure.json and discourse.jsonl.
Directories under one label add up. A link whose end has no move (or no type, for
`paragraph`) is left out; the number left out is printed per label.

Exit code:
    0 — written, or --check found the file current
    1 — --check found the file stale or missing; nothing was written
    2 — an input is missing or invalid, a value is not in the vocabulary, a head
        is `pending`, or the sidecars fail S1, S2, S3 or the plan of S5
"""
from __future__ import annotations

import argparse
import importlib.util
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.link_catalog import LABEL, START, END, Link, article_links, render  # noqa: E402
from _lib.move_vocabulary import Vocabulary, load_vocabulary  # noqa: E402
from _lib.structure_tree import PENDING, unit_index  # noqa: E402

EXIT_OK, EXIT_STALE, EXIT_USAGE = 0, 1, 2


def _load_state():
    spec = importlib.util.spec_from_file_location("structure_state", Path(__file__).parent / "structure-state.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


state = _load_state()
vs = state.vs


def parse_source(raw: str) -> tuple[str, Path]:
    label, sep, directory = raw.partition("=")
    if not sep or not directory or not LABEL.fullmatch(label):
        raise vs.InputError(f"--sidecars {raw!r} is not <label>=<directory> with a lowercase label")
    return label, Path(directory)


def _checked(analysis, types: list, vocabulary: Vocabulary, directory: Path) -> None:
    if any(head == PENDING for head in analysis.heads.values()):
        raise vs.InputError(f"{directory}: a head is `pending`; build the catalog from finished annotations")
    for rec in analysis.records:
        move = rec.data.get("move")
        if move is not None and move not in vocabulary.moves:
            raise vs.InputError(f"{directory}: move {move!r} is not in the vocabulary")
    for kind in types:
        if kind is not None and kind not in vocabulary.paragraph_types:
            raise vs.InputError(f"{directory}: paragraph type {kind!r} is not in the vocabulary")


def _row(link: Link, moves: dict, types: list, firsts: list[int]) -> tuple | None:
    """(kind, paragraph_type, from, to, relation, scope) for a link, or None when an end is unlabelled."""
    if link.kind == "paragraph":
        ends = (types[link.source], types[link.target])
        paragraph_type = ""
    else:
        ends = tuple(end if end in (START, END) else moves.get(end) for end in (link.source, link.target))
        anchor = link.source if isinstance(link.source, int) else link.target
        paragraph_type = types[unit_index(firsts, anchor)] or ""
    if None in ends:
        return None
    return (link.kind, paragraph_type, *ends, link.relation, link.scope)


def collect(label: str, directory: Path, vocabulary: Vocabulary, counts: Counter, left_out: Counter) -> None:
    analysis = state.load_checked(directory / "main.jsonl", directory / "structure.json", directory / "discourse.jsonl")
    by_id = {p["id"]: p for p in analysis.structure["paragraphs"]}
    types = [by_id[p.pid].get("type") for p in analysis.paragraphs]
    _checked(analysis, types, vocabulary, directory)
    moves = {rec.position: rec.data.get("move") for rec in analysis.records}
    firsts = [p.first for p in analysis.paragraphs]
    left_out[label] += 0
    for link in article_links(analysis):
        row = _row(link, moves, types, firsts)
        if row is None:
            left_out[label] += 1
        else:
            counts[(*row, label)] += 1


def build(sources: list[tuple[str, Path]], vocabulary_path: Path | None) -> tuple[str, Counter]:
    vocabulary = load_vocabulary(vocabulary_path)
    counts: Counter = Counter()
    left_out: Counter = Counter()
    for label, directory in sources:
        collect(label, directory, vocabulary, counts, left_out)
    return render(counts), left_out


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Build the CSV list of links observed between moves.")
    p.add_argument("--sidecars", action="append", required=True, metavar="LABEL=DIR", help="a label and a ledger directory")
    p.add_argument("--out", type=Path, required=True, help="the catalog file (CSV)")
    p.add_argument("--vocabulary", type=Path, help="vocabulary.yaml (default: the one shipped with the plugin)")
    p.add_argument("--check", action="store_true", help="write nothing; exit 1 when the file differs from what would be written")
    args = p.parse_args(argv)
    try:
        text, left_out = build(sorted(map(parse_source, args.sidecars), key=lambda s: s[0]), args.vocabulary)
    except (vs.InputError, state.StructureError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    print("links left out (an end has no move or type): " + ", ".join(f"{k} {v}" for k, v in sorted(left_out.items())))
    if args.check:
        current = args.out.read_text(encoding="utf-8") if args.out.is_file() else None
        if current != text:
            print(f"stale: {args.out} differs from what the sidecars produce")
            return EXIT_STALE
        print(f"current: {args.out}")
        return EXIT_OK
    args.out.write_text(text, encoding="utf-8")
    print(f"written: {args.out}")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
