#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/glow
root="$PWD"
work_dir="$(mktemp -d /tmp/cinematronics-glow.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp -R rtl sim "$work_dir/"
cd "$work_dir"
verilator --cc --exe --build --top-module vector_glow -Wall -Wno-UNUSEDSIGNAL \
  -GLINE_PIXELS=48 --Mdir obj -CFLAGS "-std=c++17" rtl/video/vector_glow.sv \
  "$PWD/sim/vector_glow_test.cpp" >compile.log 2>&1 \
  || { cat compile.log; exit 1; }
cp compile.log "$root/build/glow/compile.log"
obj/Vvector_glow | tee "$root/build/glow/results.txt"
