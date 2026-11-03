#!/usr/bin/env python3
"""validate-structure.py — check a ledger's article-structure sidecars (format 2.0).

The propositions ledger (`main.jsonl`) says what each proposition claims. The
structure sidecars say how the article is built: `structure.json` holds the
thesis, the section plan and the paragraph plan; `discourse.jsonl` holds one
record per proposition with its head inside the paragraph, its relation to that
head, and the commitments it opens and discharges. Format and vocabularies:
`plugins/propositions/docs/STRUCTURE.md`. `validate-propositions.py` does not
read these files.

Rules:
    S1  discourse.jsonl has exactly one record per non-retired ledger
        proposition, in ledger order (missing / extra / duplicate / out of order)
    S2  relations among the ten values, on records with a head and nowhere
        else; `refers_to` is gone; each paragraph is a dependency tree with one
        root, heads inside the paragraph and no cycle; `head: pending` only
        with --partial and only in the last paragraph; `also` entries valid
    S3  commitment ids well-formed and unique, kinds among the seven; every
        discharge names a commitment opened by a strictly earlier record;
        `future_work` is never discharged
    S4  every question / aim / hypothesis / plan / announcement is discharged
        (error), every setup is discharged (warning); with --partial both are
        reported as information only; future_work is never reported
    S5  structure.json: non-empty thesis, a section plan (unique ids, one of
        the ten roles, increasing first_prop, `parent` naming an earlier
        section, `abstract` only first and opening nothing) and a paragraph
        plan (increasing first_prop starting at the first proposition, no
        paragraph across a section boundary, one root paragraph per section,
        paragraph heads inside the section, no cycle)
    S6  an announcement is first discharged in the section that opened it or
        the next one (warning only)
    S7  crossing arcs, between records of one paragraph or paragraphs of one
        section (warning only)
    S8  a `basis` edge whose target the proposition does not cite in
        main.jsonl (warning only)
    S9  a record's `move` and a paragraph's `type`, both optional, are values of
        the vocabulary; no order of moves is ever reported

Usage:
    python3 validate-structure.py --jsonl main.jsonl [--structure structure.json]
        [--discourse discourse.jsonl] [--vocabulary vocabulary.yaml] [--partial]
        [--format text|json]

Exit code:
    0 — no rule fails (warnings and information allowed)
    1 — at least one rule fails
    2 — an input file is missing, unreadable or not valid JSON,
        structure_version is not "2.0" (version 1.0: run migrate-structure-v2.py),
        or moves or types are present and the vocabulary cannot be loaded
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.structure_io import (  # noqa: E402,F401  (re-exported for structure-state.py and structure-metrics.py)
    STRUCTURE_VERSION, InputError, Ledger, load_discourse, load_ledger, load_structure,
)
from _lib.move_vocabulary import load_vocabulary  # noqa: E402
from _lib.structure_tree import PENDING, crossing_pairs, unit_index  # noqa: E402

RELATIONS = (
    "continue", "restatement", "specification", "instance", "addition",
    "contrast", "reason", "consequence", "sequence", "basis",
)
KINDS = ("question", "aim", "hypothesis", "plan", "announcement", "setup", "future_work")
ROLES = (
    "abstract", "introduction", "background", "formal_setup", "method", "results",
    "proofs", "discussion", "conclusion", "appendix",
)
MUST_KEEP = ("question", "aim", "hypothesis", "plan", "announcement")
COMMITMENT_ID = re.compile(r"[a-z0-9][a-z0-9-]{0,63}")
RULES = (
    ("S1", "records-cover-ledger"),
    ("S2", "paragraph-trees"),
    ("S3", "commitments-opened-first"),
    ("S4", "commitments-kept"),
    ("S5", "section-and-paragraph-plan"),
    ("S6", "announcements-nearby"),
    ("S7", "crossing-arcs"),
    ("S8", "basis-cites"),
    ("S9", "moves-and-types"),
)
EXIT_OK, EXIT_FAIL, EXIT_USAGE = 0, 1, 2
MISSING = object()


def vocab(values: tuple[str, ...]) -> str:
    return "{" + ", ".join(values) + "}"


# ---------- report ----------


@dataclass
class Problem:
    severity: str  # error | warning | info
    message: str
    position: int | None = None
    prop_id: str | None = None
    line: int | None = None
    tag: str = ""  # "thesis" or "abstract": S5 problems that do not make the plan unusable

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

    def failed(self, rules: tuple[str, ...] | None = None) -> bool:
        return any(self.status(r) == "FAIL" for r in (rules or tuple(r for r, _ in RULES)))


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


@dataclass(frozen=True)
class Paragraph:
    pid: str
    first: int
    head: int | None  # index into the paragraph list, None for a section's root paragraph
    relation: str | None
    section: int | None  # index into the section plan, None when the plan is unusable


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


def _relation_problem(rel: object) -> str | None:
    if not isinstance(rel, str) or rel not in RELATIONS:
        return f"relation {rel!r} not in {vocab(RELATIONS)}"
    return None


def _check_also(rec: Record, positions: dict[str, int], head: object, report: Report) -> None:
    raw = rec.data.get("also")
    if raw is None:
        return
    if not isinstance(raw, list):
        report.add("S2", rec.problem("error", "`also` must be a list of {to, relation}"))
        return
    for entry in raw:
        to = entry.get("to") if isinstance(entry, dict) else None
        rel = entry.get("relation") if isinstance(entry, dict) else None
        if not isinstance(to, str) or to not in positions:
            report.add("S2", rec.problem("error", f"also target {to!r} is not a non-retired ledger proposition"))
        elif to == rec.data.get("prop_id"):
            report.add("S2", rec.problem("error", "an `also` entry names the record itself"))
        elif to == head:
            report.add("S2", rec.problem("error", "an `also` entry repeats the record's head"))
        problem = _relation_problem(rel)
        if problem:
            report.add("S2", rec.problem("error", f"also: {problem}"))


def head_map(records: list[Record], positions: dict[str, int], para_firsts: list[int]) -> dict[int, object]:
    """position -> head position (same paragraph), None (root) or PENDING; invalid heads are left out."""
    out: dict[int, object] = {}
    for rec in records:
        if rec.position is None:
            continue
        head = rec.data.get("head", MISSING)
        if head is MISSING:
            out[rec.position] = None
        elif head == PENDING:
            out[rec.position] = PENDING
        elif isinstance(head, str) and head in positions:
            hp = positions[head]
            if hp != rec.position and unit_index(para_firsts, hp) == unit_index(para_firsts, rec.position):
                out[rec.position] = hp
    return out


def check_s2(records: list[Record], positions: dict[str, int], paragraphs: list[Paragraph],
             partial: bool, report: Report) -> None:
    firsts = [p.first for p in paragraphs]
    last_paragraph = len(paragraphs) - 1
    for rec in records:
        if "refers_to" in rec.data:
            report.add("S2", rec.problem("error", "`refers_to` is not a version 2.0 field; use `head` (and `also`)"))
        head = rec.data.get("head", MISSING)
        rel = rec.data.get("relation", MISSING)
        here = unit_index(firsts, rec.position) if firsts and rec.position is not None else None
        if head is MISSING:
            if rel is not MISSING:
                report.add("S2", rec.problem("error", "a root (no head) carries no relation"))
        elif head == PENDING:
            if not partial:
                report.add("S2", rec.problem("error", "`head` is `pending`, which is allowed only with --partial"))
            elif here is not None and here != last_paragraph:
                report.add("S2", rec.problem("error", "`head: pending` is allowed only in the last paragraph"))
            if rel is not MISSING and _relation_problem(rel):
                report.add("S2", rec.problem("error", _relation_problem(rel)))
        else:
            hp = positions.get(head) if isinstance(head, str) else None
            if hp is None:
                report.add("S2", rec.problem("error", f"head {head!r} is not a non-retired ledger proposition or `pending`"))
            elif hp == rec.position:
                report.add("S2", rec.problem("error", "the record names itself as its head"))
            elif here is not None and unit_index(firsts, hp) != here:
                report.add("S2", rec.problem(
                    "error", f"head #{hp} is in paragraph `{paragraphs[unit_index(firsts, hp)].pid}`, "
                             f"not in this record's paragraph `{paragraphs[here].pid}`"))
            if rel is MISSING:
                report.add("S2", rec.problem("error", "a record with a head needs a relation"))
            elif _relation_problem(rel):
                report.add("S2", rec.problem("error", _relation_problem(rel)))
        _check_also(rec, positions, head, report)
    if not paragraphs:
        report.add("S2", Problem("warning", "paragraph trees not evaluated: the paragraph plan is invalid (see S5)"))
        return
    _check_trees(records, positions, paragraphs, partial, report)


def _check_trees(records: list[Record], positions: dict[str, int], paragraphs: list[Paragraph],
                 partial: bool, report: Report) -> None:
    firsts = [p.first for p in paragraphs]
    heads = head_map(records, positions, firsts)
    by_pos = {r.position: r for r in records if r.position is not None}
    roots: dict[int, list[int]] = {i: [] for i in range(len(paragraphs))}
    for pos, head in heads.items():
        if head is None:
            roots[unit_index(firsts, pos)].append(pos)
    for i, found in roots.items():
        last_partial = partial and i == len(paragraphs) - 1
        if len(found) == 1 or (last_partial and not found):
            continue
        listed = ", ".join(f"#{p}" for p in found) or "none"
        message = f"paragraph `{paragraphs[i].pid}` has {len(found)} roots ({listed}); exactly one record per paragraph has no head"
        target = by_pos.get(found[0]) if found else None
        report.add("S2", target.problem("error", message) if target else Problem("error", message))
    reported: set[frozenset[int]] = set()
    for start in heads:
        path: list[int] = []
        current = start
        while isinstance(current, int) and current not in path:
            path.append(current)
            current = heads.get(current)
        if isinstance(current, int):  # revisited: a cycle
            cycle = frozenset(path[path.index(current):])
            if cycle not in reported:
                reported.add(cycle)
                ordered = sorted(cycle)
                report.add("S2", by_pos[ordered[0]].problem(
                    "error", "heads form a cycle: " + " -> ".join(f"#{p}" for p in ordered + [ordered[0]])))


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


# ---------- S5: sections ----------


def check_s5(structure: dict, positions: dict[str, int], report: Report, partial: bool = False) -> list[tuple[str, int, str]]:
    """Validate thesis and section plan; return [(section id, first position, role)] when the section list is usable, else [].

    An error in `thesis` fails S5 but does not make a valid section list
    unusable for S6 and the state query. With `partial`, an empty thesis is
    information: a draft often has not stated its thesis yet.
    """
    sections_ok = True

    def err(message: str, about_sections: bool = False, tag: str = "") -> None:
        nonlocal sections_ok
        if about_sections:
            sections_ok = False
        report.add("S5", Problem("error", message, tag=tag))

    thesis = structure.get("thesis")
    if thesis == [] and partial:
        report.add("S5", Problem("info", "thesis not stated yet (empty list)", tag="thesis"))
    elif not isinstance(thesis, list) or not thesis:
        err("thesis must be a non-empty list of proposition ids", tag="thesis")
    else:
        for tid in thesis:
            if not isinstance(tid, str) or tid not in positions:
                err(f"thesis entry {tid!r} is not a non-retired ledger proposition", tag="thesis")
    sections = structure.get("sections")
    if not isinstance(sections, list) or not sections:
        err("sections must be a non-empty list", about_sections=True)
        return []
    plan: list[tuple[str, int, str]] = []
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
        plan.append((sid, positions[first], role))
        if role == "abstract" and i != 1:
            err(f"section `{sid}` has role `abstract` but is not the first section", about_sections=True)
    for (prev_id, prev_pos, _), (sid, pos, _) in zip(plan, plan[1:]):
        if pos <= prev_pos:
            err(f"sections `{prev_id}` (#{prev_pos}) and `{sid}` (#{pos}) are out of ledger order", about_sections=True)
    if not positions:
        err("the ledger has no non-retired propositions", about_sections=True)
    elif plan and plan[0][1] != 1:
        err(f"the first section `{plan[0][0]}` starts at #{plan[0][1]}, not at the first proposition", about_sections=True)
    return plan if sections_ok else []


def section_parents(structure: dict, plan: list[tuple[str, int, str]], report: Report) -> list[int | None]:
    """S5: each `parent` names an earlier section; return parent indices parallel to `plan`."""
    if not plan:
        return []
    index = {sid: i for i, (sid, _, _) in enumerate(plan)}
    parents: list[int | None] = []
    ok = True
    for sec in structure.get("sections", []):
        sid = sec.get("id") if isinstance(sec, dict) else None
        if sid not in index:
            continue
        parent = sec.get("parent", MISSING)
        if parent is MISSING:
            parents.append(None)
        elif isinstance(parent, str) and parent in index and index[parent] < index[sid]:
            parents.append(index[parent])
        else:
            ok = False
            parents.append(None)
            report.add("S5", Problem("error", f"section `{sid}` parent {parent!r} does not name an earlier section"))
    return parents if ok else [None] * len(plan)


def section_index(plan: list[tuple[str, int, str]], position: int) -> int:
    return unit_index([first for _, first, _ in plan], position)


def check_abstract_opens(records: list[Record], plan: list[tuple[str, int, str]], report: Report) -> None:
    """S5: the abstract states the aims and findings in advance; it opens no commitment."""
    if not plan or plan[0][2] != "abstract":
        return
    end = plan[1][1] if len(plan) > 1 else None
    for rec in records:
        if rec.position is None or (end is not None and rec.position >= end):
            continue
        raw = rec.data.get("opens", [])
        ids = [o.get("id") for o in raw if isinstance(o, dict)] if isinstance(raw, list) else []
        if ids:
            listed = ", ".join(f"`{i}`" for i in ids)
            problem = rec.problem("error", f"opens {listed} inside the abstract; the abstract opens no commitments")
            report.add("S5", Problem(problem.severity, problem.message, problem.position, problem.prop_id, problem.line, "abstract"))


# ---------- S5: paragraphs ----------


def check_paragraphs(structure: dict, positions: dict[str, int], plan: list[tuple[str, int, str]],
                     report: Report) -> list[Paragraph]:
    """S5 paragraph plan; return the paragraphs when their spans are usable (ids, starts, order), else []."""
    def err(message: str) -> None:
        report.add("S5", Problem("error", message))

    raw = structure.get("paragraphs")
    if not isinstance(raw, list) or not raw:
        err("paragraphs must be a non-empty list")
        return []
    entries: list[tuple[str, int, dict]] = []
    ids: set[str] = set()
    spans_ok = True
    for i, par in enumerate(raw, 1):
        pid = par.get("id") if isinstance(par, dict) else None
        first = par.get("first_prop") if isinstance(par, dict) else None
        if not isinstance(pid, str) or not pid:
            err(f"paragraph {i} has no string `id`")
            spans_ok = False
            continue
        if pid in ids:
            err(f"duplicate paragraph id `{pid}`")
            spans_ok = False
        ids.add(pid)
        if not isinstance(first, str) or first not in positions:
            err(f"paragraph `{pid}` first_prop {first!r} is not a non-retired ledger proposition")
            spans_ok = False
            continue
        entries.append((pid, positions[first], par))
    for (prev, prev_pos, _), (pid, pos, _) in zip(entries, entries[1:]):
        if pos <= prev_pos:
            err(f"paragraphs `{prev}` (#{prev_pos}) and `{pid}` (#{pos}) are out of ledger order")
            spans_ok = False
    if entries and entries[0][1] != 1:
        err(f"the first paragraph `{entries[0][0]}` starts at #{entries[0][1]}, not at the first proposition")
        spans_ok = False
    if not spans_ok:
        return []
    firsts = [pos for _, pos, _ in entries]
    sec_firsts = [first for _, first, _ in plan]
    for sid, first, _ in plan:
        if first not in firsts:
            inside = entries[unit_index(firsts, first)][0]
            err(f"section `{sid}` starts at #{first}, inside paragraph `{inside}`; no paragraph may cross a section boundary")
    index = {pid: i for i, (pid, _, _) in enumerate(entries)}
    paragraphs: list[Paragraph] = []
    for pid, first, par in entries:
        section = unit_index(sec_firsts, first) if plan else None
        head, rel = par.get("head", MISSING), par.get("relation", MISSING)
        head_index = None
        if head is MISSING:
            if rel is not MISSING:
                err(f"root paragraph `{pid}` carries a relation; a root has neither head nor relation")
        else:
            if not isinstance(head, str) or head not in index or head == pid:
                err(f"paragraph `{pid}` head {head!r} does not name another paragraph")
            else:
                head_index = index[head]
                if plan and unit_index(sec_firsts, entries[head_index][1]) != section:
                    err(f"paragraph `{pid}` head `{head}` is in another section")
            if rel is MISSING:
                err(f"paragraph `{pid}` has a head but no relation")
            elif _relation_problem(rel):
                err(f"paragraph `{pid}`: {_relation_problem(rel)}")
        paragraphs.append(Paragraph(pid, first, head_index, rel if isinstance(rel, str) else None, section))
    _check_paragraph_trees(paragraphs, plan, report)
    return paragraphs


def _check_paragraph_trees(paragraphs: list[Paragraph], plan: list[tuple[str, int, str]], report: Report) -> None:
    if plan:
        for s, (sid, _, _) in enumerate(plan):
            roots = [p.pid for p in paragraphs if p.section == s and p.head is None]
            if len(roots) != 1:
                report.add("S5", Problem(
                    "error", f"section `{sid}` has {len(roots)} root paragraphs ({', '.join(roots) or 'none'}); "
                             "exactly one paragraph per section has no head"))
    reported: set[frozenset[int]] = set()
    for start in range(len(paragraphs)):
        path: list[int] = []
        current: int | None = start
        while current is not None and current not in path:
            path.append(current)
            current = paragraphs[current].head
        if current is not None:
            cycle = frozenset(path[path.index(current):])
            if cycle not in reported:
                reported.add(cycle)
                names = [paragraphs[i].pid for i in sorted(cycle)]
                report.add("S5", Problem("error", "paragraph heads form a cycle: " + " -> ".join(names + names[:1])))


# ---------- S6 ----------


def check_s6(commitments: dict[str, Commitment], plan: list[tuple[str, int, str]], report: Report) -> None:
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


# ---------- S7 / S8 ----------


def check_s7(records: list[Record], heads: dict[int, object], paragraphs: list[Paragraph], report: Report) -> None:
    if not paragraphs:
        return
    firsts = [p.first for p in paragraphs]
    by_pos = {r.position: r for r in records if r.position is not None}
    groups: dict[int, list[tuple[int, int, int]]] = {}
    for pos, head in heads.items():
        if isinstance(head, int):
            groups.setdefault(unit_index(firsts, pos), []).append((pos, head, pos))
    for arcs in groups.values():
        for (a1, b1, k1), (a2, b2, _) in crossing_pairs(arcs):
            report.add("S7", by_pos[k1].problem("warning", f"arc ({a1}, {b1}) crosses arc ({a2}, {b2})"))
    by_section: dict[object, list[tuple[int, int, int]]] = {}
    for i, par in enumerate(paragraphs):
        if par.head is not None:
            by_section.setdefault(par.section, []).append((i + 1, par.head + 1, i))
    for arcs in by_section.values():
        for (a1, b1, _), (a2, b2, _) in crossing_pairs(arcs):
            names = [paragraphs[x - 1].pid for x in (a1, b1, a2, b2)]
            report.add("S7", Problem("warning", f"paragraph arc ({names[0]}, {names[1]}) crosses ({names[2]}, {names[3]})"))


def check_s8(records: list[Record], positions: dict[str, int], cites: dict[str, frozenset[str]], report: Report) -> None:
    for rec in records:
        pid = rec.data.get("prop_id")
        if rec.position is None or not isinstance(pid, str):
            continue
        targets = []
        if rec.data.get("relation") == "basis" and isinstance(rec.data.get("head"), str):
            targets.append(rec.data["head"])
        for entry in rec.data.get("also") or []:
            if isinstance(entry, dict) and entry.get("relation") == "basis" and isinstance(entry.get("to"), str):
                targets.append(entry["to"])
        for target in targets:
            if target in positions and target not in cites.get(pid, frozenset()):
                report.add("S8", rec.problem(
                    "warning", f"basis edge to #{positions[target]} {target}, which this proposition does not cite in main.jsonl"))


# ---------- S9 ----------


def check_s9(records: list[Record], structure: dict, vocabulary_path: Path | None, report: Report) -> None:
    """`move` and `type` are values of the vocabulary. Sidecars with neither never load it."""
    marked = [r for r in records if "move" in r.data]
    raw = structure.get("paragraphs")
    typed = [p for p in raw if isinstance(p, dict) and "type" in p] if isinstance(raw, list) else []
    if not marked and not typed:
        return
    vocabulary = load_vocabulary(vocabulary_path)
    for rec in marked:
        move = rec.data["move"]
        if not isinstance(move, str) or move not in vocabulary.moves:
            report.add("S9", rec.problem("error", f"move {move!r} is not in the vocabulary"))
    for par in typed:
        kind = par["type"]
        if not isinstance(kind, str) or kind not in vocabulary.paragraph_types:
            report.add("S9", Problem("error", f"paragraph `{par.get('id')}` type {kind!r} is not in the vocabulary"))


# ---------- driver ----------


@dataclass
class Analysis:
    """Everything the checks computed; the state query and the metrics read it."""
    report: Report
    ledger: Ledger
    positions: dict[str, int]
    records: list[Record]
    plan: list[tuple[str, int, str]]
    parents: list[int | None]
    paragraphs: list[Paragraph]
    heads: dict[int, object]
    commitments: dict[str, Commitment]
    structure: dict


def analyse(ledger_path: Path, structure_path: Path, discourse_path: Path, partial: bool,
            check_moves: bool = False, vocabulary_path: Path | None = None) -> Analysis:
    """Run the checks. S9 runs only with `check_moves`: the state query and the metrics do not use the vocabulary."""
    ledger = load_ledger(ledger_path)
    raw_records = load_discourse(discourse_path)
    structure = load_structure(structure_path)
    positions = {pid: i for i, pid in enumerate(ledger.live, 1)}
    records = [
        Record(i, line, data, positions.get(data.get("prop_id")) if isinstance(data.get("prop_id"), str) else None)
        for i, (line, data) in enumerate(raw_records)
    ]
    report = Report()
    check_s1(records, ledger.live, report)
    plan = check_s5(structure, positions, report, partial)
    parents = section_parents(structure, plan, report)
    check_abstract_opens(records, plan, report)
    paragraphs = check_paragraphs(structure, positions, plan, report)
    check_s2(records, positions, paragraphs, partial, report)
    commitments = check_s3(records, report)
    check_s4(commitments, partial, report)
    check_s6(commitments, plan, report)
    heads = head_map(records, positions, [p.first for p in paragraphs]) if paragraphs else {}
    check_s7(records, heads, paragraphs, report)
    check_s8(records, positions, ledger.cites, report)
    if check_moves:
        check_s9(records, structure, vocabulary_path, report)
    return Analysis(report, ledger, positions, records, plan, parents, paragraphs, heads, commitments, structure)


def validate(ledger: Path, structure_path: Path, discourse_path: Path, partial: bool,
             vocabulary_path: Path | None = None) -> Report:
    return analyse(ledger, structure_path, discourse_path, partial, True, vocabulary_path).report


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
    p = argparse.ArgumentParser(description="Check a ledger's article-structure sidecars, format 2.0 (S1-S9).")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    p.add_argument("--structure", type=Path, help="structure.json (default: beside the ledger)")
    p.add_argument("--discourse", type=Path, help="discourse.jsonl (default: beside the ledger)")
    p.add_argument("--vocabulary", type=Path, help="vocabulary.yaml (default: the one shipped with the plugin)")
    p.add_argument("--partial", action="store_true",
                   help="unfinished draft: open commitments and an empty thesis are information; `head: pending` allowed in the last paragraph")
    p.add_argument("--format", choices=("text", "json"), default="text")
    args = p.parse_args(argv)
    structure = args.structure or args.jsonl.parent / "structure.json"
    discourse = args.discourse or args.jsonl.parent / "discourse.jsonl"
    try:
        report = validate(args.jsonl, structure, discourse, args.partial, args.vocabulary)
    except InputError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    text = render_json(report, args.jsonl, args.partial) if args.format == "json" else render_text(report)
    print(text, end="")
    return EXIT_FAIL if report.failed() else EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
