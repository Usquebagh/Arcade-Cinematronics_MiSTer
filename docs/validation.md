# Validation record - updated 2026-10-04

Development baseline; not an on-device gameplay result.

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

Quartus reports three warnings: unspecified parallel processor count and a
two-message warning for unused `external_input`. The latter is expected because
the Star Castle JMI configuration selects the internal delayed minus flag.
The video component has nine warnings identifying eight unused input bits:
the four coordinate low bits are discarded by half-resolution mapping and
the four intensity low bits by 16-level quantization. No latch or uninferred
RAM warning remains. Initial shared-array inference duplicated the framebuffer;
the verified version uses two explicit banks and halves the synthesized memory.

The differential oracle is the original pinned MAME instruction function.
Agreement establishes compatibility with that reference, not independent
proof of every behavior of the physical board. The generic non-JMI variant
has not been separately tested. Synthetic tests initialize data RAM through
software. The real-ROM simulation starts with Verilator's zero-valued RAM;
physical startup RAM contents remain an integration check.

The original short capture used all-high switch inputs, which asserts the
active-high service switch and displays diagnostics. The current real-ROM run
clears switch-bank bit 6 (`inputs=0xbfffff`) for normal attract operation. The
preview shows the score screen and star field. The final partial capture frame
is excluded from integration checks. Synthetic CI video tests require no ROM.

The video oracle is an independent C++ integer Bresenham model with the same
declared half-resolution coordinate mapping and intensity quantization. It
tests raster correctness rather than analog monitor behavior or MAME's
antialiased/phosphor output.

## Still unverified or unimplemented

- Physical vector timing, point intensity,
  intensity calibration and persistence.
- MiSTer controls on hardware and sound.
- Playability and sustained operation on a DE10-Nano.
- Other games and special memory configurations, including QB-3.

To reproduce the game run, provide the local `starcas.zip` and execute the
commands in the README. No game ROMs are available in the repository or CI.
Build logs and generated images live under ignored `build/`.

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
This does not establish hardware gameplay or original analog sound/video behavior.
