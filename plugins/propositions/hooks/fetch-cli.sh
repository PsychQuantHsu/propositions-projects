#!/bin/bash
# SessionStart hook of the propositions plugin: puts the `propositions` binary this plugin
# version is pinned to into the plugin's data directory, as bin/propositions-<sha256>. The skills
# call it through run-cli.sh, which checks the pin again each time it runs the binary. Binaries
# of other pins are left where they are: a session of another plugin version may be using one.
#
# A shell of the first kind the Swift rule allows (.claude/rules/swift-is-the-implementation-
# language.md, exception 1): it checks whether the binary is there, downloads it, and runs
# shasum and codesign on it. It decides nothing about a ledger or an outline.
#
# A downloaded file is installed only when it has the SHA-256 in cli.lock AND a valid
# Developer ID signature of the team in cli.lock. This guards against a wrong or altered
# download. It is no guard against a process that can already write in the user's home.
#
# The hook always exits 0 and prints at most one line: a session never fails because of it.
set -u

HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
LOCK="$HERE/cli.lock"
DATA="${CLAUDE_PLUGIN_DATA:-}"
REPO="PsychQuantHsu/propositions-projects"

[ -n "$DATA" ] || exit 0                       # not run by Claude Code as a plugin hook
# The data directory of this plugin is named after it (propositions-<marketplace>). A shell can
# carry another plugin's CLAUDE_PLUGIN_DATA; writing there would put a binary in that plugin's
# directory, so anything not named after this plugin is left alone.
case "$(basename "$DATA")" in propositions|propositions-*) ;; *) exit 0 ;; esac
[ "$(uname -s)" = "Darwin" ] || exit 0         # the release is a macOS binary

# The lock is exactly three lines: version=, sha256=, team=, in that order.
unusable() { echo "propositions: cli.lock has no usable $1; the command-line tool was not fetched"; exit 0; }
L1=""; L2=""; L3=""; L4=""; MORE=""
# A file that cannot be opened, or that holds a NUL byte (which read would drop), is unusable.
[ -f "$LOCK" ] && LC_ALL=C tr -d '\000' 2>/dev/null < "$LOCK" | cmp -s - "$LOCK" 2>/dev/null \
  || unusable "form (the file cannot be read, or holds a NUL byte)"
{ IFS= read -r L1; IFS= read -r L2; IFS= read -r L3; if IFS= read -r L4 || [ -n "$L4" ]; then MORE=1; fi; } 2>/dev/null < "$LOCK"
[ -z "$MORE" ] || unusable "form (three lines: version, sha256, team)"
[[ "$L1" =~ ^version=([0-9]+\.[0-9]+\.[0-9]+)$ ]] || unusable version
VERSION="${BASH_REMATCH[1]}"
[[ "$L2" =~ ^sha256=([0-9a-f]{64})$ ]] || unusable sha256
WANT="${BASH_REMATCH[1]}"
[[ "$L3" =~ ^team=([0-9A-Z]{10})$ ]] || unusable team
TEAM="${BASH_REMATCH[1]}"

BIN_DIR="$DATA/bin"
# The file name holds the pinned hash: each pin has a path of its own, which a session of another
# plugin version never writes to or removes.
BIN="$BIN_DIR/propositions-$WANT"
sum() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1; }

[ ! -L "$BIN_DIR" ] || { echo "propositions: the directory for the command-line tool is a link; it was not fetched"; exit 0; }

# Already the pinned binary, and it can be run: nothing to do, and nothing to print.
if [ -f "$BIN" ] && [ ! -L "$BIN" ] && [ -x "$BIN" ] && [ "$(sum "$BIN")" = "$WANT" ]; then exit 0; fi

# Anything else at that path is not the pinned binary (a cut-off or altered file): remove it first.
if [ -e "$BIN" ] || [ -L "$BIN" ]; then
  rm -f "$BIN" 2>/dev/null || { echo "propositions: cannot remove what is in the place of the command-line tool; the skills will not run it"; exit 0; }
fi

mkdir -p "$BIN_DIR" 2>/dev/null || { echo "propositions: cannot make the directory for the command-line tool; it was not fetched"; exit 0; }
TMP="$(mktemp "$BIN_DIR/.fetch.XXXXXX" 2>/dev/null)" || { echo "propositions: cannot write the command-line tool; it was not fetched"; exit 0; }
trap 'rm -f "$TMP" 2>/dev/null' EXIT

URL="https://github.com/$REPO/releases/download/propositions-cli-v$VERSION/propositions"
if ! curl -q -fsL --proto '=https' --connect-timeout 5 --max-time 30 --max-filesize 52428800 -o "$TMP" "$URL" 2>/dev/null; then
  echo "propositions: could not download the command-line tool v$VERSION; the checks that need it are reported as not run"
  exit 0
fi
if [ "$(sum "$TMP")" != "$WANT" ]; then
  echo "propositions: the downloaded command-line tool does not have the pinned SHA-256; it was not installed"
  exit 0
fi
# Apple's Developer ID requirement, for the pinned team.
REQUIREMENT="anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"$TEAM\""
if ! codesign --verify --strict -R="$REQUIREMENT" "$TMP" 2>/dev/null; then
  echo "propositions: the downloaded command-line tool has no valid Developer ID signature of the pinned team; it was not installed"
  exit 0
fi
if chmod 755 "$TMP" 2>/dev/null && mv -f "$TMP" "$BIN" 2>/dev/null; then
  trap - EXIT
  echo "propositions: installed the command-line tool v$VERSION"
else
  echo "propositions: could not install the command-line tool"
fi
exit 0
