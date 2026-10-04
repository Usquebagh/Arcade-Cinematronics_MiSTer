# Validation record - updated 2026-10-04

Simulation and synthesis checks below are distinct from hardware feedback.
Star Castle gameplay, sound and video controls passed MiSTer user testing on
the earlier build. Star Castle also still plays on the combined build.
Rip Off is bootable but otherwise untested/WIP; CRT output remains untested. See
[hardware status](mister-integration.md#hardware-status).

## Executed locally

Environment: Ubuntu 24.04 through WSL; Verilator 5.020; Icarus Verilog;
Yosys; Docker image `theypsilon/quartus-lite-c5:17.0.2`.

| Check | Result |
| --- | --- |
| All 256 opcode values, 12 setup variations each | Pass |
| Differential register, flag, RAM-write, output and vector checks | 910,862 synthetic instruction retirements pass |
| Vector output holds during backpressure and stalls the next draw | Pass |
| Signed vector normalization | Pass |
| Duplicate E5/F5 frame-wait bytes and frame wake | Pass |
| Star Castle v3 chip size, CRC32, SHA-1 and interleave | Pass |
| Real-ROM execution against pinned reference, service OFF | 2,000,000 retirements pass; 14,421 vectors; 70 frame wakes |
| Synchronous ROM writes and all 65,536 logical read addresses | Pass |
| Verilator CPU lint during build | Pass; intentional unused-bit warnings suppressed |
| Verilator ROM lint | Pass |
| Yosys CPU synthesis and netlist check | Pass; no latches or structural errors |
| Quartus 17.0.2 component analysis and synthesis, Cyclone V | Pass; 5,519 logic cells; zero errors |
| Rasterizer, random/directed lines with output stalls | 2,011 cases pass, including signed extremes, clipped crossings and all octants |
| Captured vectors compared to the integer raster reference | 70 groups, 105,151 pixels pass |
| Framebuffer reset, clipping, crossing intensity and bank reuse | Pass |
| End-to-end rasterizer + framebuffer + synchronous scanout | 69 complete frames, 14,283 segments; every scanout pixel passes |
| Yosys video memory/netlist checks | Pass; two memory cells retained |
| Quartus vector-video analysis and synthesis | Pass; 697 logic cells, 256 RAM segments, 2,097,152 block-memory bits; zero errors |
| Rip Off chip size, CRC32, SHA-1 and MRA interleave | Pass |
| Rip Off connected real-ROM gameplay | 120 frames; 3,851,660 checked instructions; 15,059 vectors; every framebuffer pixel passes |
| Rip Off separate player controls and coin acknowledgements | Both players exercised; two coin acknowledgements pass |
| Game profile selection, malformed profiles and legacy fallback | Pass |
| Rip Off sound serial latch, six effects, release, headroom and 96 kHz timing | Pass at accelerated and 50 MHz clocks; short explosion triggers retained |

The differential oracle is the original pinned MAME instruction function.
Agreement establishes compatibility with that reference, not independent
proof of every behavior of the physical board. The generic non-JMI variant
has not been separately tested. Synthetic tests initialize data RAM through
software. The real-ROM simulation starts with Verilator's zero-valued RAM;
physical startup RAM contents remain an integration check.

The real-ROM run clears switch-bank bit 6 (`inputs=0xbfffff`) for normal attract
operation. The final partial capture frame is excluded from integration checks.
Synthetic CI video tests require no ROM.

The video oracle is an independent C++ integer Bresenham model with the same
declared half-resolution coordinate mapping and intensity quantization. It
tests raster correctness rather than analog monitor behavior or MAME's
antialiased/phosphor output.

## Still unverified or unimplemented

- Physical vector timing, point intensity,
  intensity calibration and persistence.
- CRT output and measured analog sound fidelity.
- Frame synchronization, glow and bloom.
- Other games and special memory configurations, including QB-3.

## Reproducing the Checks

Use Linux or WSL with Python 3, Verilator, Icarus Verilog, Yosys, GNU Make
and a C++ compiler. Quartus checks use the Docker image listed above.

ROM-free checks:

```sh
bash sim/run.sh
bash sim/run_vector.sh
bash sim/run_machine.sh
bash sim/run_sound.sh
bash sim/run_ripoff.sh
bash sim/run_ripoff_sound.sh
bash sim/run_overlay.sh
bash sim/run_mister.sh
bash tools/synth.sh
bash tools/synth.sh --quartus
bash tools/synth_vector.sh --quartus
bash tools/synth_machine.sh --quartus
```

Optional game-ROM checks and previews, using your local `starcas.zip`:

```sh
python3 tools/prepare_starcastle.py games/mame/starcas.zip
bash sim/run.sh build/roms/starcastle.bin build/vectors.csv
bash sim/run_vector.sh build/vectors.csv build/vector/starcastle.pgm
python3 tools/preview_vector.py build/vector/starcastle.pgm build/vector/starcastle.png
bash sim/run_machine.sh build/roms/starcastle.bin build/machine/starcastle.pgm
python3 tools/preview_vector.py build/machine/starcastle.pgm build/machine/starcastle.png
bash sim/run_mister.sh games/mame/starcas.zip
python3 tools/prepare_ripoff.py games/mame/ripoff.zip
bash sim/run_ripoff.sh build/roms/ripoff.bin build/ripoff/ripoff.pgm build/sound/ripoff-game.wav
python3 tools/check_mra.py games/mame/starcas.zip games/mame/ripoff.zip
```

Component synthesis checks do not perform fitting or generate an RBF.
Run `bash build.sh` for the full MiSTer compile and timing gate.
No game ROMs are available in the repository or CI. Logs and generated images
remain under ignored `build/` and `output_files/`.

The connected CPU/video, board controls, coin latch, watchdog and autonomous
clock/frame timer are now tested together. See
[connected-machine validation](machine-validation.md) for live-ROM gameplay
simulation results and resource estimates. The original captured-frame tests
above remain useful component regressions.

The MiSTer top-level, HPS loader, input adapter, MRA and scanout are now
implemented. Platform tests exercise full and malformed ROM downloads, DIP
isolation, keyboard/controller inputs and two complete raster frames. A full
Quartus build has passed fitting and all reported timing categories. Final
RBF evidence is recorded in the [MiSTer integration record](mister-integration.md).
These checks establish digital behavior and reported internal timing;
physical analog sound/video accuracy requires separate calibration.
