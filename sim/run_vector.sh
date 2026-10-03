#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
args=()
for arg in "$@"; do args+=("$(realpath -m "$arg")"); done
work_dir="$(mktemp -d /tmp/cinematronics-vector.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp -R rtl sim "$work_dir/"
cd "$work_dir"
mkdir -p build
verilator --cc --exe --build --top-module vector_line -Wall -Wno-UNUSEDSIGNAL \
  --Mdir build/obj rtl/vector/vector_line.sv "$PWD/sim/vector_line_test.cpp" \
  >build/compile.log 2>&1 || { cat build/compile.log; exit 1; }
mkdir -p "$root/build/vector"
cp build/compile.log "$root/build/vector/compile.log"
build/obj/Vvector_line "${args[@]}" | tee "$root/build/vector/results.txt"
verilator --cc --exe --build --top-module vector_framebuffer -Wall -Wno-UNUSEDSIGNAL \
  --Mdir build/fb_obj rtl/vector/vector_framebuffer.sv "$PWD/sim/framebuffer_test.cpp" \
  >build/framebuffer_compile.log 2>&1 || { cat build/framebuffer_compile.log; exit 1; }
cp build/framebuffer_compile.log "$root/build/vector/framebuffer_compile.log"
build/fb_obj/Vvector_framebuffer | tee -a "$root/build/vector/results.txt"
verilator --cc --exe --build --top-module vector_video -Wall -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
  --Mdir build/video_obj rtl/vector/*.sv "$PWD/sim/vector_video_test.cpp" \
  >build/video_compile.log 2>&1 || { cat build/video_compile.log; exit 1; }
cp build/video_compile.log "$root/build/vector/video_compile.log"
build/video_obj/Vvector_video "${args[@]}" | tee -a "$root/build/vector/results.txt"
