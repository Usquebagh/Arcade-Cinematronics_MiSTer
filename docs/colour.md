# Beam glow, colour overlays and video controls

All three games share adjustable beam brightness and a soft glow around the
sharp vector lines. Star Castle additionally uses a fixed screen-gel filter;
Rip Off stays monochrome. Armor Attack adds a town reflection, tint and optional
transparent building detail. Effects do not assign colours to game objects.

| Setting | Values | Default |
| --- | --- | --- |
| Beam brightness | 100%, 75%, 125%, 150% | 100% |
| Glow amount | Medium, Off, Low, High | Medium |
| Glow spread | Soft, Tight, Wide | Soft |
| Screen overlay | On, Off | On |
| Overlay strength | 100%, 75%, 50%, 25% | 100% |
| Detailed artwork (Armor Attack) | On, Off | On |

Beam brightness, Glow amount and Glow spread appear in all three games.
Screen overlay and Overlay strength appear only in Star Castle and Armor
Attack. Detailed artwork appears only in Armor Attack. MiSTer menu mask bit 1
shows the gel/town controls (`h1`); bit 2 shows detailed artwork (`h2`). The MRA
selects these capabilities automatically; saved setting bits are unchanged.

Use MiSTer's **Save settings** to retain choices for the game. Existing status
bits keep their meaning; Glow amount uses bits 14:13 and spread uses 16:15.
Try 100% brightness with Medium/Soft first. Higher brightness now feeds more
energy into the glow, even when the line centre already reaches white. With
Glow Off, brightness still clips at output white, as before. An empty vector
frame remains black; pixels near a lit vector receive its glow.

## Shared implementation

The game still draws a 4-bit, 512x384 framebuffer. Scanout expands the source
intensity to eight bits. `rtl/video/vector_glow.sv` applies beam brightness
without clipping, retaining nine-bit energy through a separable convolution.
The kernels are Tight `[1 2 1]/4`, Soft `[1 4 6 4 1]/16` and Wide
`[1 6 15 20 15 6 1]/64`, applied vertically then horizontally with rounding.
Glow gain is Low 1/4, Medium 1/2 or High 1. The narrow primary and glow are
combined before the final 8-bit clamp. This is spatial beam glow, not temporal
phosphor persistence or antialiased vector drawing.

Six full-raster scanline buffers and horizontal registers preserve the centre
pixel's coordinates, sync and blanking. All settings, including Off, have the
same delay: 2407 pixel enables (about 96 microseconds at 25 MHz). Blanking
samples contribute zero, so opposite edges and successive frames cannot bleed
into one another. Reset suppresses unread RAM rows until they have been filled.
Settings change at input frame start during the delayed output's blanking.
The filter is downstream of the drawing framebuffer and introduces no CPU
backpressure, new memory controller or SDRAM requirement.

The beam stage precedes the gel/town compositors. Neighbouring light receives
the filter at its own screen position. Armor Attack's static reflection and
building ink are composed afterward, keeping the artwork sharp. Coordinates
travel with the beam through every delay so the artwork stays aligned.

`rtl/video/vector_overlay.sv` retains the shared RGB/span interface and its
two-clock latency. The top-level now selects unity brightness there, since
beam drive has already been applied. The Star Castle map stores four spans
per row in 512 rows of 76 bits rather than a full-screen RGB image. Later spans
win; overlay strength blends tint gains toward white. The compositor precedes
the MiSTer scaler, so the game, glow and artwork scale together.

`tools/prepare_overlay.py` generates the map and coefficients from MAME's
static layout. Normalizing its complete bounds maps the centre discs to radii
62.72, 48.64 and 37.12 pixels centred at (256,192). The original gains remain
blue (0,.25,1), red (1,.125,.125), orange (1,.5,.0625) and yellow (1,1,.125).
Armor Attack uses the CC0 MAME town map and separately credited transparency;
see [Armor Attack](armor-attack.md#town-overlay).

These are adjustable display effects. Physical CRT beam shape, brightness,
gamma and gel transmission have not been calibrated. CRT output is untested.

## Provenance and checks

`rtl/video/overlays/starcastle.lay` comes from MAME commit
`9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e`, matching the CPU reference, and
retains its CC0-1.0 declaration. The generated map and gains are derived
from this artwork definition, not game ROMs or a scanned manual.

- [Pinned Star Castle layout](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/layout/starcas.lay).
- [MAME layout coordinates and colours](https://docs.mamedev.org/techspecs/layout_files.html).
- [Videodr0me's Star Wars core](https://github.com/Videodr0me/Arcade-StarWars_MiSTer)
  was inspected at commit `64aaa04aaf333c013c1b521abb68260165fcfa01`, especially
  `vfb_blur`, `vfb_halo_pipeline` and `vfb_readout`. It informed the separation
  of beam, glow and future decay. No Star Wars RTL is imported; our compact
  grayscale convolution and scanline packet pipeline are an original implementation.

`bash sim/run_overlay.sh` checks every visible position at all 16 framebuffer
brightness levels against independent circle equations, RGB input, all video
control combinations, 8-bit levels at each band, bypass transitions, reset,
black background, blanking and timing alignment. `bash sim/run_mister.sh`
also checks every output RGB pixel through the real MiSTer video pipeline in
42 frames covering colour, monochrome, plain/detailed town, adjusted settings
and detailed-artwork bypass when Screen overlay is Off.

An optional local machine PGM can be passed to `sim/run_overlay.sh` with a PPM
output path to render and check the real-game frame through the RTL. Captures
stay under ignored `build/`. The glow build passes full fitting and reported
internal timing, with 13,175 ALMs, 475 RAM blocks and 93 DSP blocks. Compared
with the previous build it adds 216 ALMs and 12 RAM blocks, with no extra DSP
blocks. It is installed on MiSTer with verified RBF/MRA hashes; all three MRA
launch requests reached FPGA state `operating`. Star Castle is left selected. On 2026-10-04 the user
confirmed that gameplay and the brightness/overlay controls work. **CRT output
has not been tested.** Save/reload persistence has not been explicitly verified.
The 2026-10-11 beam/glow update passes 288 component frames and 42 complete
MiSTer RGB frames. The user confirmed the effects are simple and effective
on 2026-10-11. The menu-only update preserves that renderer; phosphor
persistence is not implemented.
