"""Published payload tracking tests (restore-core-plugin-tracking task 1.1).

`tests/test_marketplace_entries.py` asks whether an entry ships installable
content *on disk*. That question cannot detect the failure this change exists
to fix: an un-anchored `.gitignore` pattern swallowed `plugins/propositions/`,
so the manifest and every skill were present locally and absent from every
clone. `git add` skips ignored paths silently, so nothing ever errored.

These tests ask the only question a consumer cares about — what does a clone
actually contain — by judging the git index rather than the filesystem
(spec: plugin-payload-integrity, design D5).
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST = REPO_ROOT / ".claude-plugin" / "marketplace.json"

# Payload universe = every marketplace entry's `source` directory, unioned with
# the repository-root `skills/` directory. The root directory is included so a
# retired or stray skill re-appearing there is caught as an orphan rather than
# quietly shadowing a shipped one.
#
# `.agents/` is deliberately EXCLUDED: those are spectra harness skills that
# drive the development workflow, not part of the published plugin product.
# Adding a new harness directory must be an explicit decision here — defaulting
# to refuse is safer than defaulting to admit.
ROOT_SKILLS_DIR = REPO_ROOT / "skills"


def _entries() -> list[dict]:
    with MANIFEST.open(encoding="utf-8") as fh:
        return json.load(fh)["plugins"]


def _source_rel(entry: dict) -> str:
    """Normalize a manifest `source` value to a repo-relative posix path."""
    raw = entry["source"].strip()
    if raw.startswith("./"):
        raw = raw[2:]
    return raw.rstrip("/")


def _rel(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT).as_posix()


def _git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def _require_git_work_tree() -> None:
    """Skip loudly when git cannot answer — never let that read as a pass."""
    try:
        proc = _git("rev-parse", "--is-inside-work-tree")
    except FileNotFoundError:
        pytest.skip(
            "git executable not found: whether the payload is tracked is "
            "unverifiable in this environment"
        )
    if proc.returncode != 0 or proc.stdout.strip() != "true":
        pytest.skip(
            "not inside a git work tree (e.g. running from an unpacked "
            "tarball): `git ls-files` cannot answer what a consumer would clone"
        )


def _tracked_paths() -> set[str]:
    proc = _git("ls-files")
    assert proc.returncode == 0, f"`git ls-files` failed: {proc.stderr.strip()}"
    return {line for line in proc.stdout.splitlines() if line}


def _skill_name(skill_md: Path) -> str:
    """Read `name:` from the YAML frontmatter, falling back to the directory."""
    lines = skill_md.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        return skill_md.parent.name
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line.startswith("name:"):
            return line.split(":", 1)[1].strip().strip("\"'")
    return skill_md.parent.name


def _payload_universe() -> list[Path]:
    roots = [REPO_ROOT / _source_rel(entry) for entry in _entries()]
    roots.append(ROOT_SKILLS_DIR)
    found: set[Path] = set()
    for root in roots:
        if root.is_dir():
            found.update(root.rglob("SKILL.md"))
    return sorted(found)


def test_published_manifest_is_tracked():
    """Every entry's plugin manifest must be in the index, not just on disk."""
    _require_git_work_tree()
    tracked = _tracked_paths()
    missing = [
        (entry["name"], f"{_source_rel(entry)}/.claude-plugin/plugin.json")
        for entry in _entries()
        if f"{_source_rel(entry)}/.claude-plugin/plugin.json" not in tracked
    ]
    assert not missing, (
        "marketplace entries whose plugin manifest is not tracked by git "
        "(a consumer resolving this marketplace from the remote cannot "
        "install them):\n"
        + "\n".join(f"  {name}: {path}" for name, path in missing)
    )


def test_published_skills_are_tracked():
    """Every SKILL.md present under a published entry must be in the index."""
    _require_git_work_tree()
    tracked = _tracked_paths()
    untracked: list[tuple[str, str]] = []
    for entry in _entries():
        source_dir = REPO_ROOT / _source_rel(entry)
        for skill_md in sorted(source_dir.glob("skills/*/SKILL.md")):
            rel = _rel(skill_md)
            if rel not in tracked:
                untracked.append((entry["name"], rel))
    assert not untracked, (
        "skill definitions present on disk but absent from the git index:\n"
        + "\n".join(f"  {name}: {path}" for name, path in untracked)
    )


