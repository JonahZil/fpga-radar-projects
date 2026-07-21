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