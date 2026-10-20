#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/verify-localization-completeness.py"

if command -v python3 >/dev/null 2>&1; then
    exec python3 "$PY_SCRIPT"
elif command -v python >/dev/null 2>&1; then
    exec python "$PY_SCRIPT"
else
    echo "ERROR: Neither python3 nor python is available" >&2
    exit 1
fi
