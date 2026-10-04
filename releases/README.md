# Current build — 2026-10-04

One RBF supports **Star Castle (version 3)** and **Rip Off**, each selected by
its own MRA. Both have synthesized sound and adjustable brightness;
Star Castle also has a colour filter. Simulation and reported internal timing
pass. Star Castle still plays correctly on the combined core.
**Rip Off is bootable but otherwise untested/WIP**: it boots and plays on
MiSTer, but gameplay, two-player operation and sound have not been validated.
**CRT output is untested.** Colour and analog sound calibration remain outstanding.

## Installation

| File | MiSTer SD-card destination |
| --- | --- |
| [Arcade-Cinematronics_20261004.rbf](https://github.com/Usquebagh/Arcade-Cinematronics_MiSTer/raw/refs/heads/main/releases/Arcade-Cinematronics_20261004.rbf) | `_Arcade/cores/` |
| [Star Castle (version 3).mra](https://github.com/Usquebagh/Arcade-Cinematronics_MiSTer/raw/refs/heads/main/releases/Star%20Castle%20%28version%203%29.mra) | `_Arcade/` |
| [Rip Off.mra](https://github.com/Usquebagh/Arcade-Cinematronics_MiSTer/raw/refs/heads/main/releases/Rip%20Off.mra) | `_Arcade/` |
| Your own `starcas.zip` | `_Arcade/mame/` |
| Your own `ripoff.zip` | `_Arcade/mame/` |

The links above download the actual files. Keep only the current Cinematronics
RBF and launch the MRA. From a GitHub file page, use **Download raw file**;
saving the webpage creates an unusable HTML file.
Controls and video options are listed in the [README](../README.md).
No game ROMs are embedded in the RBF or distributed here.

## Build Verification

The [manifest](Arcade-Cinematronics_20261004.json) records the source commit,
checksum and validation status. The [fitter](Arcade-Cinematronics_20261004.fit.summary)
and [timing](Arcade-Cinematronics_20261004.sta.summary) summaries accompany it.
All reported internal timing categories pass; external interface constraints
and hardware limits are described in [MiSTer integration](../docs/mister-integration.md).

If the MRA returns immediately to the menu, copy
[check_mister_install.sh](../tools/check_mister_install.sh) to `Scripts/` on the
SD card and run it. The read-only check reports the MRA's search path, matching
RBF and checksum without reading ROM contents.