def test_published_source_directories_are_not_ignored():
    """No ignore rule may shadow a published entry's source directory.

    `--no-index` is required: without it git reports an already-tracked path as
    un-ignored, which would let the half-broken "directory is ignored but the
    files were force-added" state pass unnoticed.
    """
    _require_git_work_tree()
    offenders: list[str] = []
    for entry in _entries():
        proc = _git("check-ignore", "--no-index", "-v", _source_rel(entry))
        if proc.returncode == 0:
            offenders.append(f"  {entry['name']}: {proc.stdout.strip()}")
    assert not offenders, (
        "marketplace entry source directories matched by an ignore rule "
        "(format: <ignore-file>:<line>:<pattern>\t<path>):\n"
        + "\n".join(offenders)
        + "\nAn ignore pattern without a leading slash matches a directory of "
        "that name at any depth."
    )


def test_no_duplicate_skill_names():
    """A skill name must resolve to exactly one definition."""
    by_name: dict[str, list[str]] = {}
    for skill_md in _payload_universe():
        by_name.setdefault(_skill_name(skill_md), []).append(_rel(skill_md))
    duplicates = {name: paths for name, paths in by_name.items() if len(paths) > 1}
    assert not duplicates, (
        "skill names with more than one definition (consumers cannot tell "
        "which copy is authoritative):\n"
        + "\n".join(
            f"  {name}: {', '.join(paths)}" for name, paths in sorted(duplicates.items())
        )
    )


def test_entry_version_matches_plugin_manifest():
    """The catalog version and the plugin's own version must agree.

    `claude plugin update` compares versions, not content: when the payload
    changes and the version does not, every already-installed consumer silently
    keeps the stale copy and the command reports "already at the latest
    version". A catalog/manifest mismatch produces the same silence.
    """
    mismatched: list[str] = []
    for entry in _entries():
        manifest = REPO_ROOT / _source_rel(entry) / ".claude-plugin" / "plugin.json"
        if not manifest.is_file():
            continue  # test_published_manifest_is_tracked owns that failure
        with manifest.open(encoding="utf-8") as fh:
            plugin_version = json.load(fh).get("version")
        if entry.get("version") != plugin_version:
            mismatched.append(
                f"  {entry['name']}: marketplace.json={entry.get('version')!r} "
                f"vs {_rel(manifest)}={plugin_version!r}"
            )
    assert not mismatched, (
        "marketplace entry version disagrees with the plugin's own manifest:\n"
        + "\n".join(mismatched)
    )


MD_LINK = re.compile(r"\]\(([^)]+)\)")


def _relative_link_targets(skill_md: Path) -> list[str]:
    """Link targets that claim to be files shipped alongside this skill.

    External URLs and pure anchors address nothing in the payload, so they are
    not this test's business.
    """
    targets = []
    for raw in MD_LINK.findall(skill_md.read_text(encoding="utf-8")):
        target = raw.split()[0].strip().split("#")[0]
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        targets.append(target)
    return targets


def test_shipped_skill_links_resolve_inside_the_payload():
    """A relative link in a shipped skill must land on a file consumers get.

    Skills were authored expecting `rules/` and `docs/` to sit inside the
    plugin; the port left them at the repository root, so every `../../rules/…`
    href in the published copy pointed at nothing. Nothing on the author's disk
    reveals this — the files exist there, one directory up from where the
    installed layout puts them.
    """
    _require_git_work_tree()
    tracked = _tracked_paths()
    broken: list[str] = []
    for entry in _entries():
        entry_dir = (REPO_ROOT / _source_rel(entry)).resolve()
        for skill_md in sorted(entry_dir.glob("skills/*/SKILL.md")):
            for target in _relative_link_targets(skill_md):
                resolved = (skill_md.parent / target).resolve()
                if not resolved.is_relative_to(entry_dir):
                    broken.append(
                        f"  {_rel(skill_md)} → {target} (escapes {_source_rel(entry)}/)"
                    )
                elif _rel(resolved) not in tracked:
                    broken.append(f"  {_rel(skill_md)} → {target} (not in the index)")
    assert not broken, (
        "relative links in published skills that a consumer cannot follow — "
        "either they point outside the installed plugin, or the target is not "
        "tracked and so never reaches a clone:\n" + "\n".join(broken)
    )


