#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
args=()
for arg in "$@"; do args+=("$(realpath -m "$arg")"); done
mkdir -p build/armora
iverilog -g2012 -s armora_units_tb -o build/armora/units \
  rtl/mister/cinemat_profile.sv rtl/mister/cinemat_download.sv rtl/games/cinemat_rom.sv sim/armora_units_tb.sv
vvp build/armora/units | tee build/armora/results.txt
python3 tools/check_mra.py
work_dir="$(mktemp -d /tmp/cinematronics-armora.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp -R rtl sim tools "$work_dir/"
cd "$work_dir"
python3 tools/generate_mame_adapter.py
verilator --cc --exe --build --top-module cinemat_machine -Wall -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
  --Mdir build/obj -CFLAGS "-std=c++17 -DSHARED_MACHINE -I\"$PWD/sim\" -I\"$PWD/sim/reference\"" \
  rtl/ccpu/*.sv rtl/games/*.sv rtl/io/*.sv rtl/machine/*.sv rtl/vector/*.sv rtl/sound/*.sv \
  "$PWD/sim/starcastle_machine_test.cpp" "$PWD/build/sim/mame_impl.cpp" >compile.log 2>&1 \
  || { cat compile.log; exit 1; }
cp compile.log "$root/build/armora/compile.log"
build/obj/Vcinemat_machine | tee -a "$root/build/armora/results.txt"
if (( ${#args[@]} )); then
  build/obj/Vcinemat_machine --armora "${args[@]}" | tee -a "$root/build/armora/results.txt"
  build/obj/Vcinemat_machine --armora-diag "${args[0]}" "$root/build/armora/diagnostic.pgm" | tee -a "$root/build/armora/results.txt"
fi
