#!/usr/bin/env bash
# Regenerate from the locked upstream schemas with the same FlatBuffers
# generator version as the public target provider. Keep compatibility asserts.
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 2 ]] || exit 64
source_root=$(realpath -e -- "$1")
flatc=$(realpath -e -- "$2")
schema_dir="$source_root/tensorflow/compiler/mlir/lite/schema"
[[ -f "$source_root/LICENSE" && -f "$schema_dir/schema.fbs" && -x "$flatc" ]] || exit 65
[[ "$("$flatc" --version)" == 'flatc version 24.12.23' ]] || {
  echo 'TensorFlow Lite schemas require the declared public FlatBuffers generator version' >&2
  exit 66
}
for schema in schema conversion_metadata debug_metadata; do
  [[ -f "$schema_dir/$schema.fbs" ]] || exit 67
  "$flatc" --cpp --gen-object-api --gen-mutable --reflect-types --reflect-names \
    --no-union-value-namespacing -o "$schema_dir" "$schema_dir/$schema.fbs"
  [[ -s "$schema_dir/${schema}_generated.h" ]] || exit 68
done
for configuration in acceleration/configuration; do
  configuration_dir="$source_root/tensorflow/lite/$configuration"
  [[ -f "$configuration_dir/configuration.proto" ]] || exit 69
  "$flatc" --proto -I "$source_root" -o "$configuration_dir" "$configuration_dir/configuration.proto"
  # Follow TensorFlow's own BUILD rule: protobuf and FlatBuffers definitions
  # must have distinct namespaces in the generated C++ interfaces.
  sed -i 's/tflite\.proto/tflite/g' "$configuration_dir/configuration.fbs"
  if [[ -f "$configuration_dir/testdata/configuration.old.fbs" ]]; then
    "$flatc" --conform "$configuration_dir/testdata/configuration.old.fbs" \
      --cpp -o "$configuration_dir" "$configuration_dir/configuration.fbs"
  fi
done
while IFS= read -r -d '' schema_file; do
  schema_parent=$(dirname -- "$schema_file")
  schema_name=$(basename -- "$schema_file" .fbs)
  # Regenerate only schemas with a checked-in C++ header. Test-only binary
  # schemas and source compatibility fixtures do not become build inputs.
  [[ -f "$schema_parent/${schema_name}_generated.h" ]] || continue
  "$flatc" --cpp --gen-object-api --gen-mutable --reflect-types --reflect-names \
    --no-union-value-namespacing -I "$source_root" -I "$schema_parent" \
    -o "$schema_parent" "$schema_file"
done < <(find "$source_root/tensorflow/lite" -type f -name '*.fbs' -print0)
echo 'TensorFlow Lite schemas regenerated with declared FlatBuffers version'
