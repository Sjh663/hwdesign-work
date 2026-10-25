# Reference FPGA and 10 ns clock; one C simulation, synthesis, one RTL cosimulation.
open_project -reset fir_hls
set_top fir
set flags "-I. -std=c++17 -fno-fast-math -ffp-contract=off"
add_files gen/fir.cpp -cflags $flags
add_files -tb fir_tb.cpp -cflags $flags
if {[file exists include/streamutils.cpp]} {add_files -tb include/streamutils.cpp -cflags $flags}
open_solution -reset solution1
set_part {xc7z020clg484-1}
create_clock -period 10
config_compile -unsafe_math_optimizations false
set here [file dirname [file normalize [info script]]]
set data_dir [file join $here vectors]
if {[catch {csim_design -argv "$data_dir csim"} e]} {puts "FIR_CSIM_FAILED: $e";exit 1}
puts "FIR_CSIM_PASS"
if {[catch {csynth_design} e]} {puts "FIR_SYNTHESIS_FAILED: $e";exit 2}
puts "FIR_SYNTHESIS_COMPLETE"
if {[catch {cosim_design -argv "$data_dir cosim" -trace_level port} e]} {puts "FIR_COSIM_FAILED: $e";exit 3}
puts "FIR_COSIM_PASS"
exit 0
