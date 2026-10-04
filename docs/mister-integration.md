# MiSTer integration

## Platform and Licensing

The framework in `sys/` is imported without logic changes from the Fire Trap
[source tree](https://github.com/Usquebagh/Arcade-FireTrap_MiSTer/tree/f88d48bea36003778c097f0e3c6a2a2e9873731f/sys)
at commit `f88d48bea36003778c097f0e3c6a2a2e9873731f`; its latest framework
commit is `b3db903d7da5f60988895d70e70f7688f5814e88`. Project/IP declarations
and `rtl/pll*` come from the same revision, with the implemented PLL output
changed from 48 to 50 MHz. The HDL frequency parameter determines the clock;
generated QIP GUI metadata still reflects the original IP.

Imported files retain their licenses. The integrated core is GPL-3.0-or-later;
original CCPU, machine, rasterizer and helper modules remain BSD-3-Clause.
Intel generated IP retains its embedded terms. See `LICENSE` and `LICENSES/`.

`Arcade-Cinematronics.sv` instantiates `emu`. The 50 MHz clock drives HPS I/O,
the machine, framebuffer and scanout. Game state and pixels use FPGA RAM;
unused SDRAM/DDR interfaces are disabled.

## ROM Loading

Each MRA sends a one-byte game profile at index 1 before its ROM: `00` for
Star Castle, `01` for Rip Off. `cinemat_profile` validates it and selects the
game at ROM-load start. A missing profile defaults to Star Castle; malformed
profiles keep execution stopped. See [Rip Off](ripoff.md) for the protocol.

HPS index 0 supplies the selected game's 8192-byte program. The loader holds the
machine in reset during transfer and its completion edge, accepting only
sequential addresses from zero and exactly 8192 bytes. A rejected transfer
invalidates the previous image, keeps the CPU stopped and lights the user LED.
Power/PLL reset requires a fresh download; OSD reset preserves the program.
HPS index 254 byte 0 supplies six electrical DIP bits, default `3F`.
The OSD provides a separate service switch.

Video stays black until a valid ROM is loaded and reset released. Scan timing
continues so the OSD remains accessible. The MRA uses two 16-bit interleave
groups, even-address chips on lane 0 (`01`) and odd-address chips on lane 1
(`10`), following the
[Main_MiSTer loader](https://github.com/MiSTer-devel/Main_MiSTer/blob/master/support/arcade/mra_loader.cpp).
`tools/check_mra.py` checks identities, CRC metadata and byte ordering with
synthetic CI data or an optional local ZIP. No ROM bytes are embedded in the RBF.

Installation paths and controls are in the [README](../README.md).
Use the standard `Arcade-Cinematronics_YYYYMMDD.rbf` filename so the MRA's
`<rbf>Cinematronics</rbf>` tag resolves it in `_Arcade/cores/`.

## Video and Sound

Scanout has 512x384 active pixels, 800x521 total, a 25 MHz pixel rate,
31.25 kHz lines and 59.981 Hz frames. Framebuffer reads take one clock and
pixels are sampled every second 50 MHz clock. Raster Y is reversed for the
upright game view. Sync and blanking follow the pixel through `arcade_video`.
Aspect ratio defaults to 4:3.

Scandoubler/HQ2x and serial gamma are disabled: they require at least four
video clocks per input pixel, while this scanout has two. Native output is
progressive at 31.25 kHz and preserves all sixteen brightness levels. The HPS
gamma capability flag is off. The roughly 38 Hz game presents framebuffers
independently of display blanking, so visible bank swaps can tear a frame.

The Star Castle colour filter, brightness and overlay-strength controls are
implemented in a shared compositor; see [colour](colour.md). Glow, bloom and
phosphor persistence are not implemented. CRT output remains untested.

The sound model observes CCPU output latches at 50 MHz and updates its
RC/VCO/noise model at 96 kHz. Signed 16-bit mono feeds both MiSTer channels.
Hard reset and ROM download reset the sound model; CPU watchdog recovery
does not. No additional sound ROMs or samples are required. See [sound](sound.md)
for circuit references and fidelity limits.

Rip Off selects its own six-effect [sound model](ripoff.md#sound-board) and
independent player controls. Only the selected board is active. Both games
share the same CCPU, ROM map, renderer and scanout; Rip Off bypasses the gel filter.

## Build and Verification

Run `bash build.sh` in WSL/Linux. The Docker image
`theypsilon/quartus-lite-c5:17.0.2` produces
`output_files/Arcade-Cinematronics.rbf`. Full reports remain under ignored
`output_files/` and `build/`. The script rejects missing/incomplete timing
summaries, negative slack, nonzero TNS and illegal or unconstrained clocks,
and verifies the 50 MHz machine clock.

The gate checks reported internal timing. Inherited external I/O constraints
leave some HDMI, I2C and user/SD ports without explicit input/output delays;
board-level interface timing still needs verification.

The current [build manifest](../releases/Arcade-Cinematronics_20261004.json)
records the exact RTL source commit, checksum, resource use and timing.
The accompanying fitter/timing summaries give resource use and reported slack.
Every reported timing category must pass the build gate before packaging.

[Validation](validation.md) lists reproducible checks. Platform tests cover
malformed downloads, reload recovery, DIP isolation, keyboard/controller input
and complete video frames. Connected machine tests compare CPU instructions
and framebuffer pixels to references. Overlay tests cover every visible pixel
and all video settings; the real MiSTer pipeline is checked across nine RGB frames.
For Verilator, `tools/prepare_video_sim.py` adapts legacy Quartus declarations
only in a temporary simulation copy; hardware `sys/` logic is unchanged.

## Hardware Status

The user confirmed Star Castle still plays correctly on the combined build.
Rip Off boots and plays, but is otherwise untested/WIP: gameplay, two-player
operation and sound have not been validated. The manifest records
installation/launch checks separately. CRT output, physical vector
timing, gel/CRT calibration and measured analog sound fidelity remain unverified.
Save/reload of video settings has not been separately verified.
