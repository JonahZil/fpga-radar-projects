import serial
import struct
import time
import numpy as np
import matplotlib.pyplot as plt

PORT = "COM3"
BAUD = 115200

N = 4096
FFT_SCALE = 1 / 16

CSV_FILE = "fpga_input_samples.csv"

#Radar parameters
speed_of_light = 3e8

freq_start = 77e9
freq_end = 81e9
time_chirp = 20e-6

chirp_coeff = (freq_end - freq_start) / time_chirp
ADC_sampling_Freq = 2e8

# Plot display limits
DB_FLOOR = -10
DB_CEILING = 130


#Read samples from CSV file
inputs = np.loadtxt(CSV_FILE, delimiter=",", dtype=np.int32)
inputs = inputs.flatten()

if len(inputs) != N:
    raise ValueError(f"Expected {N} samples, but CSV contains {len(inputs)} samples")

inputs = np.clip(inputs, -32768, 32767).astype(np.int16)

#Read text lines from the PS until it equals a target marker
def read_until_line(ser, target):
    while True:
        line = ser.readline().decode(errors="ignore").strip()
        if line:
            print("PS:", line)

        if line == target:
            return


#Read nbytes from UART
def read_exact(ser, nbytes):
    data = bytearray()

    while len(data) < nbytes:
        chunk = ser.read(nbytes - len(data))
        data.extend(chunk)

    return bytes(data)


#Return bit-reversed indices for length n
def bit_reverse_indices(n):
    bits = int(np.log2(n))
    rev = np.zeros(n, dtype=int)

    for i in range(n):
        b = f"{i:0{bits}b}"
        rev[i] = int(b[::-1], 2)

    return rev


with serial.Serial(PORT, BAUD, timeout=5) as ser:
    time.sleep(0.5)

    ser.reset_input_buffer()
    ser.reset_output_buffer()

    #Tell the PS to begin the transaction
    ser.write(b"S")

    read_until_line(ser, "READY")

    #Send 4096 signed int16 samples
    tx_packet = b"".join(struct.pack("<h", int(x)) for x in inputs)
    ser.write(tx_packet)

    #Wait until PS says binary FFT results are coming next
    read_until_line(ser, "RESULTS")

    #Receive 4096 complex FFT outputs
    rx_packet = read_exact(ser, N * 8)

    fpga_fft_bit_reversed = np.zeros(N, dtype=np.complex64)

    for i in range(N):
        real, imag = struct.unpack_from("<ii", rx_packet, offset=8 * i)
        fpga_fft_bit_reversed[i] = real + 1j * imag

    done_line = ser.readline().decode(errors="ignore").strip()
    if done_line:
        print("PS:", done_line)


#Convert bit reversed bin order into natural order
rev = bit_reverse_indices(N)
fpga_fft = np.zeros_like(fpga_fft_bit_reversed)
fpga_fft[rev] = fpga_fft_bit_reversed


#NumPy FFT reference using the same samples sent to the FPGA
computer_fft = np.fft.fft(inputs.astype(np.float32))
computer_fft_scaled = computer_fft * FFT_SCALE

#Convert FFT bin index to distance, same as Octave
FFT_freq = ADC_sampling_Freq * (1 / N) * np.arange(N)
Freq_to_dist = (0.5 * speed_of_light / chirp_coeff) * FFT_freq

#Convert magnitude to dB
EPS = 1e-12
fpga_mag_db = 20 * np.log10(np.abs(fpga_fft) + EPS)
computer_mag_db = 20 * np.log10(np.abs(computer_fft_scaled) + EPS)

#Clip display range so zero/near-zero bins do not appear as spikes
fpga_mag_db = np.clip(fpga_mag_db, DB_FLOOR, DB_CEILING)
computer_mag_db = np.clip(computer_mag_db, DB_FLOOR, DB_CEILING)

#FPGA result only
plt.figure(figsize=(12, 6))
plt.plot(
    Freq_to_dist[1:],
    fpga_mag_db[1:],
    linewidth=2.5,
    label="FPGA"
)
plt.title("Radar Spectrum vs Distance", fontsize=16, fontweight="bold")
plt.xlabel("Distance (m)", fontsize=14)
plt.ylabel("Magnitude (dB)", fontsize=14)
plt.grid(True, which="both")
plt.minorticks_on()
plt.xlim(1, 50)
plt.ylim(DB_FLOOR, DB_CEILING)
plt.legend()
plt.tight_layout()


#Computer result only
plt.figure(figsize=(12, 6))
plt.plot(
    Freq_to_dist[1:],
    computer_mag_db[1:],
    linewidth=2.5,
    label="Computer FFT"
)

plt.title("Computer Reference Radar Spectrum vs Distance", fontsize=16, fontweight="bold")
plt.xlabel("Distance (m)", fontsize=14)
plt.ylabel("Magnitude (dB)", fontsize=14)
plt.grid(True, which="both")
plt.minorticks_on()
plt.xlim(1, 50)
plt.ylim(DB_FLOOR, DB_CEILING)
plt.legend()
plt.tight_layout()

#Plot both
plt.figure(figsize=(12, 6))
plt.plot(
    Freq_to_dist[1:],
    fpga_mag_db[1:],
    linewidth=2.5,
    label="FPGA"
)

plt.plot(
    Freq_to_dist[1:],
    computer_mag_db[1:],
    linewidth=2.5,
    label="Computer FFT"
)

plt.title("FPGA FFT vs Computer FFT", fontsize=16, fontweight="bold")
plt.xlabel("Distance (m)", fontsize=14)
plt.ylabel("Magnitude (dB)", fontsize=14)
plt.grid(True, which="both")
plt.minorticks_on()
plt.xlim(1, 50)
plt.ylim(DB_FLOOR, DB_CEILING)
plt.legend()
plt.tight_layout()

plt.show()