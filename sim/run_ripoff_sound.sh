#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
mkdir -p build/sound
work_dir="$(mktemp -d /tmp/cinematronics-ripoff-sound.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
mkdir -p "$work_dir/rtl/sound"
cp rtl/sound/ripoff* "$work_dir/rtl/sound/"
cp sim/ripoff_sound_test.cpp "$work_dir/"
cd "$work_dir"
for mode in fast clock; do
  extra=(); args=(--clock)
  if [[ "$mode" == fast ]]; then extra=(-GCLOCK_HZ=96000);args=("$root/build/sound");fi
  verilator --cc --exe --build --top-module ripoff_sound -Wall -Wno-UNUSEDSIGNAL "${extra[@]}" \
    --Mdir "$mode" -CFLAGS '-std=c++17' rtl/sound/ripoff_sound.sv "$PWD/ripoff_sound_test.cpp" \
    >"$mode.log" 2>&1 || { cat "$mode.log"; exit 1; }
  "$mode/Vripoff_sound" "${args[@]}" | tee "$root/build/sound/ripoff-$mode-results.txt"
  cp "$mode.log" "$root/build/sound/ripoff-$mode.log"
done
