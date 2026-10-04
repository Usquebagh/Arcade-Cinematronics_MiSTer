# MiSTer integration

The platform in `sys/` is imported without logic changes from the tracked Fire Trap
framework at commit `f88d48bea36003778c097f0e3c6a2a2e9873731f`:
[source tree](https://github.com/Usquebagh/Arcade-FireTrap_MiSTer/tree/f88d48bea36003778c097f0e3c6a2a2e9873731f/sys).
Its most recent framework commit there is
`b3db903d7da5f60988895d70e70f7688f5814e88`. The import includes source and
project/IP declarations only. Git normalizes line endings under this project's
attributes. No ROMs or previous core binaries were copied.
The Quartus settings and generated `rtl/pll*` were taken from the same revision;
the PLL's implemented frequency is changed from 48 to 50 MHz, and compilation
uses four workers. Generated QIP GUI metadata still reflects the original IP;
the HDL `output_clock_frequency0` parameter determines the implemented clock.

Imported framework files retain their copyright/license notices. Many are
GPL-2.0-or-later or GPL-3.0-or-later; the integrated core is distributed under
GPL-3.0-or-later, with its license text in `LICENSES/MiSTer-GPL-3.0.txt`.
The repository's root `LICENSE` is that integrated-core license; the original
BSD license is preserved in `LICENSES/Cinematronics-BSD-3-Clause.txt`.
The original CCPU, machine, rasterizer and platform helper modules remain
BSD-3-Clause individually. Intel generated IP retains its embedded terms.

`Arcade-Cinematronics.sv` instantiates `emu` using the framework port header.
The 50 MHz PLL clocks HPS I/O, the machine, framebuffer and video scanout.
Unused SDRAM/DDR interfaces are disabled; the core's game state and pixels use
FPGA RAM. Sound outputs are currently zero.

## ROM and controls

HPS index 0 supplies the 8192-byte Star Castle v3 program. The loader holds the
machine in reset throughout the transfer and its completion edge. It accepts
only sequential addresses starting at zero and exactly 8192 bytes. A failed
replacement invalidates the previous image and keeps the CPU stopped. The user
LED stays on for a rejected transfer. Power/PLL reset requires a fresh download;
the OSD reset preserves the loaded program. HPS index 254 byte 0 supplies six
electrical DIP bits, default `3F`. The OSD has a separate service switch.
Video remains black while reset is asserted or a valid ROM has not been loaded;
scan timing continues so the OSD remains accessible.

The MRA uses two 16-bit interleave groups, with each even-address chip mapped
to lane 0 (`01`) and each odd-address chip to lane 1 (`10`). This follows the
[Main_MiSTer MRA loader](https://github.com/MiSTer-devel/Main_MiSTer/blob/master/support/arcade/mra_loader.cpp).
`tools/check_mra.py` verifies chip identities, CRC metadata and byte ordering
against the existing ROM preparation layout, with synthetic data in CI and
optionally the local ZIP. No ROM bytes are stored in the MRA or RBF source.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Rotate | Left/Right arrows | Left/Right |
| Thrust | Up arrow | Thrust button or Up |
| Fire | Space | Fire button |
| Coin | 5 | Coin button |
| Start 1 | 1 | Controller 1 Start |
| Start 2 | 2 | Start 2 button or Controller 2 Start |

## Video and limits

The one-clock framebuffer read is sampled every second 50 MHz clock. Scanout
has 512x384 active pixels, 800x521 total, a 25 MHz pixel rate, 31.25 kHz lines
and 59.981 Hz frames. Raster Y is reversed for Star Castle's upright view.
Sync and blanking accompany the same pixel through `arcade_video`.
Aspect ratio defaults to 4:3. Its optional scandoubler/HQ2x and serial gamma
paths are disabled: they require at least four video clocks per input pixel,
while this scanout has two. Native output is already progressive at 31.25 kHz
and retains all sixteen framebuffer brightness levels. The HPS gamma capability
flag is off so Main does not offer an unsupported mode.

The machine still presents its framebuffers at its approximately 38 Hz frame
rate independently of 60 Hz scanout. A bank swap during visible scanout can
tear a frame. Synchronizing presentation without reducing the CPU's execution
budget is a follow-up. HDMI/analog behavior, controller mapping and the display
timing need on-device validation; no hardware test is implied by compilation.
There is no calibrated persistence yet. The colour overlay and saved video
controls are described in [colour](colour.md). The machine now
includes a behavioral discrete sound model; see [sound](sound.md).

## Build and installation

From this project directory in WSL/Linux, run `bash build.sh`. It uses
`theypsilon/quartus-lite-c5:17.0.2` and produces
`output_files/Arcade-Cinematronics.rbf`. Full build reports remain under
`output_files/` and `build/`, both ignored. The build script rejects a missing or
incomplete STA summary, negative slack, or nonzero TNS before reporting success.
It also checks for illegal/unconstrained clocks and confirms the machine clock
is 50 MHz. This checks the reported internal timing. Imported framework external
I/O constraints remain as supplied; some HDMI, I2C and user/SD outputs have no
explicit input/output delay constraints. Board-level interface timing still
needs hardware verification.

For a hardware test, place `Arcade-Cinematronics_YYYYMMDD.rbf` in
`_Arcade/cores/`, `Star Castle (version 3).mra` in `_Arcade/`, and your own
`starcas.zip` in `_Arcade/mame/` on the MiSTer SD card. Launch the MRA.
This is a development build: report the tested
RBF hash, attract/coin/start behavior, sound, display behavior and any resets.
The current `_colour` build includes colour-overlay support and synthesized mono audio.

Tests: `bash sim/run_mister.sh` (ROM-free) or
`bash sim/run_mister.sh games/mame/starcas.zip` (local ROM layout verification).
They cover malformed downloads, reload recovery, first-edge writes, DIP isolation,
keyboard make/break, both controllers and every pixel/sync/blanking sample in
two complete video frames. Existing machine tests independently verify the
connected CPU/vector gameplay against MAME and full-frame image references.
The imported `arcade_video` pipeline is also exercised with three complete
patterned frames and every output RGB pixel checked. For Verilator compatibility,
`tools/prepare_video_sim.py` lifts Quartus's legacy unnamed-generate color wires
into module scope and marks the disabled HQ2x procedural output as a register
in the temporary simulation copy only. Hardware `sys/` has no logic changes.
These are syntax/elaboration adaptations; they do not change the selected pixel
path, which has gamma and scandoubling disabled.

## Hardware validation history

The initial silent build passed FPGA startup and a complete user-played game
on hardware. It has been superseded by the sound-enabled build below and is
no longer packaged. The initial loading failure was caused by saved GitHub
HTML pages masquerading as the MRA/RBF; verified raw-file replacement fixed it.

## Sound integration

The machine's sound output is connected to both MiSTer audio channels as signed
16-bit mono. `starcastle_sound` observes the CCPU output latches at 50 MHz and
updates its RC/VCO/noise model at 96 kHz. It resets on hard reset or ROM download,
but does not reset on the CPU watchdog's soft recovery. There are no extra
MRA downloads or sound ROMs. The OSD version suffix `colour` identifies the
current revision. Model fidelity and listening checks are described in [sound](sound.md).

### Sound-enabled build evidence, 2026-10-04

Source commit `1907fda98204c52f688d595b34081df00fe3bd7d` builds successfully
with zero errors, 70 warnings and zero critical warnings. The sound-enabled
RBF is 3,298,884 bytes; its SHA-256 is
`67a87985d6c6713c9b83ea7a1652b8b3b101c97d6612f434a794101c47a297e1`.
This build has been superseded by the colour build; its package remains in Git
history at commit `cb3a7a71fe321a7b1569cf77707e112daddc63d1`.

The fitter uses 11,056 ALMs (26%), 15,941 registers, 322 RAM blocks (58%),
77 DSP blocks (69%) and three PLLs. Worst reported slack is +0.268 ns setup,
+0.243 ns hold, +3.744 ns recovery, +0.933 ns removal and +1.122 ns minimum
pulse width. All reported TNS is zero, with no illegal or unconstrained clocks.
The external-interface constraint limitations above still apply.

Sound control/sample tests, connected machine synthesis, MiSTer platform tests
and the real-game machine regression pass: 28 frames, 1,031,753 MAME-checked
instructions, 3,435 vectors, exercised coin/start and controls, and every
framebuffer pixel checked. ROM-free GitHub CI passes.
On the analogue-I/O MiSTer running Main 260912, the installed RBF and MRA
hashes match the package. Main launches the `_sound.rbf` through the MRA and
identifies `starcas`. The user confirms audible sound and reports that it
compares well with [a Star Castle gameplay recording](https://www.youtube.com/watch?v=S_DojyqJXKE).
This establishes working audio and a passed subjective listening check;
measured analog fidelity and channel calibration remain outstanding.

### Colour build evidence, 2026-10-04

Source `27b1c1271db6a065cf3163b7426c2b5c0f7302c3` adds a shared screen-space
colour compositor, the Star Castle gel profile and three saved video controls.
The RBF is 3,289,304 bytes with SHA-256
`62a30e88d0a90f79502a3e47d0367129e2b45e1ebc38f3fdb2b46c0a43645c86`.
Its manifest and fit/timing summaries are the current package in `releases/`.

The first fit met the 50 MHz machine/colour timing but missed an HDMI scaler
setup path by 0.027 ns. A refit with placement seed 2, keeping the RTL and timing
constraints unchanged, passes the full gate. The refit reused analysis/synthesis
and reports zero errors, eight flow warnings and zero critical warnings.
Worst slacks are +0.531 ns setup, +0.247 ns hold, +4.241 ns recovery,
+0.659 ns removal and +1.122 ns minimum pulse width. Every reported TNS is zero,
with no illegal or unconstrained clocks. External I/O limitations still apply.

Resources are 11,132 ALMs (27%), 16,295 registers, 327 RAM blocks (59%),
2,586,971 block-memory bits, 83 DSP blocks (74%) and three PLLs. The overlay
adds five RAM blocks and six DSP blocks compared with the sound build.
ROM-free CI passes, including exhaustive overlay checks and nine full RGB
frames through the MiSTer video pipeline. The installed RBF/MRA hashes match
the package, and MiSTer is running with the colour RBF and MRA after launch.
Only that RBF remains installed. The user confirms that gameplay and the
brightness/overlay controls work on this revision. **CRT output has not been
tested.** Save/reload persistence and a separate audio retest have not been
explicitly reported. Neon glow, bloom and phosphor persistence are not implemented.
