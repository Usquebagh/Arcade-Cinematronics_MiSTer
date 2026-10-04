#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/prepare_overlay.py --check
root="$PWD"
args=()
for arg in "$@"; do args+=("$(realpath -m "$arg")"); done
mkdir -p build/overlay
work_dir="$(mktemp -d /tmp/cinematronics-overlay.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp -R rtl sim "$work_dir/"
cd "$work_dir"
# Test the shared module with the exact generated profile palette.
gains=$(sed -n "s/.*= \(.*\);/\1/p" rtl/video/overlays/starcastle_gains.svh | tail -1)
verilator --cc --exe --build --top-module vector_overlay -Wall -Wno-UNUSEDSIGNAL \
  "-GGAINS=$gains" --Mdir obj rtl/video/vector_overlay.sv \
  "$PWD/sim/vector_overlay_test.cpp" >compile.log 2>&1 \
  || { cat compile.log; exit 1; }
cp compile.log "$root/build/overlay/compile.log"
obj/Vvector_overlay "${args[@]}" | tee "$root/build/overlay/results.txt"
