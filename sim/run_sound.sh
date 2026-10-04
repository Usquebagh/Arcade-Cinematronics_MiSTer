#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
mkdir -p build/sound
work_dir="$(mktemp -d /tmp/cinematronics-sound.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp rtl/sound/starcastle_sound.sv sim/starcastle_sound_test.cpp "$work_dir/"
cd "$work_dir"
verilator --cc --exe --build --top-module starcastle_sound -Wall -Wno-UNUSEDSIGNAL \
  -GCLOCK_HZ=96000 --Mdir fast -CFLAGS '-std=c++17' \
  starcastle_sound.sv "$PWD/starcastle_sound_test.cpp" >fast.log 2>&1 \
  || { cat fast.log; exit 1; }
fast/Vstarcastle_sound "$root/build/sound" | tee "$root/build/sound/results.txt"
verilator --cc --exe --build --top-module starcastle_sound -Wall -Wno-UNUSEDSIGNAL \
  --Mdir clock -CFLAGS '-std=c++17' \
  starcastle_sound.sv "$PWD/starcastle_sound_test.cpp" >clock.log 2>&1 \
  || { cat clock.log; exit 1; }
clock/Vstarcastle_sound --clock | tee -a "$root/build/sound/results.txt"
cp fast.log clock.log "$root/build/sound/"
