#!/usr/bin/env python3
"""proofread-to-verification.py — turn a proofread checklist into verification records (#12).

Reads a `.proofread/<file>.md` checklist produced by the proofread skill and
emits one `method=proofread` record per walked line, as JSONL on stdout:

    - [x] **P012** `019e2fbe` [claim] @L10-L12 — "…"   → status supported
    - [~] ...                                          → status partial
    - [-] ...                                          → status not_attempted
    - [ ] ...                                          → skipped (not walked yet)

Each line is resolved to one ledger proposition only when its backticked id
prefix AND its quoted text snippet agree on exactly one (UUIDv7 ids minted
together share their leading characters, so the prefix alone is often
ambiguous; the view ordinal is never used, because it shifts when the ledger
changes). A walked line without a quoted snippet, an unknown mark, or a line
matching more than one proposition aborts: nothing is written and the exit
code is 1 — attaching a verdict to the wrong
proposition is worse than missing one. Every other line (headings, the Findings table) is ignored.

`supported` from proofread means the six reading checks passed (see
docs/VERIFICATION.md); it is not a formal proof.

Usage:
    python3 proofread-to-verification.py --checklist .proofread/main.md \\
        --ledger manuscript/propositions/main.jsonl [--checked-at YYYY-MM-DD] [--checker NAME] \\
        >> manuscript/propositions/verification.jsonl

A checklist generated before the manuscript was rewritten has lines whose text
no longer exists; ``--allow-unmatched`` skips those (listing them on stderr)
instead of aborting. Ambiguous lines abort regardless.

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
_LINE_RE = re.compile(r"^\s*-\s*\[(?P<mark>.)\]\s*\*\*P\d+\*\*\s*`(?P<prefix>[0-9a-fA-F-]+)`")
TAIPEI = datetime.timezone(datetime.timedelta(hours=8))


# The quoted text after the dash: em/en dash or hyphen, straight or curly
# quotes. Anything after the closing quote (asserts counts, a reviewer's note)
# is ignored.
_SNIPPET_RE = re.compile(r'[\u2014\u2013-]\s*["\u201c](?P<snip>.+?)["\u201d](?=[^"\u201d]*$)')


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


def _snippet(line: str) -> str | None:
    m = _SNIPPET_RE.search(line)
    if not m:
        return None
    snip = m.group("snip")
    for tail in ("\u2026", "..."):
        if snip.endswith(tail):
            snip = snip[: -len(tail)]
    return _collapse(snip) or None


def _resolve(line: str, prefix: str, ledger) -> tuple[list[str], str | None]:
    """Narrow the ledger to this line's proposition. Returns (ids, problem).

    UUIDv7 ids minted in one batch share their leading timestamp, so the
    checklist's short prefix is often ambiguous. A line resolves only when its
    id prefix AND its quoted text snippet agree on exactly one proposition.
    The snippet is mandatory: without it a line could only be matched by
    position, and a position-only match is how a verdict lands on the wrong
    proposition after the ledger changes. The view ordinal is never used.
    """
    snip = _snippet(line)
    if snip is None:
        return [], "has no quoted text snippet to confirm which proposition it means"
    ids = [p["id"] for p in ledger
           if isinstance(p.get("id"), str) and p["id"].lower().startswith(prefix)
           and _collapse(p.get("text")).startswith(snip)]
    return ids, None


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
        if why is not None:
            problems.append(f"L{lineno}: {why}")
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