def test_no_orphan_skill_outside_published_entries():
    """No SKILL.md in the payload universe may sit outside every entry source."""
    entry_dirs = [(REPO_ROOT / _source_rel(entry)).resolve() for entry in _entries()]
    orphans = [
        _rel(skill_md)
        for skill_md in _payload_universe()
        if not any(skill_md.resolve().is_relative_to(d) for d in entry_dirs)
    ]
    assert not orphans, (
        "skill definitions at paths no marketplace entry claims (they ship to "
        "nobody and shadow the published copies):\n"
        + "\n".join(f"  {path}" for path in orphans)
    )


PROPOSITIONS_SKILL = REPO_ROOT / "plugins" / "propositions" / "skills" / "propositions" / "SKILL.md"


def test_operation_d_scaffolds_an_empty_ledger():
    """A new manuscript must get from Operation D to extraction (#41).

    The validator, the coverage check and extract all open `main.jsonl`, and
    extract's Step 2 raises FileNotFoundError without it. Nothing on an author's
    disk reveals this: the reference manuscripts' ledgers were not built by
    Operation D.
    """
    section = PROPOSITIONS_SKILL.read_text(encoding="utf-8").split("## Operation D", 1)[1]
    listing, rest = section.split("**Dry-run listing.**", 1)[1].split("**Scaffold on confirm.**", 1)
    scaffold = rest.split("**Hand off.**", 1)[0]
    assert "`main.jsonl`" in listing, "the dry-run listing must show every file D creates"
    assert "empty `main.jsonl`" in scaffold, "Operation D must create the ledger file"


# ---------- propositions:analyze (Spectra change add-analyze-entry-skill) ----------
#
# The skill is text a model follows, so these tests pin what it must say: the
# states and their order, the action for each, and the rules that keep it from
# writing or bypassing a confirmation.

ANALYZE_SKILL = REPO_ROOT / "plugins" / "propositions" / "skills" / "analyze" / "SKILL.md"
ANALYZE_STATES = [
    "no-ledger",
    "ledger-invalid",
    "ledger-incomplete",
    "no-structure",
    "structure-invalid",
    "no-moves",
    "ready",
]


def _analyze_text() -> str:
    """The skill with whitespace collapsed, so rewrapping a line breaks no test."""
    return " ".join(ANALYZE_SKILL.read_text(encoding="utf-8").split())


def _analyze_section(heading: str) -> str:
    """The body of one `## heading` section, lines intact."""
    text = ANALYZE_SKILL.read_text(encoding="utf-8")
    return text.split(f"\n## {heading}\n", 1)[1].split("\n## ", 1)[0]


def _analyze_frontmatter() -> str:
    return ANALYZE_SKILL.read_text(encoding="utf-8").split("---", 2)[1]


def _analyze_state_rows() -> dict[str, str]:
    """State name → its row of the state table, in table order."""
    rows: dict[str, str] = {}
    for line in _analyze_section("Determine the state").splitlines():
        match = re.match(r"\| `([a-z-]+)` \|", line)
        if match:
            rows[match.group(1)] = line
    return rows


def test_analyze_states_are_exactly_the_seven_in_order():
    """The order is the prerequisite order: each state assumes the ones before it."""
    assert list(_analyze_state_rows()) == ANALYZE_STATES


