#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/vector
yosys -Q -T -p 'read_verilog -sv rtl/vector/vector_line.sv; synth -top vector_line; check; stat' \
  >build/vector/yosys_line.log 2>&1 || { tail -50 build/vector/yosys_line.log; exit 1; }
# Keep framebuffer memory as memory cells rather than expanding millions of flops.
yosys -Q -T -p 'read_verilog -sv rtl/vector/*.sv; hierarchy -top vector_video; proc; opt; memory_dff; memory_collect; check; stat' \
  >build/vector/yosys_video.log 2>&1 || { tail -50 build/vector/yosys_video.log; exit 1; }
tail -18 build/vector/yosys_video.log
if [[ "${1:-}" == "--quartus" ]]; then
  docker run --rm -v "$PWD:/project" -w /project/synth \
    -u "$(id -u):$(id -g)" theypsilon/quartus-lite-c5:17.0.2 \
    quartus_map Vector-Synthesis >build/vector/quartus.log 2>&1 \
    || { tail -60 build/vector/quartus.log; exit 1; }
  tail -12 build/vector/quartus.log
fi
