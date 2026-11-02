#!/usr/bin/env python3
"""migrate-structure-v2.py — turn version 1.0 structure sidecars into version 2.0.

Spectra change add-discourse-dependency-tree. Version 1.0 recorded one relation
per proposition to the previous proposition (plus `refers_to` for `return`);
version 2.0 records a dependency tree (see `plugins/propositions/docs/STRUCTURE.md`).
The validator refuses 1.0, so existing sidecars go through this tool once.

The migration is mechanical and gives a starting point, not a finished
annotation:
  - paragraphs are derived from the TeX source as derive-paragraphs.py does;
  - the first record of each paragraph becomes its root; every other record gets
    the previous record as its head, keeping its 1.0 relation when that is one of
    the ten 2.0 relations and `continue` otherwise; `refers_to` is dropped;
  - the first paragraph of each section is the section's root paragraph; every
    other paragraph gets the previous paragraph as its head, with the 1.0
    relation of its first record when that is one of the ten, `continue` otherwise;
  - each section's `parent` comes from the sectioning command level in the TeX
    source (\\chapter, \\section, \\subsection, \\subsubsection).
The review report (`migration-review.json` in --out-dir) lists every record
whose 1.0 relation was start, shift or return, every paragraph whose relation
was replaced by `continue`, every relation dropped at a section's first
paragraph, and every section whose parent could not be determined.

It writes only into --out-dir: never `main.jsonl`, never the 1.0 sidecars.

Usage:
    python3 migrate-structure-v2.py --jsonl main.jsonl --tex main.tex --out-dir DIR

Exit code:
    0 — 2.0 sidecars and review report written
    2 — an input is missing or invalid, the sidecars are not version 1.0,
        --out-dir is the ledger's directory, or --out-dir already holds sidecars
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.latex_env_parser import parse_location_v16  # noqa: E402

RELATIONS_V2 = (
    "continue", "restatement", "specification", "instance", "addition",
    "contrast", "reason", "consequence", "sequence", "basis",
)
LEVELS = {"chapter": 0, "section": 1, "subsection": 2, "subsubsection": 3}
HEADING = re.compile(r"\\(chapter|section|subsection|subsubsection)\*?\s*[\[{]")
OUTPUTS = ("structure.json", "discourse.jsonl", "migration-review.json")
EXIT_OK, EXIT_USAGE = 0, 2


class InputError(Exception):
    """Exit 2."""


def _derive_module():
    spec = importlib.util.spec_from_file_location("derive_paragraphs", Path(__file__).parent / "derive-paragraphs.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _read_json(path: Path) -> dict:
    if not path.is_file():
        raise InputError(f"not found: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise InputError(f"{path.name}: invalid JSON ({exc.msg})") from exc


def _read_jsonl(path: Path) -> list[dict]:
    if not path.is_file():
        raise InputError(f"not found: {path}")
    out = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if raw.strip():
            try:
                out.append(json.loads(raw))
            except json.JSONDecodeError as exc:
                raise InputError(f"{path.name} line {lineno}: invalid JSON ({exc.msg})") from exc
    return out


def _headings(tex: Path) -> list[tuple[int, int, str]]:
    """(line, level, command) for every sectioning command in the TeX file."""
    found = []
    for lineno, line in enumerate(tex.read_text(encoding="utf-8").splitlines(), 1):
        m = HEADING.search(line.split("%", 1)[0])
        if m:
            found.append((lineno, LEVELS[m.group(1)], m.group(1)))
    return found


def _section_parents(sections: list[dict], starts: dict[str, int], tex: Path, review: list[dict]) -> dict[str, str | None]:
    """Parent section id per section id, from the TeX heading levels."""
    headings = _headings(tex)
    heading_of: dict[str, int] = {}
    for sec in sections:
        line = starts.get(sec["first_prop"])
        before = [i for i, (hline, _, _) in enumerate(headings) if line is not None and hline <= line]
        if before:
            heading_of[sec["id"]] = before[-1]
    owner = {index: sid for sid, index in heading_of.items()}
    parents: dict[str, str | None] = {}
    for sec in sections:
        sid = sec["id"]
        if sid not in heading_of:
            parents[sid] = None
            review.append({"kind": "section", "id": sid, "reason": "no sectioning command found before its first proposition; parent could not be determined (left top-level)"})
            continue
        index = heading_of[sid]
        level = headings[index][1]
        enclosing = next((i for i in range(index - 1, -1, -1) if headings[i][1] < level), None)
        if enclosing is None:
            parents[sid] = None
        elif enclosing in owner:
            parents[sid] = owner[enclosing]
        else:
            parents[sid] = None
            review.append({"kind": "section", "id": sid,
                           "reason": f"the enclosing \\{headings[enclosing][2]} on line {headings[enclosing][0]} has no section entry; parent could not be determined (left top-level)"})
    return parents


def migrate(ledger: Path, tex: Path, out_dir: Path) -> list[dict]:
    source_dir = ledger.parent
    if out_dir.resolve() == source_dir.resolve():
        raise InputError("--out-dir is the ledger's directory; the 1.0 sidecars must not be overwritten — choose another directory")
    structure = _read_json(source_dir / "structure.json")
    if structure.get("structure_version") != "1.0":
        raise InputError(f"structure.json has structure_version {structure.get('structure_version')!r}; only version 1.0 is migrated")
    existing = [name for name in OUTPUTS if (out_dir / name).exists()]
    if existing:
        raise InputError(f"{out_dir} already holds {', '.join(existing)}; remove them or choose another --out-dir")
    old_records = _read_jsonl(source_dir / "discourse.jsonl")
    props = [p for p in _read_jsonl(ledger) if "retired" not in p]
    position = {p["id"]: n for n, p in enumerate(props, 1)}
    starts = {}
    for p in props:
        parsed = parse_location_v16(p.get("location", ""))
        if parsed:
            starts[p["id"]] = parsed[1]
    try:
        paragraphs = _derive_module().derive(ledger, tex, source_dir / "structure.json")
    except Exception as exc:  # derive-paragraphs' own InputError
        raise InputError(str(exc)) from exc
    paragraph_firsts = {p["first_prop"]: p["id"] for p in paragraphs}
    sections = structure.get("sections", [])
    section_firsts = {s.get("first_prop") for s in sections}

    review: list[dict] = []
    records: list[dict] = []
    previous_id = None
    first_relation: dict[str, str | None] = {}
    for old in old_records:
        pid = old.get("prop_id")
        rel = old.get("relation")
        rec = {k: v for k, v in old.items() if k not in ("relation", "refers_to")}
        if rel in ("start", "shift", "return"):
            item = {"kind": "record", "position": position.get(pid), "prop_id": pid, "original_relation": rel}
            if "refers_to" in old:
                item["refers_to"] = old["refers_to"]
            review.append(item)
        if pid in paragraph_firsts:
            first_relation[paragraph_firsts[pid]] = rel
        else:
            rec = {"prop_id": pid, "head": previous_id, "relation": rel if rel in RELATIONS_V2 else "continue",
                   **{k: v for k, v in rec.items() if k != "prop_id"}}
        records.append(rec)
        previous_id = pid

    new_paragraphs = []
    for i, par in enumerate(paragraphs):
        entry = {"id": par["id"], "first_prop": par["first_prop"]}
        rel = first_relation.get(par["id"])
        if par["first_prop"] in section_firsts or i == 0:
            if rel in RELATIONS_V2:
                review.append({"kind": "paragraph", "id": par["id"],
                               "reason": f"first paragraph of a section; its 1.0 relation `{rel}` to the previous section was dropped"})
        else:
            entry["head"] = paragraphs[i - 1]["id"]
            entry["relation"] = rel if rel in RELATIONS_V2 else "continue"
            if rel not in RELATIONS_V2:
                review.append({"kind": "paragraph", "id": par["id"], "reason": f"relation replaced by `continue` (1.0 relation `{rel}`)"})
        new_paragraphs.append(entry)

    parents = _section_parents(sections, starts, tex, review)
    new_sections = []
    for sec in sections:
        entry = {k: sec[k] for k in ("id", "heading", "role", "first_prop") if k in sec}
        if parents.get(sec.get("id")):
            entry["parent"] = parents[sec["id"]]
        new_sections.append(entry)
    new_structure = {"structure_version": "2.0", "thesis": structure.get("thesis", []),
                     "sections": new_sections, "paragraphs": new_paragraphs}

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "structure.json").write_text(json.dumps(new_structure, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (out_dir / "discourse.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in records), encoding="utf-8")
    (out_dir / "migration-review.json").write_text(json.dumps({"items": review}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return review


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Migrate version 1.0 structure sidecars to version 2.0.")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl); the 1.0 sidecars sit beside it")
    p.add_argument("--tex", type=Path, required=True, help="the manuscript's main .tex file")
    p.add_argument("--out-dir", type=Path, required=True, help="directory for the 2.0 sidecars and migration-review.json")
    args = p.parse_args(argv)
    try:
        review = migrate(args.jsonl, args.tex, args.out_dir)
    except InputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    kinds = {k: sum(1 for i in review if i["kind"] == k) for k in ("record", "paragraph", "section")}
    print(f"wrote {args.out_dir}/structure.json, discourse.jsonl and migration-review.json")
    print(f"review: {kinds['record']} record(s), {kinds['paragraph']} paragraph(s), {kinds['section']} section(s)")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
