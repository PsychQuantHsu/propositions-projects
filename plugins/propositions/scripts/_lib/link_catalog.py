"""Links between sentences, and the CSV catalog that counts them across manuscripts.

Spectra change add-paragraph-moves. `article_links` lists every link of one
annotated article between positions; `build-link-catalog.py` turns them into
counts between moves, and `structure-links.py` reads both. Keeping the
enumeration here means a sentence's links and the catalog's rows always use the
same kinds and directions.

Six kinds, closed: `next` (reading order inside a paragraph, from START to END),
`head`, `also`, `cites`, `discharge` and `paragraph`. `next` points forward;
every other kind points from the dependent end to what it depends on.
"""
from __future__ import annotations

import csv
import io
import re
from collections.abc import Iterator, Mapping
from dataclasses import dataclass
from pathlib import Path

from _lib.structure_io import InputError
from _lib.structure_tree import PENDING, unit_index

DEFAULT_CATALOG = Path(__file__).resolve().parents[2] / "catalog" / "links.csv"
COLUMNS = ("kind", "paragraph_type", "from", "to", "relation", "scope", "label", "count")
KINDS = ("next", "head", "also", "cites", "discharge", "paragraph")
SCOPES = ("paragraph", "section", "article")
START, END, ROOT = "START", "END", "ROOT"
LABEL = re.compile(r"[a-z0-9][a-z0-9-]*")
RELATION_GLOSSES = {
    "continue": "接續",
    "restatement": "換句話說",
    "specification": "具體說明",
    "instance": "舉例說明",
    "addition": "補充",
    "contrast": "對照",
    "reason": "說明理由",
    "consequence": "推出結果",
    "sequence": "接著下一步",
    "basis": "用到",
}
SCOPE_GLOSSES = {"paragraph": "同一段", "section": "同一節", "article": "他節"}


@dataclass(frozen=True)
class Link:
    """One link of an article. Ends are positions, START or END; paragraph indices for `paragraph`."""
    kind: str
    source: int | str
    target: int | str
    relation: str
    scope: str


class _Article:
    def __init__(self, analysis) -> None:
        self.analysis = analysis
        self.firsts = [p.first for p in analysis.paragraphs]
        self.section_firsts = [first for _, first, _ in analysis.plan]
        self.total = len(analysis.ledger.live)

    def end_of(self, index: int) -> int:
        return self.firsts[index + 1] if index + 1 < len(self.firsts) else self.total + 1

    def scope(self, a: int, b: int) -> str:
        if unit_index(self.firsts, a) == unit_index(self.firsts, b):
            return "paragraph"
        same = unit_index(self.section_firsts, a) == unit_index(self.section_firsts, b)
        return "section" if same else "article"

    def relation_of(self, position: int) -> str:
        head = self.analysis.heads.get(position)
        if head is None:
            return ROOT
        if head == PENDING:
            return PENDING
        return self.analysis.records[position - 1].data.get("relation") or ""


def _reading(art: _Article) -> Iterator[Link]:
    for i, par in enumerate(art.analysis.paragraphs):
        previous: int | str = START
        for position in range(par.first, art.end_of(i)):
            yield Link("next", previous, position, art.relation_of(position), "paragraph")
            previous = position
        yield Link("next", previous, END, "", "paragraph")


def _dependencies(art: _Article) -> Iterator[Link]:
    analysis = art.analysis
    for position, head in sorted(analysis.heads.items(), key=lambda kv: kv[0]):
        if isinstance(head, int):
            yield Link("head", position, head, art.relation_of(position), "paragraph")
    for position in range(1, art.total + 1):
        for entry in analysis.records[position - 1].data.get("also") or []:
            target = analysis.positions.get(entry.get("to"))
            if target is not None:
                yield Link("also", position, target, entry.get("relation") or "", art.scope(position, target))
        for cited in sorted(analysis.ledger.cites.get(analysis.ledger.live[position - 1], ())):
            target = analysis.positions.get(cited)
            if target is not None:
                yield Link("cites", position, target, "", art.scope(position, target))


def _discharges(art: _Article) -> Iterator[Link]:
    for commitment in art.analysis.commitments.values():
        opened = commitment.opened.position
        for record in commitment.discharged_by:
            if opened is not None and record.position is not None:
                yield Link("discharge", record.position, opened, commitment.kind, art.scope(record.position, opened))


def _paragraphs(art: _Article) -> Iterator[Link]:
    for i, par in enumerate(art.analysis.paragraphs):
        if par.head is not None:
            yield Link("paragraph", i, par.head, par.relation or "", "section")


def article_links(analysis) -> list[Link]:
    """Every link of an article whose sidecars passed the checks the state query needs."""
    art = _Article(analysis)
    return [*_reading(art), *_dependencies(art), *_discharges(art), *_paragraphs(art)]


def render(counts: Mapping[tuple[str, ...], int]) -> str:
    """The catalog text: header, then one row per key (COLUMNS without count), sorted."""
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(COLUMNS)
    for key in sorted(counts, key=lambda k: (KINDS.index(k[0]), *k[1:])):
        writer.writerow((*key, counts[key]))
    return out.getvalue()


def _checked_row(raw: list[str], where: str) -> dict:
    if len(raw) != len(COLUMNS):
        raise InputError(f"{where}: {len(raw)} fields, expected {len(COLUMNS)}")
    row = dict(zip(COLUMNS, raw))
    if row["kind"] not in KINDS:
        raise InputError(f"{where}: kind {row['kind']!r} is not one of {', '.join(KINDS)}")
    if row["scope"] not in SCOPES:
        raise InputError(f"{where}: scope {row['scope']!r} is not one of {', '.join(SCOPES)}")
    if not LABEL.fullmatch(row["label"]):
        raise InputError(f"{where}: label {row['label']!r} is not lowercase letters, digits and hyphens")
    if not row["count"].isdigit() or int(row["count"]) < 1:
        raise InputError(f"{where}: count {row['count']!r} is not a positive integer")
    return {**row, "count": int(row["count"])}


def read_catalog(path: Path) -> list[dict]:
    """The catalog's rows with `count` as an integer; every malformed line is an InputError."""
    if not path.is_file():
        raise InputError(f"catalog not found: {path}")
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader, None)
        if tuple(header or ()) != COLUMNS:
            raise InputError(f"{path.name}: the header is not {','.join(COLUMNS)}")
        return [_checked_row(raw, f"{path.name} line {n}") for n, raw in enumerate(reader, 2)]
