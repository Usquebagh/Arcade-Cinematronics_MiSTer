#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
mkdir -p build/sound
python3 tools/prepare_armora_sound.py --check
work_dir="$(mktemp -d /tmp/cinematronics-armora-sound.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
cp -R rtl sim "$work_dir/"
cd "$work_dir"
for mode in fast clock; do
  args=()
  if [ "$mode" = fast ]; then args=(-GCLOCK_HZ=96000); fi
  verilator --cc --exe --build --public-flat-rw --top-module armora_sound -Wall -Wno-UNUSEDSIGNAL \
    "${args[@]}" --Mdir "$mode" -CFLAGS '-std=c++17' \
    rtl/sound/armora_sound.sv "$PWD/sim/armora_sound_test.cpp" >"$mode.log" 2>&1 \
    || { cat "$mode.log"; exit 1; }
  if [ "$mode" = fast ]; then
    fast/Varmora_sound "$root/build/sound" | tee "$root/build/sound/armora-results.txt"
  else
    clock/Varmora_sound --clock | tee -a "$root/build/sound/armora-results.txt"
  fi
  cp "$mode.log" "$root/build/sound/armora-$mode.log"
done
