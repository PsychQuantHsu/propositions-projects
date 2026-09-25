"""Verification-record sidecar: format, validator, proofread conversion (#12).

The ledger decomposes a manuscript; it does not say whether a claim is true.
Verdicts from external methods live in `verification.jsonl` next to the
ledger, one record per (proposition, method) verdict.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
SCRIPTS = REPO_ROOT / "plugins" / "propositions" / "scripts"
VALIDATE = SCRIPTS / "validate-verification.py"
CONVERT = SCRIPTS / "proofread-to-verification.py"


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


vv = _load("validate_verification", VALIDATE)
pv = _load("proofread_to_verification", CONVERT)

ID_A = "01910b9c-d4f0-7000-8000-0123456789ab"
ID_B = "01910b9c-d4f0-7001-8000-0123456789ab"
ID_C = "0192aaaa-0000-7000-8000-000000000000"
LEDGER_IDS = {ID_A, ID_B, ID_C}
LEDGER = [{"id": ID_A, "text": "First claim holds for all n."},
          {"id": ID_B, "text": "Second, define the operator T."},
          {"id": ID_C, "text": "Third remark on\n  notation."}]


def rec(prop_id=ID_A, method="lean", status="supported", checked_at="2026-09-25",
        evidence_ref="proofs/Main.lean:thm_a", **extra):
    r = {"prop_id": prop_id, "method": method, "status": status,
         "checked_at": checked_at, **extra}
    if evidence_ref is not None:
        r["evidence_ref"] = evidence_ref
    return r


def codes(records, ledger_ids=LEDGER_IDS):
    lines = [(i + 1, r, None) for i, r in enumerate(records)]
    errors, warnings = vv.check_records(lines, ledger_ids)
    return [e[0] for e in errors], [w[0] for w in warnings]


def write(tmp_path, records, ledger=LEDGER):
    ledger_path = tmp_path / "main.jsonl"
    ledger_path.write_text("".join(json.dumps(p) + "\n" for p in ledger))
    sidecar = tmp_path / "verification.jsonl"
    sidecar.write_text("".join((r if isinstance(r, str) else json.dumps(r)) + "\n"
                               for r in records))
    return sidecar, ledger_path


def run_validate(sidecar, ledger):
    return subprocess.run([sys.executable, str(VALIDATE), "--records", str(sidecar),
                           "--ledger", str(ledger)], capture_output=True, text=True)


# ---- Verification record format ----

def test_several_methods_on_one_proposition_are_valid():
    errors, _ = codes([rec(method="proofread", evidence_ref=".proofread/main.md:L12"),
                       rec(method="lean")])
    assert errors == []


def test_empty_sidecar_is_valid(tmp_path):
    sidecar, ledger = write(tmp_path, [])
    assert run_validate(sidecar, ledger).returncode == 0


def test_missing_required_key_is_v1():
    r = rec()
    del r["checked_at"]
    assert codes([r])[0] == ["V1"]


def test_malformed_json_is_v1(tmp_path):
    sidecar, ledger = write(tmp_path, ["{not json"])
    r = run_validate(sidecar, ledger)
    assert r.returncode == 1 and "[V1] L1" in r.stdout


# ---- Method and status vocabulary ----

def test_custom_x_method_accepted():
    assert codes([rec(method="x-monte-carlo")])[0] == []


def test_unknown_method_rejected_with_allowed_values(tmp_path):
    sidecar, ledger = write(tmp_path, [rec(method="leanprover")])
    r = run_validate(sidecar, ledger)
    assert r.returncode == 1
    assert "[V3] L1" in r.stdout and "proofread" in r.stdout and "x-" in r.stdout


def test_unknown_status_rejected():
    assert codes([rec(status="proved")])[0] == ["V3"]


# ---- Validator checks ----

def test_dangling_proposition_id_is_v2(tmp_path):
    sidecar, ledger = write(tmp_path, [rec(prop_id="0199ffff-0000-7000-8000-000000000000")])
    r = run_validate(sidecar, ledger)
    assert r.returncode == 1 and "[V2] L1" in r.stdout


def test_bad_date_is_v4():
    assert codes([rec(checked_at="2026-02-30")])[0] == ["V4"]
    assert codes([rec(checked_at="25/09/2026")])[0] == ["V4"]


def test_verdict_without_evidence_is_v5(tmp_path):
    sidecar, ledger = write(tmp_path, [rec(evidence_ref=None)])
    r = run_validate(sidecar, ledger)
    assert r.returncode == 1 and "[V5] L1" in r.stdout
    assert codes([rec(evidence_ref="  ")])[0] == ["V5"]


def test_not_attempted_needs_no_evidence():
    assert codes([rec(status="not_attempted", evidence_ref=None)])[0] == []


def test_duplicate_record_is_v6_warning_only():
    errors, warnings = codes([rec(), rec()])
    assert errors == [] and warnings == ["V6"]


def test_usage_error_exits_2(tmp_path):
    r = subprocess.run([sys.executable, str(VALIDATE), "--records", str(tmp_path / "nope.jsonl"),
                        "--ledger", str(tmp_path / "nope2.jsonl")], capture_output=True, text=True)
    assert r.returncode == 2


def test_ledger_untouched_by_sidecar(tmp_path):
    # validate-propositions.py never reads verification.jsonl.
    src = (SCRIPTS / "validate-propositions.py").read_text()
    assert "verification.jsonl" not in src


# ---- Cross-method disagreement report ----

def test_lean_supports_proofread_partial_is_reported(tmp_path):
    records = [rec(method="lean", status="supported"),
               rec(method="proofread", status="partial", evidence_ref=".proofread/m.md:L3")]
    found = vv.disagreements(records)
    assert found == [(ID_A, {"lean": "supported", "proofread": "partial"})]
    sidecar, ledger = write(tmp_path, records)
    r = run_validate(sidecar, ledger)
    assert r.returncode == 0
    assert "disagreement" in r.stdout and "lean=supported" in r.stdout and "proofread=partial" in r.stdout


def test_latest_record_wins_within_a_method():
    records = [rec(method="cas", status="refuted", checked_at="2026-09-01"),
               rec(method="cas", status="supported", checked_at="2026-09-20"),
               rec(method="lean", status="supported")]
    assert vv.disagreements(records) == []


def test_same_day_later_line_wins():
    records = [rec(method="cas", status="supported", checked_at="2026-09-20"),
               rec(method="cas", status="refuted", checked_at="2026-09-20", evidence_ref="cas/run2"),
               rec(method="lean", status="supported")]
    assert vv.disagreements(records) == [(ID_A, {"cas": "refuted", "lean": "supported"})]


def test_unresolved_is_not_a_disagreement():
    records = [rec(method="lean", status="supported"),
               rec(method="cas", status="unresolved", evidence_ref="cas/run1")]
    assert vv.disagreements(records) == []


# ---- Proofread checklist conversion ----

CHECKLIST = """# Proofread — main.tex

