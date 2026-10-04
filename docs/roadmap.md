# Development milestones

1. **CPU foundation**: verify opcode behavior, Star Castle ROM layout and
   component synthesis. Add regression tests before changing CPU semantics.
2. **Vector output**: capture complete game frames, implement clipped raster
   lines and a framebuffer, compare simulation output to reference frames.
   Baseline completed: end-to-end frame pixels match the integer raster model.
   Display calibration, persistence and live machine timing remain follow-ups.
3. **Star Castle machine**: clock and frame timers, coin latch, DIP switches,
   controls, watchdog, reset and vector intensity.
   Baseline completed in simulation: CPU/ROM/video are connected and coin/start
   and gameplay controls are exercised, with watchdog recovery and frame checks.
   Original draw-busy timing and on-device behavior still require validation.
4. **MiSTer build**: import a pinned platform framework with licenses, add
   DE10-Nano project files and HPS ROM download, create the MRA, compile and
   resolve timing. A blank or diagnostic RBF does not satisfy this milestone.
   Platform wiring and tests are implemented. A first complete game-connected
   build passes fit and reported timing; the final development RBF and evidence
   are recorded in `releases/` and `docs/mister-integration.md`. Scanout/game
   frame synchronization remains a follow-up. FPGA startup and a full game
   have now passed on hardware with the original silent RBF.
5. **Playable Star Castle**: verify attract mode, coin/start, controls, gameplay,
   reset and long runs on hardware; implement and validate sound. Record the
   exact tested source commit and RBF hash. Hardware results require access to
   a MiSTer or user testing; simulation alone cannot establish them. A full
   silent game has passed. A first synthesized sound-board model now passes
   logic, effect, sample-rate and live-game simulations. Hardware listening has
   passed a user comparison; measured analog fidelity remains uncalibrated.
   Shared colour-overlay support and simple saved video controls pass simulation
   and timing. The user confirms that gameplay and brightness/overlay controls
   work on the colour build. CRT output is untested; glow, bloom and persistence
   remain future work.
6. **Shared platform**: Rip Off, Armor Attack and Solar Quest, each with ROM
   validation, proper I/O and sound. Then analog/keypad/rotary games and QB-3.

The user authorized public repository visibility on 2026-10-04. Commit each
verified development milestone, preserving clear status and known limitations.
Game ROMs and proprietary documentation remain excluded from the repository.
