#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=${1:-$SCRIPT_DIR}

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "error: poster root not found: $ROOT_DIR" >&2
  exit 1
fi

deleted_count=0
renamed_count=0
skipped_count=0

while IFS= read -r -d '' src; do
  echo "delete: $src"
  rm -- "$src"
  ((deleted_count += 1))
done < <(find "$ROOT_DIR" -type f -iname '*.pdf' ! -iname '*144dpi*' -print0 | sort -z)

while IFS= read -r -d '' src; do
  dir=$(dirname -- "$src")
  name=$(basename -- "$src")
  target_name=${name#Copy of }

  if [[ "$target_name" == "$name" ]]; then
    ((skipped_count += 1))
    continue
  fi

  target="$dir/$target_name"
  if [[ -e "$target" ]]; then
    echo "error: rename target already exists: $target" >&2
    exit 1
  fi

  echo "rename: $src -> $target"
  mv -- "$src" "$target"
  ((renamed_count += 1))
done < <(find "$ROOT_DIR" -type f -iname 'Copy of *.pdf' -print0 | sort -z)

echo
echo "done: deleted $deleted_count original pdf(s), renamed $renamed_count compressed pdf(s), skipped $skipped_count file(s) without the prefix."