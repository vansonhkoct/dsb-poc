#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="${1:-$ROOT_DIR/README.md}"
OUTPUT="${2:-$ROOT_DIR/README.pdf}"
INPUT_DIR="$(cd "$(dirname "$INPUT")" && pwd)"
INPUT_BASENAME="$(basename "$INPUT")"
GENERATED="$INPUT_DIR/$(basename "$INPUT_BASENAME" .md).pdf"

if [[ ! -f "$INPUT" ]]; then
  echo "Input file not found: $INPUT" >&2
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx is required. Install Node.js, then rerun this script." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

npx --yes md-to-pdf "$INPUT" --basedir "$ROOT_DIR" --pdf-options '{"format":"A4","printBackground":true}'

if [[ "$GENERATED" != "$OUTPUT" ]]; then
  mv "$GENERATED" "$OUTPUT"
fi

echo "Wrote $OUTPUT"
