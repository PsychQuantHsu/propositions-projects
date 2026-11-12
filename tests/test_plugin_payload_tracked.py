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
    assert "Pass these runs" in section, "construct's A1 stops on any uncovered text"


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


# ---------- Article obligations table (add-article-obligations, #47) ----------
#
# The table is data that no program reads yet, so this guard is the only thing
# that keeps it well formed and complete (spec: article-obligations). Each check
# is a function from a table to a list of problems, so every refusal the spec
# names is exercised on a small table held in memory; one case then asserts that
# the committed file has no problem at all.
#
# Exit condition: once the Swift package exists (#46) this guard moves to Swift
# Testing and these cases are deleted.

import copy  # noqa: E402
import functools  # noqa: E402
import importlib.util  # noqa: E402
import sys  # noqa: E402

PROPOSITIONS_PLUGIN = REPO_ROOT / "plugins" / "propositions"
OBLIGATIONS = PROPOSITIONS_PLUGIN / "catalog" / "obligations.yaml"
OBLIGATIONS_DOC = PROPOSITIONS_PLUGIN / "docs" / "OBLIGATIONS.md"

OBL_TOP_KEYS = ("groups", "entries", "unconstrained")
OBL_ENTRY_KEYS = (
    "id", "class", "group", "unit", "applies", "criterion", "check", "owner", "verified_by", "on_warning",
)
OBL_REQUIRED_KEYS = ("id", "class", "unit", "criterion", "check", "verified_by")
OBL_GROUP_KEYS = ("id", "zh", "does", "axiom")
OBL_GROUPS = ("dependence", "commitment", "support", "consistency", "truth", "placement", "completeness")
OBL_DEPENDENCE_AXIOM = "academic-writing/A1_no_forward_dependence"
OBL_CLASSES = ("precondition", "obligation")
OBL_UNITS = ("proposition", "article")
OBL_APPLIES_KEYS = ("profile", "claim_type", "evidence_class", "cites", "opens", "section_role")
OBL_ACCOUNTED_FIELDS = ("claim_type", "evidence_class", "opens", "section_role")
OBL_WARNING_RULES = ("judge", "info")
# `info` is the one setting that lets a warning pass, so it is allowed only on
# the entries the maintainer reviewed for it. Each is named by its id together
# with its check: a list of checks alone would let another entry of the same
# check pass on a warning, and a list of ids alone would let a reviewed entry be
# pointed at another check. Extend this in the same change in which the
# maintainer approves another entry.
OBL_INFO_REVIEWED_ENTRIES = {
    "index.proposition-is-cited": "ledger:R3",
    "index.arcs-do-not-cross": "structure:S7",
    "consistency.code-symbols-mentioned": "audit:R3",
    "completeness.bibliography-entries-cited": "audit:R2",
}
OBL_MECHANICAL_SOURCES = ("ledger", "structure", "records", "coverage", "order", "audit")
# The closed inventory of implemented checks (spec: "A check is named only when
# it is implemented"). A change that implements a check adds its id here.
OBL_INVENTORY = (
    *(f"ledger:R{n}" for n in ("1", "1.5", "2", "3", "4", "7", "8", "9", "10", "11", "12", "13")),
    "ledger:profile",
    *(f"structure:S{n}" for n in range(1, 10)),
    *(f"records:V{n}" for n in range(1, 7)),
    "coverage:text",
    "order:ledger",
    *(f"audit:R{n}" for n in range(1, 4)),
    *(f"proofread:L{n}" for n in range(1, 6)),
    *(f"proofread:E{n}" for n in range(1, 8)),
)
OBL_EMPIRICAL_LAYERS = tuple(f"proofread:E{n}" for n in range(1, 8))
OBL_UNWALKED_LAYERS_OWNER = 57
# The three proofread layers that are defined but not walked, by entry. The data
# file has no field for the layer, so the guard pins which entry stands for which.
OBL_UNWALKED_LAYERS = {
    "consistency.variable-roles": "E8",
    "truth.composite-holds-per-component": "E9",
    "support.exposures-separable": "E10",
}
# The empirical layers apply where a claim rests on data: these classes, in an
# empirical ledger. Anything wider reaches propositions the walk cannot check
# (an `external` one, or one with no artifact), which then never pass.
OBL_EMPIRICAL_APPLIES = {
    "profile": ["empirical"],
    "evidence_class": ["measured", "tested", "descriptive", "not_computable"],
}
# Gaps the spec pins by entry: (class, owner).
OBL_PINNED_GAPS = {
    "truth.not-refuted": ("obligation", 62),
    "index.structure-faithful": ("precondition", 66),
    "index.profile-fits-manuscript": ("precondition", 70),
}
OBL_REQUIRED_OWNERS = (46, 49, 50, 55, 62, 66, 70)
# A verdict against a proposition from a method that no entry lists (a Lean
# refutation, a human review) counts through this entry, so that soundness
# stays "every entry passes" with no condition outside the table.
OBL_UNLISTED_VERDICT_ENTRY = "truth.not-refuted"
OBL_OUTCOMES = ("not_applicable", "unverified", "failed", "passed")
OBL_DOC_ISSUES = ("#21", "#59", "#62", "#63", "#64", "#66", "#68", "#69", "#70")
# Words the document needs for the rules the spec asks it to state: the audit
# severity that is easy to leave out, and what a report has to show for a unit
# to pass.
OBL_DOC_WORDS = ("suspicious", "examined")
OBL_DOC_ENTRY_ID_LIMIT = 2
OBL_ID = re.compile(r"[a-z0-9-]+\.[a-z0-9-]+")
OBL_AXIOM = re.compile(r"[a-z0-9-]+/[A-Za-z0-9_]+")


