import serial
import struct
import time
import numpy as np
import matplotlib.pyplot as plt

PORT = "COM3"       
BAUD = 115200
N = 32
FFT_SCALE = 1 / N

n = np.arange(N)

components = [
    (9000,  3, "cos"),
    (7000,  6, "sin"),
    (5000, 11, "cos"),
]

signal = np.zeros(N)

# Generate the samples from the signal
for amplitude, k, kind in components:
    if kind == "cos":
        signal += amplitude * np.cos(2 * np.pi * k * n / N)
    elif kind == "sin":
        signal += amplitude * np.sin(2 * np.pi * k * n / N)
signal = np.clip(signal, -32768, 32767)
inputs = np.round(signal).astype(np.int16)

# Read text lines from the PS until it equals a target marker
def read_until_line(ser, target):
    while True:
        line = ser.readline().decode(errors="ignore").strip()
        if line == target:
            return

# Read nbytes from UART
def read_exact(ser, nbytes):
    data = bytearray()

    while len(data) < nbytes:
        chunk = ser.read(nbytes - len(data))
        data.extend(chunk)

    return bytes(data)

# Return bit reversed indices for length n
def bit_reverse_indices(n):
    bits = int(np.log2(n))
    rev = np.zeros(n, dtype=int)

    for i in range(n):
        b = f"{i:0{bits}b}"
        rev[i] = int(b[::-1], 2)

    return rev

with serial.Serial(PORT, BAUD, timeout=2) as ser:
    time.sleep(0.5)

    # Clear old bytes from previous runs
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    # Tell the PS to begin the transaction
    ser.write(b"S")

    read_until_line(ser, "READY")

    # Send 32 signed int16 samples in little endian order
    tx_packet = b"".join(struct.pack("<h", int(x)) for x in inputs)
    ser.write(tx_packet)

    # Wait until PS says binary FFT results are coming next
    read_until_line(ser, "RESULTS")

    # Receive 32 complex FFT outputs, each bin = int16 real + int16 imag
    rx_packet = read_exact(ser, N * 4)

    fpga_fft_bit_reversed = np.zeros(N, dtype=np.complex64)
    for i in range(N):
        real, imag = struct.unpack_from("<hh", rx_packet, offset=4 * i)
        fpga_fft_bit_reversed[i] = real + 1j * imag

    done_line = ser.readline().decode(errors="ignore").strip()
    if done_line:
        print("PS:", done_line)


# Converts the bit reversed bin order into natural order
rev = bit_reverse_indices(N)
fpga_fft = np.zeros_like(fpga_fft_bit_reversed)
fpga_fft[rev] = fpga_fft_bit_reversed

computer_fft = np.fft.fft(inputs.astype(np.float32))
# Scale the computer FFT
computer_fft_scaled = computer_fft * FFT_SCALE

bins = np.arange(N)

plt.figure()
plt.stem(bins, np.abs(fpga_fft), basefmt=" ")
plt.title("FPGA FFT Magnitude")
plt.xlabel("Bin")
plt.ylabel("Magnitude")
plt.grid(True)

plt.figure()
plt.stem(bins, np.abs(computer_fft_scaled), basefmt=" ")
plt.title("Computer FFT Magnitude")
plt.xlabel("Bin")
plt.ylabel("Magnitude")
plt.grid(True)

plt.figure()
plt.plot(bins, np.abs(fpga_fft), marker="o", label="FPGA")
plt.plot(bins, np.abs(computer_fft_scaled), marker="x", label="Computer FFT / 32")
plt.title("FPGA FFT vs Computer FFT")
plt.xlabel("Bin")
plt.ylabel("Magnitude")
plt.grid(True)
plt.legend()

plt.show()