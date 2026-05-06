A 32 point radix-2 SDF FFT pipeline in Verilog, implemented on the Zybo Z7 Development Board. Meant for testing of the stage modules and memory modules before expanding into a functional FMCW radar FFT pipeline.

A python folder is included to calculate the twiddle factors for each stage, where N is the amount of samples and D is the delay for that specific stage. 

A testbench is included for simulation. Its values can be used to compare to the actual output of the FPGA, measured with the provided ILA and VIO modules. 