def _load_obligations_script(stem: str):
    path = PROPOSITIONS_PLUGIN / "scripts" / f"{stem}.py"
    spec = importlib.util.spec_from_file_location(f"obligations_guard_{stem.replace('-', '_')}", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


@functools.lru_cache(maxsize=None)
def _obligation_vocabulary() -> dict[str, tuple[str, ...]]:
    """The value sets `applies` draws on, read from the validators that own them."""
    profiles = _load_obligations_script("validate-propositions").PROFILE_VOCABULARIES
    structure = _load_obligations_script("validate-structure")

    def union(field: str) -> tuple[str, ...]:
        seen: list[str] = []
        for vocabulary in profiles.values():
            seen.extend(value for value in vocabulary[field] if value not in seen)
        return tuple(seen)

    return {
        "profile": tuple(profiles),
        "claim_type": union("claim_type"),
        "evidence_class": union("evidence_class"),
        "cites": ("present", "absent"),
        "opens": tuple(structure.KINDS),
        "section_role": tuple(structure.ROLES),
    }


@functools.lru_cache(maxsize=None)
def _obligation_methods() -> tuple[str, ...]:
    return tuple(_load_obligations_script("validate-verification").METHODS)


def _is_text(value) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _group_problems(groups) -> list[str]:
    if not isinstance(groups, list):
        return ["groups is not a list"]
    problems: list[str] = []
    ids = [group.get("id") if isinstance(group, dict) else None for group in groups]
    for group_id in ids:
        if group_id not in OBL_GROUPS:
            problems.append(f"group {group_id!r} is not one of the seven groups")
    if tuple(ids) != OBL_GROUPS:
        problems.append(f"groups are not the seven in order: {', '.join(OBL_GROUPS)}")
    for group in groups:
        if not isinstance(group, dict):
            problems.append("a group is not a mapping")
            continue
        group_id = group.get("id")
        for key in group:
            if key not in OBL_GROUP_KEYS:
                problems.append(f"group {group_id!r}: key {key!r} is not allowed")
        for key in ("zh", "does"):
            if not _is_text(group.get(key)):
                problems.append(f"group {group_id!r}: {key} is missing")
        axiom = group.get("axiom")
        if axiom is not None and not (isinstance(axiom, str) and OBL_AXIOM.fullmatch(axiom)):
            problems.append(f"group {group_id!r}: axiom {axiom!r} is not <domain>/<axiom id>")
        if group_id == "dependence" and axiom != OBL_DEPENDENCE_AXIOM:
            problems.append(f"group 'dependence': axiom is not {OBL_DEPENDENCE_AXIOM}")
    return problems


def _entry_problems(entry: dict, vocabulary, methods) -> list[str]:
    problems: list[str] = []
    for key in entry:
        if key not in OBL_ENTRY_KEYS:
            problems.append(f"key {key!r} is not allowed")
    for key in OBL_REQUIRED_KEYS:
        if key not in entry:
            problems.append(f"{key} is missing")

    entry_id = entry.get("id")
    well_formed_id = isinstance(entry_id, str) and OBL_ID.fullmatch(entry_id) is not None
    if not well_formed_id:
        problems.append("id is not <prefix>.<name> in lowercase letters, digits and hyphens")
    prefix = entry_id.split(".", 1)[0] if well_formed_id else None

    kind, group = entry.get("class"), entry.get("group")
    if kind not in OBL_CLASSES:
        problems.append(f"class {kind!r} is not one of {', '.join(OBL_CLASSES)}")
    elif kind == "precondition":
        if "group" in entry:
            problems.append("a precondition has no group")
        if prefix != "index":
            problems.append("the id of a precondition starts with index.")
    elif group not in OBL_GROUPS:
        problems.append(f"an obligation needs a group among the seven, found {group!r}")
    elif prefix != group:
        problems.append(f"the id of an obligation starts with its group, {group}.")

    unit = entry.get("unit")
    if unit not in OBL_UNITS:
        problems.append(f"unit {unit!r} is not one of {', '.join(OBL_UNITS)}")
    criterion = entry.get("criterion")
    if not _is_text(criterion) or "\n" in criterion.strip() or len(criterion) > 200:
        problems.append("criterion is not one line of at most 200 characters")

    applies = entry.get("applies")
    if applies is not None and (not isinstance(applies, dict) or not applies):
        problems.append("applies is not a non-empty mapping")
        applies = None
    for key, values in (applies or {}).items():
        if key not in OBL_APPLIES_KEYS:
            problems.append(f"applies key {key!r} is not allowed")
            continue
        if unit == "article" and key != "profile":
            problems.append(f"an entry whose unit is article applies by profile only, found {key}")
        if not isinstance(values, list) or not values:
            problems.append(f"applies {key} is not a non-empty list")
            continue
        for value in values:
            if value not in vocabulary[key]:
                problems.append(f"{key} value {value!r} is not in the vocabulary")

    check, owner = entry.get("check"), entry.get("owner")
    is_gap = check == "gap"
    if not is_gap and check not in OBL_INVENTORY:
        problems.append(f"check {check!r} is neither gap nor an id of the inventory")
    if is_gap and not (isinstance(owner, int) and not isinstance(owner, bool) and owner > 0):
        problems.append("a gap needs an owner, the number of the issue that will supply the check")
    if not is_gap and "owner" in entry:
        problems.append("owner is allowed only when check is gap")
    if check in OBL_EMPIRICAL_LAYERS or owner == OBL_UNWALKED_LAYERS_OWNER:
        stated = {key: sorted(values) for key, values in (applies or {}).items() if isinstance(values, list)}
        if stated != {key: sorted(values) for key, values in OBL_EMPIRICAL_APPLIES.items()}:
            problems.append(
                "an empirical proofread layer applies with exactly profile [empirical] and evidence_class "
                f"[{', '.join(OBL_EMPIRICAL_APPLIES['evidence_class'])}]"
            )

    verified_by = entry.get("verified_by")
    mechanical = verified_by == ["mechanical"]
    source = check.split(":", 1)[0] if isinstance(check, str) and ":" in check else None
    if not isinstance(verified_by, list) or not verified_by:
        problems.append("verified_by is not a non-empty list")
        verified_by = []
    elif not mechanical:
        for method in verified_by:
            if method not in methods:
                problems.append(f"verified_by value {method!r} is neither mechanical alone nor a verification method")
        if "proofread" in verified_by and "cross_model" not in verified_by:
            problems.append("verified_by lists proofread without cross_model")
        if source in OBL_MECHANICAL_SOURCES:
            problems.append(f"a check from {source} is verified_by [mechanical]")
        if unit == "article":
            problems.append("an entry whose unit is article is verified_by [mechanical]")
    if source == "proofread" and "proofread" not in verified_by:
        problems.append("a check from proofread lists proofread in verified_by")

    rule = entry.get("on_warning")
    if mechanical:
        if rule not in OBL_WARNING_RULES:
            problems.append(f"on_warning {rule!r} is not one of {', '.join(OBL_WARNING_RULES)}")
        elif rule == "info" and OBL_INFO_REVIEWED_ENTRIES.get(entry_id) != check:
            problems.append("on_warning info is allowed only on an entry the maintainer reviewed for it, with its check")
    elif "on_warning" in entry:
        problems.append("on_warning is allowed only when verified_by is [mechanical]")
    return problems


def _format_problems(table, vocabulary, methods) -> list[str]:
    """Problems that can be told from the top level, one group or one entry at a time."""
    if not isinstance(table, dict):
        return ["the table is not a mapping"]
    problems = [f"top-level key {key!r} is not allowed" for key in table if key not in OBL_TOP_KEYS]
    problems += [f"top-level key {key!r} is missing" for key in OBL_TOP_KEYS if key not in table]
    problems += _group_problems(table.get("groups"))
    entries = table.get("entries")
    if not isinstance(entries, list):
        return problems + ["entries is not a list"]
    seen: set[str] = set()
    for position, entry in enumerate(entries, 1):
        if not isinstance(entry, dict):
            problems.append(f"entry {position} is not a mapping")
            continue
        entry_id = entry.get("id")
        label = f"entry {entry_id!r}" if isinstance(entry_id, str) else f"entry {position}"
        if isinstance(entry_id, str):
            if entry_id in seen:
                problems.append(f"{label}: id is repeated")
            seen.add(entry_id)
        problems += [f"{label}: {problem}" for problem in _entry_problems(entry, vocabulary, methods)]
    return problems


def _obl_entries(table) -> list[dict]:
    entries = table.get("entries") if isinstance(table, dict) else None
    return [entry for entry in entries or [] if isinstance(entry, dict)]


def _accounting_problems(table, vocabulary) -> list[str]:
    """Every implemented check has an entry; every vocabulary value is placed exactly once."""
    entries = _obl_entries(table)
    named_checks = {entry.get("check") for entry in entries}
    problems = [f"inventory check {check!r} is not named by any entry" for check in OBL_INVENTORY if check not in named_checks]

    named: dict[str, set] = {field: set() for field in OBL_ACCOUNTED_FIELDS}
    for entry in entries:
        applies = entry.get("applies")
        for field in OBL_ACCOUNTED_FIELDS:
            values = applies.get(field) if isinstance(applies, dict) else None
            if isinstance(values, list):
                named[field].update(value for value in values if isinstance(value, str))

    listed: dict[str, set] = {field: set() for field in OBL_ACCOUNTED_FIELDS}
    for position, item in enumerate(table.get("unconstrained") or [], 1):
        label = f"unconstrained item {position}"
        if not isinstance(item, dict) or set(item) != {"field", "value", "why"}:
            problems.append(f"{label} needs exactly field, value and why")
            if not isinstance(item, dict):
                continue
        field, value, why = item.get("field"), item.get("value"), item.get("why")
        if field not in OBL_ACCOUNTED_FIELDS:
            problems.append(f"{label}: field {field!r} is not one of {', '.join(OBL_ACCOUNTED_FIELDS)}")
            continue
        if value not in vocabulary[field]:
            problems.append(f"{label}: {field} value {value!r} is not in the vocabulary")
            continue
        if "why" in item and (not _is_text(why) or "\n" in why.strip()):
            problems.append(f"{label}: why is not one line")
        listed[field].add(value)

    for field in OBL_ACCOUNTED_FIELDS:
        for value in vocabulary[field]:
            in_entry, in_list = value in named[field], value in listed[field]
            if in_entry and in_list:
                problems.append(f"{field} value {value!r} is both named by an entry and listed in unconstrained")
            elif not in_entry and not in_list:
                problems.append(f"{field} value {value!r} is neither named by an entry nor listed in unconstrained")
    return problems


OBL_REVIEWED_BACKWARD = {
    "class": "obligation", "group": "dependence", "check": "gap", "owner": 46,
    "verified_by": ["mechanical"], "on_warning": "judge",
}


def _reviewed_problems(table) -> list[str]:
    """The entries the maintainer reviewed keep their values; the known gaps keep their owners."""
    entries = _obl_entries(table)
    problems: list[str] = []

    def with_check(check: str) -> list[dict]:
        return [entry for entry in entries if entry.get("check") == check]

    backward = next((entry for entry in entries if entry.get("id") == "dependence.cites-backward"), None)
    if backward is None:
        problems.append("entry 'dependence.cites-backward' is missing")
    else:
        for key, value in OBL_REVIEWED_BACKWARD.items():
            if backward.get(key) != value:
                problems.append(
                    f"entry 'dependence.cites-backward': {key} is {backward.get(key)!r}, reviewed as {value!r}"
                )

    announced = with_check("structure:S6")
    if not announced or any(e.get("class") != "obligation" or e.get("on_warning") != "judge" for e in announced):
        problems.append("the entries whose check is structure:S6 are obligations with on_warning judge, at least one")
    by_id = {entry.get("id"): entry for entry in entries}
    for entry_id, check in OBL_INFO_REVIEWED_ENTRIES.items():
        entry = by_id.get(entry_id)
        if entry is None:
            problems.append(f"entry {entry_id!r} is missing, reviewed as on_warning info")
        elif entry.get("on_warning") != "info" or entry.get("check") != check:
            problems.append(
                f"entry {entry_id!r}: check is {entry.get('check')!r} and on_warning is "
                f"{entry.get('on_warning')!r}, reviewed as {check!r} with info"
            )
    graph = with_check("ledger:R3")
    if not any(
        e.get("class") == "obligation" and e.get("group") == "dependence" and e.get("on_warning") == "judge"
        for e in graph
    ):
        problems.append("no entry whose check is ledger:R3 is a dependence obligation with on_warning judge")
    if not {"obligation", "precondition"} <= {e.get("class") for e in with_check("structure:S5")}:
        problems.append("the entries whose check is structure:S5 include an obligation and a precondition")

    unwalked = [entry for entry in entries if entry.get("owner") == OBL_UNWALKED_LAYERS_OWNER]
    if {entry.get("id") for entry in unwalked} != set(OBL_UNWALKED_LAYERS):
        expected = ", ".join(f"{entry_id} ({layer})" for entry_id, layer in OBL_UNWALKED_LAYERS.items())
        problems.append(f"the entries owned by issue {OBL_UNWALKED_LAYERS_OWNER} are not exactly: {expected}")
    for entry_id, (kind, owner) in OBL_PINNED_GAPS.items():
        entry = by_id.get(entry_id)
        if entry is None:
            problems.append(f"entry {entry_id!r} is missing; the spec asks for it as a gap owned by issue {owner}")
        elif (entry.get("class"), entry.get("check"), entry.get("owner")) != (kind, "gap", owner):
            problems.append(
                f"entry {entry_id!r}: class {entry.get('class')!r}, check {entry.get('check')!r}, owner "
                f"{entry.get('owner')!r}; the spec asks for a {kind} that is a gap owned by issue {owner}"
            )
    for entry in unwalked:
        verified_by = entry.get("verified_by") or []
        if entry.get("check") != "gap" or "proofread" not in verified_by or "cross_model" not in verified_by:
            problems.append(
                f"entry {entry.get('id')!r}: an entry owned by issue {OBL_UNWALKED_LAYERS_OWNER} is a gap "
                "verified by proofread and cross_model"
            )
    for owner in OBL_REQUIRED_OWNERS:
        if not any(entry.get("owner") == owner for entry in entries):
            problems.append(f"owner {owner} is named by no entry")
    verdicts = by_id.get(OBL_UNLISTED_VERDICT_ENTRY)
    if verdicts is not None and verdicts.get("unit") != "proposition":
        problems.append(f"entry {OBL_UNLISTED_VERDICT_ENTRY!r} is decided for each proposition")
    return problems


def _document_problems(text: str, table) -> list[str]:
    """The document explains the table without holding a second copy of it."""
    problems: list[str] = []
    ids = sorted({entry["id"] for entry in _obl_entries(table) if isinstance(entry.get("id"), str)})
    mentioned = [entry_id for entry_id in ids if entry_id in text]
    if len(mentioned) > OBL_DOC_ENTRY_ID_LIMIT:
        problems.append(
            f"the document mentions {len(mentioned)} entry ids, more than the {OBL_DOC_ENTRY_ID_LIMIT} allowed "
            f"as examples: {', '.join(mentioned)}"
        )
    problems += [f"the document does not name the outcome {outcome}" for outcome in OBL_OUTCOMES if outcome not in text]
    problems += [f"the document does not say why the layer {layer} is a gap" for layer in ("E8", "E9", "E10") if layer not in text]
    problems += [f"the document does not name issue {issue}" for issue in OBL_DOC_ISSUES if issue not in text]
    problems += [f"the document does not mention {word}" for word in OBL_DOC_WORDS if word not in text]
    if "owner" not in text:
        problems.append("the document does not say that a gap is owned by the issue in its owner")
    return problems


def _small_table() -> dict:
    """A table that breaks no format rule; each refusal case changes one thing in it."""
    groups = [{"id": group, "zh": "組", "does": "Protects one thing."} for group in OBL_GROUPS]
    groups[0]["axiom"] = OBL_DEPENDENCE_AXIOM
    return {
        "groups": groups,
        "entries": [
            {
                "id": "index.text-in-manuscript", "class": "precondition", "unit": "proposition",
                "criterion": "The proposition's text occurs in the manuscript.",
                "check": "ledger:R1", "verified_by": ["mechanical"], "on_warning": "judge",
            },
            {
                "id": "dependence.cites-backward", "class": "obligation", "group": "dependence",
                "unit": "proposition", "applies": {"cites": ["present"]},
                "criterion": "Every proposition this one cites comes earlier in reading order.",
                "check": "gap", "owner": 46, "verified_by": ["mechanical"], "on_warning": "judge",
            },
            {
                "id": "support.cites-imply", "class": "obligation", "group": "support",
                "unit": "proposition", "applies": {"cites": ["present"]},
                "criterion": "The propositions this one cites imply it.",
                "check": "proofread:L4", "verified_by": ["proofread", "cross_model"],
            },
        ],
        "unconstrained": [],
    }


def _obl_entry(table: dict, entry_id: str) -> dict:
    return next(entry for entry in table["entries"] if entry["id"] == entry_id)


INDEX_ROW = "index.text-in-manuscript"
GAP_ROW = "dependence.cites-backward"
MODEL_ROW = "support.cites-imply"


def _set(entry_id: str, **changes):
    return lambda table: _obl_entry(table, entry_id).update(changes)


def _drop(entry_id: str, key: str):
    return lambda table: _obl_entry(table, entry_id).pop(key)


def _then(*steps):
    def run(table):
        for step in steps:
            step(table)
    return run


OBL_FORMAT_REFUSALS = [
    ("unknown top-level key", lambda t: t.update(notes=[]), ["notes"]),
    # spec-example: article-obligations / an entry key outside the closed set
    ("unknown entry key", _set(INDEX_ROW, example="x"), [INDEX_ROW, "example"]),
    ("repeated id", lambda t: t["entries"].append(copy.deepcopy(_obl_entry(t, GAP_ROW))), [GAP_ROW, "repeated"]),
    ("two-line criterion", _set(INDEX_ROW, criterion="One thing.\nAnother."), [INDEX_ROW, "criterion"]),
    ("criterion over 200 characters", _set(INDEX_ROW, criterion="x" * 201), [INDEX_ROW, "criterion"]),
    ("third class", _set(INDEX_ROW, **{"class": "information"}), [INDEX_ROW, "information"]),
    ("precondition without the index prefix", _set(INDEX_ROW, id="info.text"), ["info.text", "index"]),
    ("obligation without its group prefix", _set(MODEL_ROW, id="truth.cites-imply"), ["truth.cites-imply", "support"]),
    ("obligation without a group", _drop(MODEL_ROW, "group"), [MODEL_ROW, "group"]),
    ("precondition with a group", _set(INDEX_ROW, group="support"), [INDEX_ROW, "group"]),
    # spec-example: article-obligations / an eighth group
    ("eighth group", lambda t: t["groups"].append({"id": "style", "zh": "文", "does": "Protects style."}), ["style"]),
    ("groups out of order", lambda t: t["groups"].reverse(), ["groups", "order"]),
    ("group without its Chinese label", lambda t: t["groups"][2].pop("zh"), ["support", "zh"]),
    ("dependence names another axiom", lambda t: t["groups"][0].update(axiom="academic-writing/A2_other"),
     ["dependence", OBL_DEPENDENCE_AXIOM]),
    # spec-example: article-obligations / a claim type that no profile accepts
    ("value outside the vocabulary", _set(INDEX_ROW, applies={"claim_type": ["lemma"]}), [INDEX_ROW, "lemma"]),
    ("optional sidecar field as a key", _set(INDEX_ROW, applies={"move": ["define"]}), [INDEX_ROW, "move"]),
    ("empty value list", _set(INDEX_ROW, applies={"claim_type": []}), [INDEX_ROW, "claim_type"]),
    ("article unit keyed on a proposition field",
     _set(INDEX_ROW, unit="article", applies={"claim_type": ["claim"]}), [INDEX_ROW, "article"]),
    ("empirical layer without the profile limit",
     _then(_set(MODEL_ROW, check="proofread:E3"), _drop(MODEL_ROW, "applies")), [MODEL_ROW, "empirical"]),
    ("empirical layer that reaches a proposition without data",
     _set(MODEL_ROW, check="proofread:E3", applies={"profile": ["empirical"]}), [MODEL_ROW, "evidence_class"]),
    ("gap without an owner", _drop(GAP_ROW, "owner"), [GAP_ROW, "owner"]),
    ("owner on an implemented check", _set(INDEX_ROW, owner=46), [INDEX_ROW, "owner"]),
    ("check outside the inventory", _set(INDEX_ROW, check="ledger:R6"), [INDEX_ROW, "ledger:R6"]),
    ("proofread without cross_model", _set(MODEL_ROW, verified_by=["proofread"]), [MODEL_ROW, "cross_model"]),
    ("unknown method", _set(MODEL_ROW, verified_by=["proofread", "cross_model", "oracle"]), [MODEL_ROW, "oracle"]),
    ("mechanical source verified by a method",
     _then(_set(INDEX_ROW, verified_by=["human"]), _drop(INDEX_ROW, "on_warning")), [INDEX_ROW, "mechanical"]),
    ("article unit verified by a method",
     _then(_set(MODEL_ROW, unit="article"), _drop(MODEL_ROW, "applies")), [MODEL_ROW, "mechanical"]),
    ("mechanical entry without a warning rule", _drop(INDEX_ROW, "on_warning"), [INDEX_ROW, "on_warning"]),
    ("warning rule on a non-mechanical entry", _set(MODEL_ROW, on_warning="judge"), [MODEL_ROW, "on_warning"]),
    ("third warning value", _set(INDEX_ROW, on_warning="none"), [INDEX_ROW, "none"]),
    ("unreviewed entry passing on a warning",
     _set(INDEX_ROW, check="ledger:R1.5", on_warning="info"), [INDEX_ROW, "info"]),
    ("another entry of a reviewed check passing on a warning",
     _set(INDEX_ROW, check="ledger:R3", on_warning="info"), [INDEX_ROW, "info"]),
    ("reviewed entry pointed at another check",
     _set(INDEX_ROW, id="index.arcs-do-not-cross", on_warning="info"), ["index.arcs-do-not-cross", "info"]),
]


def _names(problems: list[str], needles: list[str]) -> bool:
    return any(all(needle in problem for needle in needles) for problem in problems)


def test_obligations_small_table_breaks_no_format_rule():
    assert _format_problems(_small_table(), _obligation_vocabulary(), _obligation_methods()) == []


@pytest.mark.parametrize(
    "mutate, needles",
    [(mutate, needles) for _, mutate, needles in OBL_FORMAT_REFUSALS],
    ids=[label for label, _, _ in OBL_FORMAT_REFUSALS],
)
def test_obligations_format_refusal_names_what_is_wrong(mutate, needles):
    table = _small_table()
    mutate(table)
    problems = _format_problems(table, _obligation_vocabulary(), _obligation_methods())
    assert _names(problems, needles), problems


def test_obligations_guard_reads_vocabularies_from_their_source():
    vocabulary = _obligation_vocabulary()
    assert vocabulary["profile"] == ("default", "empirical")
    assert "result" in vocabulary["claim_type"] and "claim" in vocabulary["claim_type"]
    assert "measured" in vocabulary["evidence_class"] and "derived" in vocabulary["evidence_class"]
    assert "future_work" in vocabulary["opens"] and "appendix" in vocabulary["section_role"]
    assert "cross_model" in _obligation_methods()


def test_obligations_check_that_no_entry_names_is_reported():
    problems = _accounting_problems(_small_table(), _obligation_vocabulary())
    assert _names(problems, ["'records:V4'"]), problems
    assert not _names(problems, ["'ledger:R1'"]), problems  # the small table names this one


@pytest.mark.parametrize(
    "field, value",
    [
        # spec-example: article-obligations / a claim type added to the ledger validator
        ("claim_type", "conjecture"),
        # spec-example: article-obligations / a section role added to the structure validator
        ("section_role", "afterword"),
    ],
)
def test_obligations_new_vocabulary_value_has_to_be_placed(field, value):
    vocabulary = dict(_obligation_vocabulary())
    vocabulary[field] = (*vocabulary[field], value)
    assert _names(_accounting_problems(_small_table(), vocabulary), [field, value])


def test_obligations_value_is_placed_once():
    vocabulary = _obligation_vocabulary()
    table = _small_table()
    table["unconstrained"].append(
        {"field": "section_role", "value": "appendix", "why": "No entry singles the appendix out."}
    )
    assert not _names(_accounting_problems(table, vocabulary), ["section_role", "appendix"])
    _obl_entry(table, INDEX_ROW)["applies"] = {"section_role": ["appendix"]}
    assert _names(_accounting_problems(table, vocabulary), ["appendix", "both"])


@pytest.mark.parametrize(
    "item, needles",
    [
        ({"field": "section_role", "value": "appendix"}, ["unconstrained", "why"]),
        ({"field": "move", "value": "define", "why": "Not a field."}, ["unconstrained", "move"]),
        ({"field": "section_role", "value": "afterword", "why": "Not a role."}, ["unconstrained", "afterword"]),
    ],
    ids=["no reason", "field not accounted", "value outside the vocabulary"],
)
def test_obligations_unconstrained_item_is_checked(item, needles):
    table = _small_table()
    table["unconstrained"].append(item)
    assert _names(_accounting_problems(table, _obligation_vocabulary()), needles)


def test_obligations_reviewed_entries_are_required():
    problems = _reviewed_problems(_small_table())
    for entry_id in OBL_UNWALKED_LAYERS:
        assert _names(problems, ["57", entry_id]), problems
    for entry_id in OBL_PINNED_GAPS:
        assert _names(problems, [entry_id]), problems
    assert _names(problems, ["structure:S6"]), problems
    assert _names(problems, ["ledger:R3"]), problems
    for entry_id in OBL_INFO_REVIEWED_ENTRIES:
        assert _names(problems, [entry_id, "info"]), problems
    assert _names(problems, ["structure:S5"]), problems
    for owner in (49, 50, 55, 62, 66, 70):   # 46 is in the small table
        assert _names(problems, [f"owner {owner}"]), problems


def test_obligations_reviewed_entry_cannot_be_changed():
    table = _small_table()
    _obl_entry(table, GAP_ROW)["on_warning"] = "info"
    assert _names(_reviewed_problems(table), [GAP_ROW, "on_warning"])


def test_obligations_reviewed_info_entry_keeps_its_rule():
    table = _small_table()
    table["entries"].append({
        "id": "index.arcs-do-not-cross", "class": "precondition", "unit": "proposition",
        "criterion": "No two arcs of the proposition's paragraph cross.",
        "check": "structure:S7", "verified_by": ["mechanical"], "on_warning": "judge",
    })
    assert _names(_reviewed_problems(table), ["index.arcs-do-not-cross", "'judge'", "info"])


# spec-example: article-obligations / a document that names three entries
def test_obligations_document_cannot_copy_the_table():
    table = _small_table()
    text = " ".join(entry["id"] for entry in table["entries"])
    assert _names(_document_problems(text, table), ["3", "entry ids"])


def test_obligations_document_has_to_say_the_essentials():
    problems = _document_problems("An empty document.", _small_table())
    for needle in (*OBL_OUTCOMES, *OBL_DOC_ISSUES, *OBL_DOC_WORDS, "E8", "E9", "E10"):
        assert _names(problems, [needle]), (needle, problems)


def _load_obligations_text(text: str):
    """Parse the text of a data file, refusing a mapping that holds one key twice.

    PyYAML keeps the last value of a repeated key and drops the first without a
    message, so a leftover from a merge would replace a reviewed value unseen.
    """
    yaml = pytest.importorskip("yaml", reason="the obligations guard parses the table with PyYAML")

    class _NoRepeatedKeys(yaml.SafeLoader):
        pass

    def construct_mapping(loader, node, deep=False):
        seen: set = set()
        for key_node, _ in node.value:
            key = loader.construct_object(key_node, deep=deep)
            if key in seen:
                raise ValueError(f"the key {key!r} appears twice in one mapping (line {key_node.start_mark.line + 1})")
            seen.add(key)
        return yaml.SafeLoader.construct_mapping(loader, node, deep=deep)

    _NoRepeatedKeys.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping)
    return yaml.load(text, Loader=_NoRepeatedKeys)  # noqa: S506 - a SafeLoader subclass


