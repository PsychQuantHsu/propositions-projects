#!/usr/bin/env python3
"""derive-paragraphs.py — propose a paragraph plan from the TeX source.

Spectra change add-discourse-dependency-tree. The paragraph plan in
`structure.json` (format 2.0, see `plugins/propositions/docs/STRUCTURE.md`) is
explicit and the validator never reads TeX. This tool gives the annotator the
default plan to start from:

  - each maximal run of non-blank TeX lines is one paragraph;
  - each non-retired proposition belongs to the paragraph holding the first
    line of its `location`; a change of TeX paragraph between consecutive
    propositions starts a new paragraph;
  - paragraphs that hold no proposition are skipped;
  - with --structure, a section whose first_prop falls inside a paragraph
    splits it there, so that no paragraph crosses a section boundary.

The output is the `paragraphs` list, numbered p-1, p-2, ... in reading order,
printed as JSON on standard output. Merge or split it by hand afterwards.

Usage:
    python3 derive-paragraphs.py --jsonl main.jsonl --tex main.tex [--structure structure.json]

Exit code:
    0 — paragraphs printed
    2 — an input is missing or unreadable, a location cannot be parsed or lies
        outside every paragraph, or a location names a file other than the main
        file (multi-file manuscripts are not supported)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.latex_env_parser import parse_location_v16  # noqa: E402

EXIT_OK, EXIT_USAGE = 0, 2


class InputError(Exception):
    """Exit 2."""


def tex_paragraph_ids(lines: list[str]) -> list[int | None]:
    """For each TeX line (0-based), the index of its run of non-blank lines, or None for a blank line."""
    ids: list[int | None] = []
    current, previous_blank = -1, True
    for line in lines:
        blank = not line.strip()
        if not blank and previous_blank:
            current += 1
        ids.append(None if blank else current)
        previous_blank = blank
    return ids


def read_ledger(path: Path) -> list[dict]:
    if not path.is_file():
        raise InputError(f"ledger not found: {path}")
    props = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        try:
            props.append(json.loads(raw))
        except json.JSONDecodeError as exc:
            raise InputError(f"{path.name} line {lineno}: invalid JSON ({exc.msg})") from exc
    return [p for p in props if isinstance(p, dict) and "retired" not in p]


def section_starts(path: Path | None) -> set[str]:
    if path is None:
        return set()
    if not path.is_file():
        raise InputError(f"structure sidecar not found: {path}")
    try:
        structure = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise InputError(f"{path.name}: invalid JSON ({exc.msg})") from exc
    return {s.get("first_prop") for s in structure.get("sections", []) if isinstance(s, dict)}


def derive(ledger: Path, tex: Path, structure: Path | None) -> list[dict]:
    if not tex.is_file():
        raise InputError(f"TeX file not found: {tex}")
    line_ids = tex_paragraph_ids(tex.read_text(encoding="utf-8").splitlines())
    starts = section_starts(structure)
    firsts: list[str] = []
    previous = None
    for prop in read_ledger(ledger):
        loc = prop.get("location", "")
        parsed = parse_location_v16(loc) if isinstance(loc, str) else None
        if parsed is None:
            raise InputError(f"cannot parse location {loc!r} of {prop.get('id')}")
        relpath, start, _ = parsed
        if relpath is not None:
            raise InputError(f"location {loc} names another file; multi-file manuscripts are not supported, list paragraphs by hand")
        if start > len(line_ids) or line_ids[start - 1] is None:
            raise InputError(f"location {loc} of {prop.get('id')} is not inside a TeX paragraph")
        here = line_ids[start - 1]
        if here != previous or prop.get("id") in starts:
            firsts.append(prop["id"])
        previous = here
    return [{"id": f"p-{i}", "first_prop": first} for i, first in enumerate(firsts, 1)]


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Propose a paragraph plan (structure.json `paragraphs`) from the TeX source.")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    p.add_argument("--tex", type=Path, required=True, help="the manuscript's main .tex file")
    p.add_argument("--structure", type=Path, help="structure.json whose sections the paragraphs must not cross")
    args = p.parse_args(argv)
    try:
        paragraphs = derive(args.jsonl, args.tex, args.structure)
    except InputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    print(json.dumps(paragraphs, ensure_ascii=False, indent=1))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
