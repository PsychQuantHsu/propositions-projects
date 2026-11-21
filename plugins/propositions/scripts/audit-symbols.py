#!/usr/bin/env python3
"""audit-symbols.py — retired on 2026-11-21. Use `propositions audit symbols` instead."""
import sys

sys.stderr.write(
    "audit-symbols.py was retired on 2026-11-21: use the propositions command-line tool instead.\n"
    "  propositions audit symbols --manuscript-root <directory> [--tex <main file>] [--report-format md|json]\n"
    "The propositions plugin fetches it at session start on macOS; it is also at\n"
    "  https://github.com/PsychQuantHsu/propositions-projects/releases/tag/propositions-cli-v0.2.0\n"
)
sys.exit(2)
