derive_pll_clocks
derive_clock_uncertainty

# Audio arithmetic registers only advance on the common 96 kHz sample_ce.
# At 50 MHz the tested minimum enable spacing is 520 clocks. Allow only TWO
# clocks for paths between these registers, with the paired hold correction.
# Do not relax the serial latches, trigger capture, sample divider, CPU, HPS,
# or paths from audio registers into the continuously clocked MiSTer framework.
set audio_math_patterns {}
foreach audio_state {
    bg_increment laser_increment bg_phase laser_phase square_phase star_phase
    bg_counter bg_div128 bg_div126 laser_divider noise_half noise_lfsr
    soft_env loud_env fireball_env thrust_env soft_lp1 soft_lp2 loud_lp1 loud_lp2
    thrust_lp1 thrust_lp2 noise_dc bg_dc laser_dc star_c39 star_c40 star_high audio
} {
    lappend audio_math_patterns "*|sound|${audio_state}*"
}
set audio_math_regs [get_registers $audio_math_patterns]
if {[get_collection_size $audio_math_regs] == 0} {
    error "Sound arithmetic timing collection is empty"
}
set_multicycle_path -setup -from $audio_math_regs -to $audio_math_regs 2
set_multicycle_path -hold -from $audio_math_regs -to $audio_math_regs 1
