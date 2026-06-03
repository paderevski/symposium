#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=${1:-$SCRIPT_DIR}
FORCE=${FORCE:-0}

if ! command -v gs >/dev/null 2>&1; then
  echo "error: Ghostscript (gs) is required but was not found in PATH." >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "error: poster root not found: $ROOT_DIR" >&2
  exit 1
fi

count_total=0
count_created=0
count_skipped=0

while IFS= read -r -d '' src; do
  ((count_total += 1))

  if [[ "$src" == *_144dpi.pdf ]]; then
    ((count_skipped += 1))
    continue
  fi

  out="${src%.pdf}_144dpi.pdf"
  if [[ -f "$out" && "$FORCE" != "1" ]]; then
    echo "skip: $out already exists"
    ((count_skipped += 1))
    continue
  fi

  echo "compress: $src -> $out"
  gs \
    -sDEVICE=pdfwrite \
    -dCompatibilityLevel=1.4 \
    -dNOPAUSE \
    -dQUIET \
    -dBATCH \
    -dDetectDuplicateImages=true \
    -dCompressFonts=true \
    -dSubsetFonts=true \
    -dAutoRotatePages=/None \
    -dDownsampleColorImages=true \
    -dColorImageDownsampleType=/Bicubic \
    -dColorImageResolution=144 \
    -dAutoFilterColorImages=false \
    -dColorImageFilter=/DCTEncode \
    -dJPEGQ=70 \
    -dDownsampleGrayImages=true \
    -dGrayImageDownsampleType=/Bicubic \
    -dGrayImageResolution=144 \
    -dAutoFilterGrayImages=false \
    -dGrayImageFilter=/DCTEncode \
    -dDownsampleMonoImages=true \
    -dMonoImageDownsampleType=/Subsample \
    -dMonoImageResolution=300 \
    -sOutputFile="$out" \
    "$src"

  ((count_created += 1))
done < <(find "$ROOT_DIR" -type f -iname '*.pdf' -print0 | sort -z)

echo
echo "done: scanned $count_total pdf(s), created $count_created compressed file(s), skipped $count_skipped file(s)."
echo "set FORCE=1 to overwrite existing __compressed_144dpi outputs."