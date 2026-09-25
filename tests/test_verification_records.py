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

CHECKLIST = f"""# Proofread — main.tex

## sec:intro

- [x] **P001** `{ID_A}` [claim] @L10-L12 — "First claim holds…" (asserts: 1, cites: 0)
- [~] **P002** `{ID_B}` [definition] @L14-L15 — "Second, define…" (asserts: 2, cites: 1)
- [-] **P003** `{ID_C}` [remark] @L20-L20 — "Third remark on notation..." (asserts: 0, cites: 0)
- [ ] **P004** `0192aaaa` [remark] @L21-L21 — "Unwalked…" (asserts: 0, cites: 0)

## Findings

| Prop | Level | Note |
|---|---|---|
| P002 | L2 | claim_type should be claim |
"""


def line(mark, pid, snippet, tail=" (asserts: 1, cites: 0)"):
    return f'- [{mark}] **P001** `{pid}` [claim] @L1-L1 — "{snippet}"{tail}\n'


def convert(text, ledger=LEDGER, **kw):
    return pv.convert(text, "c.md", ledger, checked_at="2026-09-25", **kw)


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


def test_full_id_with_rewritten_text_is_unmatched():
    records, problems, _ = convert(line("x", ID_A, "Rewritten claim..."))
    assert records == [] and problems
    records, problems, skipped = convert(line("x", ID_A, "Rewritten claim..."), allow_unmatched=True)
    assert records == [] and problems == [] and len(skipped) == 1


def test_short_prefix_with_truncated_snippet_is_never_guessed():
    # verify #12 round 2: the reviewed proposition was rewritten away, and
    # another one sharing the prefix happens to start with the same words.
    ledger = [{"id": ID_B, "text": "Foo bard is a different claim entirely."}]
    records, problems, _ = convert(line("x", "01910b9c", "Foo bar…"), ledger=ledger)
    assert records == [] and problems and "full ids" in problems[0]
    records, problems, skipped = convert(line("x", "01910b9c", "Foo bar…"), ledger=ledger,
                                         allow_unmatched=True)
    assert records == [] and problems == [] and skipped


def test_short_prefix_is_never_resolved_even_with_whole_text():
    # verify #12 round 3: the walked proposition was rewritten and a sibling
    # sharing the prefix now holds its old text; whole-text equality picked
    # the sibling. Content says what a proposition says now, not which one
    # the reviewer walked.
    records, problems, _ = convert(line("x", "01910b9c", "Second, define the operator T."))
    assert records == [] and problems and "full ids" in problems[0]


def test_reviewer_note_after_the_snippet_does_not_break_resolution():
    ledger = [{"id": ID_A, "text": "Alpha claim about convergence rate."},
              {"id": ID_B, "text": "Beta remark about a completely different notation."}]
    text = f'- [x] **P002** `{ID_A}` [claim] @L10-L12 — "Alpha claim about convergence" [see finding #3]\n'
    records, problems, _ = convert(text, ledger=ledger)
    assert problems == [] and [r["prop_id"] for r in records] == [ID_A]


def test_quoted_reviewer_note_does_not_swallow_the_snippet():
    text = line("x", ID_A, "First claim holds…", tail=' (asserts: 1, cites: 0) — reviewer: "looks fine"')
    records, problems, _ = convert(text)
    assert problems == [] and [r["prop_id"] for r in records] == [ID_A]


def test_walked_line_without_a_snippet_aborts():
    text = f"- [x] **P001** `{ID_A}` [claim] @L10-L12\n"
    records, problems, _ = convert(text, allow_unmatched=True)
    assert records == [] and problems and "snippet" in problems[0]


def test_curly_quotes_and_en_dash_are_read():
    text = f"- [x] **P001** `{ID_A}` [claim] @L1-L1 \u2013 \u201cFirst claim holds\u2026\u201d (asserts: 1, cites: 0)\n"
    records, problems, _ = convert(text)
    assert problems == [] and [r["prop_id"] for r in records] == [ID_A]


def test_ledger_prop_with_null_text_does_not_crash():
    ledger = LEDGER + [{"id": "0192bbbb-0000-7000-8000-000000000000", "text": None}]
    records, problems, _ = pv.convert(CHECKLIST, "c.md", ledger, checked_at="2026-09-25")
    assert problems == [] and len(records) == 3


def test_ambiguous_or_unidentifiable_line_writes_nothing(tmp_path):
    checklist = tmp_path / "c.md"
    checklist.write_text(line("x", "01910b9c", "First claim…"))
    _, ledger = write(tmp_path, [])
    r = subprocess.run([sys.executable, str(CONVERT), "--checklist", str(checklist),
                        "--ledger", str(ledger)], capture_output=True, text=True)
    assert r.returncode == 1 and r.stdout == "" and "L1" in r.stderr


def test_unknown_id_aborts():
    records, problems, _ = convert(line("x", "deadbeef-0000-7000-8000-000000000000", "First claim..."))
    assert records == [] and problems


def test_checked_at_must_be_the_dashed_form(tmp_path):
    checklist = tmp_path / "main.md"
    checklist.write_text(CHECKLIST)
    _, ledger = write(tmp_path, [])
    r = subprocess.run([sys.executable, str(CONVERT), "--checklist", str(checklist),
                        "--ledger", str(ledger), "--checked-at", "20260925"],
                       capture_output=True, text=True)
    assert r.returncode == 2 and r.stdout == ""


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


def test_non_string_fields_are_v1_not_a_crash(tmp_path):
    bad = [rec(prop_id=[ID_A]), rec(status="not_attempted", evidence_ref=["x"]), rec(checked_at=20260925)]
    for r in bad:
        assert codes([r])[0] == ["V1"], r
    sidecar, ledger = write(tmp_path, bad)
    assert run_validate(sidecar, ledger).returncode == 1


def test_bom_on_the_sidecar_is_tolerated(tmp_path):
    sidecar, ledger = write(tmp_path, [rec()])
    sidecar.write_bytes(b"\xef\xbb\xbf" + sidecar.read_bytes())
    assert run_validate(sidecar, ledger).returncode == 0


def test_full_id_duplicated_in_the_ledger_aborts():
    dup = [{"id": ID_A, "text": "First claim holds for all n."},
           {"id": ID_A, "text": "First claim holds, restated."}]
    records, problems, _ = convert(line("x", ID_A, "First claim holds…"), ledger=dup,
                                   allow_unmatched=True)
    assert records == [] and problems
