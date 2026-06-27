#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fixture_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
engine_root=$(CDPATH= cd -- "$fixture_root/../../.." && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/WaterRenderPlugin.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

source_file="$fixture_root/Sources/WaterRenderPlugin/Shaders/WaterRenderPlugin.metal"
output_file="$fixture_root/Sources/WaterRenderPlugin/Resources/WaterRenderPlugin.metallib"
include_dir="$engine_root/Sources/UntoldEngineShaderSupport/include"

xcrun -sdk macosx metal \
    -c "$source_file" \
    -I "$include_dir" \
    -fmodules-cache-path="$work_dir/ModuleCache" \
    -o "$work_dir/WaterRenderPlugin.air"
xcrun -sdk macosx metallib \
    "$work_dir/WaterRenderPlugin.air" \
    -o "$output_file"
