"""tschema-check: source-fidelity records and their validator (#4).

R1 checks that a ledger's text is a substring of the manuscript it indexes.
tschema-check generalizes the source: a statement must be in the checked
document (T2/T3), and the evidence quoted for it must be in the EXTERNAL
source it names (T4).
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
PLUGIN = REPO_ROOT / "plugins" / "tschema-check"
SCRIPT = PLUGIN / "scripts" / "validate-tschema.py"
_SPEC = importlib.util.spec_from_file_location("validate_tschema", SCRIPT)
vt = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(vt)

ID1 = "01920000-0000-7000-8000-000000000001"
ID2 = "01920000-0000-7000-8000-000000000002"
ID3 = "01920000-0000-7000-8000-000000000003"

DOC = (
    "# 會議記錄\n"                                   # L1
    "\n"                                             # L2
    "- 與會者同意先以既有資料評估可行性，\n"          # L3
    "  再決定是否擴大收案。\n"                        # L4
    "- 下次會議請主計室說明報帳流程。\n"              # L5
)
SRT = (
    "1\n00:05:30,000 --> 00:05:33,000\n我們先用手上的資料看看\n\n"
    "2\n00:05:33,000 --> 00:05:36,000\n可不可行，再說要不要擴大\n\n"
)


def claim(cid=ID1, text="與會者同意先以既有資料評估可行性，再決定是否擴大收案。",
          location="L3-L4", support="attested", distance="near", **extra):
    r = {"kind": "claim", "id": cid, "text": text, "location": location,
         "source_support": support, "semantic_distance": distance}
    if support == "attested":
        r.setdefault("evidence", "我們先用手上的資料看看可不可行")
        r.setdefault("source_locator", {"type": "transcript", "ref": "[05:30]",
                                        "path": "sources/meeting.srt"})
    r.update(extra)
    return r


def run(tmp_path, records, doc=DOC, srt=SRT):
    (tmp_path / "sources").mkdir(exist_ok=True)
    (tmp_path / "sources" / "meeting.srt").write_text(srt, encoding="utf-8")
    d = tmp_path / "minutes.md"
    d.write_text(doc, encoding="utf-8")
    rec = tmp_path / "tschema.jsonl"
    rec.write_text("".join((r if isinstance(r, str) else json.dumps(r, ensure_ascii=False)) + "\n"
                           for r in records), encoding="utf-8")
    return subprocess.run([sys.executable, str(SCRIPT), "--records", str(rec),
                           "--document", str(d)], capture_output=True, text=True)


def found(result):
    return {line.split("]")[0] + "]" for line in result.stdout.splitlines()
            if line.startswith("[T")}


# ---- Check record format / vocabulary (T1) ----

def test_valid_claim_passes(tmp_path):
    r = run(tmp_path, [claim()])
    assert r.returncode == 0, r.stdout
    assert found(r) == set()


def test_unknown_kind_is_t1(tmp_path):
    r = run(tmp_path, [{**claim(), "kind": "sentence"}])
    assert r.returncode == 1 and "[T1] L1" in r.stdout


def test_evidence_class_value_is_not_a_source_support(tmp_path):
    r = run(tmp_path, [claim(support="verified", evidence="x")])
    assert r.returncode == 1 and "[T1]" in r.stdout
    for value in ("attested", "doc", "inferred", "unsupported"):
        assert value in r.stdout


def test_bad_locator_type_is_t1(tmp_path):
    r = run(tmp_path, [claim(source_locator={"type": "podcast", "ref": "x", "path": "sources/meeting.srt"})])
    assert "[T1]" in found(r)


def test_malformed_json_is_t1(tmp_path):
    r = run(tmp_path, ["{oops"])
    assert r.returncode == 1 and "[T1] L1" in r.stdout


# ---- Statement containment (T2 / T3) ----

def test_statement_wrapped_across_lines_matches(tmp_path):
    assert found(run(tmp_path, [claim()])) == set()


def test_statement_not_in_document_is_t2(tmp_path):
    r = run(tmp_path, [claim(text="與會者決定立即擴大收案。")])
    assert r.returncode == 1 and "[T2]" in found(r)


def test_statement_at_wrong_location_is_t3_warning(tmp_path):
    r = run(tmp_path, [claim(location="L5")])
    assert r.returncode == 0 and "[T3]" in found(r)


# ---- Evidence containment in the external source (T4) ----

def test_quote_spanning_two_srt_cues_matches(tmp_path):
    assert "[T4]" not in found(run(tmp_path, [claim()]))


def test_fabricated_quote_is_t4(tmp_path):
    r = run(tmp_path, [claim(evidence="我們已經決定擴大收案")])
    assert r.returncode == 1 and "[T4]" in found(r)


def test_missing_source_file_is_t4(tmp_path):
    loc = {"type": "email", "ref": "2026-09-01 來信", "path": "sources/nope.eml"}
    r = run(tmp_path, [claim(source_locator=loc)])
    assert r.returncode == 1 and "[T4]" in found(r)


def test_unverifiable_source_is_counted_not_passed(tmp_path):
    loc = {"type": "email", "ref": "2026-09-01 來信"}
    r = run(tmp_path, [claim(), claim(cid=ID2, text="下次會議請主計室說明報帳流程。",
                                      location="L5", source_locator=loc, evidence="請主計室說明")])
    assert r.returncode == 0
    lines = r.stdout.splitlines()
    assert any("transcript" in l and "1 checked" in l for l in lines)
    assert any("email" in l and "1 not machine-checked" in l for l in lines)


def test_normalize_unifies_width_and_whitespace():
    assert vt.normalize("Ａ　B\n c，") == vt.normalize("AB c,")


def test_strip_srt_keeps_only_text():
    assert vt.strip_srt(SRT).split() == ["我們先用手上的資料看看", "可不可行，再說要不要擴大"]


# ---- Attested claims carry their evidence (T5) ----

def test_attested_without_evidence_is_t5(tmp_path):
    r = run(tmp_path, [claim(evidence="")])
    assert r.returncode == 1 and "[T5]" in found(r)


def test_inferred_needs_no_evidence(tmp_path):
    r = run(tmp_path, [claim(support="inferred")])
    assert r.returncode == 0, r.stdout


# ---- Relation and logic records (T6) ----

def test_valid_relation_passes(tmp_path):
    rel = {"kind": "relation", "id": ID3, "pair": [ID1, ID2],
           "source_relation": "conditional", "rendered_relation": "coordinate"}
    other = claim(cid=ID2, text="下次會議請主計室說明報帳流程。", location="L5", support="inferred")
    assert run(tmp_path, [claim(), other, rel]).returncode == 0


def test_dangling_relation_is_t6(tmp_path):
    rel = {"kind": "relation", "id": ID3, "pair": [ID1, ID2],
           "source_relation": "causal", "rendered_relation": "coordinate"}
    r = run(tmp_path, [claim(), rel])
    assert r.returncode == 1 and "[T6]" in found(r)


def test_logic_target_must_be_a_claim(tmp_path):
    lg = {"kind": "logic", "id": ID3, "target": ID2, "drift_type": "dangling-reference"}
    assert "[T6]" in found(run(tmp_path, [claim(), lg]))


# ---- Verification-failure phrases (T7) ----

def test_failure_state_in_document_warns(tmp_path):
    doc = DOC + "- 該項名稱因錄音不清未能確認。\n"
    r = run(tmp_path, [claim()], doc=doc)
    assert r.returncode == 0 and "[T7] L6" in r.stdout


def test_percent_in_markdown_is_ordinary_text(tmp_path):
    # verify #4: in a Markdown minute a `%` is a percentage, not a comment, and
    # stripping from it hid the very phrase T7 exists to catch.
    doc = DOC + "- 尚有 50% 的項目因錄音不清未能確認。\n"
    assert "[T7] L6" in run(tmp_path, [claim()], doc=doc).stdout


def test_latex_comment_is_ignored_in_tex_documents(tmp_path):
    (tmp_path / "sources").mkdir(exist_ok=True)
    (tmp_path / "sources" / "meeting.srt").write_text(SRT, encoding="utf-8")
    d = tmp_path / "minutes.tex"
    d.write_text(DOC + "% 未能查得出處，待補\n", encoding="utf-8")
    rec = tmp_path / "tschema.jsonl"
    rec.write_text(json.dumps(claim(), ensure_ascii=False) + "\n", encoding="utf-8")
    r = subprocess.run([sys.executable, str(SCRIPT), "--records", str(rec), "--document", str(d)],
                       capture_output=True, text=True)
    assert "[T7]" not in r.stdout


# ---- verify round 1 (#4) ----

def test_absolute_or_escaping_path_is_rejected(tmp_path):
    for bad in ("/etc/passwd", "../../etc/passwd", "sources/../../x.srt"):
        loc = {"type": "other", "ref": "x", "path": bad}
        r = run(tmp_path, [claim(source_locator=loc)])
        assert r.returncode == 1 and "[T1]" in found(r), bad


def test_symlink_out_of_the_records_directory_is_not_read(tmp_path):
    outside = tmp_path.parent / f"{tmp_path.name}-outside.srt"
    outside.write_text(SRT, encoding="utf-8")
    (tmp_path / "sources").mkdir(exist_ok=True)
    (tmp_path / "sources" / "link.srt").symlink_to(outside)
    loc = {"type": "transcript", "ref": "[05:30]", "path": "sources/link.srt"}
    r = run(tmp_path, [claim(source_locator=loc)])
    assert r.returncode == 1 and "[T4]" in found(r)


def test_spoken_number_on_its_own_cue_line_is_kept():
    srt = "1\n00:00:01,000 --> 00:00:02,000\n他在\n\n2\n00:00:02,000 --> 00:00:03,000\n1996\n\n3\n00:00:03,000 --> 00:00:04,000\n年成立公司\n"
    assert vt.normalize("他在1996年成立公司") in vt.normalize(vt.strip_srt(srt))
    assert vt.normalize("他在年成立公司") not in vt.normalize(vt.strip_srt(srt))


def test_too_short_evidence_is_t4(tmp_path):
    r = run(tmp_path, [claim(evidence="資料")])
    assert r.returncode == 1 and "[T4]" in found(r)


def test_path_without_evidence_is_t4_even_when_not_attested(tmp_path):
    loc = {"type": "transcript", "ref": "[05:30]", "path": "sources/meeting.srt"}
    r = run(tmp_path, [claim(support="doc", source_locator=loc)])
    assert r.returncode == 1 and "[T4]" in found(r)


def test_claims_naming_no_source_appear_in_the_summary(tmp_path):
    r = run(tmp_path, [claim(support="inferred")])
    assert any("(no source named)" in l and "1 not machine-checked" in l for l in r.stdout.splitlines())


def test_unhashable_pair_or_target_is_t1_not_a_crash(tmp_path):
    rel = {"kind": "relation", "id": ID3, "pair": [[ID1], {}], "source_relation": "causal",
           "rendered_relation": "none"}
    lg = {"kind": "logic", "id": "01920000-0000-7000-8000-000000000004", "target": [ID1],
          "drift_type": "tautology"}
    r = run(tmp_path, [claim(), rel, lg])
    assert r.returncode == 1 and "Traceback" not in r.stderr and "[T1]" in found(r)


def test_duplicate_id_is_t1(tmp_path):
    r = run(tmp_path, [claim(), claim()])
    assert r.returncode == 1 and "[T1] L2" in r.stdout


def test_bad_location_ranges_are_t1(tmp_path):
    for bad in ("L0", "L5-L3"):
        assert "[T1]" in found(run(tmp_path, [claim(location=bad)])), bad


def test_location_beyond_document_is_named(tmp_path):
    r = run(tmp_path, [claim(location="L90")])
    assert "beyond the end" in r.stdout


def test_bom_on_records_is_tolerated(tmp_path):
    r = run(tmp_path, [claim()])
    rec = tmp_path / "tschema.jsonl"
    rec.write_bytes(b"\xef\xbb\xbf" + rec.read_bytes())
    r = subprocess.run([sys.executable, str(SCRIPT), "--records", str(rec),
                        "--document", str(tmp_path / "minutes.md")], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout


# ---- Exit codes ----

def test_io_error_exits_2(tmp_path):
    r = subprocess.run([sys.executable, str(SCRIPT), "--records", str(tmp_path / "nope.jsonl"),
                        "--document", str(tmp_path / "nope.md")], capture_output=True, text=True)
    assert r.returncode == 2


# ---- Documentation stays in step with the code ----

def test_schema_doc_lists_every_vocabulary_value():
    doc = (PLUGIN / "docs" / "SCHEMA.md").read_text(encoding="utf-8")
    values = (*vt.SOURCE_SUPPORT, *vt.SEMANTIC_DISTANCE, *vt.DRIFT_TYPES,
              *vt.LOCATOR_TYPES, *vt.RELATIONS)
    for value in values:
        assert f"`{value}`" in doc, value
