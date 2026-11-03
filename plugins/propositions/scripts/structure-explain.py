#!/usr/bin/env python3
"""structure-explain.py — read out how the sentences of a paragraph relate.

Spectra change add-paragraph-moves. The sidecars say what each sentence does
(`move`) and what it hangs on (`head`, `relation`); this tool prints both together,
indented by depth in the paragraph's tree:

    p-19  目的總結段
    #138  說目的  段根  In summary, ...
      #139  說對照基準  具體說明 #138（specification）  with which ...
      #140  說關注點  具體說明 #138（specification）  We are ...
        #141  未標  接續 #140（continue）  Our analyses ...

It writes no file. The vocabulary is read only when the sidecars have a `move` or
a `type`, so sidecars without them need neither the file nor PyYAML.

Usage:
    python3 structure-explain.py --jsonl main.jsonl (--paragraph ID | --section ID | --all)
        [--structure structure.json] [--discourse discourse.jsonl]
        [--vocabulary vocabulary.yaml] [--no-text] [--format text|json]

Exit code:
    0 — reported
    2 — an input is missing or invalid, the sidecars fail S1, S2, S3 or the plan
        of S5, structure_version is not "2.0", or the paragraph or section does
        not exist
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _lib.move_vocabulary import Vocabulary, load_vocabulary  # noqa: E402
from _lib.structure_io import ledger_field  # noqa: E402
from _lib.structure_tree import PENDING  # noqa: E402

EXIT_OK, EXIT_USAGE = 0, 2
UNLABELLED, ROOT = "未標", "段根"
WAITING = "等待後面的句子當頭"
GLOSSES = {
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


def _load_state():
    spec = importlib.util.spec_from_file_location("structure_state", Path(__file__).parent / "structure-state.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


state = _load_state()
vs = state.vs


def tree_depth(position: int, heads: dict[int, object]) -> int:
    """Edges from `position` up to the root; a pending head counts as one edge."""
    depth, current = 0, position
    while True:
        head = heads.get(current)
        if head is None:
            return depth
        depth += 1
        if head == PENDING:
            return depth
        current = head


def explain_proposition(analysis, position: int, end_heads: dict[int, object], vocabulary: Vocabulary | None,
                        texts: dict[str, object] | None) -> dict:
    prop_id = analysis.ledger.live[position - 1]
    data = analysis.records[position - 1].data
    head = end_heads.get(position)
    relation = data.get("relation") if head is not None else None
    move = data.get("move")
    entry = vocabulary.moves.get(move) if vocabulary and isinstance(move, str) else None
    item = {
        "position": position,
        "prop_id": prop_id,
        "depth": tree_depth(position, end_heads),
        "move": move,
        "move_zh": entry.zh if entry else None,
        "head": head,
        "relation": relation,
        "relation_gloss": GLOSSES.get(relation),
        "also": [
            {"to": analysis.positions.get(a.get("to")), "relation": a.get("relation"),
             "relation_gloss": GLOSSES.get(a.get("relation"))}
            for a in data.get("also") or []
        ],
    }
    if texts is not None:
        item["text"] = str(texts.get(prop_id, ""))
    return item


def explain(ledger: Path, structure: Path, discourse: Path, vocabulary_path: Path | None,
            paragraph: str | None, section: str | None, with_text: bool) -> dict:
    analysis = state.load_checked(ledger, structure, discourse)
    raw = {p["id"]: p for p in analysis.structure["paragraphs"]}
    pars = analysis.paragraphs
    plan_ids = [s[0] for s in analysis.plan]
    if paragraph is not None and paragraph not in raw:
        raise vs.InputError(f"no paragraph `{paragraph}`")
    if section is not None and section not in plan_ids:
        raise vs.InputError(f"no section `{section}`")
    has_labels = any("move" in r.data for r in analysis.records) or any("type" in p for p in raw.values())
    vocabulary = load_vocabulary(vocabulary_path) if has_labels else None
    texts = ledger_field(ledger, "text") if with_text else None
    headings = {s["id"]: s for s in analysis.structure["sections"]}
    total = len(analysis.ledger.live)
    out = []
    for i, par in enumerate(pars):
        section_id = plan_ids[par.section] if par.section is not None else None
        if (paragraph is not None and par.pid != paragraph) or (section is not None and section_id != section):
            continue
        end = pars[i + 1].first if i + 1 < len(pars) else total + 1
        kind = raw[par.pid].get("type")
        entry = vocabulary.paragraph_types.get(kind) if vocabulary and isinstance(kind, str) else None
        out.append({
            "id": par.pid,
            "section": section_id,
            "section_heading": headings.get(section_id, {}).get("heading"),
            "section_role": headings.get(section_id, {}).get("role"),
            "type": kind,
            "type_zh": entry.zh if entry else None,
            "head": pars[par.head].pid if par.head is not None else None,
            "relation": par.relation,
            "relation_gloss": GLOSSES.get(par.relation),
            "propositions": [
                explain_proposition(analysis, pos, analysis.heads, vocabulary, texts) for pos in range(par.first, end)
            ],
        })
    return {"paragraphs": out}


def _how_it_hangs(item: dict) -> str:
    if item["head"] is None:
        return ROOT
    if item["head"] == PENDING:
        return WAITING
    return f"{item['relation_gloss'] or '接在'} #{item['head']}（{item['relation']}）"


def _label(zh: str | None, raw: object) -> str:
    return zh or (f"{raw}（不在詞彙裡）" if raw else UNLABELLED)


def render_text(result: dict) -> str:
    out: list[str] = []
    current = None
    for par in result["paragraphs"]:
        if par["section"] != current:
            current = par["section"]
            out.append(f"== {current}  {par['section_heading']}（{par['section_role']}）")
        line = f"{par['id']}  {_label(par['type_zh'], par['type'])}"
        if par["head"]:
            line += f"  {par['relation_gloss'] or '接在'} {par['head']}（{par['relation']}）"
        out.append(line)
        for item in par["propositions"]:
            pad = "  " * item["depth"]
            fields = [f"#{item['position']}", _label(item["move_zh"], item["move"]), _how_it_hangs(item)]
            if item.get("text"):
                fields.append(item["text"])
            out.append(pad + "  ".join(fields))
            out.extend(
                f"{pad}  另：{a['relation_gloss'] or '接在'} #{a['to']}（{a['relation']}）" for a in item["also"]
            )
        out.append("")
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Read out how the sentences of a paragraph relate (format 2.0).")
    p.add_argument("--jsonl", type=Path, required=True, help="the ledger (main.jsonl)")
    scope = p.add_mutually_exclusive_group(required=True)
    scope.add_argument("--paragraph", help="one paragraph id")
    scope.add_argument("--section", help="one section id")
    scope.add_argument("--all", action="store_true", help="every paragraph")
    p.add_argument("--structure", type=Path, help="structure.json (default: beside the ledger)")
    p.add_argument("--discourse", type=Path, help="discourse.jsonl (default: beside the ledger)")
    p.add_argument("--vocabulary", type=Path, help="vocabulary.yaml (default: the one shipped with the plugin)")
    p.add_argument("--no-text", action="store_true", help="leave out the propositions' text")
    p.add_argument("--format", choices=("text", "json"), default="text")
    args = p.parse_args(argv)
    structure = args.structure or args.jsonl.parent / "structure.json"
    discourse = args.discourse or args.jsonl.parent / "discourse.jsonl"
    try:
        result = explain(args.jsonl, structure, discourse, args.vocabulary, args.paragraph, args.section, not args.no_text)
    except (vs.InputError, state.StructureError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_USAGE
    print(json.dumps(result, ensure_ascii=False, indent=1) if args.format == "json" else render_text(result))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
