#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=${ROOT_DIR:-$SCRIPT_DIR}
OUTPUT=${OUTPUT:-$SCRIPT_DIR/posters_montage.jpg}
COLUMNS=${COLUMNS:-15}
ROWS=${ROWS:-15}
MEGAPIXELS=${MEGAPIXELS:-24}
DENSITY=${DENSITY:-96}
GUTTER=${GUTTER:-6}
BACKGROUND=${BACKGROUND:-white}
TILE_BACKGROUND=${TILE_BACKGROUND:-white}
QUALITY=${QUALITY:-90}

usage() {
  cat <<'EOF'
Create a tiled montage of poster PDFs using ImageMagick.

Usage:
  create_poster_montage.sh [root_dir] [output_file]

Environment overrides:
  COLUMNS=15        Number of columns in the montage grid.
  ROWS=15           Number of rows in the montage grid.
  MEGAPIXELS=24     Approximate total output resolution in megapixels.
  DENSITY=96        Rasterization density for PDF input pages.
  GUTTER=6          Gap in pixels between tiles.
  BACKGROUND=white  Overall montage background.
  TILE_BACKGROUND=white
                    Fill color behind each poster thumbnail.
  QUALITY=90        JPEG quality when writing .jpg/.jpeg output.
  ROOT_DIR=...      Alternative poster root.
  OUTPUT=...        Alternative output path.

Examples:
  ./create_poster_montage.sh
  COLUMNS=12 ROWS=18 MEGAPIXELS=30 ./create_poster_montage.sh
  DENSITY=120 OUTPUT=all-posters.png ./create_poster_montage.sh ./Posters
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -ge 1 ]]; then
  ROOT_DIR=$1
fi

if [[ $# -ge 2 ]]; then
  OUTPUT=$2
fi

if [[ $# -gt 2 ]]; then
  echo "error: too many arguments" >&2
  usage >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "error: ImageMagick 'magick' is required but was not found in PATH." >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "error: poster root not found: $ROOT_DIR" >&2
  exit 1
fi

if ! [[ "$COLUMNS" =~ ^[0-9]+$ && "$ROWS" =~ ^[0-9]+$ && "$GUTTER" =~ ^[0-9]+$ && "$DENSITY" =~ ^[0-9]+$ ]]; then
  echo "error: COLUMNS, ROWS, GUTTER, and DENSITY must be non-negative integers." >&2
  exit 1
fi

if ! awk -v mp="$MEGAPIXELS" 'BEGIN { exit !(mp > 0) }'; then
  echo "error: MEGAPIXELS must be greater than zero." >&2
  exit 1
fi

if [[ "$COLUMNS" -lt 1 || "$ROWS" -lt 1 ]]; then
  echo "error: COLUMNS and ROWS must be at least 1." >&2
  exit 1
fi

read -r canvas_width canvas_height <<EOF
$(awk -v mp="$MEGAPIXELS" -v cols="$COLUMNS" -v rows="$ROWS" 'BEGIN {
  total_pixels = mp * 1000000;
  aspect = 4/3.0;
  width = int(sqrt(total_pixels * aspect) + 0.5);
  height = int(total_pixels / width + 0.5);
  print width, height;
}')
EOF

tile_width=$(( (canvas_width - ((COLUMNS - 1) * GUTTER)) / COLUMNS ))
tile_height=$(( (canvas_height - ((ROWS - 1) * GUTTER)) / ROWS ))

if [[ "$tile_width" -lt 1 || "$tile_height" -lt 1 ]]; then
  echo "error: computed tile size is invalid (${tile_width}x${tile_height}). Reduce GUTTER or increase MEGAPIXELS." >&2
  exit 1
fi

inputs=()
while IFS= read -r -d '' src; do
  inputs+=("${src}[0]")
done < <(find "$ROOT_DIR" -type f -iname '*.pdf' -print0 | sort -z)

input_count=${#inputs[@]}
if [[ "$input_count" -eq 0 ]]; then
  echo "error: no PDF files found under $ROOT_DIR" >&2
  exit 1
fi

cell_count=$(( COLUMNS * ROWS ))
if [[ "$input_count" -gt "$cell_count" ]]; then
  echo "warning: found $input_count pdf(s), but the grid only has $cell_count cells; only the first $cell_count posters will be used." >&2
  inputs=("${inputs[@]:0:$cell_count}")
  input_count=${#inputs[@]}
fi

while [[ "${#inputs[@]}" -lt "$cell_count" ]]; do
  inputs+=("xc:${TILE_BACKGROUND}")
done

mkdir -p -- "$(dirname -- "$OUTPUT")"

echo "creating montage:"
echo "  root: $ROOT_DIR"
echo "  output: $OUTPUT"
echo "  posters used: $input_count"
echo "  grid: ${COLUMNS}x${ROWS}"
echo "  canvas: ${canvas_width}x${canvas_height}"
echo "  tile: ${tile_width}x${tile_height}"

magick montage \
  -define pdf:use-cropbox=true \
  -density "$DENSITY" \
  "${inputs[@]}" \
  -strip \
  -thumbnail "${tile_width}x${tile_height}" \
  -gravity center \
  -background "$TILE_BACKGROUND" \
  -extent "${tile_width}x${tile_height}" \
  -tile "${COLUMNS}x${ROWS}" \
  -geometry "${tile_width}x${tile_height}+${GUTTER}+${GUTTER}" \
  -background "$BACKGROUND" \
  -quality "$QUALITY" \
  "$OUTPUT"

echo "done: wrote $OUTPUT"