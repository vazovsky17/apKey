#!/usr/bin/env bash
# Installs apkey into a directory on PATH.
#   curl -fsSL https://raw.githubusercontent.com/vazovsky17/apKey/main/install.sh | bash
# Override the target directory with PREFIX, e.g. PREFIX="$HOME/.local/bin".

set -euo pipefail

REPO_RAW="${APKEY_RAW:-https://raw.githubusercontent.com/vazovsky17/apKey/main}"

if [[ -z "${PREFIX:-}" ]]; then
  if [[ -w /usr/local/bin ]]; then PREFIX=/usr/local/bin; else PREFIX="$HOME/.local/bin"; fi
fi
mkdir -p "$PREFIX"
TARGET="$PREFIX/apkey"

# Local checkout: copy the script next to this file; otherwise download it.
SRC_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -n "$SRC_DIR" && -f "$SRC_DIR/apkey.sh" ]]; then
  cp "$SRC_DIR/apkey.sh" "$TARGET"
else
  curl -fsSL "$REPO_RAW/apkey.sh" -o "$TARGET"
fi
chmod +x "$TARGET"

echo "Installed: $TARGET"
case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) echo "Note: $PREFIX is not on PATH. Add to your shell profile:"
     echo "  export PATH=\"$PREFIX:\$PATH\"" ;;
esac
