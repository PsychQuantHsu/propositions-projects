"""A seven-sentence article that has every kind of link, for the link-catalog tests.

    sec-1  p-1 goal-summary  1 preview (opens announcement c-a)
                             2 state-goal   -> 1 specification, also -> 3 contrast
                             3 state-baseline -> 2 continue
           p-2 gap (-> p-1 contrast)
                             4 define
                             5 state-concern -> 4 restatement, cites 4
    sec-2  p-3 (no type)     6 state-result (discharges c-a), cites 4
                             7 (no move)    -> 6 consequence
"""
from __future__ import annotations

from pathlib import Path

from structure_case import write_case

VOCABULARY = """\
moves:
  - {id: preview, does: Announces what comes next., zh: 預告}
  - {id: state-goal, does: States the goal., zh: 說目的}
  - {id: state-baseline, does: Says what serves as the comparison., zh: 說對照基準}
  - {id: state-concern, does: Says what the study is concerned with., zh: 說關注點}
  - {id: define, does: Introduces a term., zh: 定義}
  - {id: state-result, does: States a finding., zh: 陳述結果}
paragraph_types:
  - {id: goal-summary, does: Sums up the goal., zh: 目的總結段}
  - {id: gap, does: Shows what is open., zh: 指出缺口段}
"""
RECORDS = [
    {"pos": 1, "move": "preview", "opens": [{"id": "c-a", "kind": "announcement"}]},
    {"pos": 2, "head": 1, "relation": "specification", "move": "state-goal", "also": [{"to": 3, "relation": "contrast"}]},
    {"pos": 3, "head": 2, "relation": "continue", "move": "state-baseline"},
    {"pos": 4, "move": "define"},
    {"pos": 5, "head": 4, "relation": "restatement", "move": "state-concern"},
    {"pos": 6, "move": "state-result", "discharges": ["c-a"]},
    {"pos": 7, "head": 6, "relation": "consequence"},
]
SECTIONS = [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first": 1},
    {"id": "sec-2", "heading": "Results", "role": "results", "first": 6},
]
PARAGRAPHS = [
    {"id": "p-1", "first": 1, "type": "goal-summary"},
    {"id": "p-2", "first": 4, "type": "gap", "head": "p-1", "relation": "contrast"},
    {"id": "p-3", "first": 6},
]
CITES = {5: [4], 6: [4]}


def write_vocabulary(tmp: Path) -> Path:
    path = tmp / "vocabulary.yaml"
    path.write_text(VOCABULARY, encoding="utf-8")
    return path


def write_article(directory: Path, records: list[dict] = RECORDS) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    return write_case(directory, len(records), records, sections=SECTIONS, paragraphs=PARAGRAPHS, cites=CITES)
