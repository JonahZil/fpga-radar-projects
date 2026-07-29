import math
import serial
import struct
import time

import matplotlib.pyplot as plt


PORT = "COM3"
BAUD = 921600

FRAME_MARKER = b"NEXT_FRAME\n"
PACKET_SIZE = 12

# FPGA range output is in micrometres.
RANGE_UNITS_PER_METER = 1_000_000.0

# FPGA alpha and beta outputs are Q15 radians.
ANGLE_SCALE = float(1 << 15)

# After rotating the radar 90 degrees around its viewing axis,
# beta represents physical left/right motion.
#
# Change this to -1.0 if left and right appear reversed.
HORIZONTAL_SIGN = 1.0

MIN_RANGE_M = 0.0
MAX_RANGE_M = 3.0

IGNORED_RANGES_RAW = {
    225_000,    # Bin 6 / lower search boundary
    1_650_000, 
    1_688_000 # Ignore 1.65 m detection
}


def read_until_line(ser, target):
    while True:
        line = ser.readline().decode(errors="ignore").strip()

        if line == target:
            return


def read_exact(ser, nbytes):
    data = bytearray()

    while len(data) < nbytes:
        chunk = ser.read(nbytes - len(data))

        if not chunk:
            raise ConnectionError("Serial connection closed")

        data.extend(chunk)

    return bytes(data)


def wait_for_marker(ser, marker):
    matched = 0

    while matched < len(marker):
        byte = ser.read(1)

        if not byte:
            raise ConnectionError("Serial connection closed")

        if byte == marker[matched:matched + 1]:
            matched += 1
        elif byte == marker[0:1]:
            matched = 1
        else:
            matched = 0


def main():
    plt.ion()

    figure = plt.figure(
        figsize=(8, 8),
        constrained_layout=True,
    )

    axis = figure.add_subplot(
        111,
        projection="polar",
    )

    # Zero degrees points directly away from the radar.
    axis.set_theta_zero_location("N")

    # Positive angles are displayed to the right.
    axis.set_theta_direction(-1)

    axis.set_ylim(MIN_RANGE_M, MAX_RANGE_M)

    axis.set_rticks([
        0.5,
        1.0,
        1.5,
        2.0,
        2.5,
        3.0,
    ])

    axis.set_rlabel_position(135)

    # Only show the forward-facing half-plane.
    axis.set_thetamin(-90)
    axis.set_thetamax(90)

    axis.set_title(
        "FMCW radar range and left/right angle"
    )

    target_ray, = axis.plot(
        [0.0, 0.0],
        [0.0, 0.0],
        linewidth=2,
    )

    target_point, = axis.plot(
        [0.0],
        [0.0],
        marker="o",
        markersize=10,
        linestyle="None",
    )

    figure.suptitle(
        "Range: -- m | Left/right angle: --°"
    )

    plt.show(block=False)

    with serial.Serial(PORT, BAUD, timeout=None) as ser:
        time.sleep(0.5)

        ser.reset_input_buffer()
        ser.reset_output_buffer()

        ser.write(b"S")
        ser.flush()

        read_until_line(ser, "READY")

        while plt.fignum_exists(figure.number):
            ser.reset_input_buffer()
            wait_for_marker(ser, FRAME_MARKER)

            packet = read_exact(ser, PACKET_SIZE)

            # Packet format:
            #   range: unsigned 32-bit integer
            #   alpha: signed 32-bit Q15 radians
            #   beta:  signed 32-bit Q15 radians
            range_raw, alpha_raw, beta_raw = struct.unpack(
                "<Iii",
                packet,
            )

            if range_raw in IGNORED_RANGES_RAW:
                continue

            distance_m = (
                range_raw
                / RANGE_UNITS_PER_METER
            )

            if not math.isfinite(distance_m):
                continue

            if not MIN_RANGE_M <= distance_m <= MAX_RANGE_M:
                continue

            # Because the radar has been rotated 90 degrees,
            # use beta for physical left/right position.
            horizontal_angle_rad = (
                HORIZONTAL_SIGN
                * beta_raw
                / ANGLE_SCALE
            )

            if not math.isfinite(horizontal_angle_rad):
                continue

            horizontal_angle_deg = math.degrees(
                horizontal_angle_rad
            )

            target_ray.set_data(
                [0.0, horizontal_angle_rad],
                [0.0, distance_m],
            )

            target_point.set_data(
                [horizontal_angle_rad],
                [distance_m],
            )

            if horizontal_angle_deg > 0.0:
                direction = "right"
            elif horizontal_angle_deg < 0.0:
                direction = "left"
            else:
                direction = "center"

            figure.suptitle(
                f"Range: {distance_m:.3f} m | "
                f"Angle: {abs(horizontal_angle_deg):.1f}° "
                f"{direction}"
            )

            figure.canvas.draw_idle()
            figure.canvas.flush_events()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (serial.SerialException, ConnectionError):
        pass