#!/usr/bin/env python3
"""Swap temporary proposition ids for real UUID v7 ids.

LLM extraction writes propositions with temporary identifiers
(``tmp:<name>``, matching ``tmp:[A-Za-z0-9_-]+``) so the model never has to
invent UUIDs and ``cites`` cross-references stay consistent. This script
generates one UUID v7 (RFC 9562) per temporary id and substitutes it in every
``id`` and ``cites`` entry. Already-permanent values are left unchanged, as
are all other fields, line order, blank lines and ``//`` comment lines.

Generated ids strictly increase in the order their temporary ids first appear
as an ``id`` (RFC 9562 section 6.2 Method 1: 12-bit counter in ``rand_a``).

Usage:
    assign-prop-ids.py <input.jsonl> [--out <path>]

Without --out the result goes to stdout. The input file is never modified.

Exit codes:
    0  success
    1  data error (unresolved/duplicate/malformed tmp id, bad JSON, bad cites);
       nothing is written
    2  usage error (input missing, --out exists or is the input file)
"""
from __future__ import annotations

import argparse
import json
import re
import secrets
import sys
import time
import uuid
from pathlib import Path

TMP_RE = re.compile(r"tmp:[A-Za-z0-9_-]+")
COUNTER_MAX = 0xFFF


class DataError(Exception):
    """Input content problem (exit 1)."""


class UuidV7Generator:
    """Strictly increasing UUID v7 source (RFC 9562 section 6.2, Method 1)."""

    def __init__(self) -> None:
        self._ts = -1
        self._counter = 0

    @staticmethod
    def _fresh_counter() -> int:
        return secrets.randbelow(0x800)  # top bit clear leaves headroom

    def next(self) -> str:
        now = time.time_ns() // 1_000_000
        if now > self._ts:
            self._ts = now
            self._counter = self._fresh_counter()
        else:  # same millisecond, or clock went backwards: keep last ts
            self._counter += 1
            if self._counter > COUNTER_MAX:
                self._ts += 1
                self._counter = self._fresh_counter()
        rand_b = secrets.randbits(62)
        value = (
            (self._ts & ((1 << 48) - 1)) << 80
            | 0x7 << 76
            | self._counter << 64
            | 0b10 << 62
            | rand_b
        )
        return str(uuid.UUID(int=value))


def check_tmp_syntax(value: object) -> bool:
    """True if value is a well-formed tmp id; raise on malformed tmp: values."""
    if not isinstance(value, str) or not value.startswith("tmp:"):
        return False
    if not TMP_RE.fullmatch(value):
        raise DataError(f"malformed temporary identifier: {value!r}")
    return True


def parse_lines(text: str) -> list[tuple[str, dict | None]]:
    """Return (raw_line, object-or-None) per line; None for skipped lines."""
    parsed: list[tuple[str, dict | None]] = []
    for lineno, raw in enumerate(text.split("\n"), start=1):
        stripped = raw.strip()
        if not stripped or stripped.startswith("//"):
            parsed.append((raw, None))
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise DataError(f"line {lineno}: invalid JSON ({exc.msg})") from exc
        if not isinstance(obj, dict):
            raise DataError(f"line {lineno}: not a JSON object")
        cites = obj.get("cites")
        if "cites" in obj and not isinstance(cites, list):
            raise DataError(f"line {lineno}: 'cites' is not a list")
        parsed.append((raw, obj))
    return parsed


def collect_tmp_ids(objs: list[dict]) -> list[str]:
    """Temporary ids in first-appearance order; validates cites and dups."""
    ordered: list[str] = []
    for obj in objs:
        if check_tmp_syntax(obj.get("id")):
            if obj["id"] in ordered:
                raise DataError(f"duplicate temporary id: {obj['id']}")
            ordered.append(obj["id"])
    known = set(ordered)
    for obj in objs:
        for cite in obj.get("cites", []):
            if check_tmp_syntax(cite) and cite not in known:
                raise DataError(f"unresolved temporary cite: {cite}")
    return ordered


def rewrite_object(obj: dict, mapping: dict[str, str]) -> dict:
    """New object with tmp ids/cites substituted; key order preserved."""
    out = dict(obj)
    if isinstance(out.get("id"), str):
        out["id"] = mapping.get(out["id"], out["id"])
    if "cites" in out:
        out["cites"] = [mapping.get(c, c) if isinstance(c, str) else c
                        for c in out["cites"]]
    return out


def assign_ids(text: str) -> str:
    """Return the input text with temporary ids replaced."""
    parsed = parse_lines(text)
    objs = [obj for _, obj in parsed if obj is not None]
    gen = UuidV7Generator()
    mapping = {tmp: gen.next() for tmp in collect_tmp_ids(objs)}
    lines: list[str] = []
    for raw, obj in parsed:
        if obj is None:
            lines.append(raw)
            continue
        new = rewrite_object(obj, mapping)
        lines.append(raw if new == obj else json.dumps(new, ensure_ascii=False))
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Replace temporary ids (tmp:<name>) in a propositions "
        "JSONL with UUID v7 ids, rewriting cites consistently."
    )
    p.add_argument("input", type=Path, help="input JSONL (never modified)")
    p.add_argument("--out", type=Path, help="output path (must not exist); "
                   "default: stdout")
    return p


def check_paths(src: Path, out: Path | None) -> str | None:
    """Return an error message for usage problems, else None."""
    if not src.is_file():
        return f"input file does not exist: {src}"
    if out is not None:
        if out.resolve() == src.resolve():
            return f"--out must not be the input file: {out}"
        if out.exists():
            return f"--out already exists: {out}"
    return None


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    problem = check_paths(args.input, args.out)
    if problem:
        print(f"error: {problem}", file=sys.stderr)
        return 2
    try:
        result = assign_ids(args.input.read_text(encoding="utf-8"))
    except DataError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    if args.out is None:
        sys.stdout.write(result)
        return 0
    try:
        with args.out.open("x", encoding="utf-8") as fp:
            fp.write(result)
    except FileExistsError:
        print(f"error: --out already exists: {args.out}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
