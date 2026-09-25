#!/usr/bin/env python3
"""validate-verification.py — check a ledger's verification-record sidecar (#12).

The propositions ledger (`main.jsonl`) decomposes a manuscript into claims; it
does not say whether a claim is true. Verdicts from external methods (proofread,
Lean, exact certificates, CAS, cross-model re-derivation, human review) live in
`verification.jsonl` next to the ledger, one record per line. Format and
vocabulary: `plugins/propositions/docs/VERIFICATION.md`.

Checks (per record line):
    V1  malformed JSON, not an object, or a required key missing
    V2  `prop_id` not an `id` in the ledger
    V3  `method` / `status` outside the vocabulary
    V4  `checked_at` not a valid YYYY-MM-DD date
    V5  a verdict (status other than `not_attempted`) with no `evidence_ref`
    V6  duplicate (prop_id, method, evidence_ref) — warning

Cross-method disagreement (warning): a proposition whose latest record for one
method is `supported` while another method's latest is `refuted` or `partial`.

Usage:
    python3 validate-verification.py --records verification.jsonl --ledger main.jsonl

Exit code:
    0 — no errors (warnings allowed)
    1 — at least one error
    2 — usage or I/O error
"""
from __future__ import annotations

import argparse
import datetime
import importlib.util
import json
import sys
from pathlib import Path

METHODS = ("proofread", "lean", "exact_certificate", "cas", "cross_model", "human")
CUSTOM_METHOD_PREFIX = "x-"
STATUSES = ("supported", "refuted", "partial", "unresolved", "not_attempted")
REQUIRED_KEYS = ("prop_id", "method", "status", "checked_at")
VERDICT_FREE_STATUS = "not_attempted"
DISAGREEING_STATUSES = ("refuted", "partial")


def _load_ledger_ids(ledger_path: Path) -> set[str]:
    """Ledger ids, read with validate-propositions' own JSONL loader."""
    path = Path(__file__).parent / "validate-propositions.py"
    spec = importlib.util.spec_from_file_location("validate_propositions", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    _, _, by_id = module.load_props_jsonl(ledger_path)
    return set(by_id)


def load_records(path: Path) -> list[tuple[int, dict | None, str | None]]:
    """(line number, record or None, parse error or None) per non-blank line."""
    out = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError as exc:
            out.append((lineno, None, f"malformed JSON: {exc.msg}"))
            continue
        if not isinstance(obj, dict):
            out.append((lineno, None, "record must be a JSON object"))
            continue
        out.append((lineno, obj, None))
    return out


def _is_date(value) -> bool:
    if not isinstance(value, str) or len(value) != 10:
        return False
    try:
        datetime.date.fromisoformat(value)
    except ValueError:
        return False
    return True


def _method_ok(method) -> bool:
    return isinstance(method, str) and (
        method in METHODS
        or (method.startswith(CUSTOM_METHOD_PREFIX) and len(method) > len(CUSTOM_METHOD_PREFIX))
    )


def _check_one(lineno: int, r: dict, ledger_ids: set[str]) -> list[tuple[str, int, str]]:
    missing = [k for k in REQUIRED_KEYS if k not in r]
    if missing:
        return [("V1", lineno, f"missing required key(s): {', '.join(missing)}")]
    errors = []
    if r["prop_id"] not in ledger_ids:
        errors.append(("V2", lineno, f"prop_id {r['prop_id']!r} is not an id in the ledger"))
    if not _method_ok(r["method"]):
        errors.append(("V3", lineno, f"method {r['method']!r} not in "
                       f"{'/'.join(METHODS)} and not an `{CUSTOM_METHOD_PREFIX}` custom value"))
    if r["status"] not in STATUSES:
        errors.append(("V3", lineno, f"status {r['status']!r} not in {'/'.join(STATUSES)}"))
    if not _is_date(r["checked_at"]):
        errors.append(("V4", lineno, f"checked_at {r['checked_at']!r} is not a YYYY-MM-DD date"))
    evidence = r.get("evidence_ref")
    has_evidence = isinstance(evidence, str) and evidence.strip()
    if r["status"] != VERDICT_FREE_STATUS and not has_evidence:
        errors.append(("V5", lineno, f"status {r['status']!r} needs a non-empty evidence_ref "
                       f"(only {VERDICT_FREE_STATUS} may omit it)"))
    return errors


def check_records(lines, ledger_ids: set[str]):
    """Return (errors, warnings), each a list of (code, line, message)."""
    errors, warnings, seen = [], [], {}
    for lineno, r, parse_error in lines:
        if parse_error is not None:
            errors.append(("V1", lineno, parse_error))
            continue
        found = _check_one(lineno, r, ledger_ids)
        errors.extend(found)
        if found:
            continue
        key = (r["prop_id"], r["method"], r.get("evidence_ref"))
        if key in seen:
            warnings.append(("V6", lineno, f"duplicate of line {seen[key]} "
                             f"(same prop_id, method, evidence_ref)"))
        else:
            seen[key] = lineno
    return errors, warnings


def disagreements(records) -> list[tuple[str, dict[str, str]]]:
    """Propositions whose methods' LATEST verdicts disagree.

    Latest = greatest `checked_at`; on a tie, the later record in file order.
    A disagreement is one method `supported` while another is `refuted` or
    `partial`. Returns [(prop_id, {method: status})] in first-seen order.
    """
    latest: dict[str, dict[str, tuple[str, str]]] = {}
    for r in records:
        per_method = latest.setdefault(r["prop_id"], {})
        current = per_method.get(r["method"])
        if current is None or r["checked_at"] >= current[0]:
            per_method[r["method"]] = (r["checked_at"], r["status"])
    found = []
    for prop_id, per_method in latest.items():
        statuses = {m: s for m, (_, s) in sorted(per_method.items())}
        values = set(statuses.values())
        if "supported" in values and values & set(DISAGREEING_STATUSES):
            found.append((prop_id, statuses))
    return found


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--records", required=True, type=Path, help="verification.jsonl")
    ap.add_argument("--ledger", required=True, type=Path, help="ledger main.jsonl")
    args = ap.parse_args(argv)
    try:
        lines = load_records(args.records)
        ledger_ids = _load_ledger_ids(args.ledger)
    except (OSError, ValueError) as exc:
        print(f"✗ cannot read input: {exc}", file=sys.stderr)
        return 2

    errors, warnings = check_records(lines, ledger_ids)
    valid = [r for lineno, r, err in lines
             if err is None and not any(e[1] == lineno for e in errors)]
    print(f"Records: {args.records} ({len(lines)} line(s))")
    print(f"Ledger:  {args.ledger} ({len(ledger_ids)} id(s))")
    for code, lineno, msg in errors + warnings:
        print(f"[{code}] L{lineno}: {msg}")
    for prop_id, statuses in disagreements(valid):
        pairs = ", ".join(f"{m}={s}" for m, s in statuses.items())
        print(f"[WARN] disagreement {prop_id}: {pairs}")
    if errors:
        print(f"=== {len(errors)} ERROR(s) ===")
        return 1
    print("✓ ALL VERIFICATION CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
