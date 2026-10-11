# Armor Attack

Armor Attack is a development/WIP profile in the shared Cinematronics core.
It needs the three-game RBF; the 2026-10-04 two-game release cannot load it.
The user confirmed it boots and plays on MiSTer and that the revised sound
is balanced like the arcade. Detailed artwork alignment is also confirmed.
Two-player operation, physical colour calibration and measured analog fidelity
require further testing.
No game ROMs or scanned manuals are distributed.

## Program and controls

The game uses the same JMI CCPU and frame timer, with a linear 16 KiB program
map (`pc[13:0]`). The other two games retain their mirrored 8 KiB map.
The MRA sends profile byte `02` at HPS index 1 before its index-0 program.
The loader binds the expected size before consuming the profile, validates
sequential writes and rejects incomplete or oversized downloads.

Each controller operates its own jeep: rotate, Forward and Fire. Forward
uses the existing thrust/movement button or Up. Keyboard player 1 uses
arrows/Space; player 2 uses A/D, W and F. Start 1/2 and Coin retain 1/2 and 5.
The input-bit layout matches Rip Off; service polarity is active-high, like
Star Castle. The MRA defaults to three jeeps, one coin per credit and demo
sound On (`2E`).

Only the standard `armora` set is supported initially. Its four 4 KiB chips
are validated by size, CRC32 and SHA-1 before local interleaving with
`tools/prepare_armora.py`. The assembled program SHA-256 is
`4aa91028ece84c2ef9caa8e6fab7424ced6fa635f3d6631c61022b47bf30fdf8`.

## Town overlay

The static roads/buildings are part of the visible playfield. The CC0 MAME
`armora.lay` contains both transmission tint and additive reflection SVGs;
no original cabinet art needs to be distributed.

`tools/prepare_armora_overlay.py` checks the matching orthogonal geometry,
holes and placement, then generates a two-bit indexed map. Four pixels are
packed per byte in `armora_map.hex` (64 KiB of FPGA data, including blank
padding). The palette represents black borders, green roads and yellow
building areas. A narrow SVG stroke is rasterized without antialiasing.

The compositor applies tint and adds the static reflection with saturation.
The existing Star Castle stage still handles vector brightness; a four-clock
Armor/bypass stage follows it with aligned coordinates, enables, blanking
and sync. All games share the same pipeline latency. **Screen overlay**
and **Overlay strength** affect this playfield; Vector brightness affects
the vectors. Verify road/collision alignment using Service mode's maze
pattern and actual wall impacts on hardware.

### Detailed artwork

