#!/usr/bin/env python3
"""Report text in a line range that no proposition covers.

The validator's R1 proves every prop.text occurs in the manuscript (nothing was
fabricated). This check proves the converse for one line range: every piece of
text there is covered by some proposition, or belongs to a structure that is
deliberately not extracted. It is the gate the extraction skill
(propositions:extract) runs before merging new propositions.

Coverage is computed per character, not per sentence: a clause-level ledger
that drops one clause of a sentence still leaves that clause uncovered.

Usage:
    check-extraction-coverage.py --tex FILE --lines START-END --jsonl LEDGER
                                 [--main MAIN.tex] [--format text|json]

Candidates are non-retired propositions whose `location` names FILE (v1.6 rules: no prefix,
or the prefix `main.tex`, means the main file; other prefixes resolve against
the main file's directory) and whose line span intersects the range. `--main`
defaults to FILE, which is right for single-file manuscripts.

Excluded structure — exactly these five kinds, no others: comments from an
unescaped `%`; `\\label{...}`; sectioning commands with their titles;
`\\begin{...}` / `\\end{...}` markers; the full content of table/figure floats.
Excluded floats are listed in the output.

Exit codes: 0 nothing uncovered, 1 uncovered text found, 2 bad input.
"""
from __future__ import annotations

import argparse
import bisect
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _lib.latex_env_parser import parse_location_v16  # noqa: E402
from _lib.normalize import normalize_for_match, normalize_with_map  # noqa: E402

EXIT_OK, EXIT_UNCOVERED, EXIT_USAGE = 0, 1, 2
FLOAT_ENVS = ("table", "table*", "figure", "figure*")
_RANGE_RE = re.compile(r"(\d+)-(\d+)")
_LABEL_RE = re.compile(r"\\label\{")
_SECTIONING_RE = re.compile(r"\\(?:section|subsection|subsubsection|paragraph)\*?\{")
_ENV_MARKER_RE = re.compile(r"\\(?:begin|end)\{[^}]*\}(?:\[[^\]]*\])?")
_FLOAT_BEGIN_RE = re.compile(r"\\begin\{(table\*?|figure\*?)\}")


class UsageError(Exception):
    """Bad input; reported on stderr with exit 2."""


@dataclass(frozen=True)
class Source:
    text: str
    starts: tuple[int, ...]  # offset of each line start

    @classmethod
    def read(cls, path: Path) -> "Source":
        if not path.is_file():
            raise UsageError(f"file not found: {path}")
        text = path.read_text(encoding="utf-8")
        starts = [0] if text else []
        starts += [i + 1 for i, ch in enumerate(text) if ch == "\n" and i + 1 < len(text)]
        return cls(text, tuple(starts))

    def line_of(self, offset: int) -> int:
        return bisect.bisect_right(self.starts, offset)

    def span(self, start: int, end: int) -> tuple[int, int]:
        """Offsets [a, b) covering lines start..end inclusive."""
        b = self.starts[end] if end < len(self.starts) else len(self.text)
        return self.starts[start - 1], b


def parse_range(spec: str, n_lines: int) -> tuple[int, int]:
    m = _RANGE_RE.fullmatch(spec.strip())
    if not m:
        raise UsageError(f"invalid --lines {spec!r}: expected START-END, e.g. 12-30")
    start, end = int(m.group(1)), int(m.group(2))
    if start < 1 or end < start or end > n_lines:
        raise UsageError(f"invalid --lines {spec!r}: the file has {n_lines} lines")
    return start, end


def load_props(path: Path) -> list[dict]:
    if not path.is_file():
        raise UsageError(f"file not found: {path}")
    props = []
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not raw.strip() or raw.lstrip().startswith("//"):
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise UsageError(f"{path} line {n}: invalid JSON ({exc.msg})") from exc
        if not isinstance(obj, dict):
            raise UsageError(f"{path} line {n}: not a JSON object")
        props.append(obj)
    return props


# ---------- excluded structure ----------


def _brace_end(text: str, open_brace: int) -> int:
    """Offset just past the brace group opening at `open_brace` (or EOF)."""
    depth = 0
    for i in range(open_brace, len(text)):
        if text[i] == "{" and text[i - 1] != "\\":
            depth += 1
        elif text[i] == "}" and text[i - 1] != "\\":
            depth -= 1
            if depth == 0:
                return i + 1
    return len(text)


def _comment_spans(text: str) -> list[tuple[int, int]]:
    spans = []
    for m in re.finditer("%", text):
        i, slashes = m.start(), 0
        while i - slashes - 1 >= 0 and text[i - slashes - 1] == "\\":
            slashes += 1
        if slashes % 2 == 0:
            eol = text.find("\n", i)
            spans.append((i, len(text) if eol == -1 else eol))
    return spans


def float_spans(text: str) -> list[tuple[str, int, int]]:
    """(kind, start, end) for each terminated table/figure float."""
    floats = []
    for m in _FLOAT_BEGIN_RE.finditer(text):
        kind = m.group(1)
        end_tok = "\\end{" + kind + "}"
        j = text.find(end_tok, m.end())
        if j != -1:  # an unterminated float is not excluded; its text stays visible
            floats.append((kind, m.start(), j + len(end_tok)))
    return floats


def excluded_spans(text: str) -> list[tuple[int, int]]:
    spans = _comment_spans(text)
    for rx in (_LABEL_RE, _SECTIONING_RE):
        spans += [(m.start(), _brace_end(text, m.end() - 1)) for m in rx.finditer(text)]
    spans += [m.span() for m in _ENV_MARKER_RE.finditer(text)]
    spans += [(a, b) for _, a, b in float_spans(text)]
    return spans


