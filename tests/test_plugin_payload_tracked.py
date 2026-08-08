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
