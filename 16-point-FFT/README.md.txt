## The first full project for simulated FMCW radar data.

A small 16 point radix-2 real-only data FFT with inverted input. The calculations take roughly 300 clock cycles.

The large amount of clock cycles necessary for computation were intentional as this project was meant as a rough outline for an FFT. It is not optimized and is meant for understanding. The next projects focus on optimization and expansion of input/output size.


## A testbench (tester.v) file is provided to visualize the data for the following wave:

sin(2pix/16) + sin(5pix/16)

Thus the output bins 2 and 5 are high. The output is scaled by 1/16 since each stage halves the output of the butterfly module's computations. The values are represented in signed Q1.15 format.