# Reference provenance

Hardware references supplied locally:

- `Documentation/Cinematronics_CPU_Programmers_Reference.pdf`, Zonn Moore,
  version 1.0, 2000-03-16. Memory/register layout: pages 5-8; flags: pages 9-16;
  opcode tables: pages 18-20; I/O: pages 21-22; vector hardware: pages 22-27.
- `Documentation/Cinematronics_Application_Programming_Manual.pdf`
- `Documentation/Cinematronics_Exorcisor_Manual.pdf`
- `Documentation/cine_faq_v096.pdf`
- `games/manuals/Star_Castle_Manual.pdf` and the other supplied game manuals.
- [Zonn Moore's Cinematronics documentation](http://www.zonn.com/Cinematronics/index.htm).

The instruction table on page 18 and the extracted CPU reference text were
inspected during setup. Other manuals are available for the subsequent
board/video/sound investigation; they have not all been reviewed yet. Star
Castle manual PDF pages 86-87 (printed A-25/A-26) have now been visually
reviewed for sound control wiring, oscillator/divider circuits, effect
envelopes and mixing. The sound model's provenance and fidelity limits are
recorded in [sound](sound.md). Rip Off manual PDF page 80 (printed 8-18)
was reviewed for its audio schematic, and page 81 (8-19) for controls.
The model and pinned circuit references are recorded in [Rip Off](ripoff.md).

MAME is pinned to commit `9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e`:

- [CCPU implementation](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/devices/cpu/ccpu/ccpu.cpp),
  Aaron Giles, BSD-3-Clause. Original source is stored in
  `sim/reference/mame_ccpu.cpp`, SHA-256
  `329a117e0151a8fd8773df09904b9f879e350ed7cebfcdd8282e3345330544fd`.
  The adapter generator extracts macros, reset and execute_run without rewriting
  their bodies. The adapter replaces only the MAME device framework and memory
  bus, using Star Castle's ROM map. This avoids maintaining a second hand-written
  implementation of the instruction set as the test oracle.
- [Cinematronics driver](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/cinematronics/cinemat.cpp):
  ROM interleave/checksums, program memory mirrors, clock and input definitions.
- [Vector reference](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/cinematronics/cinemat_v.cpp):
  segment and intensity handling for later video work.
- [Star Castle colour overlay](https://github.com/mamedev/mame/blob/9eea5804dc46644dd2dc9c3bc28cbb6c2e93c54e/src/mame/layout/starcas.lay),
  CC0-1.0. The original layout and generated row/gain data are stored under
  `rtl/video/overlays/`; see [colour](colour.md) for normalization and limitations.

The supplied Star Castle v3 image passes all four chip size, CRC32 and SHA-1
checks. Interleaved local image SHA-256:
`526f2a2e722323b4538a64f9394d89705d91e02aed5202d718baba05ec73f13f`.
No ROM data or archival scan is committed.
