# Development milestones

1. **CPU foundation**: verify opcode behavior, Star Castle ROM layout and
   component synthesis. Add regression tests before changing CPU semantics.
2. **Vector output**: capture complete game frames, implement clipped raster
   lines and a framebuffer, compare simulation output to reference frames.
   Baseline completed: end-to-end frame pixels match the integer raster model.
   Display calibration, persistence and live machine timing remain follow-ups.
3. **Star Castle machine**: clock and frame timers, coin latch, DIP switches,
   controls, watchdog, reset and vector intensity.
4. **MiSTer build**: import a pinned platform framework with licenses, add
   DE10-Nano project files and HPS ROM download, create the MRA, compile and
   resolve timing. A blank or diagnostic RBF does not satisfy this milestone.
5. **Playable Star Castle**: verify attract mode, coin/start, controls, gameplay,
   reset and long runs on hardware; implement and validate sound. Record the
   exact tested source commit and RBF hash. Hardware results require access to
   a MiSTer or user testing; simulation alone cannot establish them.
6. **Shared platform**: Rip Off, Armor Attack and Solar Quest, each with ROM
   validation, proper I/O and sound. Then analog/keypad/rotary games and QB-3.

Keep the repository private throughout development. Do not change visibility
or publish a public release without the user's instruction. Commit each
verified development milestone, preserving clear status and known limitations.
