#!/usr/bin/env python3
"""derive-paragraphs.py — retired on 2026-11-21. Use `propositions paragraphs` instead."""
import sys

sys.stderr.write(
    "derive-paragraphs.py was retired on 2026-11-21: use the propositions command-line tool instead.\n"
    "  propositions paragraphs --jsonl <ledger> --tex <main file> [--structure <structure.json>]\n"
    "The propositions plugin fetches it at session start on macOS; it is also at\n"
    "  https://github.com/PsychQuantHsu/propositions-projects/releases/tag/propositions-cli-v0.2.0\n"
)
sys.exit(2)
