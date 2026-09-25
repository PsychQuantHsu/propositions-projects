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
whitespace on both sides (CJK sentences wrap mid-line). `.srt` sources have
timing lines, and the cue number directly above each, removed first. T4 also
fails evidence shorter than MIN_EVIDENCE_CHARS, a source path that is absolute
or leaves the records directory, and a named source file with no evidence.
Claims that cannot be checked (no local `path`, or no source at all) are counted
per source type, never passed. T7 strips `%` comments only in `.tex` documents.

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
MIN_EVIDENCE_CHARS = 4          # shorter quotes match almost any source by chance
MAX_SOURCE_BYTES = 50 * 1024 * 1024
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
    """Subtitle text only: drop `-->` timing lines and the cue number above each.

    A digits-only line is a cue number only when the NEXT line is a timing
    line. Judging by `isdigit()` alone would also delete spoken numbers (a year,
    an amount) that sit on their own subtitle line — and a quote with that
    number removed would then pass T4.
    """
    lines = text.splitlines()
    keep = []
    for i, line in enumerate(lines):
        if _SRT_TIMING_RE.match(line):
            continue
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        if line.strip().isdigit() and _SRT_TIMING_RE.match(nxt):
            continue
        keep.append(line)
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
    for lineno, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
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
        m = _LOCATION_RE.match(r["location"]) if isinstance(r["location"], str) else None
        if not m or int(m.group(1)) < 1 or int(m.group(2) or m.group(1)) < int(m.group(1)):
            problems.append(f"location {r['location']!r} is not L<a> or L<a>-L<b> with 1 <= a <= b")
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
                if "path" in loc:
                    path = loc["path"]
                    if not (isinstance(path, str) and path.strip()):
                        problems.append("source_locator.path must be a non-empty string")
                    elif Path(path).is_absolute() or ".." in Path(path).parts:
                        problems.append(f"source_locator.path {path!r} must be relative to "
                                        f"tschema.jsonl and stay inside its directory")
    elif kind == "relation":
        pair = r["pair"]
        if not (isinstance(pair, list) and len(pair) == 2 and all(isinstance(x, str) for x in pair)):
            problems.append("pair must be a list of two claim-id strings")
        for key in ("source_relation", "rendered_relation"):
            if msg := _enum(r[key], RELATIONS, key):
                problems.append(msg)
    elif kind == "logic":
        if not isinstance(r["target"], str):
            problems.append("target must be a claim-id string")
        if msg := _enum(r["drift_type"], DRIFT_TYPES, "drift_type"):
            problems.append(msg)
    return problems


def _read_source(path: Path, base_dir: Path, cache: dict) -> str | None:
    if path not in cache:
        try:
            resolved = path.resolve()
            if not resolved.is_relative_to(base_dir.resolve()):
                raise OSError("resolves outside the records directory")
            if not resolved.is_file() or resolved.stat().st_size > MAX_SOURCE_BYTES:
                raise OSError("not a regular file within the size limit")
            text = resolved.read_text(encoding="utf-8-sig")
        except (OSError, UnicodeDecodeError):
            cache[path] = None
        else:
            if path.suffix.lower() == ".srt":
                text = strip_srt(text)
            cache[path] = normalize(text)
    return cache[path]


