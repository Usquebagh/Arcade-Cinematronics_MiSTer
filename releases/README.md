# Star Castle development build

This is the first MiSTer integration build, intended for initial hardware tests.
It has grayscale video and coin/start/gameplay controls. Audio is silent; frame
tearing is possible because game-frame presentation is not yet synchronized
to display blanking. Attract mode and gameplay have been checked in simulation.
FPGA configuration and core identification have now passed on a MiSTer with
Main version 260912. The user completed a full game on hardware successfully,
with grayscale video and silent audio as expected for this build.

Copy these files to your MiSTer SD card:

| File | Destination |
| --- | --- |
| `Arcade-Cinematronics_20261004.rbf` | `_Arcade/cores/` |
| `Star Castle (version 3).mra` | `_Arcade/` |
| Your own `starcas.zip` | `_Arcade/mame/` |

Launch the MRA. Keyboard: 5 for coin, 1/2 for start, Left/Right to rotate,
Up to thrust, Space to fire. Controller: directions to rotate, Fire/Thrust
buttons, Start and Coin; button mapping can be changed through MiSTer.

When downloading individual files from GitHub, use **Download raw file**.
Saving the GitHub file webpage produces HTML with an `.mra` or `.rbf` name.
That caused the first reported launch failure: both installed files were HTML.
Replacing them with the verified XML and bitstream allowed the core to start.

The build/source identity and RBF SHA-256 are in
`Arcade-Cinematronics_20261004.json`. No game ROM bytes are embedded in the
RBF or included in this repository; the MRA downloads your ROM at launch.
See [integration and validation](../docs/mister-integration.md) for details.

For hardware feedback, record the RBF hash and whether the picture, attract
mode, coin/start, controls, OSD reset and extended runs behave correctly.

If launching the MRA immediately returns to the MiSTer menu, copy
[`check_mister_install.sh`](../tools/check_mister_install.sh) to `Scripts/`
on your SD card and run it from MiSTer's Scripts menu. It reports each Star
Castle MRA, the `cores/` directory MiSTer searches, the matching RBF selected
by date/name, and its size and SHA-256. It reads no ROM contents and changes
no files. Send the output to identify missing, misplaced or different builds.

For a separate FPGA startup check, temporarily copy the RBF to the SD-card
root and launch it directly. Without the MRA the picture will be black;
press F12 and check for the Cinematronics options. Report whether those
options appear or whether the main MiSTer core list returns.
