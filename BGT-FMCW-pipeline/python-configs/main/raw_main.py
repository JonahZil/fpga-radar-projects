import serial
import time
import threading
import queue
import numpy as np
import matplotlib.pyplot as plt

PORT = "COM3"
BAUD = 921600

N = 64
FRAME_MARKER = b"NEXT_FRAME\n"
APPLY_BIT_REVERSE = True

# Radar parameters
speed_of_light = 3e8

freq_start = 58.1e9
freq_end = 63.1e9
time_chirp = 50e-6

chirp_coeff = (freq_end - freq_start) / time_chirp
ADC_sampling_freq = 2e6

DB_FLOOR = -10
DB_CEILING = 130
PLOT_MAX_DISTANCE = 1.5

SIGNED_24_MIN = -(1 << 23)
SIGNED_24_MAX = (1 << 23) - 1

# Only retain the newest received frame.
frame_queue = queue.Queue(maxsize=1)

receiver_running = True


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

        if chunk:
            data.extend(chunk)

    return bytes(data)


def wait_for_marker(ser, marker):
    matched = 0

    while matched < len(marker):
        byte = ser.read(1)

        if byte == marker[matched:matched + 1]:
            matched += 1
        elif byte == marker[0:1]:
            matched = 1
        else:
            matched = 0


def bit_reverse_indices(n):
    bits = int(np.log2(n))
    reversed_indices = np.zeros(n, dtype=int)

    for i in range(n):
        reversed_indices[i] = int(
            f"{i:0{bits}b}"[::-1],
            2
        )

    return reversed_indices


def receiver_thread(ser):
    global receiver_running

    frame_number = 0
    previous_frame_time = None

    while receiver_running:
        wait_for_marker(ser, FRAME_MARKER)

        rx_packet = read_exact(ser, N * 8)

        current_frame_time = time.perf_counter()
        frame_number += 1

        values = np.frombuffer(
            rx_packet,
            dtype="<i4"
        ).reshape(N, 2).copy()

        invalid_mask = (
            (values < SIGNED_24_MIN)
            | (values > SIGNED_24_MAX)
        )

        invalid_24bit = bool(np.any(invalid_mask))

        if previous_frame_time is None:
            pass
        else:
            frame_interval_ms = (
                current_frame_time -
                previous_frame_time
            ) * 1000.0

        previous_frame_time = current_frame_time

        if invalid_24bit:
            invalid_count = int(
                np.count_nonzero(invalid_mask)
            )

            continue

        # Discard an older unplotted frame if necessary.
        try:
            frame_queue.get_nowait()
        except queue.Empty:
            pass

        try:
            frame_queue.put_nowait(
                (frame_number, values)
            )
        except queue.Full:
            pass


# Distance axis
fft_freq = ADC_sampling_freq * np.arange(N) / N

distance = (
    0.5
    * speed_of_light
    * fft_freq
    / chirp_coeff
)

plot_bins = np.arange(1, N // 2)

if APPLY_BIT_REVERSE:
    bit_reverse = bit_reverse_indices(N)


# Plot setup
plt.ion()

fig, ax = plt.subplots(figsize=(12, 6))

line, = ax.plot(
    distance[plot_bins],
    np.full(len(plot_bins), DB_FLOOR),
    linewidth=2.5
)

ax.set_title("FPGA FFT")
ax.set_xlabel("Distance-equivalent bin axis (m)")
ax.set_ylabel("Magnitude (dB)")
ax.set_xlim(0, PLOT_MAX_DISTANCE)
ax.set_ylim(DB_FLOOR, DB_CEILING)
ax.grid(True)
ax.minorticks_on()

fig.tight_layout()
plt.show(block=False)


with serial.Serial(PORT, BAUD, timeout=None) as ser:
    time.sleep(0.5)

    ser.reset_input_buffer()
    ser.reset_output_buffer()

    ser.write(b"S")

    read_until_line(ser, "READY")

    receiver = threading.Thread(
        target=receiver_thread,
        args=(ser,),
        daemon=True
    )

    receiver.start()

    try:
        while plt.fignum_exists(fig.number):
            newest_frame = None

            # Consume all queued entries and use only the newest.
            while True:
                try:
                    newest_frame = frame_queue.get_nowait()
                except queue.Empty:
                    break

            if newest_frame is not None:
                frame_number, values = newest_frame

                real = values[:, 0]
                imag = values[:, 1]

                fpga_fft_received = (
                    real.astype(np.float64)
                    + 1j * imag.astype(np.float64)
                )

                if APPLY_BIT_REVERSE:
                    fpga_fft = np.zeros_like(
                        fpga_fft_received
                    )

                    fpga_fft[bit_reverse] = (
                        fpga_fft_received
                    )
                else:
                    fpga_fft = fpga_fft_received

                magnitude_db = 20.0 * np.log10(
                    np.abs(fpga_fft) + 1e-12
                )

                magnitude_db = np.clip(
                    magnitude_db,
                    DB_FLOOR,
                    DB_CEILING
                )

                line.set_ydata(
                    magnitude_db[plot_bins]
                )

                ax.set_title(
                    f"FPGA FFT"
                )

                fig.canvas.draw_idle()

            # Service GUI events without stopping serial reception.
            plt.pause(0.001)

    finally:
        receiver_running = False