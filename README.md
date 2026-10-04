# Cinematronics vector arcade hardware for MiSTer FPGA

An FPGA implementation of Cinematronics vector arcade hardware for the
[MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer/wiki) platform,
supporting **Star Castle (version 3, 1980)** and **Rip Off (1980)** in one RBF.

Defend your ship against the central cannon, breaking through its rotating
shield rings while avoiding mines. The core recreates the CCPU, vector display
and discrete sound, with a colour filter based on the original screen gels.
Rip Off adds simultaneous two-player defence of the fuel supply.
Armor Attack and Solar Quest are planned next.

<p align="center">
  <img src="docs/arcade_cabinet.png" alt="Star Castle arcade cabinet" height="310">
  <img src="docs/star_castle.png" alt="Star Castle game screen" height="310">
</p>

> **Status:** Star Castle still plays correctly on the combined core.
> **Rip Off is bootable but otherwise untested/WIP**: it boots and plays on
> MiSTer, but gameplay, two-player operation and sound have not been validated.
> Simulation, fitting and reported internal timing pass for both games.
>
> **Known issues:** **CRT output is untested.** Explosion levels have been
> corrected in simulation; hardware listening is pending. Neon glow, bloom and phosphor
> persistence are not implemented. Frame tearing is possible. Physical colour,
> vector timing and analog sound fidelity remain uncalibrated. Feedback and
> bug reports are welcome via [Issues](https://github.com/Usquebagh/Arcade-Cinematronics_MiSTer/issues).

---

## Original Hardware

| Subsystem | Original Hardware | FPGA Implementation |
| --- | --- | --- |
| CPU | Cinematronics CCPU, two 12-bit accumulators | SystemVerilog CCPU, checked against the pinned MAME instruction reference |
| Program | Four ROM chips, 8 KiB total | Writable program ROM, loaded through the MRA |
| Video | Monochrome vector display with coloured screen gels | 512x384 raster framebuffer, 16 brightness levels and a Star Castle colour filter |
| Sound | Game-specific discrete sound boards | Synthesized oscillators, noise and envelopes: eight Star Castle channels and six Rip Off effects; signed mono audio |

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Rotate | Left/Right | Left/Right |
| Thrust | Up | Thrust button or Up |
| Fire | Space | Fire button |
| Coin | 5 | Coin button |
| Start 1 | 1 | Controller 1 Start |
| Start 2 | 2 | Start 2 button or Controller 2 Start |

For Rip Off, each controller operates its own player. Player 2 keyboard controls
are **A/D** to rotate, **W** to thrust and **F** to fire.

The OSD provides **Colour overlay**, **Vector brightness** and **Overlay strength**.
Use MiSTer's **Save settings** to retain your choices. See
[video controls](docs/colour.md) for details.
Rip Off uses monochrome output with adjustable brightness.

## ROMs and Installation

Copy the current files from [releases](releases/) to your MiSTer SD card:

| File | Destination |
| --- | --- |
| `Arcade-Cinematronics_20261004.rbf` | `_Arcade/cores/` |
| `Star Castle (version 3).mra` | `_Arcade/` |
| `Rip Off.mra` | `_Arcade/` |
| Your own `starcas.zip` | `_Arcade/mame/` |
| Your own `ripoff.zip` | `_Arcade/mame/` |

Launch either game through its MRA; both select the same RBF. For individual GitHub
downloads, use **Download raw file**. Keep only the current Cinematronics RBF
in `cores/`. See [release details](releases/README.md) for build information
and installation troubleshooting.

Game ROMs and other proprietary game data or documentation are not included
or distributed with this repository.

## Compilation and Tests

From Linux or WSL, run `bash build.sh`. It uses Quartus Prime Lite 17.0.2 in
`theypsilon/quartus-lite-c5:17.0.2` and checks fitting and reported timing.
The output is `output_files/Arcade-Cinematronics.rbf`.

[Validation](docs/validation.md) lists test commands and results. CI uses
synthetic programs and requires no game ROMs. Technical details are in
[architecture](docs/architecture.md), [MiSTer integration](docs/mister-integration.md),
[Star Castle sound](docs/sound.md), [Rip Off](docs/ripoff.md),
[colour](docs/colour.md) and [roadmap](docs/roadmap.md).

## Credits

- Aaron Giles and MAME: CCPU instruction reference and Cinematronics board definitions.
- MAME contributors: Star Castle sound-circuit and colour-filter references.
- MiSTer developers: platform framework, imported through the Fire Trap core.
- Hardware documentation authors: original CPU, board and circuit references.

See [reference provenance](docs/references.md) for source revisions and licenses.

## License

The integrated MiSTer core is [GPL-3.0-or-later](LICENSE). Original CPU,
machine, video modules and tools remain
[BSD-3-Clause](LICENSES/Cinematronics-BSD-3-Clause.txt) individually.
Imported components retain their respective licenses and credits.