# spec-example: article-obligations / an entry with the same key twice
def test_obligations_loader_refuses_a_key_given_twice():
    text = (
        "groups: []\n"
        "unconstrained: []\n"
        "entries:\n"
        "  - id: index.text-in-manuscript\n"
        "    check: ledger:R1\n"
        "    check: ledger:R2\n"
    )
    with pytest.raises(ValueError, match="check"):
        _load_obligations_text(text)


@pytest.fixture(scope="module")
def obligations() -> dict:
    assert OBLIGATIONS.is_file(), f"missing {_rel(OBLIGATIONS)}"
    return _load_obligations_text(OBLIGATIONS.read_text(encoding="utf-8"))


def test_obligations_table_has_no_problem(obligations):
    vocabulary = _obligation_vocabulary()
    problems = (
        _format_problems(obligations, vocabulary, _obligation_methods())
        + _accounting_problems(obligations, vocabulary)
        + _reviewed_problems(obligations)
    )
    assert problems == [], "\n".join(problems)


def _entries_with_check(table: dict, check: str) -> list[dict]:
    return [entry for entry in table["entries"] if entry.get("check") == check]


def _only_entry_with_check(table: dict, check: str) -> dict:
    found = _entries_with_check(table, check)
    assert len(found) == 1, f"{check} is named by {len(found)} entries, expected one"
    return found[0]


