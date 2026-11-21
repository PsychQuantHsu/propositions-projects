"""derive-paragraphs.py was retired on 2026-11-21; `propositions paragraphs` replaces it.

What the Swift command does is tested in tests/PropositionsKitTests/ParagraphsTests.swift. This file keeps one
case: the retired script tells whoever runs it what to run instead, and fails.
"""
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
SCRIPTS = [REPO_ROOT / "plugins" / "propositions" / "scripts" / "derive-paragraphs.py"]


def test_the_retired_script_points_to_the_swift_command():
    for script in SCRIPTS:
        result = subprocess.run([sys.executable, str(script), "--any", "argument"], capture_output=True, text=True)
        assert result.returncode == 2, script
        assert result.stdout == "", script
        assert "derive-paragraphs.py was retired on 2026-11-21" in result.stderr, script
        assert "propositions paragraphs" in result.stderr, script
        assert "releases/tag/propositions-cli-v" in result.stderr, script
