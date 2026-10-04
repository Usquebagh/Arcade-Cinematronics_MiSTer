#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
python3 tools/prepare_overlay.py --check
python3 tools/prepare_ripoff_sound.py --check
docker run --rm -v "$PWD:/project" -w /project -u "$(id -u):$(id -g)" \
  theypsilon/quartus-lite-c5:17.0.2 quartus_sh --flow compile Arcade-Cinematronics.qpf \
  >build/quartus.log 2>&1 || { tail -60 build/quartus.log; exit 1; }
cat output_files/Arcade-Cinematronics.fit.summary
python3 tools/check_timing.py output_files/Arcade-Cinematronics.sta.summary output_files/Arcade-Cinematronics.sta.rpt
echo "RBF: output_files/Arcade-Cinematronics.rbf"
