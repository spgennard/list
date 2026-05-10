#!/bin/bash
set -euo pipefail

REPO="spgennard/list"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin"

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
    Darwin)
        case "${ARCH}" in
            arm64) PATTERN="macos-arm64" ;;
            x86_64) PATTERN="macos-x64" ;;
            *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
        esac
        ;;
    Linux)
        case "${ARCH}" in
            x86_64) PATTERN="linux-x64" ;;
            aarch64) PATTERN="linux-arm64" ;;
            *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported OS: ${OS}"
        exit 1
        ;;
esac

echo "Fetching latest release info from ${REPO}..."
DOWNLOAD_URL=$(curl -fsSL "${API_URL}" \
    | grep -o '"browser_download_url": *"[^"]*'"${PATTERN}"'[^"]*"' \
    | grep -o 'https://[^"]*')

if [[ -z "${DOWNLOAD_URL}" ]]; then
    echo "No release asset found matching platform: ${PATTERN}"
    exit 1
fi

FILENAME="$(basename "${DOWNLOAD_URL}")"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Downloading ${FILENAME}..."
curl -fsSL -o "${TMPDIR}/${FILENAME}" "${DOWNLOAD_URL}"

echo "Extracting..."
tar -xzf "${TMPDIR}/${FILENAME}" -C "${TMPDIR}"

# Find the extracted 'list' binary
LIST_BIN="$(find "${TMPDIR}" -type f -name "list" | head -1)"
if [[ -z "${LIST_BIN}" ]]; then
    echo "Could not find 'list' binary in archive"
    exit 1
fi

chmod +x "${LIST_BIN}"
cp "${LIST_BIN}" "${BIN_DIR}/list"
echo "Installed list -> ${BIN_DIR}/list"
