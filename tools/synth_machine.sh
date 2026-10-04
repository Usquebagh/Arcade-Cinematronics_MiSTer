#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/machine
yosys -Q -T -p 'read_verilog -sv rtl/ccpu/*.sv rtl/games/*.sv rtl/io/*.sv rtl/machine/*.sv rtl/vector/*.sv rtl/sound/*.sv; hierarchy -top starcastle_machine; proc; opt; memory_dff; memory_collect; check; stat' \
  >build/machine/yosys.log 2>&1 || { tail -50 build/machine/yosys.log; exit 1; }
tail -20 build/machine/yosys.log
if [[ "${1:-}" == "--quartus" ]]; then
  docker run --rm -v "$PWD:/project" -w /project/synth \
    -u "$(id -u):$(id -g)" theypsilon/quartus-lite-c5:17.0.2 \
    quartus_map Machine-Synthesis >build/machine/quartus.log 2>&1 \
    || { tail -60 build/machine/quartus.log; exit 1; }
  tail -12 build/machine/quartus.log
fi
