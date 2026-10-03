#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/sim
yosys -Q -T -p 'read_verilog -sv rtl/ccpu/ccpu.sv; synth -top ccpu; check; stat' \
  >build/sim/yosys.log 2>&1 || { tail -50 build/sim/yosys.log; exit 1; }
tail -22 build/sim/yosys.log
if [[ "${1:-}" == "--quartus" ]]; then
  docker run --rm -v "$PWD:/project" -w /project/synth \
    -u "$(id -u):$(id -g)" theypsilon/quartus-lite-c5:17.0.2 \
    quartus_map CCPU-Synthesis >build/sim/quartus.log 2>&1 \
    || { tail -60 build/sim/quartus.log; exit 1; }
  tail -12 build/sim/quartus.log
fi
