import math
import serial
import struct
import time

import matplotlib.pyplot as plt


PORT = "COM3"
BAUD = 921600

FRAME_MARKER = b"NEXT_FRAME\n"

ANGLE_SCALE = float(1 << 15)

MIN_RANGE_M = 0.0
MAX_RANGE_M = 3.0

# If bin 6 is the strongest peak, ignore the frame.
IGNORED_RANGE = 225000

def read_until_line(ser, target):
    while True:
        line = ser.readline().decode(errors="ignore").strip()

        if line == target:
            return

# Read nbytes from the serial terminal
def read_exact(ser, nbytes):
    data = bytearray()

    while len(data) < nbytes:
        chunk = ser.read(nbytes - len(data))
        data.extend(chunk)

    return bytes(data)

# Wait until marker is sent over UART
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

# Output the direction of the angle
def direction_text(angle_deg, positive_direction, negative_direction):
    if angle_deg > 0.0:
        return positive_direction

    if angle_deg < 0.0:
        return negative_direction

    return "center"


def main():
    plt.ion()

    figure = plt.figure(
        figsize=(10, 9),
        constrained_layout=True,
    )

    axis = figure.add_subplot(
        111,
        projection="3d",
    )

    axis.set_xlabel("Left / right (m)")
    axis.set_ylabel("Forward distance (m)")
    axis.set_zlabel("Up / down (m)")

    axis.set_xlim(-MAX_RANGE_M, MAX_RANGE_M)
    axis.set_ylim(MIN_RANGE_M, MAX_RANGE_M)
    axis.set_zlim(-MAX_RANGE_M, MAX_RANGE_M)

    # Preserve the physical scaling
    axis.set_box_aspect((2.0, 1.0, 2.0))

    # Initial camera position
    axis.view_init(
        elev=22,
        azim=-55,
    )

    axis.set_title(
        "FMCW radar 3D target position"
    )

    # Display the radar at the origin
    radar_point, = axis.plot(
        [0.0],
        [0.0],
        [0.0],
        marker="s",
        markersize=8,
        linestyle="None",
        label="Radar",
    )

    target_ray, = axis.plot(
        [0.0, 0.0],
        [0.0, 0.0],
        [0.0, 0.0],
        linewidth=2,
    )

    # Display strongest target
    target_point, = axis.plot(
        [0.0],
        [0.0],
        [0.0],
        marker="o",
        markersize=10,
        linestyle="None",
        label="Target",
    )

    # Forward center line
    axis.plot(
        [0.0, 0.0],
        [MIN_RANGE_M, MAX_RANGE_M],
        [0.0, 0.0],
        linestyle="--",
        linewidth=1,
    )
    # Sideways center line
    axis.plot(
        [-MAX_RANGE_M, MAX_RANGE_M],
        [0.0, 0.0],
        [0.0, 0.0],
        linestyle="--",
        linewidth=1,
    )

    axis.legend()

    figure.suptitle(
        "Range: -- m | Left/right: --° | Up/down: --°"
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
            # Prevents overflow due to graphing overhead
            ser.reset_input_buffer()

            wait_for_marker(ser, FRAME_MARKER)

            packet = read_exact(ser, 12)

            range_raw, alpha_raw, beta_raw = struct.unpack(
                "<Iii",
                packet,
            )

            if range_raw == IGNORED_RANGE:
                continue

            # Convert to meters
            distance_m = range_raw / 1000000

            # Convert to decimal
            horizontal_angle_rad = (beta_raw / ANGLE_SCALE)
            vertical_angle_rad = (alpha_raw / ANGLE_SCALE)

            horizontal_angle_deg = math.degrees(horizontal_angle_rad)
            vertical_angle_deg = math.degrees(vertical_angle_rad)

            horizontal_distance_m = (distance_m * math.cos(vertical_angle_rad))

            # Cartesian coordinates for graph
            x_m = (horizontal_distance_m * math.sin(horizontal_angle_rad))
            y_m = (horizontal_distance_m * math.cos(horizontal_angle_rad))
            z_m = (distance_m * math.sin(vertical_angle_rad))

            target_ray.set_data_3d(
                [0.0, x_m],
                [0.0, y_m],
                [0.0, z_m],
            )

            target_point.set_data_3d(
                [x_m],
                [y_m],
                [z_m],
            )

            horizontal_direction = direction_text(horizontal_angle_deg, "right", "left")
            vertical_direction = direction_text(vertical_angle_deg, "up", "down")

            figure.suptitle(
                f"Range: {distance_m:.3f} m | "
                f"Left/right: {abs(horizontal_angle_deg):.1f}° "
                f"{horizontal_direction} | "
                f"Up/down: {abs(vertical_angle_deg):.1f}° "
                f"{vertical_direction}\n"
                f"Position: "
                f"x={x_m:+.3f} m, "
                f"y={y_m:.3f} m, "
                f"z={z_m:+.3f} m"
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