def excluded_mask(spans: list[tuple[int, int]], length: int) -> list[bool]:
    mask = [False] * length
    for a, b in spans:
        for i in range(max(a, 0), min(b, length)):
            mask[i] = True
    return mask


# ---------- candidates and coverage ----------


def refers_to(loc: str, target: Path, main: Path) -> tuple[int, int] | None:
    """Line span of `loc` if it names `target`, else None."""
    parsed = parse_location_v16(loc)
    if parsed is None:
        return None
    relfile, a, b = parsed
    named = main if relfile is None else (main.parent / relfile).resolve()
    return (a, b) if named == target else None


def locate(norm: str, needle: str, abs_pos: list[int], src: Source, near: int) -> tuple[int | None, str | None]:
    """Start index of the occurrence nearest line `near`, or (None, reason)."""
    if not needle:
        return None, "text is empty after normalization"
    hits, i = [], norm.find(needle)
    while i != -1:
        hits.append(i)
        i = norm.find(needle, i + 1)
    if not hits:
        return None, "text not found in the range (paraphrased, or only partly inside the range)"
    dist = {h: abs(src.line_of(abs_pos[h]) - near) for h in hits}
    best = min(dist.values())
    nearest = [h for h in hits if dist[h] == best]
    if len(nearest) > 1:
        return None, f"{len(nearest)} occurrences are equally near L{near}; not guessing"
    return nearest[0], None


def uncovered_runs(norm: str, covered: list[bool], mask: list[bool], abs_pos: list[int], src: Source) -> list[dict]:
    runs, i = [], 0
    while i < len(norm):
        if covered[i] or mask[abs_pos[i]]:
            i += 1
            continue
        j = i
        while j < len(norm) and not covered[j] and not mask[abs_pos[j]]:
            j += 1
        piece = norm[i:j]
        if any(ch.isalnum() for ch in piece):
            runs.append({
                "start_line": src.line_of(abs_pos[i]),
                "end_line": src.line_of(abs_pos[j - 1]),
                "excerpt": piece.strip(),
            })
        i = j
    return runs


def check(tex: Path, main: Path, spec: str, props: list[dict]) -> dict:
    src = Source.read(tex)
    start, end = parse_range(spec, len(src.starts))
    r0, r1 = src.span(start, end)
    norm, rel_pos = normalize_with_map(src.text[r0:r1])
    abs_pos = [r0 + p for p in rel_pos]
    mask = excluded_mask(excluded_spans(src.text), len(src.text))
    covered = [False] * len(norm)
    target, warnings, candidates = tex.resolve(), [], 0
    for prop in props:
        if "retired" in prop:  # describes text no longer in the paper (SCHEMA.md §retired)
            continue
        span = refers_to(str(prop.get("location", "")), target, main.resolve())
        if span is None or span[0] > end or span[1] < start:
            continue
        candidates += 1
        needle = normalize_for_match(str(prop.get("text", "")))
        hit, reason = locate(norm, needle, abs_pos, src, span[0])
        if hit is None:
            warnings.append({"id": str(prop.get("id", "?")), "message": reason})
            continue
        for k in range(hit, hit + len(needle)):
            covered[k] = True
    floats = [
        {"kind": kind, "start_line": src.line_of(a), "end_line": src.line_of(b - 1)}
        for kind, a, b in float_spans(src.text)
        if src.line_of(a) <= end and src.line_of(b - 1) >= start
    ]
    return {
        "tex": str(tex), "lines": [start, end], "candidates": candidates,
        "uncovered": uncovered_runs(norm, covered, mask, abs_pos, src),
        "excluded": floats, "warnings": warnings,
    }


def render_text(rep: dict) -> str:
    a, b = rep["lines"]
    out = [f"coverage {rep['tex']} L{a}-L{b}: {rep['candidates']} candidate prop(s)"]
    for r in rep["uncovered"]:
        out.append(f"  UNCOVERED L{r['start_line']}-L{r['end_line']}: {r['excerpt']}")
    for f in rep["excluded"]:
        out.append(f"  excluded {f['kind']} L{f['start_line']}-L{f['end_line']}")
    for w in rep["warnings"]:
        out.append(f"  WARNING {w['id']}: {w['message']}")
    n = len(rep["uncovered"])
    out.append(f"{'OK' if n == 0 else 'FAIL'}: {n} uncovered run(s)")
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Report text in a line range that no proposition covers.")
    p.add_argument("--tex", type=Path, required=True, help="file holding the range")
    p.add_argument("--lines", required=True, help="inclusive range START-END")
    p.add_argument("--jsonl", type=Path, required=True, help="propositions ledger")
    p.add_argument("--main", type=Path, help="manuscript main file (default: --tex)")
    p.add_argument("--format", choices=("text", "json"), default="text")
    args = p.parse_args(argv)
    try:
        main_file = args.main or args.tex
        if not main_file.is_file():
            raise UsageError(f"file not found: {main_file}")
        rep = check(args.tex, main_file, args.lines, load_props(args.jsonl))
    except UsageError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    print(json.dumps(rep, ensure_ascii=False, indent=1) if args.format == "json" else render_text(rep), end="")
    if args.format == "json":
        print()
    return EXIT_UNCOVERED if rep["uncovered"] else EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
