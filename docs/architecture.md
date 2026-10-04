# Initial architecture

The CCPU executes game code and emits vector segments. The vector renderer
converts those segments into a framebuffer with a synchronous grayscale scanout.
Star Castle I/O, CPU/frame timing and watchdog are now connected. Sound and
other game configurations remain separate implementation tasks.

## CPU component contract

`rtl/ccpu/ccpu.sv` is an instruction-level implementation derived from the
pinned MAME semantics. ROM has one system-clock read latency. Fetch and operand
accesses use separate states, so it can connect to inferred FPGA block RAM.
The simulation uses a 50 MHz system clock and a CPU enable every ten clocks.
Allow at least six system clocks between CPU enables for worst-case operand
fetch. The connected machine generates the nominal 19.923 MHz / 4 enable rate.
`trace_cycles` uses MAME's instruction cycle counts, which
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
MAME. The machine wrapper supplies the frame timer and watchdog. `watchdog_clear`
marks CST; its arithmetic side effect is retained. `soft_reset` resets CPU
state while preserving the external output latch, following the reference.

The DV post-instruction A/B assignment follows MAME's compatibility behavior.
This choice is explicitly not a claim that the CPU is a gate-level reproduction
or that QB-3 is supported. Check that behavior against schematics before
expanding the game family.

## Planned machine and MiSTer integration

- Connect synchronous scanout to MiSTer video timing; add persistence,
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

This interface is connected to the live machine component, but MiSTer video
timing is not implemented yet. The capture test replays reference-checked CPU segments
through the RTL video component. FRM groups the capture's frames; the final
instruction-limited group is incomplete and excluded from framebuffer checks.
Timing is not real-time in this capture path. No antialiasing, phosphor decay,
cabinet overlay or normalization-dependent point brightness is implemented yet.

## Connected Star Castle machine

`rtl/games/starcastle_machine.sv` combines the CPU, synchronous program ROM,
board I/O, timing, watchdog, a 16-entry segment FIFO and vector video. All ports
are synchronous to a 50 MHz system clock. The MiSTer wrapper clocks HPS/OSD
and machine interfaces from this same PLL. The input controls are active-high booleans;
the I/O module converts them to the original active-low electrical inputs.

`cinemat_timing` uses a fractional accumulator to produce exactly 19,923 CPU
enables per 200,000 system clocks (4.98075 MHz average). Enable gaps are 10 or
11 system clocks. A divider emits a hardware frame tick every 131,072 enables,
approximately 38 Hz, independent of instruction stalls and display refresh.
The timer is reset by hard reset or ROM loading, not by a watchdog reset.

Machine states are STARTUP, RUN, DRAIN and CLEAR. Startup holds CPU execution
until the framebuffer is initialized. Each hardware frame tick stops new
instruction retirement, drains the CPU producer slot and segment queue into
the renderer, then presents the completed frame. It clears the new draw bank
before resuming execution and waking FRM. A sticky `frame_overrun` flags a new
timer tick arriving before the previous frame transaction has finished.
The tested workloads have no overruns.

Each queued segment carries its intensity snapshot (OUT6 selects 128 or 255).
CPU enables are gated while its vector producer slot is occupied, preventing
a subsequent OUT instruction from changing that segment's brightness before
enqueue. The FIFO decouples line drawing from ordinary CPU execution and
backpressures the producer when full. This adds renderer-dependent CPU stalls;
it is an engineering baseline, not a claim of exact analog vector timing.
The DR branch input remains low, consistent with the current MAME baseline.

Input wiring: start1/start2 at bits 0/2, left/right at 6/8, thrust/fire at 10/12.
Switch input ports 16-21 read DIP bits 2/5/4/3/0/1 respectively. `dips=6'h3f`
is the initial default; service is separately active-high on port 22. A coin
press latches port 23 low until OUT5 rises. Holding coin does not retrigger it,
and a new coin wins if it coincides with an acknowledge edge.

The watchdog counts hardware frame ticks, with CST clear taking priority if
both arrive together. The third uncleared tick pulses reset. CPU state, queued
segments and video restart; board output and coin latches are preserved.
The watchdog count resets after expiration so recovery can service it again.

`load_active` or `!rom_loaded` holds the machine in hard reset while ROM writes
are accepted. The caller must assert load state before writing and only mark
the complete image loaded when finished. Reloading also clears old frame and
queue contents. `rtl/mister/starcastle_download.sv` implements this contract
for HPS index 0. `outputs` is exposed for the sound
board implementation; there is no audio output yet.

The platform wrapper and scanout contracts, pin/IP provenance and remaining
display limitations are described in [MiSTer integration](mister-integration.md).
