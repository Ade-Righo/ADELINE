#!/usr/bin/env bash
set -euo pipefail

APP_NAME="adeline"
SRC_PATH="$(cd "$(dirname "$0")" && pwd)"
TARGET="/usr/local/bin/${APP_NAME}"

if [[ $EUID -ne 0 ]]; then
    echo "[INFO] Installing ADELINE to /usr/local/bin..."
    if command -v sudo >/dev/null 2>&1; then
        sudo cp "$SRC_PATH/adeline.py" "$TARGET"
        sudo chmod +x "$TARGET"
    else
        cp "$SRC_PATH/adeline.py" "$TARGET"
        chmod +x "$TARGET"
    fi
else
    cp "$SRC_PATH/adeline.py" "$TARGET"
    chmod +x "$TARGET"
fi

echo "ADELINE installed successfully."
echo "Run: adeline --help"
