#!/bin/bash
# Builds, signs, notarizes and publishes the `propositions` binary.
# A shell of the first kind the Swift rule allows: it runs swift, codesign, notarytool, git
# and gh in order. It is run by the maintainer only: it publishes a file under their
# signing identity. Needs DEVELOPER_ID (certificate SHA-1) and NOTARY_PROFILE (keychain profile).
set -euo pipefail

VERSION="${VERSION:?VERSION is required (for example 0.1.0)}"
DEVELOPER_ID="${DEVELOPER_ID:?DEVELOPER_ID is required (certificate SHA-1)}"
NOTARY_PROFILE="${NOTARY_PROFILE:?NOTARY_PROFILE is required (keychain profile)}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BINARY="propositions"
TAG="propositions-cli-v${VERSION}"

cd "${REPO_ROOT}"

SWIFT_VERSION=$(sed -n 's/.*public static let current = "\(.*\)".*/\1/p' Sources/PropositionsKit/Version.swift)
[ "${SWIFT_VERSION}" = "${VERSION}" ] || {
  echo "VERSION (${VERSION}) differs from Sources/PropositionsKit/Version.swift (${SWIFT_VERSION}); make them equal first"; exit 1; }

# The release must be built from the commit the tag names.
[ -z "$(git status --porcelain)" ] || { echo "the working tree is not clean:"; git status --short; exit 1; }
BUILD_COMMIT=$(git rev-parse HEAD)
git fetch -q --tags origin
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  [ "$(git rev-parse "${TAG}^{commit}")" = "${BUILD_COMMIT}" ] || {
    echo "tag ${TAG} exists and names another commit; choose a new version"; exit 1; }
fi

echo "[1/5] universal release build"
BUILD_ARGS=(-c release --arch arm64 --arch x86_64)
BUILT="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/${BINARY}"
rm -f "${BUILT}"   # still there after the build means this build made it
swift build "${BUILD_ARGS[@]}"
[ -f "${BUILT}" ] || { echo "the build did not produce ${BUILT}"; exit 1; }
GOT=$("${BUILT}" --version)
[ "${GOT}" = "${VERSION}" ] || { echo "the built binary reports ${GOT}, not ${VERSION}"; exit 1; }

OUT="$(mktemp -d)"
cp "${BUILT}" "${OUT}/${BINARY}"

echo "[2/5] codesign (Developer ID, hardened runtime)"
codesign --force --options runtime --timestamp --sign "${DEVELOPER_ID}" "${OUT}/${BINARY}"
codesign --verify --strict "${OUT}/${BINARY}"

echo "[3/5] notarize"
ditto -c -k "${OUT}/${BINARY}" "${OUT}/${BINARY}-notarize.zip"
xcrun notarytool submit "${OUT}/${BINARY}-notarize.zip" --keychain-profile "${NOTARY_PROFILE}" --wait

echo "[4/5] checksum and tag"
shasum -a 256 "${OUT}/${BINARY}" | awk '{print $1}' > "${OUT}/${BINARY}.sha256"
git tag "${TAG}" "${BUILD_COMMIT}" 2>/dev/null || echo "  (the tag exists and names the build commit)"
git push origin "${TAG}"

echo "[5/5] GitHub release"
gh release create "${TAG}" --title "propositions CLI v${VERSION}" \
  --notes "propositions CLI v${VERSION}: signed and notarized universal binary (arm64 and x86_64)" \
  "${OUT}/${BINARY}" "${OUT}/${BINARY}.sha256"

echo "released ${TAG}. Next: set \"binary_version\": \"${VERSION}\" in plugins/propositions/.claude-plugin/plugin.json."