def check(records, document: str, base_dir: Path, latex: bool = False):
    """Return (errors, warnings, summary).

    errors/warnings: lists of (code, line, message); the line is the record's
    line in the jsonl, except T7 which names the document line.
    summary: {source_type: {"checked": n, "no path": n, "no evidence": n}};
    claims naming no source are counted under "(no source named)".
    ``latex`` turns on `%` line-comment stripping for T7 (only .tex documents).
    """
    errors, warnings = [], []
    summary: dict[str, dict[str, int]] = {}
    doc_lines = document.splitlines()
    doc_norm = normalize(document)
    sources: dict[Path, str | None] = {}
    valid, seen_ids = [], {}
    for lineno, r, parse_error in records:
        if parse_error is not None:
            errors.append(("T1", lineno, parse_error))
            continue
        problems = _shape_problems(r)
        if not problems and r["id"] in seen_ids:
            problems.append(f"id {r['id']!r} already used on line {seen_ids[r['id']]}")
        errors.extend(("T1", lineno, p) for p in problems)
        if not problems:
            seen_ids[r["id"]] = lineno
            valid.append((lineno, r))

    claim_ids = {r["id"] for _, r in valid if r["kind"] == "claim"}
    for lineno, r in valid:
        if r["kind"] == "relation":
            pair = r["pair"]
            if not (pair[0] != pair[1] and all(p in claim_ids for p in pair)):
                errors.append(("T6", lineno, f"pair {pair!r} is not two distinct claim ids in this file"))
            continue
        if r["kind"] == "logic":
            if r["target"] not in claim_ids:
                errors.append(("T6", lineno, f"target {r['target']!r} is not a claim id in this file"))
            continue

        text = normalize(r["text"])
        m = _LOCATION_RE.match(r["location"])
        start, end = int(m.group(1)), int(m.group(2) or m.group(1))
        if text not in doc_norm:
            errors.append(("T2", lineno, "text not found in the checked document"))
        elif end > len(doc_lines):
            warnings.append(("T3", lineno, f"{r['location']} is beyond the end of the checked "
                             f"document ({len(doc_lines)} lines)"))
        elif text not in normalize("\n".join(doc_lines[start - 1:end])):
            warnings.append(("T3", lineno, f"text is not within {r['location']} "
                             f"of the checked document (location drift)"))

        evidence = r.get("evidence") or ""
        loc = r.get("source_locator")
        if r["source_support"] == "attested" and (not evidence.strip() or loc is None):
            errors.append(("T5", lineno, "attested claim needs non-empty evidence and a source_locator"))
        if loc is None:
            bucket = summary.setdefault("(no source named)", {"checked": 0, "no path": 0, "no evidence": 0})
            bucket["no path"] += 1
            continue
        bucket = summary.setdefault(loc["type"], {"checked": 0, "no path": 0, "no evidence": 0})
        if "path" not in loc:
            bucket["no path"] += 1
            continue
        if not evidence.strip():
            bucket["no evidence"] += 1
            errors.append(("T4", lineno, f"names source file {loc['path']!r} but quotes no evidence to check"))
            continue
        bucket["checked"] += 1
        if len(normalize(evidence)) < MIN_EVIDENCE_CHARS:
            errors.append(("T4", lineno, f"evidence is shorter than {MIN_EVIDENCE_CHARS} characters, "
                           f"too short to show it came from the source"))
            continue
        source = _read_source(base_dir / loc["path"], base_dir, sources)
        if source is None:
            errors.append(("T4", lineno, f"source file {loc['path']!r} cannot be read (missing, outside "
                           f"the records directory, not a regular file, or over the size limit)"))
        elif normalize(evidence) not in source:
            errors.append(("T4", lineno, f"evidence not found in source {loc['path']!r}"))

    for n, line in enumerate(doc_lines, 1):
        body = _strip_percent_comment(line) if latex else line
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
        document = args.document.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"✗ cannot read input: {exc}", file=sys.stderr)
        return 2

    errors, warnings, summary = check(records, document, args.records.parent,
                                      latex=args.document.suffix.lower() == ".tex")
    print(f"Records:  {args.records} ({len(records)} line(s))")
    print(f"Document: {args.document}")
    for code, lineno, msg in errors + warnings:
        print(f"[{code}] L{lineno}: {msg}")
    print("Source coverage (per type; never merged):")
    if not summary:
        print("  (no claim names a source)")
    for source_type, c in sorted(summary.items()):
        unchecked = c["no path"] + c["no evidence"]
        print(f"  {source_type}: {c['checked']} checked against the source, "
              f"{unchecked} not machine-checked "
              f"({c['no path']} no local path, {c['no evidence']} no evidence)")
    if errors:
        print(f"=== {len(errors)} ERROR(s) ===")
        return 1
    print("✓ ALL TSCHEMA CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
