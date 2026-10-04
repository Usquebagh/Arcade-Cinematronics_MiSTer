# Star Castle development build

This is the first MiSTer integration build, intended for initial hardware tests.
It has grayscale video and coin/start/gameplay controls. Audio is silent; frame
tearing is possible because game-frame presentation is not yet synchronized
to display blanking. Attract mode and gameplay have been checked in simulation,
but this RBF has not been tested on a DE10-Nano.

Copy these files to your MiSTer SD card:

| File | Destination |
| --- | --- |
| `Arcade-Cinematronics_20261004.rbf` | `_Arcade/cores/` |
| `Star Castle (version 3).mra` | `_Arcade/` |
| Your own `starcas.zip` | `_Arcade/mame/` |

Launch the MRA. Keyboard: 5 for coin, 1/2 for start, Left/Right to rotate,
Up to thrust, Space to fire. Controller: directions to rotate, Fire/Thrust
buttons, Start and Coin; button mapping can be changed through MiSTer.

The build/source identity and RBF SHA-256 are in
`Arcade-Cinematronics_20261004.json`. No game ROM bytes are embedded in the
RBF or included in this repository; the MRA downloads your ROM at launch.
See [integration and validation](../docs/mister-integration.md) for details.

For hardware feedback, record the RBF hash and whether the picture, attract
mode, coin/start, controls, OSD reset and extended runs behave correctly.
