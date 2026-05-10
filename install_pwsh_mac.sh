#!/bin/bash
set -euo pipefail

ARCH="$(uname -m)"
case "${ARCH}" in
    arm64)   PATTERN="osx-arm64.pkg" ;;
    x86_64)  PATTERN="osx-x64.pkg" ;;
    *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

echo "Fetching latest PowerShell release URL..."
PKG_URL=$(curl -fsSL https://api.github.com/repos/PowerShell/PowerShell/releases/latest \
    | grep -o '"browser_download_url": *"[^"]*'"${PATTERN}"'"' \
    | head -1 \
    | grep -o 'https://[^"]*' \
    | tr -d '\r\n')

if [[ -z "${PKG_URL}" ]]; then
    echo "Could not find a .pkg asset matching: ${PATTERN}"
    exit 1
fi

echo "Downloading $(basename "${PKG_URL}")..."
curl -fsSL -o /tmp/pwsh.pkg "${PKG_URL}"

echo "Installing (requires sudo)..."
sudo installer -pkg /tmp/pwsh.pkg -target /
rm -f /tmp/pwsh.pkg

echo "Done. Verify with: pwsh --version"

