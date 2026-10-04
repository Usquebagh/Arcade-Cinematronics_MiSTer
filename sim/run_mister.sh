#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/mister
iverilog -g2012 -s mister_units_tb -o build/mister/units rtl/mister/*.sv sim/mister_units_tb.sv
vvp build/mister/units | tee build/mister/results.txt
python3 tools/check_mra.py "${1:-}"
for top in starcastle_download starcastle_controls vector_scanout; do
  verilator --lint-only --top-module "$top" -Wall -Wno-UNUSEDSIGNAL "rtl/mister/$top.sv"
done
root="$PWD"
work_dir="$(mktemp -d /tmp/cinematronics-mister.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp -R rtl sim sys tools "$work_dir/"
cd "$work_dir"
python3 tools/prepare_video_sim.py
verilator --cc --exe --build --top-module mister_video_harness -Wno-fatal \
  --Mdir obj -CFLAGS "-std=c++17" \
  rtl/mister/vector_scanout.sv rtl/video/vector_overlay.sv sim/mister_video_harness.sv \
  sys/arcade_video.v sys/video_cleaner.sv sys/video_mixer.sv \
  sys/gamma_corr.sv sys/video_freezer.sv sys/scandoubler.v sys/hq2x.sv sync_fix.v \
  "$PWD/sim/mister_video_test.cpp" >compile.log 2>&1 \
  || { cat compile.log; exit 1; }
cp compile.log "$root/build/mister/video-compile.log"
obj/Vmister_video_harness | tee -a "$root/build/mister/results.txt"