**Detailed artwork On/Off** adds or removes transparent black building detail
from [ArcadeArtwork.org](https://www.arcadeartwork.org/picture.php?/99140).
The original 1448x1086 PNG is retained under `assets/armor_attack/`, with
archive credit and separate artwork provenance. No cabinet bezel is added.

`tools/prepare_armora_artwork.py` scales its alpha channel into the same
4.04x3.03 bounds and vertical offset as the CC0 town. Lanczos resampling
preserves fine details at 512x384. Four opacity levels use a 64 KiB packed
ink map, with the 128 unused bottom rows clear.

The ink ROM is read beside the town ROM. An extra output stage attenuates
the composed vectors and background according to ink opacity; Overlay
strength blends the ink toward transparency. Every game uses four-clock
latency, preserving pixel/sync alignment. Screen overlay Off bypasses
both town and ink; Detailed artwork Off retains the plain town. Its status
bit is 12; all earlier settings retain their original bits. MiSTer's Save
settings retains the choice.

The map is embedded in the RBF; no extra SD-card artwork file or MRA part
is needed. Colours still come from the existing town palette. On 2026-10-11
the user confirmed the detailed artwork lines up on MiSTer. This confirms
visual placement; exhaustive collision testing has not been separately reported.

## Sound

`armora_sound` models audio drawing 72-11141-02, supplied manual PDF pages
84-86 (printed A16-1 to A16-3). Its theory and test tables are on PDF pages
27-39 (6-9 to 6-21). The serial interface is OUT7 data, rising OUT4 shift,
rising OUT0 latch. Latched active-low bits 0/1/2/3 select tank fire, high
explosion, jeep fire and low explosion; bits 4-7 select tank rate with the
board's reversed TS3/TS2/TS1/TS0 order.

Direct active-low OUT1 enables the tank motor/tread circuits and OUT2 the
beeper. OUT3 drives the helicopter switch: its blade rhythm comes from the
CPU, not an invented free-running helicopter oscillator. Jeep firing and
high explosion share a noise filter and combine their envelope gains.

The model uses a shared 17-bit noise source, shift/add RC approximations,
envelopes and nominal digital dividers at 96 kHz. Tank pitch uses the manual's
7.35 kHz test clock and programmable divide-by-N, divide-13/divide-16 network.
Tread modulation uses the resistor network and pinned MAME VCO fit. The
beeper is approximately 396 Hz from its component values; the manual prose
has conflicting units/frequency, so it is not used as an exact oscillator value.

Gameplay feedback identified excessively loud beeper/tread tones and faint
explosions. The revised mix lowers the beeper and engine/tread tones, doubles
low-explosion gain and raises helicopter gain. Loaded second-pole RC values
also correct the tank, helicopter and shared jeep/high-explosion filters;
in particular C33 is 0.0047 uF, giving the firing/high-explosion path much
more bandwidth than the initial model.

The mixer retains 75% master gain. A 4:1 compression knee above +/-24576
limits large correlated sums while leaving smaller signals unchanged,
preventing overlapping noise voices from clipping. Three continuously
clocked pipeline stages take 60 ns at 50 MHz. No timing exceptions were
added for Armor Attack arithmetic.
Short serial explosion pulses are retained between audio enables. Reset and
download mute/clear the selected board; inactive boards remain reset.

This is a behavioral approximation. Analog loading, nonlinearities, channel
balance and tread squeak need comparison with recordings or an original board.
The pinned MAME netlist also flags tread-squeak and schematic-verification
limits; passing digital tests does not establish exact analog fidelity.

## Verification

- All 65,536 logical addresses are checked in both ROM maps; mixed-size
  switching, legacy fallback, malformed downloads and DIP isolation pass.
- Real-ROM run: 420 frames, 12,696,763 reference-checked instructions,
  86,174 vectors, two coin acknowledgements and both players' controls.
  Every framebuffer pixel is compared with the raster reference.
- Combat command counts: tank fire 2, high explosion 2, jeep fire 27,
  low explosion 2 and helicopter 25. The game produces 66 latch changes
  and an audio peak of 19,480. The earlier 180-frame run ended before
  these effects and only established initial beeper activity.
- Service diagnostic: 12 frames, 301,168 checked instructions and 2,508
  vectors; every framebuffer pixel passes. The captured city outline was
  visually compared with the overlay's town geometry. The user subsequently
  confirmed hardware artwork alignment; exhaustive collisions remain unvalidated.
- All 256 serial commands, seven audible effect groups, every tank-rate code,
  release, reset, silence and all-voice headroom pass sound tests.
- Settled sub-sample high/low explosion bursts pass at 50 MHz, with first
  100 ms RMS about 1793/1101. The worst directed mixer excursion is 29,131,
  below signed 16-bit saturation.
- Level checks require high/low explosions to exceed the beeper by at least
  8x/5x RMS and firing/helicopter to exceed engine/treads by at least 3x.
  Revised isolated levels are approximately 2387/1560 for high/low explosions,
  1912 for gunfire, 2297 for helicopter, 222 for beep and 450 for engine/treads.
- The actual MiSTer video pipeline passes 24 complete frames, checking every
  RGB pixel and sync alignment: colour/monochrome/plain town, detailed town
  at default/adjusted settings, and Screen overlay bypass with artwork On.

Reproduce with `bash sim/run_armora.sh` and `bash sim/run_armora_sound.sh`.
Optional local program/captures:

```sh
python3 tools/prepare_armora.py games/mame/armora.zip
bash sim/run_armora.sh build/roms/armora.bin build/armora/armora.pgm build/sound/armora-game.wav
```

The longer scripted ROM capture checks actual game-generated firing,
high/low explosion and helicopter commands. It does not establish analog
sound fidelity or replace hardware listening. On 2026-10-11 the user confirmed
the revised mix sounds much better and balanced like the arcade on MiSTer.
This is subjective playback feedback, not a measured waveform comparison.
Build and hardware status are recorded in the release manifest.

## References

Pinned MAME revision `9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e`:

- [Machine/input/ROM definitions](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/cinematronics/cinemat.cpp).
- [Audio circuit netlist](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/cinematronics/nl_armora.cpp), Aaron Giles, CC0-1.0.
- [Town overlay](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/layout/armora.lay), CC0-1.0; source retained under `rtl/video/overlays/`.
