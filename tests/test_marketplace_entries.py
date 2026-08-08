"""Marketplace entry substance tests (umbrella-marketplace-migration task 5.1).

Every entry in `.claude-plugin/marketplace.json` must resolve to a directory
that actually ships installable content. An entry pointing at an empty
placeholder is worse than no entry at all: a user who installs it gets a
plugin that silently does nothing (spec: umbrella-marketplace-layout,
"Umbrella marketplace manifest" + "Plugins monorepo layout with a single
tool implementation", design D6).
"""

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST = REPO_ROOT / ".claude-plugin" / "marketplace.json"


def _entries() -> list[dict]:
    with MANIFEST.open(encoding="utf-8") as fh:
        return json.load(fh)["plugins"]


def _resolve(source: str) -> Path:
    """Resolve a manifest `source` value against the repository root."""
    return (REPO_ROOT / source).resolve()


def _has_installable_content(plugin_dir: Path) -> bool:
    """True when the directory ships at least one skill or one script."""
    if any(plugin_dir.glob("skills/*/SKILL.md")):
        return True
    scripts = plugin_dir / "scripts"
    return scripts.is_dir() and any(p.is_file() for p in scripts.rglob("*"))


def test_manifest_parses():
    assert MANIFEST.exists(), f"marketplace manifest missing: {MANIFEST}"
    assert _entries(), "marketplace declares no plugins"


def test_every_entry_directory_exists():
    for entry in _entries():
        target = _resolve(entry["source"])
        assert target.is_dir(), (
            f"entry {entry['name']!r} points at {entry['source']!r} "
            f"which is not a directory"
        )


def test_every_entry_has_installable_content():
    """No entry may resolve to a directory without skills and without scripts."""
    empty = [
        entry["name"]
        for entry in _entries()
        if not _has_installable_content(_resolve(entry["source"]))
    ]
    assert not empty, (
        f"marketplace entries with no skills and no scripts: {empty}. "
        f"An empty plugin directory must not be published (design D6)."
    )


def test_no_legacy_root_entry():
    """The single-plugin `\"./\"` source is retired by the umbrella layout."""
    legacy = [e["name"] for e in _entries() if e["source"].strip().rstrip("/") in {".", "./"}]
    assert not legacy, f"legacy root entries still present: {legacy}"
