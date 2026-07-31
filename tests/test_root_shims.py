"""Shim smoke tests (umbrella-marketplace-migration task 1.1).

Root-level scripts/ entries are forwarding shims; the single implementation
lives under plugins/propositions/scripts/. These tests assert the shim layer
is byte-transparent for the pinned CI entry-point contract: identical exit
codes and equivalent output for the same fixture input, whichever entry is
invoked (spec: umbrella-marketplace-layout, "Root-level CI entry shims").
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CORE_SCRIPTS = REPO_ROOT / "plugins" / "propositions" / "scripts"
ROOT_SCRIPTS = REPO_ROOT / "scripts"
FIXTURES = REPO_ROOT / "tests" / "fixtures" / "_smoke_tests"


def _run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def _make_manuscript(tmp_path: Path) -> Path:
    """Assemble a minimal manuscript root from the duplicate_id fixture."""
    root = tmp_path / "manuscript"
    (root / "propositions").mkdir(parents=True)
    (tmp_path / "analysis").mkdir()  # run-audit.sh requires a code root
    shutil.copy(FIXTURES / "duplicate_id.tex", root / "main.tex")
    shutil.copy(FIXTURES / "duplicate_id.jsonl", root / "propositions" / "main.jsonl")
    shutil.copy(FIXTURES / "duplicate_id_meta.json", root / "propositions" / "_meta.json")
    return root


def test_core_implementation_exists():
    """The single implementation lives under plugins/propositions/scripts/."""
    assert (CORE_SCRIPTS / "run-audit.sh").exists(), "core run-audit.sh missing"
    assert (CORE_SCRIPTS / "validate-propositions.py").exists(), (
        "core validate-propositions.py missing"
    )
    assert (CORE_SCRIPTS / "_lib" / "latex_env_parser.py").exists(), (
        "core _lib missing"
    )


def test_validate_propositions_shim_transparent():
    """Root shim and core script agree on exit code and stdout."""
    fixture_args = [
        "--jsonl", str(FIXTURES / "duplicate_id.jsonl"),
        "--tex", str(FIXTURES / "duplicate_id.tex"),
        "--meta", str(FIXTURES / "duplicate_id_meta.json"),
    ]
    root = _run([sys.executable, str(ROOT_SCRIPTS / "validate-propositions.py"), *fixture_args], REPO_ROOT)
    core = _run([sys.executable, str(CORE_SCRIPTS / "validate-propositions.py"), *fixture_args], REPO_ROOT)
    assert root.returncode == core.returncode, (
        f"exit codes differ: root={root.returncode} core={core.returncode}\n"
        f"root stderr: {root.stderr[-500:]}\ncore stderr: {core.stderr[-500:]}"
    )
    assert root.stdout == core.stdout, "stdout differs between shim and core"


def _exit_codes_line(manuscript_root: Path) -> str:
    reports = sorted((manuscript_root / "docs" / "audit").glob("audit-*.md"))
    assert reports, "no audit report produced"
    text = reports[-1].read_text()
    m = re.search(r"^\*\*Exit codes\*\*.*$", text, re.M)
    assert m, "report lacks Exit codes line"
    return m.group(0)


def test_run_audit_shim_transparent(tmp_path):
    """Root run-audit.sh shim and core implementation produce the same
    audit-chain verdict (exit code + report Exit-codes line) for one fixture."""
    ms_root = _make_manuscript(tmp_path / "via_root")
    ms_core = _make_manuscript(tmp_path / "via_core")

    root = _run(
        [str(ROOT_SCRIPTS / "run-audit.sh"), str(ms_root),
         "--code-root", str(ms_root.parent / "analysis")], REPO_ROOT)
    core = _run(
        [str(CORE_SCRIPTS / "run-audit.sh"), str(ms_core),
         "--code-root", str(ms_core.parent / "analysis")], REPO_ROOT)

    assert root.returncode == core.returncode, (
        f"exit codes differ: root={root.returncode} core={core.returncode}\n"
        f"root stderr: {root.stderr[-500:]}\ncore stderr: {core.stderr[-500:]}"
    )
    assert _exit_codes_line(ms_root) == _exit_codes_line(ms_core), (
        "audit report Exit-codes line differs between shim and core"
    )
