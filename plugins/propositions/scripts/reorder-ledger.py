#!/usr/bin/env python3
"""reorder-ledger.py — retired on 2026-11-21. Use `propositions ledger-order` instead."""
import sys

sys.stderr.write(
    "reorder-ledger.py was retired on 2026-11-21: use the propositions command-line tool instead.\n"
    "  propositions ledger-order --jsonl <ledger> [--tex <main file>] [--write]\n"
    "The propositions plugin fetches it at session start on macOS; it is also at\n"
    "  https://github.com/PsychQuantHsu/propositions-projects/releases/tag/propositions-cli-v0.2.0\n"
)
sys.exit(2)
