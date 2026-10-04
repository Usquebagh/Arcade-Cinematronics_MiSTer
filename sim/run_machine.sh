#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
args=()
for arg in "$@"; do args+=("$(realpath -m "$arg")"); done
work_dir="$(mktemp -d /tmp/cinematronics-machine.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp -R rtl sim tools "$work_dir/"
cd "$work_dir"
mkdir -p build/sim "$root/build/machine"
iverilog -g2012 -s machine_units_tb -o build/units \
  rtl/machine/*.sv rtl/io/starcastle_io.sv sim/machine_units_tb.sv
vvp build/units | tee "$root/build/machine/results.txt"
iverilog -g2012 -s vector_queue_tb -o build/queue rtl/vector/vector_queue.sv sim/vector_queue_tb.sv
vvp build/queue | tee -a "$root/build/machine/results.txt"
python3 tools/generate_mame_adapter.py
verilator --cc --exe --build --top-module starcastle_machine -Wall -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
  --Mdir build/obj -CFLAGS "-std=c++17 -I\"$PWD/sim\" -I\"$PWD/sim/reference\"" \
  rtl/ccpu/ccpu.sv rtl/games/*.sv rtl/io/*.sv rtl/machine/*.sv rtl/vector/*.sv rtl/sound/*.sv \
  "$PWD/sim/starcastle_machine_test.cpp" "$PWD/build/sim/mame_impl.cpp" \
  >build/compile.log 2>&1 || { cat build/compile.log; exit 1; }
cp build/compile.log "$root/build/machine/compile.log"
build/obj/Vstarcastle_machine | tee -a "$root/build/machine/results.txt"
if (( ${#args[@]} )); then
  build/obj/Vstarcastle_machine "${args[@]}" | tee -a "$root/build/machine/results.txt"
fi
