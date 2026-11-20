#!/bin/bash
# Runs the `propositions` binary that this plugin version is pinned to, and no other.
#
#   bash run-cli.sh <plugin data directory> <subcommand> [arguments...]
#
# A shell of the first kind the Swift rule allows (.claude/rules/swift-is-the-implementation-
# language.md, exception 1): it checks that the binary fetch-cli.sh installed for this pin
# (bin/propositions-<sha256>, a path no other pin uses) is there and has the SHA-256 in cli.lock,
# then runs it. It decides nothing about a ledger or an outline.
#
# When the pinned binary is not there, it prints one line that starts with
# "propositions: NOT RUN" and exits 3. The subcommands use 0, 1 and 2, so 3 always means that
# the check did not run. A skill reports such a check as not run, never as passed.
#
# One case is outside this: the pinned file is there and has the pinned hash, and the system
# still cannot start it. Then the shell's own message is printed and the status is the shell's
# (126 or 127), which is none of 0 to 3. A skill reports every status but 0 as not checked.
set -u

not_run() { echo "propositions: NOT RUN ($1)"; exit 3; }

[ "$#" -ge 2 ] || not_run "usage: run-cli.sh <plugin data directory> <subcommand> [arguments...]"
DATA="$1"; shift

HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
LOCK="$HERE/cli.lock"

# The skill writes the data directory as ${CLAUDE_PLUGIN_DATA}, which Claude Code replaces when
# it loads the skill. Where it was not replaced, the shell gives nothing, or the directory of
# another plugin: neither is this plugin's.
case "$(basename "$DATA")" in
  propositions|propositions-*) ;;
  *) not_run "the plugin's data directory is not known here" ;;
esac

L1=""; L2=""; L3=""; L4=""; MORE=""
[ -f "$LOCK" ] && LC_ALL=C tr -d '\000' 2>/dev/null < "$LOCK" | cmp -s - "$LOCK" 2>/dev/null \
  || not_run "cli.lock is unusable"
{ IFS= read -r L1; IFS= read -r L2; IFS= read -r L3; if IFS= read -r L4 || [ -n "$L4" ]; then MORE=1; fi; } 2>/dev/null < "$LOCK"
[ -z "$MORE" ] || not_run "cli.lock is unusable"
[[ "$L1" =~ ^version=([0-9]+\.[0-9]+\.[0-9]+)$ ]] || not_run "cli.lock is unusable"
VERSION="${BASH_REMATCH[1]}"
[[ "$L2" =~ ^sha256=([0-9a-f]{64})$ ]] || not_run "cli.lock is unusable"
WANT="${BASH_REMATCH[1]}"
[[ "$L3" =~ ^team=([0-9A-Z]{10})$ ]] || not_run "cli.lock is unusable"

BIN="$DATA/bin/propositions-$WANT"
[ ! -L "$DATA/bin" ] && [ -f "$BIN" ] && [ ! -L "$BIN" ] && [ -x "$BIN" ] \
  || not_run "the command-line tool v$VERSION is not installed; it is fetched at session start, on macOS only"
[ "$(shasum -a 256 "$BIN" 2>/dev/null | cut -d' ' -f1)" = "$WANT" ] \
  || not_run "the file in the place of the command-line tool v$VERSION does not have the pinned SHA-256"

exec "$BIN" "$@"
