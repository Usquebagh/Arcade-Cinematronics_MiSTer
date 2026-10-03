#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
args=()
for arg in "$@"; do args+=("$(realpath "$arg")"); done
# GNU Make rejects paths with spaces. Stage only test sources in /tmp,
# leaving all user inputs and ROMs in the original workspace.
work_dir="$(mktemp -d /tmp/cinematronics-sim.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp -R rtl sim tools "$work_dir/"
cd "$work_dir"
python3 tools/generate_mame_adapter.py
verilator --cc --exe --build --top-module ccpu -Wall -Wno-UNUSEDSIGNAL \
  --Mdir build/sim/obj -Irtl/ccpu \
  -CFLAGS "-std=c++17 -I\"$PWD/sim\" -I\"$PWD/sim/reference\"" \
  rtl/ccpu/ccpu.sv "$PWD/sim/ccpu_diff.cpp" "$PWD/build/sim/mame_impl.cpp" \
  >build/sim/compile.log 2>&1 || { cat build/sim/compile.log; exit 1; }
mkdir -p "$root/build/sim"
cp build/sim/compile.log "$root/build/sim/compile.log"
build/sim/obj/Vccpu "${args[@]}" | tee "$root/build/sim/results.txt"
iverilog -g2012 -s starcastle_rom_tb -o build/sim/rom_tb \
  rtl/games/starcastle_rom.sv sim/starcastle_rom_tb.sv
vvp build/sim/rom_tb | tee -a "$root/build/sim/results.txt"
