"""Tests for scripts/check-extraction-coverage.py (Spectra change add-extract-skill).

Spec: openspec/changes/add-extract-skill/specs/proposition-extraction/spec.md
Requirements "Coverage check reports uncovered text in a line range" and
"Coverage exclusions are a closed set and are reported".

The validator's R1 proves extracted text was not fabricated; this check proves
nothing in a line range was left out. All manuscript text here is synthetic.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "plugins" / "propositions" / "scripts" / "check-extraction-coverage.py"

ID = "01910b9c-d4f0-7000-8000-{:012x}"


def tex_with(lines: dict[int, str], total: int = 80) -> str:
    """A .tex body whose line N holds lines[N]; other lines are blank."""
    return "\n".join(lines.get(n, "") for n in range(1, total + 1)) + "\n"


def prop(n: int, text: str, location: str) -> dict:
    return {
        "id": ID.format(n), "text": text, "location": location,
        "containing_block": "sec:results", "claim_type": "claim", "asserts": ["x"], "cites": [],
    }


def write_case(tmp_path: Path, tex: str, props: list[dict], name: str = "main.tex") -> tuple[Path, Path]:
    tex_path = tmp_path / name
    tex_path.parent.mkdir(parents=True, exist_ok=True)
    tex_path.write_text(tex)
    jsonl = tmp_path / "main.jsonl"
    jsonl.write_text("".join(json.dumps(p) + "\n" for p in props))
    return tex_path, jsonl


def run(tex: Path, lines: str, jsonl: Path, *extra: str, fmt: str = "json") -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--tex", str(tex), "--lines", lines, "--jsonl", str(jsonl),
         "--format", fmt, *extra],
        capture_output=True, text=True,
    )


def report(result: subprocess.CompletedProcess) -> dict:
    return json.loads(result.stdout)


# ---------- Requirement: Coverage check reports uncovered text in a line range ----------


def test_fully_covered_paragraph(tmp_path):
    tex = tex_with({5: "The sample was large. The effect was small."})
    props = [prop(1, "The sample was large.", "main.tex:L5"), prop(2, "The effect was small.", "main.tex:L5")]
    tex_path, jsonl = write_case(tmp_path, tex, props)
    result = run(tex_path, "5-5", jsonl)
    assert result.returncode == 0, result.stdout + result.stderr
    assert report(result)["uncovered"] == []


def test_dropped_clause(tmp_path):
    tex = tex_with({12: "The sample was large, but the effect was small."})
    tex_path, jsonl = write_case(tmp_path, tex, [prop(1, "The sample was large,", "main.tex:L12")])
    result = run(tex_path, "10-14", jsonl)
    assert result.returncode == 1
    runs = report(result)["uncovered"]
    assert len(runs) == 1
    assert runs[0]["start_line"] == 12 and runs[0]["end_line"] == 12
    assert "but the effect was small" in runs[0]["excerpt"]


def test_proposition_spanning_a_line_break(tmp_path):
    tex = tex_with({20: "The sample was large and", 21: "the effect was small."})
    tex_path, jsonl = write_case(
        tmp_path, tex, [prop(1, "The sample was large and the effect was small.", "main.tex:L20-L21")]
    )
    result = run(tex_path, "20-21", jsonl)
    assert result.returncode == 0, result.stdout
    assert report(result)["uncovered"] == []


def test_paraphrased_proposition_is_a_warning_and_text_stays_uncovered(tmp_path):
    # Spec "Example: paraphrased proposition".
    tex = tex_with({8: "Most participants preferred the second option."})
    tex_path, jsonl = write_case(
        tmp_path, tex, [prop(7, "Most participants favoured the second option.", "main.tex:L8")]
    )
    result = run(tex_path, "8-8", jsonl)
    data = report(result)
    assert result.returncode == 1
    assert [w["id"] for w in data["warnings"]] == [ID.format(7)]
    assert len(data["uncovered"]) == 1
    assert data["uncovered"][0]["start_line"] == 8
    assert "Most participants preferred the second option" in data["uncovered"][0]["excerpt"]


def test_nearest_occurrence_to_location_is_used(tmp_path):
    tex = tex_with({3: "The effect was small.", 9: "The effect was small."})
    tex_path, jsonl = write_case(tmp_path, tex, [prop(1, "The effect was small.", "main.tex:L9")])
    data = report(run(tex_path, "3-9", jsonl))
    assert [(r["start_line"], r["end_line"]) for r in data["uncovered"]] == [(3, 3)]
    assert data["warnings"] == []


def test_equidistant_occurrences_are_a_warning_not_a_guess(tmp_path):
    tex = tex_with({3: "The effect was small.", 5: "The effect was small."})
    tex_path, jsonl = write_case(tmp_path, tex, [prop(1, "The effect was small.", "main.tex:L4")])
    result = run(tex_path, "3-5", jsonl)
    data = report(result)
    assert result.returncode == 1
    assert [w["id"] for w in data["warnings"]] == [ID.format(1)]
    # Lines 3-5 hold no covered text and only a blank line between the two
    # sentences, so the spec's "maximal run" is a single run spanning L3-L5.
    assert [(r["start_line"], r["end_line"]) for r in data["uncovered"]] == [(3, 5)]


def test_props_outside_the_range_or_in_other_files_are_not_candidates(tmp_path):
    tex = tex_with({5: "The effect was small.", 30: "The effect was small."})
    props = [
        prop(1, "The effect was small.", "main.tex:L30"),
        prop(2, "The effect was small.", "parts/other.tex:L5"),
    ]
    tex_path, jsonl = write_case(tmp_path, tex, props)
    data = report(run(tex_path, "5-5", jsonl))
    assert data["candidates"] == 0
    assert len(data["uncovered"]) == 1


def test_unprefixed_location_refers_to_the_main_file(tmp_path):
    tex = tex_with({5: "The effect was small."})
    tex_path, jsonl = write_case(tmp_path, tex, [prop(1, "The effect was small.", "L5")])
    result = run(tex_path, "5-5", jsonl)
    assert result.returncode == 0, result.stdout


def test_part_file_resolved_against_main(tmp_path):
    (tmp_path / "main.tex").write_text("\\input{parts/results}\n")
    tex = tex_with({2: "The effect was small. The sample was large."}, total=4)
    props = [prop(1, "The effect was small.", "parts/results.tex:L2"), prop(2, "The sample was large.", "main.tex:L2")]
    part, jsonl = write_case(tmp_path, tex, props, name="parts/results.tex")
    data = report(run(part, "2-2", jsonl, "--main", str(tmp_path / "main.tex")))
    assert data["candidates"] == 1
    assert len(data["uncovered"]) == 1
    assert "The sample was large" in data["uncovered"][0]["excerpt"]


def test_text_after_an_escaped_percent_sign_is_checked(tmp_path):
    tex = tex_with({6: "About 30\\% of participants finished early."})
    tex_path, jsonl = write_case(tmp_path, tex, [])
    data = report(run(tex_path, "6-6", jsonl))
    assert "of participants finished early" in data["uncovered"][0]["excerpt"]


def test_verbatim_prop_with_escaped_percent_covers_its_line(tmp_path):
    line = "About 30\\% of participants finished early."
    tex_path, jsonl = write_case(tmp_path, tex_with({6: line}), [prop(1, line, "main.tex:L6")])
    result = run(tex_path, "6-6", jsonl)
    assert result.returncode == 0, result.stdout


# ---------- Requirement: Coverage exclusions are a closed set and are reported ----------


def test_heading_followed_by_prose_on_the_same_line(tmp_path):
    tex = tex_with({30: "\\subsubsection{Participants}There were 40 students in this study."})
    tex_path, jsonl = write_case(tmp_path, tex, [])
    data = report(run(tex_path, "30-30", jsonl))
    assert len(data["uncovered"]) == 1
    assert data["uncovered"][0]["start_line"] == 30
    assert "There were 40 students in this study" in data["uncovered"][0]["excerpt"]
    assert "Participants" not in data["uncovered"][0]["excerpt"]


def test_float_is_excluded_and_listed(tmp_path):
    lines = {50: "\\begin{table}", 51: "\\caption{Means of the two groups.}", 60: "A & 1.2 \\\\", 70: "\\end{table}"}
    tex_path, jsonl = write_case(tmp_path, tex_with(lines), [])
    result = run(tex_path, "45-75", jsonl)
    data = report(result)
    assert data["uncovered"] == []
    assert data["excluded"] == [{"kind": "table", "start_line": 50, "end_line": 70}]
    assert result.returncode == 0


def test_float_that_starts_before_the_range_is_still_excluded(tmp_path):
    lines = {40: "\\begin{figure*}", 55: "\\caption{Choice proportions.}", 60: "\\end{figure*}"}
    tex_path, jsonl = write_case(tmp_path, tex_with(lines), [])
    data = report(run(tex_path, "50-65", jsonl))
    assert data["uncovered"] == []
    assert data["excluded"] == [{"kind": "figure*", "start_line": 40, "end_line": 60}]


def test_comments_labels_and_environment_markers_are_excluded(tmp_path):
    lines = {
        10: "% a note to coauthors about wording",
        11: "\\section*{Results}\\label{sec:results}",
        12: "\\begin{theorem}[Main result]",
        13: "\\end{theorem}",
        14: "\\paragraph{Undetermined.}",
    }
    tex_path, jsonl = write_case(tmp_path, tex_with(lines), [])
    result = run(tex_path, "10-14", jsonl)
    assert report(result)["uncovered"] == [], result.stdout
    assert result.returncode == 0


def test_label_inside_prose_does_not_hide_the_prose(tmp_path):
    tex = tex_with({7: "The effect was small.\\label{res:small} The sample was large."})
    tex_path, jsonl = write_case(tmp_path, tex, [prop(1, "The effect was small.", "main.tex:L7")])
    data = report(run(tex_path, "7-7", jsonl))
    assert len(data["uncovered"]) == 1
    assert "The sample was large" in data["uncovered"][0]["excerpt"]
    assert "res:small" not in data["uncovered"][0]["excerpt"]


# ---------- Output shape and exit codes ----------


def test_json_output_shape(tmp_path):
    tex_path, jsonl = write_case(tmp_path, tex_with({3: "The effect was small."}), [])
    data = report(run(tex_path, "3-3", jsonl))
    assert set(data) == {"tex", "lines", "candidates", "uncovered", "excluded", "warnings"}
    assert data["lines"] == [3, 3]
    assert set(data["uncovered"][0]) == {"start_line", "end_line", "excerpt"}


def test_text_output_names_lines_and_exit_code(tmp_path):
    tex_path, jsonl = write_case(tmp_path, tex_with({3: "The effect was small."}), [])
    result = run(tex_path, "3-3", jsonl, fmt="text")
    assert result.returncode == 1
    assert "L3" in result.stdout
    assert "The effect was small" in result.stdout


@pytest.mark.parametrize("lines", ["5-3", "0-2", "3", "abc", "1-999"])
def test_invalid_range_exits_2(tmp_path, lines):
    tex_path, jsonl = write_case(tmp_path, tex_with({3: "x"}), [])
    result = run(tex_path, lines, jsonl)
    assert result.returncode == 2
    assert result.stdout == ""
    assert "--lines" in result.stderr  # names the bad argument (a missing script also exits 2)


def test_missing_tex_exits_2(tmp_path):
    _, jsonl = write_case(tmp_path, tex_with({}), [])
    result = run(tmp_path / "nope.tex", "1-2", jsonl)
    assert result.returncode == 2
    assert "nope.tex" in result.stderr


def test_unparsable_jsonl_exits_2(tmp_path):
    tex_path, jsonl = write_case(tmp_path, tex_with({3: "x"}), [])
    jsonl.write_text("{not json\n")
    result = run(tex_path, "3-3", jsonl)
    assert result.returncode == 2
    assert "line 1" in result.stderr


def test_retired_props_are_not_candidates(tmp_path):
    # A retired prop describes text that is no longer in the paper; it must not
    # count as covering the passage that replaced it.
    tex = tex_with({5: "The effect was small."})
    retired = prop(1, "The effect was small.", "main.tex:L5")
    retired["retired"] = {"mechanism": "rewrite", "match": "verbatim", "reason": "passage rewritten"}
    tex_path, jsonl = write_case(tmp_path, tex, [retired])
    result = run(tex_path, "5-5", jsonl)
    data = report(result)
    assert data["candidates"] == 0
    assert len(data["uncovered"]) == 1
    assert result.returncode == 1
