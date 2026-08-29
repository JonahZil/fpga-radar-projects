import numpy as np

filename = "python-files/main/data/two-reflector/ab_t150us_50_150.npy"

raw = np.load(filename)

RX_INDEX = 0
FLAT_PTP_THRESHOLD = 2

x = raw[:, :, RX_INDEX]

# A frame is invalid if it is constant or nearly constant.
frame_ptp = np.ptp(x, axis=1)
invalid = frame_ptp <= FLAT_PTP_THRESHOLD

invalid_frames = x[invalid]

num_invalid = len(invalid_frames)
num_total = len(x)

print("=" * 60)
print(f"INVALID FRAME SUMMARY - RX{RX_INDEX}")
print("=" * 60)

print(
    f"Invalid frames: {num_invalid} / {num_total} "
    f"({100 * num_invalid / num_total:.2f}%)"
)

if num_invalid == 0:
    print("No invalid frames found.")
else:
    # Perfectly constant vs nearly-flat
    constant = np.ptp(invalid_frames, axis=1) == 0
    num_constant = np.sum(constant)
    num_nearly_flat = num_invalid - num_constant

    print(
        f"Perfectly constant: {num_constant} / {num_invalid} "
        f"({100 * num_constant / num_invalid:.2f}%)"
    )

    print(
        f"Nearly flat:        {num_nearly_flat} / {num_invalid} "
        f"({100 * num_nearly_flat / num_invalid:.2f}%)"
    )

    # Find the most common value in each invalid frame.
    dominant_values = []

    for frame in invalid_frames:
        values, counts = np.unique(frame, return_counts=True)
        dominant_values.append(values[np.argmax(counts)])

    dominant_values = np.array(dominant_values)

    values, counts = np.unique(
        dominant_values,
        return_counts=True
    )

    print()
    print("Dominant values among invalid frames:")
    print("Value | Frames | % of invalid")
    print("-" * 32)

    order = np.argsort(counts)[::-1]

    for i in order:
        value = int(values[i])
        count = int(counts[i])
        percentage = 100 * count / num_invalid

        print(
            f"{value:5d} | "
            f"{count:6d} | "
            f"{percentage:10.2f}%"
        )