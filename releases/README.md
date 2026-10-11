# Current build — 2026-10-11

One RBF supports **Star Castle (version 3)**, **Rip Off** and **Armor Attack**,
each selected by its own MRA. All three have synthesized sound and adjustable
brightness. Star Castle has a colour filter; Armor Attack has a static city
overlay. Simulation and reported internal timing pass. Star Castle gameplay
was confirmed on the previous two-game build.
**Rip Off is bootable but otherwise untested/WIP**: it boots and plays on
MiSTer, but gameplay, two-player operation and sound have not been validated.
**Armor Attack boots and plays, but remains WIP**; its revised sound balance
and detailed artwork alignment are confirmed by user testing. Two-player
controls need testing. The current build lowers beeper/tread tones and brings up firing,
explosions and helicopter audio. Other profiles still need hardware
regression checks. **CRT output is untested.** Colour and analog sound calibration remain outstanding.

Armor Attack includes credited ArcadeArtwork.org transparent building detail,
scaled to 512x384. **Detailed artwork On/Off** switches between detailed and
plain city views; **Save settings** retains the choice. No extra artwork file
is required on the SD card. The user confirmed the artwork lines up on MiSTer.

## Installation

| File | MiSTer SD-card destination |
| --- | --- |
| [Arcade-Cinematronics_20261011.rbf](https://github.com/Usquebagh/Arcade-Cinematronics_MiSTer/raw/refs/heads/main/releases/Arcade-Cinematronics_20261011.rbf) | `_Arcade/cores/` |
| [Star Castle (version 3).mra](https://github.com/Usquebagh/Arcade-Cinematronics_MiSTer/raw/refs/heads/main/releases/Star%20Castle%20%28version%203%29.mra) | `_Arcade/` |
| [Rip Off.mra](https://github.com/Usquebagh/Arcade-Cinematronics_MiSTer/raw/refs/heads/main/releases/Rip%20Off.mra) | `_Arcade/` |
| [Armor Attack.mra](https://github.com/Usquebagh/Arcade-Cinematronics_MiSTer/raw/refs/heads/main/releases/Armor%20Attack.mra) | `_Arcade/` |
| Your own `starcas.zip` | `_Arcade/mame/` |
| Your own `ripoff.zip` | `_Arcade/mame/` |
| Your own `armora.zip` | `_Arcade/mame/` |

The links above download the actual files. Keep only the current Cinematronics
RBF and launch the MRA. From a GitHub file page, use **Download raw file**;
saving the webpage creates an unusable HTML file.
Controls and video options are listed in the [README](../README.md).
No game ROMs are embedded in the RBF or distributed here.

## Build Verification

The [manifest](Arcade-Cinematronics_20261011.json) records the source commit,
checksum and validation status. The [fitter](Arcade-Cinematronics_20261011.fit.summary)
and [timing](Arcade-Cinematronics_20261011.sta.summary) summaries accompany it.
All reported internal timing categories pass; external interface constraints
and hardware limits are described in [MiSTer integration](../docs/mister-integration.md).

If the MRA returns immediately to the menu, copy
[check_mister_install.sh](../tools/check_mister_install.sh) to `Scripts/` on the
SD card and run it. The read-only check reports the MRA's search path, matching
RBF and checksum without reading ROM contents.
