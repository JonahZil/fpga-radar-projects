import serial
import struct
import time
import numpy as np
import matplotlib.pyplot as plt

PORT = "COM3"
BAUD = 115200

N = 64
APPLY_BIT_REVERSE = True

# Radar parameters from BGT register configuration
speed_of_light = 3e8

freq_start = 58.1e9
freq_end = 63.1e9
time_chirp = 50e-6

chirp_coeff = (freq_end - freq_start) / time_chirp
ADC_sampling_Freq = 2e6

DB_FLOOR = -10
DB_CEILING = 130
PLOT_MAX_DISTANCE = 1.5


def read_until_line(ser, target):
    while True:
        line = ser.readline().decode(errors="ignore").strip()

        if line:
            print("PS:", line)

        if line == target:
            return


def read_exact(ser, nbytes):
    data = bytearray()

    while len(data) < nbytes:
        chunk = ser.read(nbytes - len(data))

        if not chunk:
            raise TimeoutError(
                f"Timed out after receiving {len(data)} of {nbytes} bytes"
            )

        data.extend(chunk)

    return bytes(data)


def bit_reverse_indices(n):
    bits = int(np.log2(n))

    if 2 ** bits != n:
        raise ValueError("N must be a power of two for bit reversal")

    rev = np.zeros(n, dtype=int)

    for i in range(n):
        b = f"{i:0{bits}b}"
        rev[i] = int(b[::-1], 2)

    return rev


def next_lfsr_word(w):
    return ((w >> 1) |
            (((w << 11) ^ (w << 10) ^ (w << 9) ^ (w << 3)) & 0x0800)) & 0x0FFF


def generate_lfsr_samples(n):
    w = 0x0001
    samples = []

    for _ in range(n):
        samples.append(w)
        w = next_lfsr_word(w)

    return np.array(samples, dtype=np.int32)


# ------------------------------------------------------------
# Read FPGA FFT output over UART
# ------------------------------------------------------------

with serial.Serial(PORT, BAUD, timeout=5) as ser:
    time.sleep(0.5)

    ser.reset_input_buffer()
    ser.reset_output_buffer()

    ser.write(b"S")

    read_until_line(ser, "READY")
    read_until_line(ser, "RESULTS")

    rx_packet = read_exact(ser, N * 8)

    fpga_fft_received = np.zeros(N, dtype=np.complex64)

    for i in range(N):
        real, imag = struct.unpack_from("<ii", rx_packet, offset=8 * i)
        fpga_fft_received[i] = real + 1j * imag

    done_line = ser.readline().decode(errors="ignore").strip()
    if done_line:
        print("PS:", done_line)


# ------------------------------------------------------------
# Fix FPGA FFT output ordering if needed
# ------------------------------------------------------------

if APPLY_BIT_REVERSE:
    rev = bit_reverse_indices(N)
    fpga_fft = np.zeros_like(fpga_fft_received)
    fpga_fft[rev] = fpga_fft_received
else:
    fpga_fft = fpga_fft_received


# ------------------------------------------------------------
# Generate expected LFSR samples and expected FFT
# ------------------------------------------------------------

lfsr_raw = generate_lfsr_samples(N)

# Match your Verilog preprocessing:
# 12-bit sample -> subtract DC offset 2048
lfsr_input = (lfsr_raw.astype(np.int32) - 2048) << 4

# Match your FPGA FFT:
# last stage is scaled, so final output is divided by 2
expected_fft = np.fft.fft(lfsr_input) / 2

# ------------------------------------------------------------
# Convert FFT magnitude to dB
# ------------------------------------------------------------

FFT_freq = ADC_sampling_Freq * np.arange(N) / N
Freq_to_dist = (0.5 * speed_of_light / chirp_coeff) * FFT_freq

EPS = 1e-12

fpga_mag_db = 20 * np.log10(np.abs(fpga_fft) + EPS)
fpga_mag_db = np.clip(fpga_mag_db, DB_FLOOR, DB_CEILING)

expected_mag_db = 20 * np.log10(np.abs(expected_fft) + EPS)
expected_mag_db = np.clip(expected_mag_db, DB_FLOOR, DB_CEILING)


# ------------------------------------------------------------
# Plot both FFTs
# ------------------------------------------------------------

plot_bins = np.arange(1, N // 2)

plt.figure(figsize=(12, 6))

plt.plot(
    Freq_to_dist[plot_bins],
    fpga_mag_db[plot_bins],
    linewidth=2.5,
    label="FPGA FFT"
)

plt.plot(
    Freq_to_dist[plot_bins],
    expected_mag_db[plot_bins],
    linewidth=2.0,
    linestyle="--",
    label="Expected NumPy FFT"
)

plt.title("LFSR FFT Comparison", fontsize=16, fontweight="bold")
plt.xlabel("Distance-equivalent bin axis (m)", fontsize=14)
plt.ylabel("Magnitude (dB)", fontsize=14)
plt.grid(True, which="both")
plt.minorticks_on()
plt.xlim(0, PLOT_MAX_DISTANCE)
plt.ylim(DB_FLOOR, DB_CEILING)
plt.legend()
plt.tight_layout()
plt.show()