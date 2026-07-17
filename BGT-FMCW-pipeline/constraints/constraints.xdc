#set_property PACKAGE_PIN L16 [get_ports clk]
#set_property IOSTANDARD LVCMOS33 [get_ports clk]
#create_clock -period 8.000 -name sys_clk [get_ports clk]


set_property PACKAGE_PIN P16 [get_ports start]
set_property IOSTANDARD LVCMOS33 [get_ports start]
set_property PULLTYPE PULLDOWN [get_ports start]

#set_property PACKAGE_PIN R18 [get_ports rst]
#set_property IOSTANDARD LVCMOS33 [get_ports rst]
#set_property PULLTYPE PULLDOWN [get_ports rst]

set_property PACKAGE_PIN H15 [get_ports MISO]
set_property IOSTANDARD LVCMOS33 [get_ports MISO]

set_property PACKAGE_PIN Y17 [get_ports IRQ]
set_property IOSTANDARD LVCMOS33 [get_ports IRQ]

set_property PACKAGE_PIN T17 [get_ports SCLK]
set_property IOSTANDARD LVCMOS33 [get_ports SCLK]

set_property PACKAGE_PIN U17 [get_ports MOSI]
set_property IOSTANDARD LVCMOS33 [get_ports MOSI]

set_property PACKAGE_PIN W16 [get_ports CS_N]
set_property IOSTANDARD LVCMOS33 [get_ports CS_N]

set_property PACKAGE_PIN V13 [get_ports SRST]
set_property IOSTANDARD LVCMOS33 [get_ports SRST]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 2048 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list updated_design_i/processing_system7_0/inst/FCLK_CLK0]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 12 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[1]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[2]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[3]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[4]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[5]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[6]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[7]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[8]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[9]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[10]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_data[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[1]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[2]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[3]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[4]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[5]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[6]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[7]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[8]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[9]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[10]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[11]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[12]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[13]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[14]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[15]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[16]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[17]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[18]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[19]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[20]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[21]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[22]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[23]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[24]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[25]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[26]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[27]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[28]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[29]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[30]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_data[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 6 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_address[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_address[1]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_address[2]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_address[3]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_address[4]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_address[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 2 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_state[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_state[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 12 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[1]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[2]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[3]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[4]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[5]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[6]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[7]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[8]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[9]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[10]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/raw_sample[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 4 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/state[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/state[1]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/state[2]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/state[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[1]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[2]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[3]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[4]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[5]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[6]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[7]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[8]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[9]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[10]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[11]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[12]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[13]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[14]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[15]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[16]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[17]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[18]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[19]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[20]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[21]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[22]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[23]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[24]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[25]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[26]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[27]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[28]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[29]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[30]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/bgt_word[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 48 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[1]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[2]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[3]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[4]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[5]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[6]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[7]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[8]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[9]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[10]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[11]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[12]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[13]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[14]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[15]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[16]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[17]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[18]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[19]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[20]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[21]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[22]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[23]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[24]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[25]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[26]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[27]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[28]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[29]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[30]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[31]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[32]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[33]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[34]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[35]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[36]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[37]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[38]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[39]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[40]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[41]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[42]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[43]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[44]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[45]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[46]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/adc_output[47]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 32 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[1]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[2]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[3]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[4]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[5]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[6]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[7]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[8]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[9]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[10]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[11]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[12]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[13]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[14]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[15]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[16]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[17]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[18]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[19]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[20]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[21]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[22]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[23]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[24]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[25]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[26]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[27]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[28]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[29]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[30]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master_word[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 32 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[0]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[1]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[2]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[3]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[4]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[5]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[6]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[7]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[8]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[9]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[10]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[11]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[12]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[13]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[14]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[15]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[16]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[17]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[18]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[19]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[20]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[21]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[22]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[23]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[24]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[25]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[26]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[27]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[28]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[29]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[30]} {updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/configure_rom_word[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/CS_N]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/IRQ_r]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/MISO_r]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/MOSI]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/master/out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/burst_reader/out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/rst]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/sample_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/SCLK]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/SRST]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list updated_design_i/BGT_AXI_slave_0/inst/buffer/bgt_driver/valid_word]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_0_FCLK_CLK0]
