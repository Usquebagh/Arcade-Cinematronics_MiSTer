# Initial architecture

The CCPU executes game code and emits vector segments. The vector renderer
converts those segments into a framebuffer with a synchronous grayscale scanout.
Game I/O and sound
sit alongside the CPU, selected by game configuration.

## CPU component contract

`rtl/ccpu/ccpu.sv` is an instruction-level implementation derived from the
pinned MAME semantics. ROM has one system-clock read latency. Fetch and operand
accesses use separate states, so it can connect to inferred FPGA block RAM.
The simulation uses a 50 MHz system clock and a CPU enable every ten clocks.
Allow at least six system clocks between CPU enables for worst-case operand
fetch. Nominal machine clock is 19.923 MHz / 4; generating that rate is a future
integration task. `trace_cycles` uses MAME's instruction cycle counts, which
are not yet proof of the original four-phase hardware timing.

The CPU's `pc` is the full logical program address. Star Castle's physical ROM
address is `{pc[13], pc[11:0]}`: logical banks 0/1 mirror the first half and
2/3 mirror the second half. Masking the logical PC to 13 bits is incorrect.
Data RAM is **256 12-bit words**, not 256 bytes. It is not reset by the CPU;
the game initializes it. Current asynchronous RAM reads may synthesize into
logic; a later memory-timing pass may replace them with synchronous block RAM.

SSA and the B-selecting branch opcodes toggle the active accumulator. Each
other instruction selects A for the following instruction. MI follows the
reference's delayed pipeline; comparison flags retain previous operands.
Vector normalization currently uses a bounded combinational sequence of
16 shifts. Synthesis/timing results will guide conversion to an iterative unit.

`vector_valid` holds the segment until `vector_ready` accepts it. A second
draw stalls if the previous segment has not been accepted. Coordinates are
signed 16-bit values; the source registers are signed 12-bit. `draw_busy`
is an external status input distinct from this output handshake. The reference
normally reports no drawing-busy state; actual board timing still needs study.

`frame_tick` wakes FRM; a consecutive identical FRM byte is skipped, following
MAME. The machine wrapper must supply the original frame timer and watchdog.
`watchdog_clear` marks CST; its arithmetic side effect is retained. The CPU
does not itself implement the three-frame watchdog reset yet.

The DV post-instruction A/B assignment follows MAME's compatibility behavior.
This choice is explicitly not a claim that the CPU is a gate-level reproduction
or that QB-3 is supported. Check that behavior against schematics before
expanding the game family.

## Planned machine and MiSTer integration

- Exact-rate enable and frame/watchdog timers independent of HDMI refresh.
- Star Castle inputs: active-low start at bits 0/2, left/right at 6/8,
  thrust/fire at 10/12, switch shuffle and latched coin detection.
- Output bit 6 selects normal/bright vector intensity; other outputs feed
  game-specific sound and the coin reset latch.
- Connect the renderer to machine frames and video timing; add persistence,
  point-intensity handling, intensity calibration and optional cabinet overlay.
- MiSTer `emu` wrapper, HPS ROM download, OSD controls, reset and platform video.
- Sound modeled from the supplied Star Castle circuitry, with comparison to
  the reference circuit model and on-device testing.

The existing Jedi and Fire Trap repositories are build/platform examples.
Their raster video and CPU designs do not implement this vector architecture.

## Vector video component

`rtl/vector/vector_video.sv` connects the line rasterizer to the framebuffer.
Signed CCPU coordinates are divided by two using arithmetic shift, giving a
512x384 viewport. Bresenham steps retain the line's slope through clipped
regions; writes outside the viewport are suppressed and segments wholly on
one outside side are rejected. Off-screen crossing segments still consume
step cycles. Endpoints are inclusive; a zero-length vector emits one pixel.
Visible pixels remain stable while the framebuffer stalls them.

Each framebuffer bank has 65,536 16-bit words, with four adjacent 4-bit pixels
per word. Only the first 384 rows are displayed. Two explicit banks allow a
single read port per bank: the draw port reads one bank while scanout reads
the other. Pixel updates use read/modify/write, keeping the brighter value
where vectors overlap. Intensity is quantized to the upper nibble and scanout
expands it by multiplication by 17; 128 becomes 136 and 255 stays 255.

Reset clears both physical banks before accepting segments. A `frame_valid`
request drains the active line and pending framebuffer write, swaps the banks,
and pulses `frame_presented`. The new drawing bank's visible area is then
cleared before accepting more lines. Scanout remains independent while clearing.
`scan_gray` corresponds to `scan_x/scan_y` sampled on the preceding rising
edge. Y inversion belongs to the scanout caller; the preview inverts it.

This interface is not yet connected to a live CPU/machine wrapper or MiSTer
video timing. The capture test replays retired, reference-checked CPU segments
through the RTL video component. FRM groups the capture's frames; the final
instruction-limited group is incomplete and excluded from framebuffer checks.
Timing is not real-time in this capture path. No antialiasing, phosphor decay,
cabinet overlay or normalization-dependent point brightness is implemented yet.
