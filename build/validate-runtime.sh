#!/usr/bin/env bash
set -euo pipefail

binary=$1
shift
roots=("$@")
readelf_bin=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf

mapfile -t needed < <("$readelf_bin" -d --wide "$binary" | awk '/Shared library:/ {gsub(/[][]/, "", $5); print $5}')
if (( ${#needed[@]} == 0 )); then
    echo "HAL has no dynamic dependencies" >&2
    exit 1
fi

missing=0
binary_machine=$("$readelf_bin" -h "$binary" | awk -F: '/Machine:/ {sub(/^[[:space:]]+/, "", $2); print $2}')
for library in "${needed[@]}"; do
    found='' candidate_machine=''
    for root in "${roots[@]}"; do
        while IFS= read -r -d '' candidate; do
            candidate_machine=$("$readelf_bin" -h "$candidate" 2>/dev/null \
                | awk -F: '/Machine:/ {sub(/^[[:space:]]+/, "", $2); print $2}' || true)
            if [[ $candidate_machine == "$binary_machine" ]]; then
                found=$candidate
                break 2
            fi
        done < <(find "$root" -name "$library" -print0)
    done
    if [[ -z $found ]]; then
        echo "missing from pinned redroid image: $library" >&2
        missing=1
    else
        echo "runtime dependency: $library -> $found"
    fi
done

# A matching SONAME is not enough: an older HIDL executable can still refer to
# a symbol that disappeared in the newer runtime. Compare every strong dynamic
# undefined symbol with exports from the exact image used by the final stage.
symbols_dir=$(mktemp -d)
trap 'rm -rf "$symbols_dir"' EXIT
"$readelf_bin" --dyn-syms --wide "$binary" \
    | awk '$7 == "UND" && $5 == "GLOBAL" {sub(/@.*/, "", $8); print $8}' \
    | sort -u >"$symbols_dir/undefined"

: >"$symbols_dir/exports.unsorted"
while IFS= read -r -d '' candidate; do
    candidate_machine=$("$readelf_bin" -h "$candidate" 2>/dev/null \
        | awk -F: '/Machine:/ {sub(/^[[:space:]]+/, "", $2); print $2}' || true)
    [[ $candidate_machine == "$binary_machine" ]] || continue
    "$readelf_bin" --dyn-syms --wide "$candidate" 2>/dev/null \
        | awk '$7 != "UND" && ($5 == "GLOBAL" || $5 == "WEAK") {sub(/@.*/, "", $8); print $8}' \
        >>"$symbols_dir/exports.unsorted"
done < <(find "${roots[@]}" \( -name '*.so' -o -name '*.so.*' \) -print0)
sort -u "$symbols_dir/exports.unsorted" >"$symbols_dir/exports"

comm -23 "$symbols_dir/undefined" "$symbols_dir/exports" >"$symbols_dir/unresolved"
if [[ -s $symbols_dir/unresolved ]]; then
    echo "strong symbols unresolved by the pinned redroid image:" >&2
    sed 's/^/  /' "$symbols_dir/unresolved" >&2
    missing=1
else
    echo "all strong undefined symbols resolve against the pinned redroid image"
fi

exit "$missing"
