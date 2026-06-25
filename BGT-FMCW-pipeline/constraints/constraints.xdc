set_property PACKAGE_PIN L16 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 8.000 -name sys_clk [get_ports clk]


set_property PACKAGE_PIN P16 [get_ports start]
set_property IOSTANDARD LVCMOS33 [get_ports start]
set_property PULLTYPE PULLDOWN [get_ports start]

set_property PACKAGE_PIN R18 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property PULLTYPE PULLDOWN [get_ports rst]


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
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {master/out_data[0]} {master/out_data[1]} {master/out_data[2]} {master/out_data[3]} {master/out_data[4]} {master/out_data[5]} {master/out_data[6]} {master/out_data[7]} {master/out_data[8]} {master/out_data[9]} {master/out_data[10]} {master/out_data[11]} {master/out_data[12]} {master/out_data[13]} {master/out_data[14]} {master/out_data[15]} {master/out_data[16]} {master/out_data[17]} {master/out_data[18]} {master/out_data[19]} {master/out_data[20]} {master/out_data[21]} {master/out_data[22]} {master/out_data[23]} {master/out_data[24]} {master/out_data[25]} {master/out_data[26]} {master/out_data[27]} {master/out_data[28]} {master/out_data[29]} {master/out_data[30]} {master/out_data[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {bgt_word[0]} {bgt_word[1]} {bgt_word[2]} {bgt_word[3]} {bgt_word[4]} {bgt_word[5]} {bgt_word[6]} {bgt_word[7]} {bgt_word[8]} {bgt_word[9]} {bgt_word[10]} {bgt_word[11]} {bgt_word[12]} {bgt_word[13]} {bgt_word[14]} {bgt_word[15]} {bgt_word[16]} {bgt_word[17]} {bgt_word[18]} {bgt_word[19]} {bgt_word[20]} {bgt_word[21]} {bgt_word[22]} {bgt_word[23]} {bgt_word[24]} {bgt_word[25]} {bgt_word[26]} {bgt_word[27]} {bgt_word[28]} {bgt_word[29]} {bgt_word[30]} {bgt_word[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list CS_N_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list IRQ_r]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list MISO_r]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list MOSI_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list master/out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list p_0_in]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list rst_IBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list SCLK_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list SRST_OBUF]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_IBUF_BUFG]
