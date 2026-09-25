#!/usr/bin/env python3
"""proofread-to-verification.py — turn a proofread checklist into verification records (#12).

Reads a `.proofread/<file>.md` checklist produced by the proofread skill and
emits one `method=proofread` record per walked line, as JSONL on stdout:

    - [x] **P012** `019e2fbe` [claim] @L10-L12 — "…"   → status supported
    - [~] ...                                          → status partial
    - [-] ...                                          → status not_attempted
    - [ ] ...                                          → skipped (not walked yet)

Each line is resolved to one ledger proposition by its backticked id prefix,
then its quoted text snippet, then its ``P{seq}`` view ordinal (UUIDv7 ids
minted together share their leading characters, so the prefix alone is often
ambiguous). If any line still matches no proposition or more than one, nothing
is written and the exit code is 1 — attaching a verdict to the wrong
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


_SNIPPET_RE = re.compile(r'\u2014\s*"(?P<snip>.*)"\s*\(asserts')
_ORDINAL_RE = re.compile(r"\*\*(?P<ord>P\d+)\*\*")


def _load_validator():
    path = Path(__file__).parent / "validate-propositions.py"
    spec = importlib.util.spec_from_file_location("validate_propositions", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _collapse(text: str) -> str:
    return " ".join(text.split())


def _snippet(line: str) -> str | None:
    m = _SNIPPET_RE.search(line)
    if not m:
        return None
    snip = m.group("snip")
    for tail in ("\u2026", "..."):
        if snip.endswith(tail):
            snip = snip[: -len(tail)]
    return _collapse(snip) or None


def _resolve(line: str, prefix: str, ledger, ordinals) -> tuple[list[str], str]:
    """Narrow the ledger to this line's proposition. Returns (ids, stage).

    UUIDv7 ids minted in one batch share their leading timestamp, so the
    checklist's short prefix is often ambiguous. Narrow in order: id prefix,
    then the quoted text snippet, then the view ordinal (``P{seq}``). The
    ordinal comes last because it shifts whenever the ledger gains or loses a
    proposition; the snippet survives that.
    """
    ids = [p["id"] for p in ledger if p["id"].lower().startswith(prefix)]
    snip = _snippet(line)
    if snip is not None:
        # Always applied, even to a unique prefix: a verdict on text that has
        # since been rewritten must not be recorded as current.
        texts = {p["id"]: _collapse(p.get("text", "")) for p in ledger}
        ids = [i for i in ids if texts[i].startswith(snip)]
    if len(ids) <= 1:
        return ids, "text snippet" if snip is not None else "prefix"
    m = _ORDINAL_RE.search(line)
    if ordinals and m:
        narrowed = [i for i in ids if ordinals.get(i) == m.group("ord")]
        if narrowed:
            return narrowed, "ordinal"
    return ids, "ordinal"


def convert(text: str, checklist_ref: str, ledger, checked_at: str,
            checker: str | None = None, ordinals: dict[str, str] | None = None,
            allow_unmatched: bool = False):
    """Return (records, problems, skipped). Records are empty whenever problems exist.

    A line matching NO proposition (its text was rewritten or removed since the
    checklist was generated) is a problem by default; with ``allow_unmatched``
    it is listed in ``skipped`` instead — it cannot attach a verdict to the
    wrong proposition. A line matching SEVERAL is always a problem.

    ``ledger`` is the list of ledger props (``id`` and ``text`` are read);
    ``ordinals`` maps id to its view ordinal (``P001``…), used only to break
    ties the prefix and text snippet leave.
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
        matches, stage = _resolve(line, prefix, ledger, ordinals)
        if not matches and allow_unmatched:
            skipped.append(f"L{lineno}: prefix `{prefix}` matches no ledger proposition")
            continue
        if len(matches) != 1:
            what = ("matches no ledger proposition" if not matches
                    else f"still matches {len(matches)} propositions after the {stage}")
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
        datetime.date.fromisoformat(args.checked_at)
        text = args.checklist.read_text(encoding="utf-8")
        validator = _load_validator()
        _, ledger, _ = validator.load_props_jsonl(args.ledger)
        ordinals = {uid: disp for disp, uid in validator.derive_view_ordinals(args.ledger)}
    except (OSError, ValueError) as exc:
        print(f"✗ {exc}", file=sys.stderr)
        return 2
    records, problems, skipped = convert(text, str(args.checklist), ledger,
                                         args.checked_at, args.checker, ordinals,
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
