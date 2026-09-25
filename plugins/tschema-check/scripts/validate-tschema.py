#!/usr/bin/env python3
"""validate-tschema.py — mechanical checks for a tschema-check record file (#4).

A tschema check asks whether a document written from source material (minutes,
interview notes, a draft) is faithful to that source. Judging how well a
statement is supported stays with the reviewer (see the skill). This script
checks what a script can check: that every recorded statement is really in the
checked document, and that every quoted piece of evidence is really in the
external source it names.

Checks:
    T1  record shape and vocabulary                               error
    T2  claim `text` not in the checked document                  error
    T3  claim `text` not within the lines its `location` names    warning
    T4  `evidence` not in the source file `source_locator.path`   error
    T5  `attested` claim without `evidence` or `source_locator`   error
    T6  relation `pair` / logic `target` not a claim in the file  error
    T7  verification-failure phrase in the checked document       warning

T2/T3 are R1/R13 from the propositions validator applied to any document; T4 is
R1 generalized to an external source. Matching applies NFKC and removes ALL
whitespace on both sides (CJK sentences wrap mid-line). `.srt` sources have cue
numbers and timing lines removed first. Claims whose source has no local `path`
cannot be checked by T4; they are counted per source type, never passed.

Usage:
    python3 validate-tschema.py --records tschema.jsonl --document minutes.md

Exit code: 0 no errors, 1 at least one error, 2 usage or I/O error.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

KINDS = ("claim", "relation", "logic")
SOURCE_SUPPORT = ("attested", "doc", "inferred", "unsupported")
SEMANTIC_DISTANCE = ("verbatim", "near", "far")
DRIFT_TYPES = ("modality", "abstraction", "evaluation", "agency", "nominalization",
               "dangling-reference", "missing-step", "tautology", "irrelevance",
               "overgeneralization")
LOCATOR_TYPES = ("transcript", "email", "statute", "document", "dataset", "other")
RELATIONS = ("causal", "conditional", "concessive", "sequential", "elaboration",
             "coordinate", "none")
FAILURE_PHRASES = ("未能查得", "未能確認", "因錄音不清", "無從查證")
REQUIRED = {
    "claim": ("id", "text", "location", "source_support", "semantic_distance"),
    "relation": ("id", "pair", "source_relation", "rendered_relation"),
    "logic": ("id", "target", "drift_type"),
}
_UUID7_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
_LOCATION_RE = re.compile(r"^L(\d+)(?:-L(\d+))?$")
_SRT_TIMING_RE = re.compile(r"^\s*\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}\s*-->")
_WS_RE = re.compile(r"\s+")


def normalize(text: str) -> str:
    """NFKC, then every whitespace character removed."""
    return _WS_RE.sub("", unicodedata.normalize("NFKC", text))


def strip_srt(text: str) -> str:
    """Subtitle text only: drop cue-number lines and `-->` timing lines."""
    keep = [line for line in text.splitlines()
            if not line.strip().isdigit() and not _SRT_TIMING_RE.match(line)]
    return "\n".join(keep)


def _strip_percent_comment(line: str) -> str:
    run = 0
    for i, ch in enumerate(line):
        if ch == "%" and run % 2 == 0:
            return line[:i]
        run = run + 1 if ch == "\\" else 0
    return line


def load_records(path: Path):
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


def _enum(value, allowed, name):
    if value not in allowed:
        return f"{name} {value!r} not in {'/'.join(allowed)}"
    return None


def _shape_problems(r: dict) -> list[str]:
    kind = r.get("kind")
    if kind not in KINDS:
        return [f"kind {kind!r} not in {'/'.join(KINDS)}"]
    missing = [k for k in REQUIRED[kind] if k not in r]
    if missing:
        return [f"{kind} record missing required key(s): {', '.join(missing)}"]
    problems = []
    if not (isinstance(r["id"], str) and _UUID7_RE.match(r["id"])):
        problems.append(f"id {r['id']!r} is not a UUID v7")
    if kind == "claim":
        if not (isinstance(r["text"], str) and normalize(r["text"])):
            problems.append("text must be a non-empty string")
        if not (isinstance(r["location"], str) and _LOCATION_RE.match(r["location"])):
            problems.append(f"location {r['location']!r} is not L<a> or L<a>-L<b>")
        for value, allowed, name in ((r["source_support"], SOURCE_SUPPORT, "source_support"),
                                     (r["semantic_distance"], SEMANTIC_DISTANCE, "semantic_distance")):
            msg = _enum(value, allowed, name)
            if msg:
                problems.append(msg)
        if "drift_type" in r and (msg := _enum(r["drift_type"], DRIFT_TYPES, "drift_type")):
            problems.append(msg)
        if "evidence" in r and not isinstance(r["evidence"], str):
            problems.append("evidence must be a string")
        loc = r.get("source_locator")
        if loc is not None:
            if not isinstance(loc, dict):
                problems.append("source_locator must be an object")
            else:
                if msg := _enum(loc.get("type"), LOCATOR_TYPES, "source_locator.type"):
                    problems.append(msg)
                if not (isinstance(loc.get("ref"), str) and loc["ref"].strip()):
                    problems.append("source_locator.ref must be a non-empty string")
                if "path" in loc and not (isinstance(loc["path"], str) and loc["path"].strip()):
                    problems.append("source_locator.path must be a non-empty string")
    elif kind == "relation":
        for key in ("source_relation", "rendered_relation"):
            if msg := _enum(r[key], RELATIONS, key):
                problems.append(msg)
    elif kind == "logic":
        if msg := _enum(r["drift_type"], DRIFT_TYPES, "drift_type"):
            problems.append(msg)
    return problems


def _read_source(path: Path, cache: dict) -> str | None:
    if path not in cache:
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            cache[path] = None
        else:
            if path.suffix.lower() == ".srt":
                text = strip_srt(text)
            cache[path] = normalize(text)
    return cache[path]


def check(records, document: str, base_dir: Path):
    """Return (errors, warnings, summary).

    errors/warnings: lists of (code, line, message); the line is the record's
    line in the jsonl, except T7 which names the document line.
    summary: {source_type: [checked_by_T4, not_machine_checked]}.
    """
    errors, warnings = [], []
    summary: dict[str, list[int]] = {}
    doc_lines = document.splitlines()
    doc_norm = normalize(document)
    sources: dict[Path, str | None] = {}
    valid = []
    for lineno, r, parse_error in records:
        if parse_error is not None:
            errors.append(("T1", lineno, parse_error))
            continue
        problems = _shape_problems(r)
        errors.extend(("T1", lineno, p) for p in problems)
        if not problems:
            valid.append((lineno, r))

    claim_ids = {r["id"] for _, r in valid if r["kind"] == "claim"}
    for lineno, r in valid:
        if r["kind"] == "relation":
            pair = r["pair"]
            if not (isinstance(pair, list) and len(pair) == 2 and pair[0] != pair[1]
                    and all(p in claim_ids for p in pair)):
                errors.append(("T6", lineno, f"pair {pair!r} is not two distinct claim ids in this file"))
            continue
        if r["kind"] == "logic":
            if r["target"] not in claim_ids:
                errors.append(("T6", lineno, f"target {r['target']!r} is not a claim id in this file"))
            continue

        text = normalize(r["text"])
        if text not in doc_norm:
            errors.append(("T2", lineno, "text not found in the checked document"))
        else:
            m = _LOCATION_RE.match(r["location"])
            start, end = int(m.group(1)), int(m.group(2) or m.group(1))
            if text not in normalize("\n".join(doc_lines[start - 1:end])):
                warnings.append(("T3", lineno, f"text is not within {r['location']} "
                                 f"of the checked document (location drift)"))

        evidence = r.get("evidence") or ""
        loc = r.get("source_locator")
        if r["source_support"] == "attested" and (not evidence.strip() or loc is None):
            errors.append(("T5", lineno, "attested claim needs non-empty evidence and a source_locator"))
        if loc is None:
            continue
        counts = summary.setdefault(loc["type"], [0, 0])
        if "path" not in loc or not evidence.strip():
            counts[1] += 1
            continue
        counts[0] += 1
        source = _read_source(base_dir / loc["path"], sources)
        if source is None:
            errors.append(("T4", lineno, f"source file {loc['path']!r} cannot be read"))
        elif normalize(evidence) not in source:
            errors.append(("T4", lineno, f"evidence not found in source {loc['path']!r}"))

    for n, line in enumerate(doc_lines, 1):
        body = _strip_percent_comment(line)
        hits = [p for p in FAILURE_PHRASES if p in body]
        if hits:
            warnings.append(("T7", n, f"verification-failure phrase in the document text "
                             f"({', '.join(hits)}); say what the reader should do instead"))
    return errors, warnings, summary


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--records", required=True, type=Path, help="tschema.jsonl")
    ap.add_argument("--document", required=True, type=Path, help="the checked document")
    args = ap.parse_args(argv)
    try:
        records = load_records(args.records)
        document = args.document.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"✗ cannot read input: {exc}", file=sys.stderr)
        return 2

    errors, warnings, summary = check(records, document, args.records.parent)
    print(f"Records:  {args.records} ({len(records)} line(s))")
    print(f"Document: {args.document}")
    for code, lineno, msg in errors + warnings:
        print(f"[{code}] L{lineno}: {msg}")
    print("Source coverage (per type; never merged):")
    if not summary:
        print("  (no claim names a source)")
    for source_type, (checked, unchecked) in sorted(summary.items()):
        print(f"  {source_type}: {checked} checked against the source, "
              f"{unchecked} not machine-checked")
    if errors:
        print(f"=== {len(errors)} ERROR(s) ===")
        return 1
    print("✓ ALL TSCHEMA CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
