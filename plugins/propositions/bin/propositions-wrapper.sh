#!/bin/bash
# Downloads the released `propositions` binary this plugin names, then runs it.
# A shell of the first kind the Swift rule allows: it checks, downloads and hands over.
# It decides nothing about ledgers; anything of that kind belongs in the Swift package.
set -u

REPO="PsychQuantHsu/propositions-projects"
BINARY_NAME="propositions"
INSTALL_DIR="${HOME}/bin"
BINARY="${INSTALL_DIR}/${BINARY_NAME}"
VERSION_FILE="${INSTALL_DIR}/.${BINARY_NAME}.version"

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_JSON="${PLUGIN_ROOT}/.claude-plugin/plugin.json"

# Only `binary_version` names a release. The plugin's own `version` is bumped for changes
# to skills and documents that have no binary release behind them, so it is never read here.
DESIRED_VERSION=""
if [[ -f "${PLUGIN_JSON}" ]]; then
    DESIRED_VERSION=$(grep -oE '"binary_version":[[:space:]]*"[^"]+"' "${PLUGIN_JSON}" 2>/dev/null \
        | head -1 | cut -d'"' -f4 || true)
fi
if [[ -z "${DESIRED_VERSION}" ]]; then
    echo "${BINARY_NAME}: the plugin manifest names no binary_version, so no binary has been released for this plugin version. Nothing was downloaded." >&2
    exit 1
fi

INSTALLED_VERSION=""
[[ -f "${VERSION_FILE}" ]] && INSTALLED_VERSION=$(tr -d '[:space:]' < "${VERSION_FILE}" 2>/dev/null || true)

if [[ ! -x "${BINARY}" ]] || [[ "${INSTALLED_VERSION}" != "${DESIRED_VERSION}" ]]; then
    TAG="propositions-cli-v${DESIRED_VERSION}"
    URL="https://github.com/${REPO}/releases/download/${TAG}/${BINARY_NAME}"
    echo "${BINARY_NAME}: downloading v${DESIRED_VERSION} from ${REPO}" >&2
    mkdir -p "${INSTALL_DIR}"
    TMP_DIR="$(mktemp -d)" || { echo "${BINARY_NAME}: cannot make a temporary directory" >&2; exit 1; }
    OK=false
    # Only the tag this plugin names is downloaded, never "latest": a release whose asset is
    # still uploading must not be replaced by an older one under the new version's name.
    if command -v gh >/dev/null 2>&1; then
        gh release download "${TAG}" --repo "${REPO}" --pattern "${BINARY_NAME}" \
            --dir "${TMP_DIR}" 2>/dev/null && OK=true
    fi
    if ! ${OK}; then
        curl -sL --max-time 120 -o "${TMP_DIR}/${BINARY_NAME}" "${URL}" 2>/dev/null \
            && file "${TMP_DIR}/${BINARY_NAME}" 2>/dev/null | grep -q "Mach-O" && OK=true
    fi
    if ${OK} && [[ -s "${TMP_DIR}/${BINARY_NAME}" ]]; then
        chmod +x "${TMP_DIR}/${BINARY_NAME}"
        mv "${TMP_DIR}/${BINARY_NAME}" "${BINARY}"
        echo "${DESIRED_VERSION}" > "${VERSION_FILE}"
        rm -rf "${TMP_DIR}"
    else
        rm -rf "${TMP_DIR}"
        echo "${BINARY_NAME}: could not download ${TAG} (no network, or the release has no asset yet). The installed binary, if any, is another version and was not run." >&2
        exit 1
    fi
fi

exec "${BINARY}" "$@"
