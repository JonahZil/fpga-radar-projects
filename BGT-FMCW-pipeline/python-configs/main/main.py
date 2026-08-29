import math
import serial
import struct
import time

import matplotlib.pyplot as plt


PORT = "COM3"
BAUD = 921600

FRAME_MARKER = b"NEXT_FRAME\n"

ANGLE_SCALE = float(1 << 15)

MAX_RANGE_M = 3.0
IGNORED_RANGE = 225000


def read_until_line(ser, target):
    while True:
        line = ser.readline().decode(errors="ignore").strip()

        if line == target:
            return


def read_exact(ser, nbytes):
    data = bytearray()

    while len(data) < nbytes:
        chunk = ser.read(nbytes - len(data))
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


def direction_text(angle_deg):
    if angle_deg > 0.0:
        return "right"

    if angle_deg < 0.0:
        return "left"

    return "center"


def main():
    plt.ion()

    figure = plt.figure(figsize=(8, 8), constrained_layout=True)
    axis = figure.add_subplot(111, projection="polar")

    axis.set_theta_zero_location("N")
    axis.set_theta_direction(-1)
    axis.set_thetamin(-90)
    axis.set_thetamax(90)
    axis.set_ylim(0.0, MAX_RANGE_M)

    axis.set_title("FMCW radar top-down target position")

    radar_point, = axis.plot(
        [0.0],
        [0.0],
        marker="s",
        markersize=8,
        linestyle="None",
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

    figure.suptitle("Range: -- m | Left/right: --°")

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

            packet = read_exact(ser, 12)

            range_raw, _, beta_raw = struct.unpack(
                "<Iii",
                packet,
            )

            if range_raw == IGNORED_RANGE:
                continue

            distance_m = range_raw / 1000000
            beta_rad = beta_raw / ANGLE_SCALE
            beta_deg = math.degrees(beta_rad)

            direction = direction_text(beta_deg)

            target_ray.set_data(
                [0.0, beta_rad],
                [0.0, distance_m],
            )

            target_point.set_data(
                [beta_rad],
                [distance_m],
            )

            figure.suptitle(
                f"Range: {distance_m:.3f} m | "
                f"Left/right: {abs(beta_deg):.1f}° {direction}"
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