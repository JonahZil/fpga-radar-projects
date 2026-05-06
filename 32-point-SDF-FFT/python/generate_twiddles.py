import math

N = 32
D = 2
scale = 32767
outfile = "fft_python/tw_s4.mem"

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