import math
from pathlib import Path

scale = 2**15

script_dir = Path(__file__).resolve().parent
outfile = script_dir / "asin_lut.mem"

drop_bits = 7

pi_code = 102944
max_valid_address = pi_code >> drop_bits
entries = max_valid_address + 1

def to_18bit_hex(x): 
    if(x < 0):
        x = (1 << 18) + x

    x = x & ((1 << 18) - 1)
    return f"{x:05X}"

with open(outfile, "w", encoding="ascii") as file:
    for i in range(entries):
        angle = math.asin(i * (2**drop_bits) / pi_code)
        dec = round(angle * scale)
        file.write(f"{to_18bit_hex(dec)}\n")

        
print(f"Wrote {entries} values")