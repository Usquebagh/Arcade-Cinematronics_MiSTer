# Roadmap

Star Castle's baseline is implemented: CCPU execution, ROM loading, controls,
vector rasterization, synthesized sound and adjustable colour filtering.
Simulation and reported FPGA timing pass. Gameplay, sound and video controls
have passed user testing on MiSTer.

Next steps:

- Test CRT output and additional displays and controllers.
- Synchronize framebuffer presentation to display blanking to prevent tearing.
- Improve vector appearance with optional glow and phosphor persistence.
- Calibrate physical vector timing, colour, intensity and analog sound.
- Add Rip Off, Armor Attack and Solar Quest with their own ROM layouts,
  controls, sound and display profiles.
- Extend to other CCPU games, including analog/keypad/rotary controls and
  QB-3's banking and video differences.

Current limitations and hardware status are recorded in the
[README](../README.md) and [build manifest](../releases/Arcade-Cinematronics_20261004.json).
