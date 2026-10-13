#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 2 ]] || exit 64
source_root=$(realpath -e -- "$1")
flatc=$(realpath -e -- "$2")
schema_dir="$source_root/onnxruntime/core/flatbuffers/schema"
[[ -f "$source_root/LICENSE" && -f "$schema_dir/ort.fbs" && -x "$flatc" ]] || exit 65
[[ "$("$flatc" --version)" == 'flatc version 24.12.23' ]] || exit 66
for schema in ort ort_training_checkpoint; do
  "$flatc" --cpp --scoped-enums --filename-suffix .fbs -I "$schema_dir" \
    -o "$schema_dir" "$schema_dir/$schema.fbs"
  [[ -s "$schema_dir/$schema.fbs.h" ]] || exit 67
done
while IFS= read -r -d '' schema_file; do
  schema_parent=$(dirname -- "$schema_file")
  [[ -f "$schema_file.h" ]] || continue
  "$flatc" --cpp --scoped-enums --filename-suffix .fbs \
    -I "$schema_dir" -I "$schema_parent" -o "$schema_parent" "$schema_file"
done < <(find "$source_root/onnxruntime" -type f -name '*.fbs' -print0)
echo 'ONNX Runtime schemas regenerated with declared FlatBuffers version'
