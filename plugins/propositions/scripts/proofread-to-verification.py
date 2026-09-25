#!/usr/bin/env python3
"""proofread-to-verification.py — turn a proofread checklist into verification records (#12).

Reads a `.proofread/<file>.md` checklist produced by the proofread skill and
emits one `method=proofread` record per walked line, as JSONL on stdout:

    - [x] **P012** `019e2fbe-c7f3-…` [claim] @L10-L12 — "…"   → status supported
    - [~] ...                                          → status partial
    - [-] ...                                          → status not_attempted
    - [ ] ...                                          → skipped (not walked yet)

Identity comes only from the full proposition id in backticks (the proofread
skill writes it), and that proposition's text must still start with the quoted
snippet, so a verdict on rewritten text is not recorded as current. A short id
prefix is never resolved: every content-based fallback (ordinal, prefix plus
snippet, prefix plus whole text) was shown to hand a verdict to another
proposition after the ledger changed. A walked line without a snippet, an
unknown mark, or an unresolvable line aborts: nothing is written and the exit
code is 1 — attaching a verdict to the wrong proposition is worse than
missing one.

A checklist generated before the manuscript was rewritten has lines whose text
no longer exists, and an old checklist may carry only short id prefixes;
``--allow-unmatched`` skips both kinds (listing them on stderr) instead of
aborting. Ambiguous lines abort regardless.

Exit code: 0 ok, 1 unresolved line, 2 usage or I/O error.
"""
from __future__ import annotations

import argparse
import datetime
import importlib.util
import json
import re
import sys
from pathlib import Path

MARK_TO_STATUS = {"x": "supported", "X": "supported", "~": "partial", "-": "not_attempted"}
_LINE_RE = re.compile(r"^\s*-\s*\[(?P<mark>.)\]\s*\*\*[PC]\d+\*\*\s*`(?P<prefix>[0-9a-fA-F-]+)`")
TAIPEI = datetime.timezone(datetime.timedelta(hours=8))


# The quoted text after the dash: em/en dash or hyphen, straight or curly
# quotes. The snippet ends at the first closing quote that is followed by the
# `(asserts …)` tail, a `[` note, or the end of the line; anything after it is
# ignored.
_SNIPPET_RE = re.compile(r'[\u2014\u2013-]\s*["\u201c](?P<snip>.+?)["\u201d]\s*(?=\(|\[|$)')
_FULL_ID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def _load_validator():
    path = Path(__file__).parent / "validate-propositions.py"
    spec = importlib.util.spec_from_file_location("validate_propositions", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _is_date(value) -> bool:
    """Same rule as validate-verification.py's V4: exactly YYYY-MM-DD."""
    if not (isinstance(value, str) and len(value) == 10):
        return False
    try:
        datetime.date.fromisoformat(value)
    except ValueError:
        return False
    return True


def _collapse(text) -> str:
    return " ".join(text.split()) if isinstance(text, str) else ""


def _snippet(line: str) -> tuple[str | None, bool]:
    """(collapsed snippet, whether it was truncated with an ellipsis)."""
    m = _SNIPPET_RE.search(line)
    if not m:
        return None, False
    snip, truncated = m.group("snip"), False
    for tail in ("\u2026", "..."):
        if snip.endswith(tail):
            snip, truncated = snip[: -len(tail)], True
    return (_collapse(snip) or None), truncated


def _resolve(line: str, prefix: str, ledger) -> tuple[list[str], str | None]:
    """Find this line's proposition. Returns (ids, problem).

    Identity comes only from a FULL UUID in backticks: that exact ledger id,
    whose text must still start with the snippet (a verdict on rewritten text
    is stale). A short prefix is never resolved. Every content-based fallback
    tried before — view ordinal, prefix + truncated snippet, prefix + whole
    text — was shown to hand the verdict to another proposition after the
    ledger changed, because matching content says what a proposition says now,
    not which proposition the reviewer walked.
    """
    snip, _ = _snippet(line)
    if snip is None:
        return [], "has no quoted text snippet to confirm which proposition it means"
    if not _FULL_ID_RE.match(prefix):
        return [], ("gives only an id prefix, which cannot identify a proposition; "
                    "regenerate the checklist with full ids")
    return [p["id"] for p in ledger
            if isinstance(p.get("id"), str) and p["id"].lower() == prefix
            and _collapse(p.get("text")).startswith(snip)], None


def convert(text: str, checklist_ref: str, ledger, checked_at: str,
            checker: str | None = None, allow_unmatched: bool = False):
    """Return (records, problems, skipped). Records are empty whenever problems exist.

    A line matching NO proposition (its text was rewritten or removed since the
    checklist was generated) is a problem by default; with ``allow_unmatched``
    it is listed in ``skipped`` instead — it cannot attach a verdict to the
    wrong proposition. A line matching SEVERAL is always a problem.

    ``ledger`` is the list of ledger props (``id`` and ``text`` are read).
    """
    records, problems, skipped = [], [], []
    for lineno, line in enumerate(text.splitlines(), 1):
        m = _LINE_RE.match(line)
        if not m or m.group("mark") == " ":
            continue
        status = MARK_TO_STATUS.get(m.group("mark"))
        if status is None:
            problems.append(f"L{lineno}: unknown checklist mark [{m.group('mark')}]")
            continue
        prefix = m.group("prefix").lower()
        matches, why = _resolve(line, prefix, ledger)
        if why is not None and not (allow_unmatched and "regenerate" in why):
            problems.append(f"L{lineno}: {why}")
            continue
        if why is not None:
            skipped.append(f"L{lineno}: {why}")
            continue
        if not matches and allow_unmatched:
            skipped.append(f"L{lineno}: prefix `{prefix}` matches no ledger proposition")
            continue
        if len(matches) != 1:
            what = ("matches no ledger proposition" if not matches
                    else f"and its text snippet still match {len(matches)} propositions")
            problems.append(f"L{lineno}: prefix `{prefix}` {what}")
            continue
        record = {"prop_id": matches[0], "method": "proofread", "status": status,
                  "checked_at": checked_at, "evidence_ref": f"{checklist_ref}:L{lineno}"}
        if checker:
            record["checker"] = checker
        records.append(record)
    return ([] if problems else records), problems, skipped


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--checklist", required=True, type=Path)
    ap.add_argument("--ledger", required=True, type=Path)
    ap.add_argument("--checked-at", default=datetime.datetime.now(TAIPEI).date().isoformat())
    ap.add_argument("--checker")
    ap.add_argument("--allow-unmatched", action="store_true",
                    help="skip (and list) lines whose proposition text changed since the "
                         "checklist was generated; ambiguous lines still abort")
    args = ap.parse_args(argv)
    try:
        if not _is_date(args.checked_at):
            raise ValueError(f"--checked-at {args.checked_at!r} is not a YYYY-MM-DD date")
        text = args.checklist.read_text(encoding="utf-8-sig")
        _, ledger, _ = _load_validator().load_props_jsonl(args.ledger)
    except (OSError, ValueError) as exc:
        print(f"✗ {exc}", file=sys.stderr)
        return 2
    records, problems, skipped = convert(text, str(args.checklist), ledger,
                                         args.checked_at, args.checker,
                                         args.allow_unmatched)
    for sk in skipped:
        print(f"⚠ {args.checklist} {sk} — skipped", file=sys.stderr)
    if problems:
        for p in problems:
            print(f"✗ {args.checklist} {p}", file=sys.stderr)
        print("✗ no records written", file=sys.stderr)
        return 1
    for r in records:
        print(json.dumps(r, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
