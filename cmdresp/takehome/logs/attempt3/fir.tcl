
log_wave [get_objects -filter {type == in_port || type == out_port || type == inout_port || type == port} /apatb_fir_top/AESL_inst_fir/*]
set designtopgroup [add_wave_group "Design Top Signals"]
set coutputgroup [add_wave_group "C Outputs" -into $designtopgroup]
set return_group [add_wave_group return(axis) -into $coutputgroup]
add_wave /apatb_fir_top/AESL_inst_fir/m_out_TLAST -into $return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/m_out_TSTRB -into $return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/m_out_TKEEP -into $return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/m_out_TREADY -into $return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/m_out_TVALID -into $return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/m_out_TDATA -into $return_group -radix hex
set halted__error__tx_id__return_group [add_wave_group halted__error__tx_id__return(axi_slave) -into $coutputgroup]
add_wave /apatb_fir_top/AESL_inst_fir/interrupt -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_BRESP -into $halted__error__tx_id__return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_BREADY -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_BVALID -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_RRESP -into $halted__error__tx_id__return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_RDATA -into $halted__error__tx_id__return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_RREADY -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_RVALID -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_ARREADY -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_ARVALID -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_ARADDR -into $halted__error__tx_id__return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_WSTRB -into $halted__error__tx_id__return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_WDATA -into $halted__error__tx_id__return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_WREADY -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_WVALID -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_AWREADY -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_AWVALID -into $halted__error__tx_id__return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_axi_control_AWADDR -into $halted__error__tx_id__return_group -radix hex
set cinputgroup [add_wave_group "C Inputs" -into $designtopgroup]
set return_group [add_wave_group return(axis) -into $cinputgroup]
add_wave /apatb_fir_top/AESL_inst_fir/s_in_TLAST -into $return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_in_TSTRB -into $return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_in_TKEEP -into $return_group -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_in_TREADY -into $return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_in_TVALID -into $return_group -color #ffff00 -radix hex
add_wave /apatb_fir_top/AESL_inst_fir/s_in_TDATA -into $return_group -radix hex
set resetgroup [add_wave_group "Reset" -into $designtopgroup]
add_wave /apatb_fir_top/AESL_inst_fir/ap_rst_n -into $resetgroup
set clockgroup [add_wave_group "Clock" -into $designtopgroup]
add_wave /apatb_fir_top/AESL_inst_fir/ap_clk -into $clockgroup
save_wave_config fir.wcfg
# FIR_PORT_VCD_HOOK: record this original RTL simulation, no replay.
set fir_timing_ports [get_objects -filter { type == port } /apatb_fir_top/AESL_inst_fir/*]
puts "FIR_TIMING_PORTS: $fir_timing_ports"
if {[llength $fir_timing_ports] == 0} { error "FIR: no DUT ports selected for VCD" }
open_vcd "/home/js15828/hwdesign-work/cmdresp/takehome/evidence/cosim_ports.vcd"
log_vcd -level 1 $fir_timing_ports
run all
close_vcd

quit

