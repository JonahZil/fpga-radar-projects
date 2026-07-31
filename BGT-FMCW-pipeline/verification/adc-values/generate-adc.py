# This file calculates the ADC values needed for the testbench based on three signals with the same beat frequency but different phases.
# It computes everything in fixed point format to match the calculations done in the RTL.

import numpy as np
import math
from pathlib import Path
from matplotlib.pyplot import *

N = 256
scale = 4096

script_dir = Path(__file__).resolve().parent
outfile = script_dir / "adc.mem"

frequency = (40.0 * 2 * np.pi)/N
A = 1500

rx0_phase = 0
rx1_phase = np.pi/6
rx2_phase = np.pi/4

def to_unsigned_q12(value):
    value = round(value)
    return max(0, min(scale - 1, value))

with open(outfile, "w", encoding="ascii") as file:

    x = np.arange(N)

    rx0 = scale/2 + A * np.sin(frequency * x + rx0_phase)
    rx1 = scale/2 + A * np.sin(frequency * x + rx1_phase)
    rx2 = scale/2 + A * np.sin(frequency * x + rx2_phase)

    for i in range(N):
        file.write(
            f"{to_unsigned_q12(rx0[i]):03X}\n"
            f"{to_unsigned_q12(rx1[i]):03X}\n"
            f"{to_unsigned_q12(rx2[i]):03X}\n"
        )

azimuth_offset = 846
elevation_offset = -44946
range_m = 40 * 0.0375

PI = round(np.pi * 2**15)

phase_az = round((rx2_phase - rx0_phase) * 2**15) + azimuth_offset
phase_el = round((rx2_phase - rx1_phase) * 2**15) + elevation_offset

def asin_lut(phase):
    neg = phase < 0
    mag = abs(phase)

    lut_address = mag >> 7
    real_address = lut_address << 7

    angle = round(math.asin(real_address / PI) * 2**15)

    if(neg):
        return -angle
    else:
        return angle

alpha_fixed = asin_lut(phase_az)
beta_fixed = asin_lut(phase_el)
range_fixed = round(range_m * 10**6)

print(
    f"Expected alpha: {alpha_fixed}\n"
    f"Expected beta: {beta_fixed}\n"
    f"Expected range: {range_fixed}"
)