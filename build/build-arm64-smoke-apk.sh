#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_dir=$(cd -- "$script_dir/.." && pwd)
project_dir=$repository_dir/tests/arm64-smoke-app
sdk_root=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
[[ -n $sdk_root ]] || { echo "ANDROID_SDK_ROOT or ANDROID_HOME is required" >&2; exit 2; }

build_tools=$(find "$sdk_root/build-tools" -mindepth 1 -maxdepth 1 -type d \
    -printf '%f\n' | sort -V | tail -1)
platform=$(find "$sdk_root/platforms" -mindepth 1 -maxdepth 1 -type d \
    -printf '%f\n' | sort -V | tail -1)
ndk_version=$(find "$sdk_root/ndk" -mindepth 1 -maxdepth 1 -type d \
    -printf '%f\n' | sort -V | tail -1)

tools=$sdk_root/build-tools/$build_tools
android_jar=$sdk_root/platforms/$platform/android.jar
ndk=$sdk_root/ndk/$ndk_version
output=${1:-$repository_dir/.runtime/redroid-arm64-smoke.apk}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/classes" "$work/apk/lib/arm64-v8a" "$(dirname -- "$output")"
javac --release 8 -classpath "$android_jar" -d "$work/classes" \
    "$project_dir/MainActivity.java"
"$tools/d8" --lib "$android_jar" --output "$work/apk" \
    "$work/classes/dev/redroid/arm64smoke/MainActivity.class"
"$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android23-clang" \
    -O2 -fPIC -shared "$project_dir/native.c" \
    -I"$ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include" \
    -o "$work/apk/lib/arm64-v8a/libredroid_arm64_smoke.so"

"$tools/aapt2" link -o "$work/unsigned.apk" -I "$android_jar" \
    --manifest "$project_dir/AndroidManifest.xml"
(
    cd "$work/apk"
    zip -q -u "$work/unsigned.apk" classes.dex \
        lib/arm64-v8a/libredroid_arm64_smoke.so
)
"$tools/zipalign" -f 4 "$work/unsigned.apk" "$work/aligned.apk"
"$tools/apksigner" sign --ks "$HOME/.android/debug.keystore" \
    --ks-pass pass:android --key-pass pass:android \
    --out "$output" "$work/aligned.apk"
"$tools/apksigner" verify "$output"
echo "$output"
