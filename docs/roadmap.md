# Roadmap

Star Castle's baseline is implemented: CCPU execution, ROM loading, controls,
vector rasterization, synthesized sound and adjustable colour filtering.
Simulation and reported FPGA timing pass. Gameplay, sound and video controls
have passed user testing on MiSTer.

Rip Off shares the CPU/video path and adds its own MRA, two-player controls
and sound board. Its 120-frame live-ROM regression passes 3,851,660 checked
instructions and every framebuffer pixel. It boots and plays on MiSTer but
is otherwise untested/WIP; gameplay, two-player operation and sound need validation.

Armor Attack now has a 16 KiB profile, two-player inputs, a city/road overlay
and synthesized sound. Its simulation and sound checks pass; the user confirmed
playback, revised sound balance and detailed artwork alignment. Two-player
operation and measured analog fidelity need validation.

Next steps:

- Test CRT output and additional displays and controllers.
- Synchronize framebuffer presentation to display blanking to prevent tearing.
- Improve vector appearance with optional glow and phosphor persistence.
- Calibrate physical vector timing, colour, intensity and analog sound.
- Validate Rip Off gameplay and sound on hardware.
- Validate Armor Attack two-player operation and remaining hardware details.
- Add Solar Quest with its own ROM layout,
  controls, sound and display profiles.
- Extend to other CCPU games, including analog/keypad/rotary controls and
  QB-3's banking and video differences.

Current limitations and hardware status are recorded in the
[README](../README.md) and [build manifest](../releases/Arcade-Cinematronics_20261011.json).
