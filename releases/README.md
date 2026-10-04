# Current build — 2026-10-04

One RBF supports **Star Castle (version 3)** and **Rip Off**, each selected by
its own MRA. Both have synthesized sound and adjustable brightness;
Star Castle also has a colour filter. Simulation and reported internal timing
pass. Both MRA paths and FPGA startup have been checked on MiSTer.
Star Castle's earlier build passed hardware gameplay and sound checks;
**gameplay testing of this combined build and Rip Off listening are pending.**
**CRT output is untested.** Glow, bloom and phosphor persistence are not
implemented; frame tearing is possible. Colour and analog sound calibration
remain outstanding.

## Installation

| File | MiSTer SD-card destination |
| --- | --- |
| [Arcade-Cinematronics_20261004.rbf](Arcade-Cinematronics_20261004.rbf) | `_Arcade/cores/` |
| [Star Castle (version 3).mra](Star%20Castle%20%28version%203%29.mra) | `_Arcade/` |
| [Rip Off.mra](Rip%20Off.mra) | `_Arcade/` |
| Your own `starcas.zip` | `_Arcade/mame/` |
| Your own `ripoff.zip` | `_Arcade/mame/` |

Keep only the current Cinematronics RBF and launch the MRA. When downloading
individual files from GitHub, use **Download raw file**.
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
