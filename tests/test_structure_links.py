"""Tests for structure-links.py (Spectra change add-paragraph-moves).

Spec: Requirement "Link queries report every link of a sentence and the paths of a value".
The article is tests/link_case.py; `out` means the sentence is the link's `from` end.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

pytest.importorskip("yaml")

sys.path.insert(0, str(Path(__file__).parent))
from link_case import write_article, write_vocabulary  # noqa: E402
from structure_case import pid, write_case  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "structure-links.py"
CATALOG = """\
kind,paragraph_type,from,to,relation,scope,label,count
next,goal-summary,state-goal,state-baseline,specification,paragraph,empirical,2
next,goal-summary,state-goal,END,,paragraph,default,1
next,gap,state-goal,state-baseline,specification,paragraph,default,3
next,gap,state-goal,END,,paragraph,empirical,1
head,goal-summary,state-baseline,state-goal,specification,paragraph,empirical,4
paragraph,,gap,goal-summary,contrast,section,default,1
"""


def run(tmp: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), *args, "--vocabulary", str(write_vocabulary(tmp))],
                          capture_output=True, text=True)


def sentence(tmp: Path, at: str, *flags: str) -> dict:
    ledger = write_article(tmp / "a")
    result = run(tmp, "sentence", "--jsonl", str(ledger), "--at", at, "--format", "json", *flags)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


def links(data: dict) -> set[tuple]:
    return {(l["kind"], l["direction"], l["position"], l["relation"], l["scope"]) for l in data["links"]}


def catalog(tmp: Path, *flags: str) -> subprocess.CompletedProcess:
    path = tmp / "links.csv"
    path.write_text(CATALOG, encoding="utf-8")
    return run(tmp, "catalog", "--catalog", str(path), *flags)


# ---------- sentence ----------


def test_a_sentence_links_in_both_directions(tmp_path: Path) -> None:
    found = links(sentence(tmp_path, "2"))
    assert {
        ("head", "out", 1, "specification", "paragraph"),
        ("head", "in", 3, "continue", "paragraph"),
        ("next", "in", 1, "specification", "paragraph"),
        ("next", "out", 3, "continue", "paragraph"),
        ("also", "out", 3, "contrast", "paragraph"),
    } <= found


def test_the_spec_example_fan(tmp_path: Path) -> None:
    write_vocabulary(tmp_path)
    ledger = write_case(tmp_path, 4, [{"pos": 1}, {"pos": 2, "head": 1, "relation": "specification"},
                                      {"pos": 3, "head": 1, "relation": "specification"}, {"pos": 4, "head": 3, "relation": "continue"}])
    data = json.loads(run(tmp_path, "sentence", "--jsonl", str(ledger), "--at", "3", "--format", "json").stdout)
    assert {("head", "out", 1, "specification"), ("head", "in", 4, "continue"), ("next", "in", 2, "specification"),
            ("next", "out", 4, "continue")} <= {(l["kind"], l["direction"], l["position"], l["relation"]) for l in data["links"]}


def test_also_is_seen_from_its_target(tmp_path: Path) -> None:
    assert ("also", "in", 2, "contrast", "paragraph") in links(sentence(tmp_path, "3"))


def test_paragraph_ends_are_start_and_end(tmp_path: Path) -> None:
    found = links(sentence(tmp_path, "1"))
    assert ("next", "in", "START", "ROOT", "paragraph") in found
    assert ("next", "out", "END", "", "paragraph") in links(sentence(tmp_path, "3"))


def test_citations_carry_their_scope(tmp_path: Path) -> None:
    found = links(sentence(tmp_path, "4"))
    assert ("cites", "in", 5, "", "paragraph") in found
    assert ("cites", "in", 6, "", "article") in found


def test_a_discharge_in_both_directions(tmp_path: Path) -> None:
    assert ("discharge", "out", 1, "announcement", "article") in links(sentence(tmp_path, "6"))
    assert ("discharge", "in", 6, "announcement", "article") in links(sentence(tmp_path, "1"))


def test_the_sentence_itself_is_described(tmp_path: Path) -> None:
    data = sentence(tmp_path, "2")
    assert (data["position"], data["move"], data["move_zh"], data["paragraph"], data["paragraph_type"], data["section"]) == \
        (2, "state-goal", "說目的", "p-1", "goal-summary", "sec-1")
    assert data["text"] == "Sentence 2."
    head = next(l for l in data["links"] if l["kind"] == "head" and l["direction"] == "out")
    assert head["move"] == "preview" and head["move_zh"] == "預告" and head["text"] == "Sentence 1."


def test_a_proposition_id_selects_the_sentence(tmp_path: Path) -> None:
    assert sentence(tmp_path, pid(5))["position"] == 5


def test_text_can_be_left_out(tmp_path: Path) -> None:
    ledger = write_article(tmp_path / "a")
    result = run(tmp_path, "sentence", "--jsonl", str(ledger), "--at", "2", "--no-text")
    assert result.returncode == 0 and "Sentence" not in result.stdout and "說目的" in result.stdout


def test_text_output_names_kind_relation_and_scope(tmp_path: Path) -> None:
    ledger = write_article(tmp_path / "a")
    out = run(tmp_path, "sentence", "--jsonl", str(ledger), "--at", "6", "--no-text").stdout
    line = next(l for l in out.splitlines() if "discharge" in l)
    assert "#1" in line and "announcement" in line and "他節" in line


@pytest.mark.parametrize("at", ["99", "0", "not-an-id"])
def test_an_unknown_sentence_is_an_input_error(tmp_path: Path, at: str) -> None:
    ledger = write_article(tmp_path / "a")
    result = run(tmp_path, "sentence", "--jsonl", str(ledger), "--at", at)
    assert result.returncode == 2 and at in result.stderr


def test_the_sentence_query_writes_nothing(tmp_path: Path) -> None:
    ledger = write_article(tmp_path / "a")
    write_vocabulary(tmp_path)
    before = {p: p.read_bytes() for p in (tmp_path / "a").iterdir()}
    run(tmp_path, "sentence", "--jsonl", str(ledger), "--at", "3")
    assert {p: p.read_bytes() for p in (tmp_path / "a").iterdir()} == before


# ---------- catalog ----------


def query(tmp: Path, *flags: str) -> dict:
    result = catalog(tmp, *flags, "--format", "json")
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


def test_counts_are_summed_and_sorted_by_total(tmp_path: Path) -> None:
    seen = query(tmp_path, "--from", "state-goal", "--kind", "next")["seen"]
    assert [(s["to"], s["relation"], s["total"], s["counts"]) for s in seen] == [
        ("state-baseline", "specification", 5, {"default": 3, "empirical": 2}),
        ("END", "", 2, {"default": 1, "empirical": 1}),
    ]


def test_type_and_label_filter(tmp_path: Path) -> None:
    seen = query(tmp_path, "--from", "state-goal", "--kind", "next", "--type", "goal-summary", "--label", "empirical")["seen"]
    assert [(s["to"], s["total"]) for s in seen] == [("state-baseline", 2)]


def test_to_reverses_the_query(tmp_path: Path) -> None:
    seen = query(tmp_path, "--to", "state-goal", "--kind", "head")["seen"]
    assert [(s["from"], s["relation"], s["total"]) for s in seen] == [("state-baseline", "specification", 4)]


def test_without_a_kind_every_kind_is_listed(tmp_path: Path) -> None:
    seen = query(tmp_path, "--from", "state-goal")["seen"]
    assert {s["kind"] for s in seen} == {"next"}
    seen = query(tmp_path, "--to", "state-goal")["seen"]
    assert {s["kind"] for s in seen} == {"head"}


def test_unseen_paths_are_computed_not_stored(tmp_path: Path) -> None:
    data = query(tmp_path, "--from", "state-goal", "--kind", "next", "--unseen")
    assert data["unseen"] == ["define", "preview", "state-concern", "state-goal", "state-result"]


def test_unseen_for_paragraph_links_uses_paragraph_types(tmp_path: Path) -> None:
    assert query(tmp_path, "--from", "gap", "--kind", "paragraph", "--unseen")["unseen"] == ["gap"]


def test_unseen_in_reverse_next_offers_start(tmp_path: Path) -> None:
    unseen = query(tmp_path, "--to", "state-baseline", "--kind", "next", "--unseen")["unseen"]
    assert "START" in unseen and "END" not in unseen and "state-goal" not in unseen


def test_text_output_lists_seen_and_unseen(tmp_path: Path) -> None:
    out = catalog(tmp_path, "--from", "state-goal", "--kind", "next", "--unseen").stdout
    assert "state-baseline" in out and "specification" in out and "define" in out


@pytest.mark.parametrize("flags, named", [
    (("--from", "state-gaol"), "state-gaol"),
    (("--from", "state-goal", "--type", "summary"), "summary"),
    (("--from", "state-goal", "--unseen"), "--kind"),
    (("--from", "gap", "--kind", "next"), "gap"),
    (("--from", "state-goal", "--label", "Bad Label"), "Bad Label"),
])
def test_bad_values_are_input_errors(tmp_path: Path, flags: tuple, named: str) -> None:
    result = catalog(tmp_path, *flags)
    assert result.returncode == 2 and named in result.stderr


def test_exactly_one_of_from_and_to(tmp_path: Path) -> None:
    assert catalog(tmp_path).returncode == 2
    assert catalog(tmp_path, "--from", "state-goal", "--to", "define").returncode == 2


@pytest.mark.parametrize("text", [
    "kind,from,to\nnext,a,b\n",
    CATALOG.replace(",2\n", ",two\n", 1),
    CATALOG.replace("next,goal-summary", "nextt,goal-summary", 1),
])
def test_a_malformed_catalog_is_an_input_error(tmp_path: Path, text: str) -> None:
    path = tmp_path / "links.csv"
    path.write_text(text, encoding="utf-8")
    assert run(tmp_path, "catalog", "--catalog", str(path), "--from", "state-goal").returncode == 2


# ---------- next mode's move hint (Spectra change add-next-mode-move-hint) ----------

SKILL = REPO_ROOT / "plugins" / "propositions" / "skills" / "construct" / "SKILL.md"
STATE = REPO_ROOT / "plugins" / "propositions" / "scripts" / "structure-state.py"
VALIDATE = REPO_ROOT / "plugins" / "propositions" / "scripts" / "validate-structure.py"


def next_mode() -> str:
    text = SKILL.read_text(encoding="utf-8")
    return " ".join(text[text.index("## Next mode"):text.index("## Explain mode")].split())


def test_next_mode_no_longer_refuses_the_catalog() -> None:
    assert "does not read" not in next_mode()


def test_next_mode_reads_the_last_move_with_the_sentence_query() -> None:
    assert '"$LINKS" sentence --jsonl "$LEDGER/main.jsonl" --at' in next_mode()
    assert "--no-text --format json" in next_mode()


def test_next_mode_queries_the_whole_catalog() -> None:
    raw = SKILL.read_text(encoding="utf-8")
    section = raw[raw.index("## Next mode"):raw.index("## Explain mode")]
    calls = [line for line in section.splitlines() if '"$LINKS" catalog' in line]
    assert len(calls) == 1, calls
    assert "--kind next" in calls[0]
    assert "--type" not in calls[0] and "--label" not in calls[0]


@pytest.mark.parametrize("phrase", (
    "Add up the rows by `to`",
    "`END` counts as a value",
    "first appear in the listing",
    "observed paths, not a rule",
    "does not change the order of the candidates",
    "does not choose the relation",
))
def test_next_mode_states_how_the_hint_is_built_and_used(phrase: str) -> None:
    assert phrase in next_mode()


def test_next_mode_skips_the_hint_in_three_named_cases() -> None:
    section = next_mode()
    for case in ("has no `move`", "no `next` path", "exits non-zero"):
        assert case in section


def test_next_mode_candidates_state_a_move() -> None:
    section = next_mode()
    assert "**Does**" in section
    assert "`none fits`" in section


def draft_with_a_pending_record(tmp: Path) -> Path:
    records = [{"pos": 1, "move": "state-goal"}, {"pos": 2, "head": "pending", "move": "state-baseline"}]
    return write_case(tmp, 2, records=records)


def test_next_mode_sentence_query_reads_a_draft_with_a_pending_head(tmp_path: Path) -> None:
    ledger = draft_with_a_pending_record(tmp_path)
    vocabulary = write_vocabulary(tmp_path)
    partial = subprocess.run([sys.executable, str(VALIDATE), "--jsonl", str(ledger), "--partial",
                              "--vocabulary", str(vocabulary)], capture_output=True, text=True)
    assert partial.returncode == 0, partial.stdout + partial.stderr
    result = run(tmp_path, "sentence", "--jsonl", str(ledger), "--at", "2", "--no-text", "--format", "json")
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["move"] == "state-baseline"


def test_next_mode_sentence_query_reports_no_move(tmp_path: Path) -> None:
    assert sentence(tmp_path, "7", "--no-text")["move"] is None


def test_next_mode_catalog_query_fails_loudly_without_the_catalog(tmp_path: Path) -> None:
    result = run(tmp_path, "catalog", "--catalog", str(tmp_path / "absent.csv"),
                 "--from", "state-goal", "--kind", "next")
    assert result.returncode == 2
    assert "not found" in result.stderr


def test_next_mode_catalog_query_finds_no_path_for_an_unobserved_move(tmp_path: Path) -> None:
    assert query(tmp_path, "--from", "define", "--kind", "next")["seen"] == []


def test_next_mode_state_query_does_not_depend_on_the_catalog(tmp_path: Path) -> None:
    ledger = write_article(tmp_path / "a")
    copy = tmp_path / "plugin" / "scripts"
    shutil.copytree(STATE.parent, copy, ignore=shutil.ignore_patterns("__pycache__"))
    assert not (copy.parent / "catalog").exists()

    def state(script: Path) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, str(script), "--jsonl", str(ledger), "--at", "end", "--format", "json"],
                              capture_output=True, text=True)

    with_catalog, without_catalog = state(STATE), state(copy / STATE.name)
    assert with_catalog.returncode == 0, with_catalog.stderr
    assert with_catalog.stdout == without_catalog.stdout