# spec-example: article-obligations / the two entries for the citation graph
def test_obligations_citation_graph_has_two_entries(obligations):
    graph = _entries_with_check(obligations, "ledger:R3")
    assert len(graph) >= 2, [entry["id"] for entry in graph]
    cycle = [e for e in graph if e["class"] == "obligation" and e.get("group") == "dependence"]
    assert [e.get("on_warning") for e in cycle] == ["judge"], cycle
    assert "cycle" in cycle[0]["criterion"] or "path" in cycle[0]["criterion"], cycle[0]["criterion"]
    uncited = [e for e in graph if e.get("on_warning") == "info"]
    assert [e["id"] for e in uncited] == ["index.proposition-is-cited"], uncited


# spec-example: article-obligations / the forward-citation obligation
def test_obligations_forward_citation_entry(obligations):
    entry = _obl_entry(obligations, "dependence.cites-backward")
    stated = {key: entry.get(key) for key in ("class", "group", "check", "owner", "verified_by", "on_warning")}
    assert stated == {
        "class": "obligation", "group": "dependence", "check": "gap", "owner": 46,
        "verified_by": ["mechanical"], "on_warning": "judge",
    }


OBL_REVIEWED_ROWS = [
    ("dependence.cites-backward", None, "obligation", "judge"),
    (None, "structure:S6", "obligation", "judge"),
    ("index.arcs-do-not-cross", "structure:S7", "precondition", "info"),
    ("index.proposition-is-cited", "ledger:R3", "precondition", "info"),
    ("consistency.code-symbols-mentioned", "audit:R3", "obligation", "info"),
    ("completeness.bibliography-entries-cited", "audit:R2", "obligation", "info"),
    (None, "ledger:R1.5", "precondition", "judge"),
]


# spec-example: article-obligations / the entries the maintainer reviewed
@pytest.mark.parametrize(
    "entry_id, check, expected_class, expected_rule",
    OBL_REVIEWED_ROWS,
    ids=[entry_id or check for entry_id, check, _, _ in OBL_REVIEWED_ROWS],
)
def test_obligations_reviewed_entry_has_its_values(obligations, entry_id, check, expected_class, expected_rule):
    entry = _obl_entry(obligations, entry_id) if entry_id else _only_entry_with_check(obligations, check)
    if check:
        assert entry["check"] == check
    assert (entry["class"], entry.get("on_warning")) == (expected_class, expected_rule), entry["id"]


def test_obligations_document_has_no_problem(obligations):
    assert OBLIGATIONS_DOC.is_file(), f"missing {_rel(OBLIGATIONS_DOC)}"
    problems = _document_problems(OBLIGATIONS_DOC.read_text(encoding="utf-8"), obligations)
    assert problems == [], "\n".join(problems)
