# This file generates the twiddle factors for a specific stage of the FFT.

import math
from pathlib import Path

N = 4096
scale = 32767

script_dir = Path(__file__).resolve().parent
D = 2
outfile = script_dir / "tw_s11.mem"

stride = N // (D * 2)

def to_signed_hex(x):
    if x < 0:
        x = (1 << 16) + x
    return x & 0xFFFF

with open(outfile, "w") as file:
    for i in range(D):
        k = i * stride
        angle = -2 * math.pi * k/N 

        re = round(math.cos(angle) * scale)
        im = round(math.sin(angle) * scale)

        re_hex = to_signed_hex(re)
        im_hex = to_signed_hex(im)

        file.write(f"{re_hex:04X}{im_hex:04X}\n")
    
print(f"Wrote {outfile}")