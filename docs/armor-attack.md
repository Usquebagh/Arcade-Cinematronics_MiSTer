# Armor Attack

Armor Attack is a development/WIP profile in the shared Cinematronics core.
It needs the three-game RBF; the 2026-10-04 two-game release cannot load it.
Hardware gameplay, two-player operation, overlay calibration and sound
comparison require user testing. No game ROMs or scanned manuals are distributed.

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
The existing Star Castle stage still handles vector brightness; a three-clock
Armor/bypass stage follows it with aligned coordinates, enables, blanking
and sync. All games share the same pipeline latency. **Screen overlay**
and **Overlay strength** affect this playfield; Vector brightness affects
the vectors. Verify road/collision alignment using Service mode's maze
pattern and actual wall impacts on hardware.

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

The mixer has a 75% master gain to preserve headroom when correlated noise
voices overlap, with two continuously clocked pipeline stages (40 ns at
50 MHz). No timing exceptions were added for Armor Attack arithmetic.
Short serial explosion pulses are retained between audio enables. Reset and
download mute/clear the selected board; inactive boards remain reset.

This is a behavioral approximation. Analog loading, nonlinearities, channel
balance and tread squeak need comparison with recordings or an original board.
The pinned MAME netlist also flags tread-squeak and schematic-verification
limits; passing digital tests does not establish exact analog fidelity.

## Verification

- All 65,536 logical addresses are checked in both ROM maps; mixed-size
  switching, legacy fallback, malformed downloads and DIP isolation pass.
- Real-ROM run: 180 frames, 6,529,570 reference-checked instructions,
  59,164 vectors, two coin acknowledgements and both players' controls.
  Every framebuffer pixel is compared with the raster reference.
- Service diagnostic: 12 frames, 301,168 checked instructions and 2,508
  vectors; every framebuffer pixel passes. The captured city outline was
  visually compared with the overlay's town geometry; hardware alignment
  and collisions remain unvalidated.
- All 256 serial commands, seven audible effect groups, every tank-rate code,
  release, reset, silence and all-voice headroom pass sound tests.
- Settled sub-sample high/low explosion bursts pass at 50 MHz, with first
  100 ms RMS about 1173/538. The worst directed mixer excursion is 27,300,
  below signed 16-bit saturation.
- The actual MiSTer video pipeline passes three default and three adjusted
  Armor town frames, checking every output RGB pixel and sync alignment,
  alongside the existing nine Star Castle/monochrome frames.

Reproduce with `bash sim/run_armora.sh` and `bash sim/run_armora_sound.sh`.
Optional local program/captures:

```sh
python3 tools/prepare_armora.py games/mame/armora.zip
bash sim/run_armora.sh build/roms/armora.bin build/armora/armora.pgm build/sound/armora-game.wav
```

The scripted ROM capture establishes execution and input/audio activity;
it does not independently validate every combat effect or human gameplay.
Build and hardware status are recorded in the release manifest.

## References

Pinned MAME revision `9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e`:

- [Machine/input/ROM definitions](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/cinematronics/cinemat.cpp).
- [Audio circuit netlist](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/cinematronics/nl_armora.cpp), Aaron Giles, CC0-1.0.
- [Town overlay](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/layout/armora.lay), CC0-1.0; source retained under `rtl/video/overlays/`.