@pytest.mark.parametrize(
    ("state", "needles"),
    [
        ("no-ledger", ["_meta.json", "Operation D", "`/propositions:propositions`"]),
        ("ledger-invalid", ["`validate-propositions.py`", "Stop", "`/propositions:propositions`"]),
        ("ledger-incomplete", ["uncovered", "`/propositions:extract`", "one section"]),
        (
            "no-structure",
            ["`structure.json`", "`discourse.jsonl`", "100", "`/propositions:construct-batch`",
             "`/propositions:construct`"],
        ),
        ("structure-invalid", ["--partial", "Stop", "`/propositions:construct`"]),
        (
            "no-moves",
            ["`moves`", "`proposition_share`", "`paragraph_share`", "moves-only",
             "`/propositions:construct-batch`"],
        ),
        ("ready", ["read-out"]),
    ],
)
def test_analyze_state_row_names_its_check_and_action(state, needles):
    row = _analyze_state_rows()[state]
    missing = [needle for needle in needles if needle not in row]
    assert not missing, f"{state} row lacks {missing}: {row}"


def test_analyze_derives_progress_from_the_files():
    text = _analyze_text()
    assert "no progress file" in text
    assert "determine the state again" in text


def test_analyze_description_sends_narrow_requests_elsewhere():
    """A whole-article entry must not capture what the narrow skills answer."""
    description = " ".join(_analyze_frontmatter().split())
    for skill in ("extract", "construct", "clarity-audit", "propositions"):
        assert f"/propositions:{skill}" in description


def test_analyze_does_not_pre_approve_writing():
    """`allowed-tools` only pre-approves, so this pins intent, not enforcement.

    `disallowed-tools` is not an option: it empties the pool for the whole turn,
    which would stop the invoked skills from writing after their confirmations.
    """
    frontmatter = _analyze_frontmatter()
    tools = frontmatter.split("allowed-tools:", 1)[1].split()
    assert "Write" not in tools and "Edit" not in tools
    assert "disallowed-tools" not in frontmatter


def test_analyze_leaves_writing_and_confirmation_to_the_invoked_skills():
    text = _analyze_text()
    assert "writes nothing" in text
    assert "never answers a confirmation" in text
    assert "shasum -a 256" in text, "the no-write rule needs its before-and-after check"


def test_analyze_judges_coverage_from_the_runs():
    """A finished ledger also exits 1, so the exit code decides nothing."""
    section = " ".join(_analyze_section("Determine the state").split())
    for needle in (
        "\\begin{document}", "\\end{document}", "exit code",
        "LaTeX commands", "headings", "front matter", "author statements",
        "appendix instruments", "bibliography",
    ):
        assert needle in section, needle
    assert "location" in section, "the runs not counted must stay checkable"
    assert "Pass these runs" in section, "construct's A1 stops on any uncovered text (#42)"


def test_analyze_labels_moves_without_redrawing_the_tree():
    """construct's annotate mode redraws the tree, so moves go to the moves-only path at any length."""
    row = _analyze_state_rows()["no-moves"]
    assert "100" not in row
    assert "`/propositions:construct`" not in row


def test_analyze_reports_what_the_article_owes_as_a_finding():
    section = " ".join(_analyze_section("Read-out").split())
    assert "without `--partial`" in section
    assert "finding" in section


def test_analyze_runs_three_steps_only_on_request():
    section = _analyze_section("Steps that run only on request")
    rows = re.findall(r"^\| `/propositions:([a-z-]+)` \|", section, flags=re.M)
    assert rows == ["proofread", "manuscript-audit", "clarity-audit"]
    assert "only when the user asks" in " ".join(section.split())


def test_analyze_stops_rather_than_works_around():
    section = " ".join(_analyze_section("When to stop").split())
    for needle in ("declines", "exit 2", "Do not retry", "work around"):
        assert needle in section, needle
    assert "again resumes" in section


def test_analyze_report_has_its_ten_items():
    items = re.findall(r"^\d+\. (.+)$", _analyze_section("Report"), flags=re.M)
    assert len(items) == 10, items
    for number, keyword in enumerate(
        ["state", "validator", "uncovered", "roles", "moves", "findings",
         "read-out", "files written", "optional", "next step"]
    ):
        assert keyword in items[number], (keyword, items[number])


def test_analyze_holds_no_program_of_its_own():
    """New code is Swift: a skill may call tools, not carry a program for python3 to run."""
    text = ANALYZE_SKILL.read_text(encoding="utf-8")
    assert not re.search(r"python3\s+-", text), "python3 - and python3 -c are programs in a skill"
    assert "<<" not in text, "heredocs hand a program to an interpreter"
