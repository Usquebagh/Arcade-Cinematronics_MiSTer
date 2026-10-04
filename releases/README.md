# Star Castle development build

The current `_sound` revision adds eight synthesized sound effects to the
grayscale video and coin/start/gameplay controls. It passes simulation, fitting
and reported internal timing, and has launched on MiSTer Main version 260912.
The user confirms sound works and compares well with a Star Castle gameplay
recording. The sound model is a behavioral approximation;
its fidelity and channel balance still need calibration. Frame
tearing is possible because game-frame presentation is not yet synchronized
to display blanking. The original silent build is retained for rollback; the
user completed a full game with that build on hardware.

Copy these files to your MiSTer SD card:

| File | Destination |
| --- | --- |
| `Arcade-Cinematronics_20261004_sound.rbf` | `_Arcade/cores/` |
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
`Arcade-Cinematronics_20261004_sound.json`. No game ROM bytes are embedded in the
RBF or included in this repository; the MRA downloads your ROM at launch.
See [integration and validation](../docs/mister-integration.md) for details.

For hardware feedback, record the RBF hash and whether the picture, attract
mode, coin/start, controls, thrust/fire/explosion/shield/background sounds,
OSD reset and extended runs behave correctly.

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
