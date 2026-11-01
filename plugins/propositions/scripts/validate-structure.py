#!/usr/bin/env python3
"""validate-structure.py — check a ledger's article-structure sidecars.

The propositions ledger (`main.jsonl`) says what each proposition claims. The
structure sidecars say how the article is built: `structure.json` holds the
section plan and the thesis, `discourse.jsonl` holds one record per proposition
with its relation to the previous proposition and the commitments it opens and
discharges. Format and vocabularies: `plugins/propositions/docs/STRUCTURE.md`.
`validate-propositions.py` does not read these files.

Rules:
    S1  discourse.jsonl has exactly one record per non-retired ledger
        proposition, in ledger order (missing / extra / duplicate / out of order)
    S2  `relation` is one of the twelve values; `start` exactly once, first;
        `return` carries `refers_to` naming an earlier proposition; no other
        relation carries `refers_to`
    S3  commitment ids well-formed and unique, kinds among the seven; every
        discharge names a commitment opened by a strictly earlier record;
        `future_work` is never discharged
    S4  every question / aim / hypothesis / plan / announcement is discharged
        (error), every setup is discharged (warning); with --partial both are
        reported as information only; future_work is never reported
    S5  structure.json: structure_version, non-empty thesis of non-retired
        propositions, sections with unique ids, one of the nine roles, and
        first_prop values that start at the first proposition and strictly
        increase in ledger order
    S6  an announcement is first discharged in the section that opened it or
        the next one (warning only)

Usage:
    python3 validate-structure.py --jsonl main.jsonl [--structure structure.json]
        [--discourse discourse.jsonl] [--partial] [--format text|json]

Exit code:
    0 — no rule fails (warnings and information allowed)
    1 — at least one rule fails
    2 — an input file is missing, unreadable or not valid JSON
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

RELATIONS = (
    "start", "shift", "continue", "restatement", "specification", "instance",
    "addition", "contrast", "reason", "consequence", "sequence", "return",
)
KINDS = ("question", "aim", "hypothesis", "plan", "announcement", "setup", "future_work")
ROLES = (
    "introduction", "background", "formal_setup", "method", "results",
    "proofs", "discussion", "conclusion", "appendix",
)
MUST_KEEP = ("question", "aim", "hypothesis", "plan", "announcement")
STRUCTURE_VERSIONS = ("1.0",)
COMMITMENT_ID = re.compile(r"[a-z0-9][a-z0-9-]{0,63}")
RULES = (
    ("S1", "records-cover-ledger"),
    ("S2", "relations-closed"),
    ("S3", "commitments-opened-first"),
    ("S4", "commitments-kept"),
    ("S5", "section-plan"),
    ("S6", "announcements-nearby"),
)
EXIT_OK, EXIT_FAIL, EXIT_USAGE = 0, 1, 2


class InputError(Exception):
    """A file is missing, unreadable or not valid JSON; exit 2."""


def vocab(values: tuple[str, ...]) -> str:
    return "{" + ", ".join(values) + "}"


# ---------- loading ----------


def load_ledger(path: Path) -> tuple[list[str], set[str]]:
    """(non-retired ids in ledger order, every id) via validate-propositions' loader."""
    if not path.is_file():
        raise InputError(f"ledger not found: {path}")
    spec = importlib.util.spec_from_file_location(
        "validate_propositions", Path(__file__).parent / "validate-propositions.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    try:
        _, props, _ = module.load_props_jsonl(path)
    except ValueError as exc:
        raise InputError(f"{path}: {exc}") from exc
    live = [p["id"] for p in props if "retired" not in p]
    return live, {p["id"] for p in props}


def load_discourse(path: Path) -> list[tuple[int, dict]]:
    if not path.is_file():
        raise InputError(f"discourse sidecar not found: {path}")
    records = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise InputError(f"{path.name} line {lineno}: invalid JSON ({exc.msg})") from exc
        if not isinstance(obj, dict):
            raise InputError(f"{path.name} line {lineno}: not a JSON object")
        records.append((lineno, obj))
    return records


def load_structure(path: Path) -> dict:
    if not path.is_file():
        raise InputError(f"structure sidecar not found: {path}")
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise InputError(f"{path.name}: invalid JSON at line {exc.lineno} ({exc.msg})") from exc
    if not isinstance(obj, dict):
        raise InputError(f"{path.name}: not a JSON object")
    return obj


# ---------- report ----------


@dataclass
class Problem:
    severity: str  # error | warning | info
    message: str
    position: int | None = None
    prop_id: str | None = None
    line: int | None = None

    def where(self) -> str:
        if self.position is not None:
            return f"#{self.position} {self.prop_id}"
        return f"line {self.line}" if self.line is not None else "structure.json"


@dataclass
class Report:
    problems: dict[str, list[Problem]] = field(default_factory=lambda: {r: [] for r, _ in RULES})

    def add(self, rule: str, problem: Problem) -> None:
        self.problems[rule].append(problem)

    def status(self, rule: str) -> str:
        sev = {p.severity for p in self.problems[rule]}
        return "FAIL" if "error" in sev else "WARN" if "warning" in sev else "PASS"

    def failed(self) -> bool:
        return any(self.status(r) == "FAIL" for r, _ in RULES)


@dataclass(frozen=True)
class Record:
    index: int  # 0-based file order
    line: int
    data: dict
    position: int | None  # 1-based ledger position, None when not a live ledger id

    def problem(self, severity: str, message: str) -> Problem:
        pid = self.data.get("prop_id") if self.position is not None else None
        return Problem(severity, message, self.position, pid, self.line)

    def where(self) -> str:
        return self.problem("info", "").where()


# ---------- S1 ----------


def check_s1(records: list[Record], live: list[str], report: Report) -> None:
    seen: dict[str, int] = {}
    last_position = 0
    for rec in records:
        pid = rec.data.get("prop_id")
        if not isinstance(pid, str):
            report.add("S1", Problem("error", "record has no string `prop_id`", line=rec.line))
            continue
        if rec.position is None:
            report.add("S1", Problem("error", f"extra record for {pid}: not a non-retired ledger proposition", line=rec.line))
            continue
        if pid in seen:
            report.add("S1", rec.problem("error", f"duplicate record (also on line {seen[pid]})"))
            continue
        seen[pid] = rec.line
        if rec.position < last_position:
            report.add("S1", rec.problem("error", f"out of order: comes after #{last_position}"))
        last_position = max(last_position, rec.position)
    for pos, pid in enumerate(live, 1):
        if pid not in seen:
            report.add("S1", Problem("error", "missing record", pos, pid))


# ---------- S2 ----------


def check_s2(records: list[Record], positions: dict[str, int], report: Report) -> None:
    for rec in records:
        rel = rec.data.get("relation")
        if not isinstance(rel, str) or rel not in RELATIONS:
            report.add("S2", rec.problem("error", f"relation {rel!r} not in {vocab(RELATIONS)}"))
        elif rec.index == 0 and rel != "start":
            report.add("S2", rec.problem("error", "the first record must be `start`"))
        elif rec.index > 0 and rel == "start":
            report.add("S2", rec.problem("error", "`start` is allowed only on the first record"))
        target = rec.data.get("refers_to")
        if rel == "return":
            target_pos = positions.get(target) if isinstance(target, str) else None
            if target is None:
                report.add("S2", rec.problem("error", "`return` needs `refers_to`"))
            elif target_pos is None:
                report.add("S2", rec.problem("error", f"refers_to {target!r} is not a non-retired ledger proposition"))
            elif rec.position is not None and target_pos >= rec.position:
                report.add("S2", rec.problem("error", f"refers_to must name an earlier proposition (names #{target_pos})"))
        elif "refers_to" in rec.data:
            report.add("S2", rec.problem("error", "`refers_to` is allowed only with `return`"))


# ---------- S3 / S4 ----------


@dataclass
class Commitment:
    cid: str
    kind: str
    opened: Record
    discharged_by: list[Record] = field(default_factory=list)


def _opens(rec: Record, report: Report) -> list[tuple[str, str]]:
    raw = rec.data.get("opens", [])
    if not isinstance(raw, list):
        report.add("S3", rec.problem("error", "`opens` must be a list"))
        return []
    out = []
    for item in raw:
        cid = item.get("id") if isinstance(item, dict) else None
        kind = item.get("kind") if isinstance(item, dict) else None
        if not isinstance(cid, str) or not COMMITMENT_ID.fullmatch(cid):
            report.add("S3", rec.problem("error", f"commitment id {cid!r} does not match ^[a-z0-9][a-z0-9-]{{0,63}}$"))
        elif not isinstance(kind, str) or kind not in KINDS:
            report.add("S3", rec.problem("error", f"commitment `{cid}` kind {kind!r} not in {vocab(KINDS)}"))
        else:
            out.append((cid, kind))
    return out


def _discharges(rec: Record, report: Report) -> list[str]:
    raw = rec.data.get("discharges", [])
    if not isinstance(raw, list) or not all(isinstance(x, str) for x in raw):
        report.add("S3", rec.problem("error", "`discharges` must be a list of commitment ids"))
        return []
    return raw


def check_s3(records: list[Record], report: Report) -> dict[str, Commitment]:
    opened: dict[str, Commitment] = {}
    planned: list[tuple[Record, list[tuple[str, str]]]] = [(rec, _opens(rec, report)) for rec in records]
    first_opening = {}
    for rec, items in planned:
        for cid, _ in items:
            first_opening.setdefault(cid, rec)
    for rec, items in planned:
        own = {cid for cid, _ in items}
        for cid in _discharges(rec, report):
            if cid in own:
                report.add("S3", rec.problem("error", f"a proposition cannot discharge its own commitment `{cid}`"))
            elif cid in opened:
                if opened[cid].kind == "future_work":
                    report.add("S3", rec.problem("error", f"`{cid}` is future_work and must never be discharged"))
                else:
                    opened[cid].discharged_by.append(rec)
            elif cid in first_opening:
                report.add("S3", rec.problem("error", f"discharges `{cid}` before it is opened (opened at {first_opening[cid].where()})"))
            else:
                report.add("S3", rec.problem("error", f"discharges `{cid}`, which no record opens"))
        for cid, kind in items:
            if cid in opened:
                report.add("S3", rec.problem("error", f"duplicate commitment id `{cid}`"))
            else:
                opened[cid] = Commitment(cid, kind, rec)
    return opened


def check_s4(commitments: dict[str, Commitment], partial: bool, report: Report) -> None:
    for c in commitments.values():
        if c.discharged_by or c.kind == "future_work":
            continue
        message = f"`{c.cid}` ({c.kind}) opened here was never discharged"
        if partial:
            report.add("S4", c.opened.problem("info", f"open: `{c.cid}` ({c.kind})"))
        elif c.kind in MUST_KEEP:
            report.add("S4", c.opened.problem("error", message))
        else:  # setup
            report.add("S4", c.opened.problem("warning", message))


# ---------- S5 / S6 ----------


def check_s5(structure: dict, positions: dict[str, int], report: Report, partial: bool = False) -> list[tuple[str, int]]:
    """Validate the plan; return [(section id, first position)] when the section list is usable, else [].

    Errors in `thesis` or `structure_version` fail S5 but do not make a valid
    section list unusable for S6 and the state query. With `partial`, an empty
    thesis is information: a draft often has not stated its thesis yet.
    """
    sections_ok = True

    def err(message: str, about_sections: bool = False) -> None:
        nonlocal sections_ok
        if about_sections:
            sections_ok = False
        report.add("S5", Problem("error", message))

    version = structure.get("structure_version")
    if version not in STRUCTURE_VERSIONS:
        err(f"structure_version {version!r} not in {vocab(STRUCTURE_VERSIONS)}")
    thesis = structure.get("thesis")
    if thesis == [] and partial:
        report.add("S5", Problem("info", "thesis not stated yet (empty list)"))
    elif not isinstance(thesis, list) or not thesis:
        err("thesis must be a non-empty list of proposition ids")
    else:
        for tid in thesis:
            if not isinstance(tid, str) or tid not in positions:
                err(f"thesis entry {tid!r} is not a non-retired ledger proposition")
    sections = structure.get("sections")
    if not isinstance(sections, list) or not sections:
        err("sections must be a non-empty list", about_sections=True)
        return []
    plan: list[tuple[str, int]] = []
    ids: set[str] = set()
    for i, sec in enumerate(sections, 1):
        if not isinstance(sec, dict):
            err(f"section {i} is not an object", about_sections=True)
            continue
        sid, heading, role, first = sec.get("id"), sec.get("heading"), sec.get("role"), sec.get("first_prop")
        if not isinstance(sid, str) or not sid:
            err(f"section {i} has no string `id`", about_sections=True)
            continue
        if sid in ids:
            err(f"duplicate section id `{sid}`", about_sections=True)
        ids.add(sid)
        if not isinstance(heading, str) or not heading.strip():
            err(f"section `{sid}` has no heading", about_sections=True)
        if not isinstance(role, str) or role not in ROLES:
            err(f"section `{sid}` role {role!r} not in {vocab(ROLES)}", about_sections=True)
        if not isinstance(first, str) or first not in positions:
            err(f"section `{sid}` first_prop {first!r} is not a non-retired ledger proposition", about_sections=True)
            continue
        plan.append((sid, positions[first]))
    for (prev_id, prev_pos), (sid, pos) in zip(plan, plan[1:]):
        if pos <= prev_pos:
            err(f"sections `{prev_id}` (#{prev_pos}) and `{sid}` (#{pos}) are out of ledger order", about_sections=True)
    if not positions:
        err("the ledger has no non-retired propositions", about_sections=True)
    elif plan and plan[0][1] != 1:
        err(f"the first section `{plan[0][0]}` starts at #{plan[0][1]}, not at the first proposition", about_sections=True)
    return plan if sections_ok else []


def section_index(plan: list[tuple[str, int]], position: int) -> int:
    idx = 0
    for i, (_, first) in enumerate(plan):
        if first <= position:
            idx = i
    return idx


def check_s6(commitments: dict[str, Commitment], plan: list[tuple[str, int]], report: Report) -> None:
    if not plan:
        report.add("S6", Problem("warning", "not evaluated: the section plan is invalid (see S5)"))
        return
    for c in commitments.values():
        if c.kind != "announcement" or not c.discharged_by:
            continue
        first = min(c.discharged_by, key=lambda r: r.index)
        if c.opened.position is None or first.position is None:
            continue
        opened_in = section_index(plan, c.opened.position)
        kept_in = section_index(plan, first.position)
        if kept_in not in (opened_in, opened_in + 1):
            report.add("S6", c.opened.problem(
                "warning",
                f"announcement `{c.cid}` opened in `{plan[opened_in][0]}` is first kept in `{plan[kept_in][0]}` (#{first.position})",
            ))


# ---------- driver ----------


def validate(ledger: Path, structure_path: Path, discourse_path: Path, partial: bool) -> Report:
    live, _ = load_ledger(ledger)
    raw_records = load_discourse(discourse_path)
    structure = load_structure(structure_path)
    positions = {pid: i for i, pid in enumerate(live, 1)}
    records = [
        Record(i, line, data, positions.get(data.get("prop_id")) if isinstance(data.get("prop_id"), str) else None)
        for i, (line, data) in enumerate(raw_records)
    ]
    report = Report()
    check_s1(records, live, report)
    check_s2(records, positions, report)
    commitments = check_s3(records, report)
    check_s4(commitments, partial, report)
    plan = check_s5(structure, positions, report, partial)
    check_s6(commitments, plan, report)
    return report


def render_text(report: Report) -> str:
    out = []
    for rule, name in RULES:
        problems = report.problems[rule]
        counted = [p for p in problems if p.severity != "info"]
        suffix = f" ({len(counted)} problem(s))" if counted else ""
        out.append(f"[{report.status(rule)}] {rule} {name}{suffix}")
        for p in problems:
            if p.severity == "info":
                out.append(f"  [INFO] {rule} {p.where()}: {p.message}")
            else:
                tag = " (warning)" if p.severity == "warning" else ""
                out.append(f"  [{rule}] {p.where()}: {p.message}{tag}")
    errors = sum(1 for ps in report.problems.values() for p in ps if p.severity == "error")
    warnings = sum(1 for ps in report.problems.values() for p in ps if p.severity == "warning")
    out.append(f"{'FAIL' if report.failed() else 'OK'}: {errors} error(s), {warnings} warning(s)")
    return "\n".join(out) + "\n"


def render_json(report: Report, ledger: Path, partial: bool) -> str:
    rules = [
        {
            "rule": rule,
            "name": name,
            "status": report.status(rule),
            "problems": [
                {"severity": p.severity, "position": p.position, "prop_id": p.prop_id, "line": p.line, "message": p.message}
                for p in report.problems[rule]
            ],
        }
        for rule, name in RULES
    ]
    return json.dumps({"ledger": str(ledger), "partial": partial, "rules": rules}, ensure_ascii=False, indent=1) + "\n"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Check a ledger's article-structure sidecars (S1-S6).")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    p.add_argument("--structure", type=Path, help="structure.json (default: beside the ledger)")
    p.add_argument("--discourse", type=Path, help="discourse.jsonl (default: beside the ledger)")
    p.add_argument("--partial", action="store_true", help="unfinished draft: report open commitments as information")
    p.add_argument("--format", choices=("text", "json"), default="text")
    args = p.parse_args(argv)
    structure = args.structure or args.jsonl.parent / "structure.json"
    discourse = args.discourse or args.jsonl.parent / "discourse.jsonl"
    try:
        report = validate(args.jsonl, structure, discourse, args.partial)
    except InputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    text = render_json(report, args.jsonl, args.partial) if args.format == "json" else render_text(report)
    print(text, end="")
    return EXIT_FAIL if report.failed() else EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
