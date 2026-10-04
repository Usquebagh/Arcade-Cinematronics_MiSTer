# Colour overlays and video controls

The first profile reproduces MAME's fixed Star Castle colour filter: a blue
field and red, orange and yellow regions around the centre. It does not assign
colours to objects. Any vector passing through a region receives its tint,
like light passing through a gel. Black stays black.

The OSD offers three controls:

| Setting | Values | Default |
| --- | --- | --- |
| Colour overlay | On, Off | On |
| Vector brightness | 100%, 75%, 125%, 150% | 100% |
| Overlay strength | 100%, 75%, 50%, 25% | 100% |

Use MiSTer's **Save settings** to retain these choices for the game. They use
the ordinary HPS status/configuration mechanism, not presets or game NVRAM.
Existing aspect and service settings keep their original bit positions.
Brightness increases saturate instead of wrapping; overlay strength blends
the filter gains toward white, without lighting empty pixels. These are
display preferences, not calibrated CRT circuit emulation. Bloom, glow,
phosphor decay and cabinet artwork are not implemented by these controls.

## Shared implementation

`rtl/video/vector_overlay.sv` accepts RGB and aligned pixel coordinates,
sync, blanking and enables. A profile supplies a row-span memory and packed
RGB coefficients. Each span has a valid bit and inclusive left/right X bounds;
later spans take priority. This represents Star Castle's four regions with
512 rows of 76 bits (38,912 bits), rather than a full-screen RGB image.
The first 384 rows are visible; padding rows contain no spans.

The game continues to draw its original 4-bit intensity framebuffer. Scanout
provides coordinates for the exact grayscale sample, in upright screen space.
The compositor performs a synchronous row lookup, applies brightness with
clamping, then multiplies RGB by the selected Q8 gains. Pixel data and all
timing signals have the same two-clock latency in both colour and bypass modes.
The overlay precedes the MiSTer scaler, so aspect changes scale it with the game.
Unity gain is exactly 256/256; the default bypass is bit-exact grayscale.

`tools/prepare_overlay.py` compiles the supplied static MAME definition into
`starcastle_spans.hex` and `starcastle_gains.svh`. It supports opaque rectangles
and disks covering the screen with multiply blending, rejects unsupported
features, and uses integer/rational pixel-centre geometry. This is a deliberately
small subset of MAME layouts, not a general artwork loader. Another simple
game profile can use the same compositor with different span and gain data.
Electronic-colour games will still need their actual colour latches and an RGB
renderer/framebuffer; accepting RGB here does not implement that hardware.

MAME scales an element's complete bounds to its placement in the view. The
Star Castle element covers source Y=.125..875. Normalizing that bounding box
to our 512x384, 4:3 viewport makes the three centre discs circular: radii
62.72, 48.64 and 37.12 pixels, centred at (256,192). Using the source Y fractions
directly as screen fractions would incorrectly flatten them. The reference
gains are blue (0,.25,1), red (1,.125,.125), orange (1,.5,.0625) and yellow
(1,1,.125). Hard pixel boundaries and Q8 integer rounding replace MAME's
artwork antialiasing; physical gel colour, CRT bloom and display gamma are
not calibrated.

## Provenance and checks

`rtl/video/overlays/starcastle.lay` comes from MAME commit
`9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e`, matching the CPU reference, and
retains its CC0-1.0 declaration. The generated map and gains are derived
from this artwork definition, not game ROMs or a scanned manual.

- [Pinned Star Castle layout](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/layout/starcas.lay).
- [MAME layout coordinates and colours](https://docs.mamedev.org/techspecs/layout_files.html).
- [Videodr0me's Star Wars core](https://github.com/Videodr0me/Arcade-StarWars_MiSTer)
  informed the request for adjustable video options. Its CRT pipeline has not
  been imported; these controls are an original, simpler implementation.

`bash sim/run_overlay.sh` checks every visible position at all 16 framebuffer
brightness levels against independent circle equations, RGB input, all video
control combinations, 8-bit levels at each band, bypass transitions, reset,
black background, blanking and timing alignment. `bash sim/run_mister.sh`
also checks every output RGB pixel through the real MiSTer video pipeline in
three colour, three monochrome and three adjusted-colour frames.

An optional local machine PGM can be passed to `sim/run_overlay.sh` with a PPM
output path to render and check the real-game frame through the RTL. Captures
stay under ignored `build/`. Hardware visual and save/reload checks are pending
until the new build is installed and tested.
