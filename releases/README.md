# Star Castle development build

The current `_colour` revision adds a Star Castle colour overlay and adjustable
video to the playable core with eight synthesized sound effects. It passes
simulation, fitting and reported internal timing, and is installed and launched
on MiSTer with matching file hashes. Visual and saved-settings
checks on this revision are pending. The previous sound build passed the user's
listening comparison with a Star Castle gameplay recording; its audio logic is
retained. Sound fidelity, physical gel/CRT colour and persistence remain
uncalibrated. Frame tearing is possible because game-frame presentation is not
yet synchronized to display blanking. Only the current RBF is packaged here.

Copy these files to your MiSTer SD card:

| File | Destination |
| --- | --- |
| `Arcade-Cinematronics_20261004_colour.rbf` | `_Arcade/cores/` |
| `Star Castle (version 3).mra` | `_Arcade/` |
| Your own `starcas.zip` | `_Arcade/mame/` |

Launch the MRA. Keyboard: 5 for coin, 1/2 for start, Left/Right to rotate,
Up to thrust, Space to fire. Controller: directions to rotate, Fire/Thrust
buttons, Start and Coin; button mapping can be changed through MiSTer.

The OSD offers **Colour overlay** (On/Off), **Vector brightness**
(100/75/125/150%) and **Overlay strength** (100/75/50/25%). Use MiSTer's
**Save settings** to retain your choices. Defaults are colour on, normal
brightness and full overlay strength. See [colour controls](../docs/colour.md).

When downloading individual files from GitHub, use **Download raw file**.
Saving the GitHub file webpage produces HTML with an `.mra` or `.rbf` name.
That caused the first reported launch failure: both installed files were HTML.
Replacing them with the verified XML and bitstream allowed the core to start.

The build/source identity and RBF SHA-256 are in
`Arcade-Cinematronics_20261004_colour.json`. No game ROM bytes are embedded in the
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
