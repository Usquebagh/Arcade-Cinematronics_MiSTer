#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
args=()
for arg in "$@"; do args+=("$(realpath -m "$arg")"); done
mkdir -p build/ripoff
python3 tools/prepare_ripoff_sound.py --check
iverilog -g2012 -s ripoff_units_tb -o build/ripoff/units rtl/mister/cinemat_*.sv rtl/io/cinemat_io.sv sim/ripoff_units_tb.sv
vvp build/ripoff/units | tee build/ripoff/results.txt
python3 tools/check_mra.py
yosys -Q -T -p 'read_verilog -sv rtl/ccpu/*.sv rtl/games/*.sv rtl/io/*.sv rtl/machine/*.sv rtl/vector/*.sv rtl/sound/*.sv; hierarchy -top cinemat_machine; proc; opt; memory_dff; memory_collect; check; stat' \
  >build/ripoff/yosys.log 2>&1 || { tail -50 build/ripoff/yosys.log; exit 1; }
work_dir="$(mktemp -d /tmp/cinematronics-ripoff.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp -R rtl sim tools "$work_dir/"
cd "$work_dir"
python3 tools/generate_mame_adapter.py
verilator --cc --exe --build --top-module cinemat_machine -Wall -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
  --Mdir build/obj -CFLAGS "-std=c++17 -DSHARED_MACHINE -I\"$PWD/sim\" -I\"$PWD/sim/reference\"" \
  rtl/ccpu/*.sv rtl/games/*.sv rtl/io/*.sv rtl/machine/*.sv rtl/vector/*.sv rtl/sound/*.sv \
  "$PWD/sim/starcastle_machine_test.cpp" "$PWD/build/sim/mame_impl.cpp" >compile.log 2>&1 \
  || { cat compile.log; exit 1; }
cp compile.log "$root/build/ripoff/compile.log"
build/obj/Vcinemat_machine | tee -a "$root/build/ripoff/results.txt"
if (( ${#args[@]} )); then
  build/obj/Vcinemat_machine --ripoff "${args[@]}" | tee -a "$root/build/ripoff/results.txt"
fi
