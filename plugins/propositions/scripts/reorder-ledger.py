#!/usr/bin/env python3
"""reorder-ledger.py — put a ledger's lines into TeX reading order.

The structure model reads the ledger's line order as reading order. A ledger
built in blocks (statements first, appendix proofs later) breaks that. This
tool sorts propositions by the first line of their `location`. Lines are moved,
never edited: each stays byte-identical. Propositions on the same TeX line keep
their relative order and are reported, because only a reader can tell whether
that order is right. A retired or location-less line stays behind the line it
followed. Single-file manuscripts only.

Dry run by default; --write rewrites the ledger.

Usage:
    python3 reorder-ledger.py --jsonl main.jsonl [--write]

Exit code:
    0 — already in order, or written
    1 — dry run: lines would move
    2 — the ledger is missing or invalid, or a location cannot be used
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.latex_env_parser import parse_location_v16  # noqa: E402

EXIT_OK, EXIT_WOULD_MOVE, EXIT_USAGE = 0, 1, 2


class InputError(Exception):
    """Exit 2."""


def start_line(prop: dict) -> int:
    location = prop.get("location")
    parsed = parse_location_v16(location) if isinstance(location, str) else None
    if parsed is None:
        raise InputError(f"cannot parse location {location!r} of {prop.get('id')}")
    relpath, start, _ = parsed
    if relpath is not None:
        raise InputError(f"location {location} names another file; multi-file manuscripts are not supported")
    return start


def plan(raw_lines: list[str]) -> tuple[list[str], list[int]]:
    """The reordered lines, and the TeX lines shared by more than one proposition."""
    blocks: list[tuple[int, list[str]]] = []  # (TeX line, the line plus the lines that follow it)
    head: list[str] = []
    for raw in raw_lines:
        stripped = raw.strip()
        prop = None
        if stripped and not stripped.startswith("//"):
            try:
                prop = json.loads(stripped)
            except json.JSONDecodeError as exc:
                raise InputError(f"invalid JSON: {exc.msg}: {stripped[:60]}") from exc
        if isinstance(prop, dict) and "retired" not in prop:
            blocks.append((start_line(prop), [raw]))
        elif blocks:
            blocks[-1][1].append(raw)
        else:
            head.append(raw)
    counts: dict[int, int] = {}
    for line, _ in blocks:
        counts[line] = counts.get(line, 0) + 1
    ordered = sorted(blocks, key=lambda b: b[0])  # stable: ties keep their order
    result = head + [raw for _, group in ordered for raw in group]
    return result, sorted(line for line, n in counts.items() if n > 1)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Put a ledger's lines into TeX reading order (dry run by default).")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    p.add_argument("--write", action="store_true", help="rewrite the ledger")
    args = p.parse_args(argv)
    if not args.jsonl.is_file():
        print(f"error: ledger not found: {args.jsonl}", file=sys.stderr)
        return EXIT_USAGE
    lines = args.jsonl.read_text(encoding="utf-8").splitlines(keepends=True)
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    try:
        result, ties = plan(lines)
    except InputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    moved = sum(a != b for a, b in zip(lines, result))
    if ties:
        print(f"{len(ties)} TeX line(s) hold several propositions on the same line, check their order: {ties[:20]}")
    if not moved:
        print("already in reading order")
        return EXIT_OK
    print(f"{moved} line(s) move")
    if not args.write:
        return EXIT_WOULD_MOVE
    temp = args.jsonl.with_suffix(".jsonl.reorder-tmp")
    temp.write_text("".join(result), encoding="utf-8")
    temp.replace(args.jsonl)
    print(f"written: {args.jsonl}")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
