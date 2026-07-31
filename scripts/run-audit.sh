#!/bin/sh
# Forwarding shim (umbrella-marketplace-migration): the implementation lives in
# plugins/propositions/scripts/. This shim preserves the pinned CI entry-point
# contract (propositions-plugin/scripts/run-audit.sh) byte-transparently.
exec "$(cd "$(dirname "$0")/.." && pwd)/plugins/propositions/scripts/run-audit.sh" "$@"
