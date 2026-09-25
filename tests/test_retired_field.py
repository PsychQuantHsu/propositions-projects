"""Schema-1.4 `retired` field support in R1 / R13 (#1).

A prop whose source passage was deliberately disabled keeps its place in the
ledger with a `retired` block. Its visibility to R1 depends on HOW it was
disabled (SCHEMA.md `retired` section):

- `line_comment` / `removed` — the text is gone from what R1 reads, so R1
  would fail. That absence is expected, and must be reported separately and
  NOT counted as an error.
- `comment_env` — the text is still in the source, so R1 passes; if the text
  has actually vanished that is a real failure and must still block.

A malformed `retired` block must never buy an exemption.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "scripts" / "validate-propositions.py"  # root shim (CI contract)
_SPEC = importlib.util.spec_from_file_location(
    "validate_propositions",
    REPO_ROOT / "plugins" / "propositions" / "scripts" / "validate-propositions.py",
)
vp = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(vp)

TEX = "\\section{S}\nLive sentence stays.\n\\begin{comment}\nParked sentence.\n\\end{comment}\n"


def retired(mechanism, **extra):
    block = {"since": "2026-07-29", "mechanism": mechanism, "match": "exact",
             "reason": "disabled by author"}
    block.update(extra)
    return block


def prop(pid, text, loc="L2", **extra):
    return {"id": pid, "text": text, "location": loc, **extra}


def test_live_missing_text_is_still_an_error():
    errors, retired_absent, _ = vp.check_iso([prop("a", "Gone sentence.")], TEX)
    assert [e[0] for e in errors] == ["a"]
    assert retired_absent == []


def test_removed_and_line_comment_are_expected_absent_not_errors():
    props = [prop("a", "Gone sentence.", retired=retired("removed")),
             prop("b", "Also gone.", retired=retired("line_comment"))]
    errors, retired_absent, _ = vp.check_iso(props, TEX)
    assert errors == []
    assert sorted(r[0] for r in retired_absent) == ["a", "b"]


def test_comment_env_with_vanished_text_still_blocks():
    props = [prop("a", "Vanished from comment env.", retired=retired("comment_env"))]
    errors, retired_absent, _ = vp.check_iso(props, TEX)
    assert [e[0] for e in errors] == ["a"]
    assert retired_absent == []


def test_comment_env_with_present_text_passes():
    props = [prop("a", "Parked sentence.", retired=retired("comment_env"))]
    errors, retired_absent, warnings = vp.check_iso(props, TEX)
    assert errors == [] and retired_absent == [] and warnings == []


def test_retired_removed_but_text_still_present_warns_stale_marker():
    props = [prop("a", "Live sentence stays.", retired=retired("removed"))]
    errors, retired_absent, warnings = vp.check_iso(props, TEX)
    assert errors == [] and retired_absent == []
    assert [w[0] for w in warnings] == ["a"]


def test_unknown_mechanism_buys_no_exemption():
    props = [prop("a", "Gone sentence.", retired=retired("deleted"))]
    errors, retired_absent, _ = vp.check_iso(props, TEX)
    assert [e[0] for e in errors] == ["a"]
    assert "mechanism" in errors[0][1]
    assert retired_absent == []


def test_missing_required_key_buys_no_exemption():
    block = retired("removed")
    del block["reason"]
    errors, retired_absent, _ = vp.check_iso([prop("a", "Gone.", retired=block)], TEX)
    assert [e[0] for e in errors] == ["a"]
    assert retired_absent == []


def test_r13_skips_expected_absent_retired_props():
    props = [prop("a", "Gone.", loc="parts/x.tex:L1", retired=retired("removed"))]
    corpus = {None: TEX, "parts/x.tex": "Other text.\n"}
    warnings, unanchorable, failures = vp.check_location_anchoring(
        props, TEX, corpus=corpus, schema_ge_16=True, expected_absent_ids={"a"})
    assert warnings == [] and failures == []


def test_r13_does_not_skip_a_retired_prop_r1_did_not_confirm_absent():
    # A `retired` marker alone must not buy an R13 skip: only ids R1 found
    # actually absent do. Here the blocking prefix check must still fire.
    props = [prop("a", "Live sentence stays.", loc="parts/x.tex:L1",
                  retired=retired("removed"))]
    corpus = {None: TEX, "parts/x.tex": "Other text.\n"}
    _, _, failures = vp.check_location_anchoring(props, TEX, corpus=corpus,
                                                 schema_ge_16=False)
    assert [f[0] for f in failures] == ["a"]


def _run(tmp_path, props):
    tex = tmp_path / "main.tex"
    tex.write_text(TEX)
    jsonl = tmp_path / "main.jsonl"
    jsonl.write_text("".join(json.dumps(p) + "\n" for p in props))
    meta = tmp_path / "_meta.json"
    meta.write_text(json.dumps({"schema_version": "1.6", "source": {"file": "main.tex"}}))
    return subprocess.run([sys.executable, str(SCRIPT), "--jsonl", str(jsonl),
                           "--meta", str(meta), "--tex", str(tex)],
                          capture_output=True, text=True)


UUID_A = "01910b9c-d4f0-7000-8000-0123456789ab"
UUID_B = "01910b9c-d4f0-7001-8000-0123456789ab"
BASE = {"containing_block": "sec:s", "claim_type": "claim", "asserts": ["x"],
        "cites": [], "evidence_class": "verified"}


def test_end_to_end_retired_absence_passes_and_is_reported(tmp_path):
    props = [{**BASE, "id": UUID_A, "text": "Live sentence stays.", "location": "L2"},
             {**BASE, "id": UUID_B, "text": "Gone sentence.", "location": "L2",
              "cites": [UUID_A], "retired": retired("removed")}]
    r = _run(tmp_path, props)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "retired" in r.stdout and "expected-absent" in r.stdout


def test_end_to_end_live_absence_still_fails(tmp_path):
    props = [{**BASE, "id": UUID_A, "text": "Gone sentence.", "location": "L2"}]
    r = _run(tmp_path, props)
    assert r.returncode == 1


COMMENTED = "%This assumption is local.\n"  # real ledger shape: `%` + trailing newline


def test_comment_line_text_retired_is_expected_absent_while_still_commented():
    props = [prop("a", COMMENTED, retired=retired("line_comment"))]
    errors, retired_absent, warnings = vp.check_iso(props, TEX + COMMENTED)
    assert errors == [] and warnings == []
    assert [r[0] for r in retired_absent] == ["a"]


def test_restored_comment_line_is_a_stale_marker_in_both_stored_shapes():
    # The author un-commented the line: the claim is back in the paper, so the
    # `retired` marker is stale — for text stored with or without the newline.
    for text in (COMMENTED, COMMENTED.rstrip("\n")):
        props = [prop("a", text, retired=retired("line_comment"))]
        errors, retired_absent, warnings = vp.check_iso(
            props, TEX + "This assumption is local.\n")
        assert errors == [] and retired_absent == [], text
        assert [w[0] for w in warnings] == ["a"], text


def test_live_commented_text_absent_from_the_paper_is_an_error():
    errors, retired_absent, warnings = vp.check_iso([prop("a", "%Only a comment.\n")], TEX)
    assert [e[0] for e in errors] == ["a"] and retired_absent == [] and warnings == []


def test_comment_env_commented_text_that_vanished_still_blocks():
    props = [prop("a", "%Only a comment.\n", retired=retired("comment_env"))]
    errors, retired_absent, _ = vp.check_iso(props, "")
    assert [e[0] for e in errors] == ["a"] and retired_absent == []


def test_text_with_no_words_is_an_error():
    errors, _, _ = vp.check_iso([prop("a", "%\n")], TEX)
    assert [e[0] for e in errors] == ["a"]
    assert "empty" in errors[0][1]


def test_malformed_values_buy_no_exemption():
    bad = [dict(since=[1]), dict(since="2026/07/29"), dict(match="bogus"),
           dict(match=1), dict(reason="   "), dict(reason=["x"]),
           dict(mechanism="Removed"), dict(mechanism=["removed"])]
    for override in bad:
        block = {**retired("removed"), **override}
        props = [prop("a", "Gone sentence.", retired=block)]
        errors, retired_absent, _ = vp.check_iso(props, TEX)
        assert [e[0] for e in errors] == ["a"], override
        assert retired_absent == [], override