## sec:intro

- [x] **P001** `01910b9c-d4f0-7000` [claim] @L10-L12 — "First claim holds…" (asserts: 1, cites: 0)
- [~] **P002** `01910b9c-d4f0-7001` [definition] @L14-L15 — "Second, define…" (asserts: 2, cites: 1)
- [-] **P003** `0192aaaa` [remark] @L20-L20 — "Third remark on notation..." (asserts: 0, cites: 0)
- [ ] **P004** `0192aaaa` [remark] @L21-L21 — "Unwalked…" (asserts: 0, cites: 0)

## Findings

| Prop | Level | Note |
|---|---|---|
| P002 | L2 | claim_type should be claim |
"""


def test_checklist_marks_map_to_statuses():
    records, problems, _ = pv.convert(CHECKLIST, ".proofread/main.md", LEDGER,
                                   checked_at="2026-09-25", checker="che")
    assert problems == []
    got = [(r["prop_id"], r["status"], r["evidence_ref"]) for r in records]
    assert got == [(ID_A, "supported", ".proofread/main.md:L5"),
                   (ID_B, "partial", ".proofread/main.md:L6"),
                   (ID_C, "not_attempted", ".proofread/main.md:L7")]
    assert all(r["method"] == "proofread" and r["checked_at"] == "2026-09-25"
               and r["checker"] == "che" for r in records)


def test_shared_uuidv7_prefix_is_resolved_by_the_text_snippet():
    # UUIDv7 ids minted in one batch share their leading timestamp, so the
    # 8-hex `uuid_short` alone is ambiguous on real ledgers.
    text = ('- [x] **P002** `01910b9c` [definition] @L1-L1 — "Second, define..." (asserts: 1, cites: 0)\n'
            '- [x] **P001** `01910b9c` [claim] @L2-L2 — "First claim..." (asserts: 1, cites: 0)\n')
    records, problems, _ = pv.convert(text, "c.md", LEDGER, checked_at="2026-09-25")
    assert problems == []
    assert [r["prop_id"] for r in records] == [ID_B, ID_A]


def test_same_prefix_and_snippet_falls_back_to_the_ordinal():
    twins = [{"id": ID_A, "text": "Same start, then A."},
             {"id": ID_B, "text": "Same start, then B."}]
    text = '- [x] **P002** `01910b9c` [claim] @L1-L1 — "Same start..." (asserts: 1, cites: 0)\n'
    records, problems, _ = pv.convert(text, "c.md", twins, checked_at="2026-09-25",
                                   ordinals={ID_A: "P001", ID_B: "P002"})
    assert problems == [] and [r["prop_id"] for r in records] == [ID_B]


def test_ambiguous_line_aborts_with_no_output(tmp_path):
    twins = [{"id": ID_A, "text": "Same start, then A."},
             {"id": ID_B, "text": "Same start, then B."}]
    text = '- [x] **P009** `01910b9c` [claim] @L1-L1 — "Same start..." (asserts: 1, cites: 0)\n'
    records, problems, _ = pv.convert(text, "c.md", twins, checked_at="2026-09-25",
                                   ordinals={ID_A: "P001", ID_B: "P002"})
    assert records == [] and len(problems) == 1 and "L1" in problems[0]
    checklist = tmp_path / "c.md"
    checklist.write_text(text)
    _, ledger = write(tmp_path, [], ledger=twins)
    r = subprocess.run([sys.executable, str(CONVERT), "--checklist", str(checklist),
                        "--ledger", str(ledger)], capture_output=True, text=True)
    assert r.returncode == 1 and r.stdout == "" and "L1" in r.stderr


def test_unknown_prefix_aborts():
    text = '- [x] **P001** `deadbeef` [claim] @L1-L1 — "First claim..." (asserts: 1, cites: 0)\n'
    records, problems, _ = pv.convert(text, "c.md", LEDGER, checked_at="2026-09-25")
    assert records == [] and problems


def test_snippet_that_matches_no_candidate_aborts():
    # Right prefix, but the text changed since the checklist was generated.
    text = '- [x] **P001** `01910b9c-d4f0-7000` [claim] @L1-L1 — "Rewritten claim..." (asserts: 1, cites: 0)\n'
    records, problems, _ = pv.convert(text, "c.md", LEDGER, checked_at="2026-09-25")
    assert records == [] and problems


def test_converted_output_passes_the_validator(tmp_path):
    checklist = tmp_path / "main.md"
    checklist.write_text(CHECKLIST)
    _, ledger = write(tmp_path, [])
    conv = subprocess.run([sys.executable, str(CONVERT), "--checklist", str(checklist),
                           "--ledger", str(ledger), "--checked-at", "2026-09-25"],
                          capture_output=True, text=True)
    assert conv.returncode == 0, conv.stderr
    sidecar = tmp_path / "verification.jsonl"
    sidecar.write_text(conv.stdout)
    assert run_validate(sidecar, ledger).returncode == 0


# ---- Documentation stays in step with the code ----

def test_verification_doc_lists_every_vocabulary_value():
    doc = (REPO_ROOT / "plugins" / "propositions" / "docs" / "VERIFICATION.md").read_text()
    for value in (*vv.METHODS, *vv.STATUSES, "x-"):
        assert f"`{value}`" in doc, value


def test_allow_unmatched_skips_rewritten_text_but_not_ambiguity():
    stale = '- [x] **P001** `01910b9c-d4f0-7000` [claim] @L1-L1 — "Rewritten claim..." (asserts: 1, cites: 0)\n'
    ok = '- [x] **P002** `01910b9c` [definition] @L2-L2 — "Second, define..." (asserts: 1, cites: 0)\n'
    records, problems, skipped = pv.convert(stale + ok, "c.md", LEDGER,
                                            checked_at="2026-09-25", allow_unmatched=True)
    assert problems == [] and [r["prop_id"] for r in records] == [ID_B]
    assert len(skipped) == 1 and "L1" in skipped[0]
    twins = [{"id": ID_A, "text": "Same start, then A."},
             {"id": ID_B, "text": "Same start, then B."}]
    amb = '- [x] **P009** `01910b9c` [claim] @L1-L1 — "Same start..." (asserts: 1, cites: 0)\n'
    records, problems, _ = pv.convert(amb, "c.md", twins, checked_at="2026-09-25",
                                      allow_unmatched=True)
    assert records == [] and problems
