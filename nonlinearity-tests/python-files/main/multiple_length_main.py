import serial
import time
import numpy as np

PORT = "COM3"
BAUD = 921600

N = 128
RX_COUNT = 3

IGNORE_FRAMES = 500
NUM_CHIRPS = 1000

CHIRP_LENGTHS = [
    100, 110, 120, 130, 140,
    150, 160, 170, 180, 190,
    200, 210, 220, 230, 240
]

FRAME_SAMPLES = N * RX_COUNT
FRAME_BYTES = FRAME_SAMPLES * 2

FRAME_MARKER = b"NEXT_FRAME\n"

OUTPUT_FILE_TEMPLATE = "python-files/main/data/two-reflector/b_t{}us_120.npy"

def read_until_line(ser, target):
    while True:
        line = ser.readline().decode(
            errors="ignore"
        ).strip()

        if line:
            print("PS:", line)

        if line == target:
            return


def read_exact(ser, nbytes):
    data = bytearray()

    while len(data) < nbytes:
        chunk = ser.read(
            nbytes - len(data)
        )

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


with serial.Serial(
    PORT,
    BAUD,
    timeout=None
) as ser:

    time.sleep(0.5)

    ser.reset_input_buffer()
    ser.reset_output_buffer()

    ser.write(b"S")

    read_until_line(
        ser,
        "READY"
    )

    total_start_time = time.perf_counter()

    for chirp_index, chirp_length in enumerate(CHIRP_LENGTHS):

        print()
        print(
            f"Chirp configuration "
            f"{chirp_index + 1}/{len(CHIRP_LENGTHS)}: "
            f"{chirp_length} us"
        )

        raw_frames = np.empty(
            (NUM_CHIRPS, N, RX_COUNT),
            dtype=np.uint16
        )

        print(
            f"Ignoring first {IGNORE_FRAMES} frames..."
        )

        for frame_number in range(IGNORE_FRAMES):

            wait_for_marker(
                ser,
                FRAME_MARKER
            )

            read_exact(
                ser,
                FRAME_BYTES
            )

            if (
                frame_number == 0
                or (frame_number + 1) % 100 == 0
            ):
                print(
                    f"Ignored {frame_number + 1}/"
                    f"{IGNORE_FRAMES} frames"
                )

        print("Initial frames discarded.")
        print()

        print(
            f"Collecting {NUM_CHIRPS} chirps "
            f"from all {RX_COUNT} receivers..."
        )

        start_time = time.perf_counter()
        previous_time = None

        for frame_number in range(NUM_CHIRPS):

            wait_for_marker(
                ser,
                FRAME_MARKER
            )

            packet = read_exact(
                ser,
                FRAME_BYTES
            )

            current_time = time.perf_counter()

            samples = np.frombuffer(
                packet,
                dtype="<u2"
            )

            samples = samples & 0x0FFF

            samples = samples.reshape(
                N,
                RX_COUNT
            )

            raw_frames[
                frame_number,
                :,
                :
            ] = samples

            if (
                frame_number == 0
                or (frame_number + 1) % 100 == 0
            ):

                if previous_time is not None:
                    dt_ms = (
                        current_time
                        - previous_time
                    ) * 1000.0

                    print(
                        f"{frame_number + 1}/"
                        f"{NUM_CHIRPS} "
                        f"chirps collected "
                        f"(latest dt={dt_ms:.2f} ms)"
                    )

                else:
                    print(
                        f"{frame_number + 1}/"
                        f"{NUM_CHIRPS} "
                        f"chirps collected"
                    )

            previous_time = current_time

        elapsed = (
            time.perf_counter()
            - start_time
        )

        output_file = OUTPUT_FILE_TEMPLATE.format(
            chirp_length
        )

        np.save(
            output_file,
            raw_frames
        )

        print()
        print(
            f"Collected {NUM_CHIRPS} chirps "
            f"for {chirp_length} us "
            f"in {elapsed:.2f} seconds."
        )

        print(
            f"Saved raw data to: {output_file}"
        )

    total_elapsed = (
        time.perf_counter()
        - total_start_time
    )

print()
print(
    f"All {len(CHIRP_LENGTHS)} chirp configurations completed "
    f"in {total_elapsed:.2f} seconds."
)