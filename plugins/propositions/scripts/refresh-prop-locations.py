#!/usr/bin/env python3
"""Refresh propositions location field from current main.tex (#106 Option 1).

For each prop in a propositions JSONL file, find the actual line range where
prop.text appears in main.tex and update the `location` field accordingly.

Uses validator's `normalize_for_match` throughout: an R1 existence check
against the whole-text normalized form, then a windowed locator that
normalizes each candidate MAX_SPAN-line window as one whole string and tests
substring containment. Normalizing whole windows (rather than per line) makes
context-dependent rules — macro / comment / math-delimiter stripping whose
span crosses a source-wrap boundary — resolve correctly, which the earlier
per-line search space could not do (#137).

Usage:
    python3 scripts/refresh-prop-locations.py --jsonl PATH [--tex PATH] [--dry-run]

Exits:
    0 — all props refreshed (or already accurate)
    1 — at least one prop's text not found (R1) or not anchorable (windowed)
    2 — usage / IO error

Refs PsychQuantHsu/psychophysical_representations#106
Refs PsychQuantHsu/psychophysical_representations#137
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_TEX = SCRIPT_DIR.parent / "manuscript" / "main.tex"

sys.path.insert(0, str(SCRIPT_DIR))
from _lib.latex_env_parser import (  # noqa: E402
    InputTreeError,
    parse_location_v16,
    resolve_input_tree,
)

# Windowed-locator span: each candidate window is MAX_SPAN source lines. The
# longest range-form prop in main.jsonl spans 12 source lines; 40 gives >3x
# headroom. A prop whose true source span exceeds MAX_SPAN cannot be anchored
# and is reported as a loud `anchor_failed` (#137).
MAX_SPAN = 40


def load_validator():
    """Import validate-propositions.py via importlib (filename has hyphen)."""
    spec = importlib.util.spec_from_file_location(
        "validator", SCRIPT_DIR / "validate-propositions.py"
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load validate-propositions.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def precompute_window_norms(tex_lines: list[str], normalize_fn) -> list[str]:
    """Normalized form of the MAX_SPAN-line window starting at each line.

    `window_norms[s]` (0-indexed) is `normalize_fn` applied to the joined block
    `tex_lines[s : s + MAX_SPAN]`. Computed once per run; `find_prop_span` then
    locates props by cheap substring checks against this cache.

    Each window is normalized as one whole multi-line string, so
    context-dependent rules in `normalize_for_match` (macro / comment /
    math-delimiter stripping whose span crosses a source-wrap boundary) resolve
    correctly — which the earlier per-line search space could not do (#137).
    """
    return [
        normalize_fn("\n".join(tex_lines[s:s + MAX_SPAN]))
        for s in range(len(tex_lines))
    ]


def _grow_end(
    normalized_prop: str, tex_lines: list[str], normalize_fn, start: int
) -> int | None:
    """Smallest end line `e` (>= start) such that the normalized join of
    `tex_lines[start..e]` contains `normalized_prop`.

    None when no `e` within MAX_SPAN lines works (defensive — a caller only
    grows from a `start` whose MAX_SPAN window already contained the prop).
    """
    last = min(start + MAX_SPAN, len(tex_lines))
    for end in range(start, last + 1):
        if normalized_prop in normalize_fn("\n".join(tex_lines[start - 1:end])):
            return end
    return None


def find_prop_span(
    normalized_prop: str,
    window_norms: list[str],
    tex_lines: list[str],
    normalize_fn,
    claimed_start: int | None,
) -> tuple[int, int] | None:
    """Locate a prop's (start_line, end_line) in main.tex via windowed search.

    `normalized_prop` is the prop's text already passed through `normalize_fn`.
    `window_norms[s]` is the normalized MAX_SPAN-line window starting at the
    1-indexed line `s + 1` (see `precompute_window_norms`).

    `starts` collects every 1-indexed line whose MAX_SPAN-window contains the
    prop. Distinct occurrences are then separated:

    - Common case — no window contains the prop more than once: each maximal
      contiguous run of `starts` is exactly one occurrence, and its MAX is the
      true start line (a window starting at `s` contains the prop iff `s` is at
      or before the start, so the largest such `s` is the start). No extra
      normalization — fast.
    - Duplicate case — some window contains the prop twice (a verbatim repeat
      within MAX_SPAN lines): each `start` is resolved to the minimal end line
      of its span via `_grow_end`. One distinct end line is one occurrence, and
      the largest start resolving to it is that occurrence's true start.

    Among occurrences, the one whose start is nearest `claimed_start` wins (the
    first if there is no claim) — the duplicate-text disambiguation contract.

    Returns None when the prop matches no window — genuinely un-anchorable
    within MAX_SPAN lines (source span longer, or absent). The caller counts
    this as a loud `anchor_failed` — never a silent mis-write.
    """
    if not normalized_prop.strip():
        return None  # empty / whitespace-only prop — not locatable

    starts = [
        t
        for t in range(1, len(window_norms) + 1)
        if normalized_prop in window_norms[t - 1]
    ]
    if not starts:
        return None

    if any(window_norms[t - 1].count(normalized_prop) >= 2 for t in starts):
        # A window sees the prop twice — resolve each start to its span's end
        # line; one distinct end == one occurrence, largest start wins per end.
        by_end: dict[int, int] = {}
        for t in starts:
            e = _grow_end(normalized_prop, tex_lines, normalize_fn, t)
            if e is not None and t > by_end.get(e, 0):
                by_end[e] = t
        occurrences = sorted((t, e) for e, t in by_end.items())
    else:
        # Each contiguous run of `starts` is one occurrence; run-max is the
        # true start line.
        occ_starts: list[int] = []
        run_max = starts[0]
        for s in starts[1:]:
            if s == run_max + 1:
                run_max = s
            else:
                occ_starts.append(run_max)
                run_max = s
        occ_starts.append(run_max)
        occurrences = [
            (t, _grow_end(normalized_prop, tex_lines, normalize_fn, t))
            for t in occ_starts
        ]

    occurrences = [(t, e) for t, e in occurrences if e is not None]
    if not occurrences:
        return None

    if claimed_start is not None:
        return min(occurrences, key=lambda oc: abs(oc[0] - claimed_start))
    return occurrences[0]


_TEX_COMMENT = re.compile(r"(?:^|[^\\])(?:\\\\)*%")


def _code(line: str) -> str:
    """`line` without its TeX comment (text after an unescaped `%`)."""
    m = _TEX_COMMENT.search(line)
    return line if m is None else line[: m.end() - 1]


def _escaped(text: str, i: int) -> bool:
    """Whether the character at `i` follows an odd number of backslashes."""
    n = 0
    while i - n - 1 >= 0 and text[i - n - 1] == "\\":
        n += 1
    return n % 2 == 1


def _count_token(text: str, token: str) -> int:
    """Occurrences of `token` in `text` that are not escaped (`\\[` is a line break)."""
    count, i = 0, text.find(token)
    while i != -1:
        if not _escaped(text, i):
            count += 1
            i = text.find(token, i + len(token))
        else:
            i = text.find(token, i + 1)
    return count


def _dollars_before(tex_lines: list[str], line_no: int, col: int) -> int:
    """`$$` outside comments and not escaped, before column `col` of line `line_no`."""
    before = sum(_count_token(_code(line), "$$") for line in tex_lines[: line_no - 1])
    return before + _count_token(_code(tex_lines[line_no - 1][:col]), "$$")


def _window_matches(window: list[str], own: list[str], first_silent: bool, last_silent: bool) -> bool:
    """Whether manuscript lines `window` hold the prop's stripped lines `own`.

    The first line may begin with other text (a sentence starts partway
    through a line) and the last may end with other text; every other line,
    blank lines included, is equal. On a side whose own line is a lone
    delimiter, that delimiter must be a real one (not after a TeX comment, not
    preceded by an odd number of backslashes, as in `\\\\[2pt]`), and the
    rest of the manuscript line, outside a comment, must not hold the same
    delimiter again: such a delimiter belongs to other text (verify rounds 3
    and 4 of issue 110).
    """
    lines = [line.strip() for line in window]
    if lines[1:-1] != own[1:-1]:
        return False
    if not lines[0].endswith(own[0]) or not lines[-1].startswith(own[-1]):
        return False
    head = lines[0][: len(lines[0]) - len(own[0])]
    if first_silent and head and (
        _TEX_COMMENT.search(head) or _escaped(lines[0], len(head)) or _count_token(head, own[0])
    ):
        return False
    tail = lines[-1][len(own[-1]):]
    if last_silent and tail and _count_token(_code(tail), own[-1]):
        return False
    return True


def _dollar_roles_hold(tex_lines: list[str], first: int, last: int, own: list[str]) -> bool:
    """A `$$` side opens (even count before it) or closes (odd count) a display.

    `$$` opens and closes with the same token, so a window whose first `$$`
    closes the previous display looks, line by line, like a proposition's own
    display (verify round 4 of issue 110).
    """
    if own[0] == "$$":
        line = tex_lines[first - 1].rstrip()
        if _dollars_before(tex_lines, first, len(line) - 2) % 2 != 0:
            return False
    if own[-1] == "$$":
        line = tex_lines[last - 1]
        if _dollars_before(tex_lines, last, len(line) - len(line.lstrip())) % 2 != 1:
            return False
    return True


def widen_to_text(
    span: tuple[int, int], text: str, tex_lines: list[str], normalize_fn
) -> tuple[int, int]:
    """Grow a located span over the prop's own delimiter lines (issue 110).

    `find_prop_span` returns the smallest span whose normalized text contains
    the prop. A line that normalizes to nothing on its own — a lone `\\]`,
    `\\[`, `$$`, `\\begin{equation}` — never makes a window contain more, so a
    prop that ends (or starts) with one comes back a line short.

    A widened span has to match the prop line by line, so it has exactly as
    many lines as the prop. The windows of that length that contain the span
    are tried, nearest the span's start first, extending only a side whose own
    line normalizes to nothing; the first that `_window_matches` is kept. A
    walk that stopped at the first line looking like the boundary picked
    comment lines and other text's delimiters, and gave up on a repeated
    closing line (verify rounds 1 to 3). No match keeps the span.
    """
    own = [line.strip() for line in text.split("\n")]
    while own and not own[0]:
        own.pop(0)
    while own and not own[-1]:
        own.pop()
    start, end = span
    count = len(own)
    if count == 0 or count > MAX_SPAN or end - start + 1 >= count:
        return span
    first_silent = not normalize_fn(own[0]).strip()
    last_silent = not normalize_fn(own[-1]).strip()
    for first in range(start, end - count, -1):
        last = first + count - 1
        if first < 1 or last < end or last > len(tex_lines):
            continue
        if (first < start and not first_silent) or (last > end and not last_silent):
            continue
        if _window_matches(
            tex_lines[first - 1:last], own, first_silent, last_silent
        ) and _dollar_roles_hold(tex_lines, first, last, own):
            return first, last
    return span


def read_tex_lines(path: Path) -> tuple[str, list[str]]:
    """(text, lines) of one manuscript file, as every `location` this tool writes counts them.

    `read_text()` reads with universal newlines, so a line ends at LF, CR or CRLF and at
    no other character. The Swift package counts lines the same way
    (Sources/PropositionsKit/ReadingOrder.swift, `LatexLine.splitLines`), and its ParityTests
    call this function: change the two together.
    """
    text = path.read_text()
    return text, text.split("\n")


def parse_claimed_loc(loc_str: str) -> tuple[str | None, int | None, int | None]:
    """v1.6-aware parse: returns (relpath_or_None, start, end).

    relpath None = the main file (bare `L<n>` or a literal `main.tex:` prefix).
    """
    parsed = parse_location_v16(loc_str or "")
    if parsed is None:
        return None, None, None
    return parsed


def refresh_jsonl(
    jsonl_path: Path, tex_path: Path, dry_run: bool
) -> tuple[int, int, int, int]:
    """Refresh location fields in jsonl_path.

    Returns (props_total, props_updated, props_match_failed, props_anchor_failed).
    """
    validator = load_validator()
    normalize = validator.normalize_for_match

    # v1.6 multi-file: resolve the input tree; each prop anchors within the
    # file its location names (unprefixed → the main file). Per-file locator
    # state is built lazily so single-file repos pay nothing extra.
    try:
        tree = resolve_input_tree(tex_path)
    except InputTreeError as e:
        print(f"✗ input-tree resolution failed: {e}", file=sys.stderr)
        raise SystemExit(2)
    main_dir = tex_path.resolve().parent
    file_paths: dict[str | None, Path] = {None: tex_path}
    for part in tree[1:]:
        rel = os.path.relpath(part, main_dir).replace(os.sep, "/")
        file_paths[rel] = part

    _locator_cache: dict[str | None, tuple[list[str], str, list[str]]] = {}

    def locator_state(key: str | None) -> tuple[list[str], str, list[str]]:
        """(tex_lines, normalized_tex, window_norms) for one corpus file."""
        if key not in _locator_cache:
            text, lines = read_tex_lines(file_paths[key])
            _locator_cache[key] = (
                lines,
                normalize(text),
                precompute_window_norms(lines, normalize),
            )
        return _locator_cache[key]

    props = []
    with jsonl_path.open() as fp:
        for line in fp:
            line = line.strip()
            if line:
                props.append(json.loads(line))

    updated = 0
    match_failed = 0
    anchor_failed = 0
    new_lines = []

    for p in props:
        text = p.get("text", "")
        claimed_file, claimed_start, claimed_end = parse_claimed_loc(
            p.get("location", "")
        )
        if claimed_file is not None and claimed_file not in file_paths:
            match_failed += 1
            print(
                f"⚠ {p['id'][:8]} ({p.get('location','?')}): location file "
                f"not in input tree — leaving location unchanged",
                file=sys.stderr,
            )
            new_lines.append(p)
            continue
        tex_lines, normalized_tex, window_norms = locator_state(claimed_file)
        loc_prefix = claimed_file if claimed_file is not None else "main.tex"
        normalized_text = normalize(text)

        # Empty / whitespace-only prop.text: `"" in anything` is always True, so
        # it would slip past the R1 containment check and be silently relocated
        # to L1. Reject as match_failed instead (#123 F3).
        if not normalized_text.strip():
            match_failed += 1
            print(
                f"⚠ {p['id'][:8]} ({p.get('location','?')}): prop.text empty / whitespace-only — cannot locate",
                file=sys.stderr,
            )
            new_lines.append(p)
            continue

        # R1 normalize-aware existence check (whole-text)
        if normalized_text not in normalized_tex:
            match_failed += 1
            print(
                f"⚠ {p['id'][:8]} ({p.get('location','?')}): text (normalized) NOT in {loc_prefix} — leaving location unchanged",
                file=sys.stderr,
            )
            new_lines.append(p)
            continue

        # Map to actual line span via the windowed locator (#137)
        span = find_prop_span(
            normalized_text, window_norms, tex_lines, normalize, claimed_start
        )
        if span is None:
            # R1 (whole-text) passed but the prop is not anchorable within
            # MAX_SPAN lines. Surface loudly; never silently mis-write
            # `location`.
            anchor_failed += 1
            print(
                f"⚠ {p['id'][:8]} ({p.get('location','?')}): R1 passes but anchor failed — location unchanged",
                file=sys.stderr,
            )
            new_lines.append(p)
            continue

        actual_start, actual_end = widen_to_text(span, text, tex_lines, normalize)
        new_loc = (
            f"{loc_prefix}:L{actual_start}-L{actual_end}"
            if actual_end > actual_start
            else f"{loc_prefix}:L{actual_start}"
        )

        old_loc = p.get("location", "")
        if new_loc != old_loc:
            updated += 1
            # The stored location as it was, read before it is replaced
            # (issue 110); `?` only when the key is missing.
            shown = p.get("location", "?")
            if not dry_run:
                p["location"] = new_loc
            print(
                f"✓ {p['id'][:8]}: {shown} → {new_loc}",
                file=sys.stderr,
            )
        new_lines.append(p)

    if not dry_run:
        # Write back preserving JSON structure (one object per line, no trailing newline weirdness)
        with jsonl_path.open("w") as fp:
            for p in new_lines:
                fp.write(json.dumps(p, ensure_ascii=False) + "\n")

    return len(props), updated, match_failed, anchor_failed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jsonl", type=Path, required=True, help="propositions JSONL path")
    parser.add_argument("--tex", type=Path, default=DEFAULT_TEX, help="manuscript .tex path")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="show what would change without writing",
    )
    args = parser.parse_args()

    if not args.jsonl.exists():
        print(f"error: jsonl not found: {args.jsonl}", file=sys.stderr)
        return 2
    if not args.tex.exists():
        print(f"error: tex not found: {args.tex}", file=sys.stderr)
        return 2

    total, updated, match_failed, anchor_failed = refresh_jsonl(
        args.jsonl, args.tex, args.dry_run
    )

    print(f"\n=== {args.jsonl.name} ===", file=sys.stderr)
    print(f"total props: {total}", file=sys.stderr)
    print(f"updated: {updated}", file=sys.stderr)
    print(f"R1 match failed: {match_failed}", file=sys.stderr)
    print(f"anchor failed: {anchor_failed}", file=sys.stderr)
    if args.dry_run:
        print(f"(dry-run — no changes written)", file=sys.stderr)

    return 1 if (match_failed > 0 or anchor_failed > 0) else 0


if __name__ == "__main__":
    sys.exit(main())
