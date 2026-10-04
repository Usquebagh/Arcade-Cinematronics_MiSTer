# Star Castle sound

`rtl/sound/starcastle_sound.sv` implements a first behavioral model of the
Star Castle audio board, drawing 72-10861-02. The supplied manual's PDF pages
86-87 contain the two circuit sheets (printed A-25/A-26). No sample playback,
sound ROM, ROM-derived waveform or initialization file is used.

## Control wiring

OUT7 supplies serial data to the LS164. Rising OUT4 shifts it into QA and
toward QH. Rising OUT0 transfers all eight bits to the LS377. This physical
shift-left representation is the bit reversal of MAME's older sample driver's
shift-right representation; mixing the two orders swaps the sounds.

| Control | Effect | Active level |
| --- | --- | --- |
| LS377 QA / bit 0 | Fireball / castle cannon | Low |
| LS377 QB / bit 1 | Shield hit | Low |
| LS377 QC / bit 2 | Star sound | High |
| LS377 QD / bit 3 | Thrust | Low |
| LS377 QE / bit 4 | Background drone | Low |
| LS377 QF/QG/QH / bits 5/6/7 | BL2/BL1/BL0 background pitch | Resistor DAC |
| OUT1 | Loud explosion | Low |
| OUT2 | Soft explosion | Low |
| OUT3 | Player laser | Low |

OUT5 remains the coin acknowledgement and OUT6 the vector intensity. Every
system clock observes control edges. Short explosion/fireball pulses are
retained until the audio sample enable, including a one-clock pulse at 50 MHz.
Hard reset, MRA reload and unloaded ROM state clear and mute the sound board.
The CPU's watchdog recovery preserves the output latches and sound state.

## Signal generation

The core runs at 50 MHz. A fractional enable produces exactly 96,000 samples
per second with 520/521-clock spacing; MiSTer receives signed 16-bit mono on
both audio channels through its existing audio framework.

The SDC allows two system-clock cycles only between the named audio arithmetic
registers that share this enable. Their actual minimum update spacing is 520
clocks, as checked by simulation. The paired hold correction retains the
original hold relationship. Serial latches, trigger capture, sample timing,
CPU/HPS/video and paths into the MiSTer audio framework remain single-cycle.
This follows [Intel's multicycle timing model](https://resources.altera.com/quartushelp/17.0/tafs/tafs/tcl_pkg_sdc_ver_1.5_cmd_set_multicycle_path.htm).

The noise source uses the 17-bit MM5837/S2688 polynomial, seeded to all ones,
and advances at 48 kHz. It is shared by the explosion, fireball, shield and
thrust voices. The two-pole noise filters use the corresponding schematic
resistor/capacitor values. The thrust's second pole includes the load from
R109+R110. OTA control envelopes approximate the capacitor charging and
discharging; the nominal release constants are .22 s (soft), .47 s (loud),
.136 s (fireball) and .238 s (thrust). Thrust attack is about .119 s.

The common 555 noise modulation oscillator uses R32=2k, R33=130k and C20=.1uF,
giving about 55 Hz (the schematic labels it 60 Hz). Shield gating and the
fireball's noise/tone mixture use this source. The star sound combines the
roughly 9 Hz IC23 oscillator with the IC24 timing-capacitor model and the
R114/R115/C39 modulation network, using the 555's 1/3 and 2/3 supply thresholds.

Background pitch uses the three resistor-DAC weights, a voltage/frequency
curve based on MAME's fitted VCO model, and endpoint normalization to the
schematic's nominal 7.5-23.3 kHz range. The 3.3M/.68uF control pole smooths
pitch changes. The digital divider follows MAME's IC10/IC11 wiring (C1
reload), IC28 and IC12, giving divide 126, mixed with IC13's divide 128.
The manual labels the first branch divide 220; that conflicts with the
reference netlist's counter wiring and needs comparison to a physical board.

The laser VCO sweeps from about 22 kHz toward 5.8 kHz using the C22 charging
network. The LS393 divides it, with QA/QB/QD summed according to R47/R48/R49.
Output coupling filters remove DC. Filters and envelopes use a signed
fixed-point first-order RC update with coefficient
`1-exp(-1/(96000*R*C))`; near zero, a minimum state step prevents permanent
DC residue. A signed mixer leaves headroom and saturates rather than wraps.

## Fidelity limits

This is a schematic-informed behavioral approximation, not a transistor-level
netlist translation. VCO control-voltage mapping, OTA gains, nonlinearities,
filter loading, star output shaping and channel balance need listening and
measurement against an original board or the full reference netlist. It has
not been waveform-matched to MAME. Independent channel gains provide an
initial listening balance rather than calibrated resistor-network gains.
The explosion balance was corrected after the user reported missing crash
and destruction sounds: soft explosion gain increased by 24 dB and loud by
12 dB. Their isolated one-second RMS levels are now about 842 and 1664,
compared with 1415 for the laser; previously they were 53 and 416.
The filters, control wiring and decay constants are unchanged. This is an
audibility correction, with physical-board balance still requiring listening.
Do not describe passing logic tests as proof of analog sound accuracy.

Reference sources are pinned to the same MAME commit as the CPU:

- [Star Castle circuit netlist](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/cinematronics/nl_starcas.cpp),
  Aaron Giles, CC0-1.0. Supplies circuit connectivity and fitted VCO equations.
- [Audio-board interface](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/cinematronics/cinemat_a.cpp),
  Aaron Giles, BSD-3-Clause.
- [MM5837 noise model](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/lib/netlist/devices/nld_mm5837.cpp),
  Couriersud, BSD-3-Clause. Shared polynomial and nominal noise clock.

## Verification

`bash sim/run_sound.sh` requires no ROMs. It tests all 256 serial values,
shift/latch isolation, non-sound outputs, reset and exact silence, all eight
voices, bipolar output, approximate oscillator ranges, envelope decay,
simultaneous effects without clipping, sample rate and short triggers between
sample enables. Individual synthetic WAV files remain ignored under
`build/sound/` for listening.
Both 20 ns explosion triggers are checked at 50 MHz, including burst-level
floors that reject the previously inaudible mix. Their first 100 ms RMS
levels after a full second of filter settling are approximately 658 (soft)
and 1297 (loud). All voices together
remain below saturation in the directed mixer test.

`bash sim/run_machine.sh build/roms/starcastle.bin
build/machine/starcastle-sound.pgm build/sound/starcastle-game.wav` additionally
checks the local game's CPU retirement and every frame pixel against the
existing references while capturing the game's own sound commands. The
28-frame run produced five sound-latch changes, 71,491 audio samples and peak
6,392. The optional game WAV is local only and is not uploaded. The MRA and
program ROM layout are unchanged by sound integration.

The current build passes full Quartus fitting and the timing gate; results
are in the [manifest](../releases/Arcade-Cinematronics_20261004.json).
On 2026-10-04 the user confirmed audible sound on MiSTer,
reporting "sound is good in comparison" to
[this Star Castle gameplay recording](https://www.youtube.com/watch?v=S_DojyqJXKE).
This passes the initial subjective listening check; no measured waveform or
individual channel calibration is implied. The user subsequently reported
missing explosion sounds; the revised levels need hardware listening.
Further checks can cover each
effect, background pitch progression, both output channels, OSD reset and reload.
