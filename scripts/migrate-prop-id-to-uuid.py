#!/usr/bin/env python3
"""Forwarding shim (umbrella-marketplace-migration): implementation lives in
plugins/propositions/scripts/migrate-prop-id-to-uuid.py. Preserves the pinned entry-point contract."""
import os, runpy, sys

_target = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       os.pardir, "plugins", "propositions", "scripts", "migrate-prop-id-to-uuid.py")
sys.argv[0] = _target
runpy.run_path(_target, run_name="__main__")
