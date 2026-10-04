# Connected-machine validation - 2026-10-04

This milestone runs the real CPU, writable program ROM, board I/O, fractional
clock/frame timer, watchdog, vector queue, rasterizer and framebuffer together
under Verilator. It does not provide a MiSTer wrapper or an RBF.

## Checks performed

- Icarus timing test: 19,923 enables in 200,000 50 MHz system clocks; every
  enable gap is 10 or 11 clocks. Two hardware frame ticks occur at the expected
  131,072-enable boundaries in a 2.7-million-clock run.
- Every control bit, all six DIP shuffle positions and active-high service.
- Coin press, held coin, OUT5 acknowledge, and a simultaneous new coin/ack.
- Watchdog's third-frame expiration, one-clock pulse and CST/frame priority.
- 10,000 randomized FIFO cycles covering full/empty, simultaneous transfers,
  wraparound and complete 72-bit packet ordering.
- Synthetic live-machine program: ROM download, all input banks, duplicate FRM,
  watchdog servicing, queue saturation, differently colored rows, and every
  displayed pixel. Reload clears old machine/video/queue contents.
- A nonservicing program resets on its third hardware frame. It preserves the
  output latch and resumes executing after framebuffer initialization.

## Star Castle v3 local-ROM run

28 hardware-timed frames; 1,031,753 instruction retirements match the pinned
MAME execution reference. All registers, delayed flags, RAM writes, output
latch updates, cycle counts and emitted vector endpoints are checked.
The video test checks every scanout pixel on every presented frame against
an independent integer raster model: 3,435 vector segments, no frame overruns
and no watchdog expiration.

Scripted inputs insert one coin, press start, then exercise both rotation
directions, thrust and fire. The game acknowledges the coin and reads the
asserted controls: start/left/right/thrust/fire = 1/3/3/30/14 reads. The final
frame shows the castle rings and player ship. This is a simulated gameplay
frame; hardware gameplay and sound have not been validated.

## Synthesis

Yosys hierarchy, memory and structural checks pass. Quartus 17.0.2 Docker
analysis and synthesis for `5CSEBA6U23I7` succeed with zero errors:

- 6,467 logic cells; 3,648 registers.
- 2,163,712 logical block-memory bits; 328 synthesized RAM segments.
- 12 warnings: FIFO read-during-write pass-through logic and unused electrical
  input bits exposed as constant debug pins. The CPU's 256x12-bit data RAM
  remains asynchronous logic RAM, as documented in the initial baseline.

These are analysis/synthesis estimates. They are not fitted ALM/M10K counts,
timing closure or proof that the complete MiSTer build fits. The component
exports debug ports; the MiSTer wrapper will leave unused ones unconnected.

## Remaining limitations

CPU execution pauses during frame presentation/clear and vector producer
backpressure. Frame timing is autonomous and exact on average, but physical
four-phase instruction timing and DR/draw-busy behavior remain to be checked.
Scanout currently shares the system clock. A MiSTer platform wrapper must
implement display timing and any required clock-domain crossing. Audio,
antialiasing, phosphor persistence, overlays, point brightness and physical
controls have not been validated.

Run `bash sim/run_machine.sh` without ROMs for CI checks. Add
`build/roms/starcastle.bin build/machine/starcastle.pgm` to run the local game
test and save the actual framebuffer scanout preview.
