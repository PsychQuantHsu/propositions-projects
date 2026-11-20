#!/bin/bash
# SessionStart hook of the propositions plugin: puts the `propositions` binary this plugin
# version is pinned to into the plugin's data directory, where the skills call it.
#
# A shell of the first kind the Swift rule allows (.claude/rules/swift-is-the-implementation-
# language.md, exception 1): it checks whether the binary is there, downloads it, and runs
# shasum and codesign on it. It decides nothing about a ledger or an outline.
#
# The binary is installed only when it has the SHA-256 in cli.lock AND a Developer ID signature
# of the team in cli.lock. Anything else leaves the directory as it was, prints one line, and
# exits 0: a session never fails because of this hook, and the skills fall back to their own
# commands when the binary is not there.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
LOCK="$HERE/cli.lock"
DATA="${CLAUDE_PLUGIN_DATA:-}"
REPO="PsychQuantHsu/propositions-projects"

[ -n "$DATA" ] || exit 0                       # not run by Claude Code as a plugin hook
# The data directory of this plugin is named after it (propositions-<marketplace>). A shell can
# carry another plugin's CLAUDE_PLUGIN_DATA; writing there would put a binary in that plugin's
# directory, so anything not named after this plugin is left alone.
case "$(basename "$DATA")" in propositions|propositions-*) ;; *) exit 0 ;; esac
[ -f "$LOCK" ] || exit 0
[ "$(uname -s)" = "Darwin" ] || exit 0         # the release is a macOS binary

value() { sed -n "s/^$1=//p" "$LOCK" | head -1; }
VERSION="$(value version)"; WANT="$(value sha256)"; TEAM="$(value team)"
unusable() { echo "propositions: cli.lock has no usable $1; the command-line tool was not fetched"; exit 0; }
case "$VERSION" in ''|*[!0-9.]*) unusable version ;; esac
case "$WANT" in ''|*[!0-9a-f]*) unusable sha256 ;; esac
[ "${#WANT}" = 64 ] || unusable sha256
case "$TEAM" in ''|*[!0-9A-Z]*) unusable team ;; esac

BIN_DIR="$DATA/bin"
BIN="$BIN_DIR/propositions"
sum() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1; }

# Already the pinned binary: nothing to do, and nothing to print.
if [ -f "$BIN" ] && [ ! -L "$BIN" ] && [ "$(sum "$BIN")" = "$WANT" ]; then exit 0; fi

# Anything else at that path is not the pinned binary: remove it first, so that a failed download
# leaves no binary, and the skills fall back, instead of leaving one of another version.
if [ -e "$BIN" ] || [ -L "$BIN" ]; then
  rm -f "$BIN" || { echo "propositions: cannot remove the command-line tool of another version; the skills may call it"; exit 0; }
fi

mkdir -p "$BIN_DIR" || { echo "propositions: cannot make the directory for the command-line tool; it was not fetched"; exit 0; }
TMP="$(mktemp "$BIN_DIR/.fetch.XXXXXX")" || { echo "propositions: cannot write the command-line tool; it was not fetched"; exit 0; }
trap 'rm -f "$TMP"' EXIT

URL="https://github.com/$REPO/releases/download/propositions-cli-v$VERSION/propositions"
if ! curl -fsSL --proto '=https' --connect-timeout 5 --max-time 60 -o "$TMP" "$URL"; then
  echo "propositions: could not download the command-line tool v$VERSION; the skills use their own commands until it is there"
  exit 0
fi
if [ "$(sum "$TMP")" != "$WANT" ]; then
  echo "propositions: the downloaded command-line tool does not have the pinned SHA-256; it was not installed"
  exit 0
fi
if ! codesign --verify --strict "$TMP" 2>/dev/null; then
  echo "propositions: the downloaded command-line tool has no valid signature; it was not installed"
  exit 0
fi
SIGNED_BY="$(codesign -dv --verbose=2 "$TMP" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -1)"
if [ "$SIGNED_BY" != "$TEAM" ]; then
  echo "propositions: the downloaded command-line tool is not signed by the pinned team; it was not installed"
  exit 0
fi
if chmod 755 "$TMP" && mv -f "$TMP" "$BIN"; then
  trap - EXIT
  echo "propositions: installed the command-line tool v$VERSION"
else
  echo "propositions: could not install the command-line tool"
fi
exit 0
