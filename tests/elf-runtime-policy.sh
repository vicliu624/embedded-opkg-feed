#!/usr/bin/env bash
# An empty DT_RPATH/DT_RUNPATH carries no loader search location. It is safe
# only for a byte-identical target transfer; real path values remain rejected.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT

fake_readelf="$work_root/readelf"
cat >"$fake_readelf" <<'EOF'
#!/usr/bin/env bash
case "${*: -1}" in
  *empty*) printf '%s\n' ' 0x000000000000001d (RUNPATH)            Library runpath: []' ;;
  *space*) printf '%s\n' ' 0x000000000000001d (RPATH)              Library rpath: [   ]' ;;
  *unsafe*) printf '%s\n' ' 0x000000000000001d (RUNPATH)            Library runpath: [$ORIGIN/lib]' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_readelf"
touch "$work_root/empty" "$work_root/space" "$work_root/unsafe"

# shellcheck source=/dev/null
source "$repo_root/support/elf-runtime-policy.sh"
tdvp_assert_elf_without_runtime_search_path "$fake_readelf" "$work_root/empty"
tdvp_assert_elf_without_runtime_search_path "$fake_readelf" "$work_root/space"
if tdvp_assert_elf_without_runtime_search_path "$fake_readelf" "$work_root/unsafe"; then
  echo 'accepted a non-empty ELF runtime search path' >&2
  exit 1
fi

echo 'ELF runtime search-path policy: PASS'
