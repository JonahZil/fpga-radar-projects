# This file computes the cordic angles needed for the CORDIC algorithm which calculated the four quadrant inverse tangent, used in phase calculation.
# All angles are in signed Q3.15 format.

import numpy as np
from pathlib import Path

iterations = 16
scale = 2**15

script_dir = Path(__file__).resolve().parent
outfile = script_dir / "cordic_angles.mem"

def to_18bit_hex(x): 
    if(x < 0):
        x = (1 << 18) + x

    x = x & ((1 << 18) - 1)
    return f"{x:05X}"

with open(outfile, "w", encoding="ascii") as file:
    for i in range(iterations):
        dec_angle = int(round(np.atan(2**(-i)) * scale))
        file.write(f"{to_18bit_hex(dec_angle)}\n")

print(f"Wrote {iterations} angles")