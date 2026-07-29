import numpy as np
from pathlib import Path

N = 256
scale = 4096

script_dir = Path(__file__).resolve().parent
outfile = script_dir / "hann.mem"

hann = np.hanning(N)

def to_unsigned_q12(x):
    value = round(x * scale)
    return max(0, min(scale - 1, value))

with open(outfile, "w", encoding="ascii") as file:
    for coefficient in hann:
        q12 = to_unsigned_q12(float(coefficient))
        file.write(f"{q12:03X}\n")

print(f"Wrote {N} coefficients")