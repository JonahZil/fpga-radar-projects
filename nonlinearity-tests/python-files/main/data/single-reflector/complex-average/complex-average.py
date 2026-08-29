from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

DATA_DIR = Path("python-files/main/data/two-reflector")
CHIRP_TIMES_US = np.arange(100, 241, 10)
REFLECTOR_CM = 50

FILE_PATTERN = "ab_t{chirp_us}us_{distance_cm}_150.npy"
EMPTY_DISTANCE_CM = 0

RX_INDEX = 0
NUM_FRAMES = 1000

N = 128
FFT_LEN = 8192
ADC_FS = 2e6

C = 3e8
FREQ_START = 58.1e9
FREQ_END = 63.1e9
BANDWIDTH = FREQ_END - FREQ_START

TARGET_SEARCH_HALF_WIDTH_M = 0.25

MIN_RANGE_M = 0.15
MAX_RANGE_M = 3.0

TARGET_EXCLUSION_HALF_WIDTH_M = 0.20
GHOST_SEARCH_HALF_WIDTH_M = 0.10

COMMON_RANGE_STEP_M = 0.001

EPS = 1e-15

hann_window = np.hanning(N)

fft_freq = np.fft.rfftfreq(
    FFT_LEN,
    d=1.0 / ADC_FS,
)


def process_file(filename):
    raw = np.load(filename)

    if raw.ndim != 3:
        raise ValueError(
            f"{filename}: expected "
            f"(frames, samples, receivers), "
            f"got {raw.shape}"
        )

    if raw.shape[1] != N:
        raise ValueError(
            f"{filename}: expected {N} samples, "
            f"got {raw.shape[1]}"
        )

    if RX_INDEX >= raw.shape[2]:
        raise ValueError(
            f"{filename}: RX_INDEX={RX_INDEX} unavailable"
        )

    frames = min(
        NUM_FRAMES,
        raw.shape[0],
    )

    signal = raw[
        :frames,
        :,
        RX_INDEX,
    ].astype(np.float64)

    signal -= 2048.0

    average_signal = np.mean(
        signal,
        axis=0,
    )

    average_signal *= hann_window

    return np.fft.rfft(
        average_signal,
        n=FFT_LEN,
    )


def frequency_to_range(
    frequency,
    chirp_time,
):
    slope = BANDWIDTH / chirp_time

    return (
        C * frequency
        / (2.0 * slope)
    )


def interp_complex(
    x_new,
    x,
    y,
):
    real = np.interp(
        x_new,
        x,
        y.real,
    )

    imag = np.interp(
        x_new,
        x,
        y.imag,
    )

    return real + 1j * imag


expected_target_range = (
    REFLECTOR_CM / 100.0
)


# ============================================================
# EMPTY-ROOM SPECTRA
# ============================================================

empty_spectra = {}

for chirp_us in CHIRP_TIMES_US:
    pass
    #filename = (
    #    DATA_DIR
    #    / FILE_PATTERN.format(
    #        chirp_us=chirp_us,
    #        distance_cm=EMPTY_DISTANCE_CM,
    #    )
    #)

    #empty_spectra[chirp_us] = (
    #    process_file(filename)
    #)


# ============================================================
# COMPLEX DIFFERENCE SPECTRA
# ============================================================

records = []

for chirp_us in CHIRP_TIMES_US:

    chirp_time = (
        chirp_us * 1e-6
    )

    filename = (
        DATA_DIR
        / FILE_PATTERN.format(
            chirp_us=chirp_us,
            distance_cm=REFLECTOR_CM,
        )
    )

    reflector = process_file(
        filename
    )

    diff = (
        reflector
        # - empty_spectra[chirp_us]
    )

    range_axis = frequency_to_range(
        fft_freq,
        chirp_time,
    )

    target_mask = (
        (
            range_axis
            >= expected_target_range
            - TARGET_SEARCH_HALF_WIDTH_M
        )
        &
        (
            range_axis
            <= expected_target_range
            + TARGET_SEARCH_HALF_WIDTH_M
        )
    )

    target_bins = np.where(
        target_mask
    )[0]

    target_bin = target_bins[
        np.argmax(
            np.abs(
                diff[target_bins]
            )
        )
    ]

    target_range = (
        range_axis[target_bin]
    )

    target_complex = (
        diff[target_bin]
    )

    records.append(
        {
            "range": range_axis,
            "diff": diff,
            "target_range": target_range,
            "target_complex": target_complex,
        }
    )


# ============================================================
# ALIGN REAL TARGET
# ============================================================

target_reference_range = np.median(
    [
        record["target_range"]
        for record in records
    ]
)


aligned_ranges = []

for record in records:

    aligned_range = (
        record["range"]
        - record["target_range"]
        + target_reference_range
    )

    aligned_ranges.append(
        aligned_range
    )


common_min = max(
    MIN_RANGE_M,
    max(
        x[0]
        for x in aligned_ranges
    ),
)

common_max = min(
    MAX_RANGE_M,
    min(
        x[-1]
        for x in aligned_ranges
    ),
)


common_range = np.arange(
    common_min,
    common_max
    + 0.5 * COMMON_RANGE_STEP_M,
    COMMON_RANGE_STEP_M,
)


# ============================================================
# COMPLEX TARGET NORMALIZATION
# ============================================================

normalized_spectra = []

for record, aligned_range in zip(
    records,
    aligned_ranges,
):

    # The controlled target becomes 1 + 0j.
    # Ghosts retain their phase relative to the target.
    normalized = (
        record["diff"]
        / (
            record["target_complex"]
            + EPS
        )
    )

    normalized_common = interp_complex(
        common_range,
        aligned_range,
        normalized,
    )

    normalized_spectra.append(
        normalized_common
    )


normalized_spectra = np.stack(
    normalized_spectra,
    axis=0,
)


# ============================================================
# TWO FUSION METHODS
# ============================================================

# No cancellation:
# average magnitudes after target alignment.
mean_magnitude = np.mean(
    np.abs(
        normalized_spectra
    ),
    axis=0,
)


# Proposed method:
# average complex values first.
complex_average = np.abs(
    np.mean(
        normalized_spectra,
        axis=0,
    )
)


coherence = (
    complex_average
    / (
        mean_magnitude
        + EPS
    )
)


mean_magnitude_db = (
    20.0
    * np.log10(
        mean_magnitude
        + EPS
    )
)

complex_average_db = (
    20.0
    * np.log10(
        complex_average
        + EPS
    )
)


suppression_db = (
    mean_magnitude_db
    - complex_average_db
)


# ============================================================
# BACKGROUND / GHOST STATISTICS
# ============================================================

background_mask = (
    (
        common_range
        >= MIN_RANGE_M
    )
    &
    (
        common_range
        <= common_max
    )
    &
    (
        np.abs(
            common_range
            - target_reference_range
        )
        >= TARGET_EXCLUSION_HALF_WIDTH_M
    )
)


p95_before = np.percentile(
    mean_magnitude_db[
        background_mask
    ],
    95,
)

p95_after = np.percentile(
    complex_average_db[
        background_mask
    ],
    95,
)


strongest_before = np.max(
    mean_magnitude_db[
        background_mask
    ]
)

strongest_after = np.max(
    complex_average_db[
        background_mask
    ]
)


median_suppression = np.median(
    suppression_db[
        background_mask
    ]
)

print("============================")


print(
    f"Target reference range: "
    f"{target_reference_range:.4f} m"
)

print(
    f"Receiver: "
    f"{RX_INDEX}"
)

print(
    f"Median background suppression: "
    f"{median_suppression:.2f} dB"
)

print(
    f"95th-percentile background: "
    f"{p95_before:.2f} -> "
    f"{p95_after:.2f} dBc "
    f"({p95_before - p95_after:.2f} dB suppression)"
)

print(
    f"Strongest residual: "
    f"{strongest_before:.2f} -> "
    f"{strongest_after:.2f} dBc "
    f"({strongest_before - strongest_after:.2f} dB suppression)"
)


# ============================================================
# H2-H5
# ============================================================

print()

print(
    "Ghost | Range (m) | Before (dBc) | "
    "After (dBc) | Suppression (dB) | Coherence"
)


for order in range(2, 6):

    expected_ghost_range = (
        order
        * target_reference_range
    )

    if not (
        common_min
        <= expected_ghost_range
        <= common_max
    ):
        continue

    ghost_mask = (
        np.abs(
            common_range
            - expected_ghost_range
        )
        <= GHOST_SEARCH_HALF_WIDTH_M
    )

    ghost_bins = np.where(
        ghost_mask
    )[0]

    if len(ghost_bins) == 0:
        continue

    # Find the ghost using the non-cancelling
    # magnitude-average spectrum.
    peak_bin = ghost_bins[
        np.argmax(
            mean_magnitude_db[
                ghost_bins
            ]
        )
    ]

    print(
        f"H{order:<4d} | "
        f"{common_range[peak_bin]:9.3f} | "
        f"{mean_magnitude_db[peak_bin]:12.2f} | "
        f"{complex_average_db[peak_bin]:11.2f} | "
        f"{suppression_db[peak_bin]:16.2f} | "
        f"{coherence[peak_bin]:9.3f}"
    )


# ============================================================
# SINGLE RESULT PLOT
# ============================================================

plt.figure(
    figsize=(12, 7)
)

plt.plot(
    common_range,
    mean_magnitude_db,
    linewidth=1.5,
    label="Mean magnitude",
)

plt.plot(
    common_range,
    complex_average_db,
    linewidth=1.5,
    label="Complex average",
)

plt.axvline(
    target_reference_range,
    linestyle="--",
    linewidth=1.0,
    label="Aligned target",
)

plt.xlabel(
    "Aligned Range (m)"
)

plt.ylabel(
    "Magnitude Relative to Target (dBc)"
)

plt.title(
    f"Reflector {REFLECTOR_CM} cm — "
    f"Chirp-Diversity Complex Averaging — RX{RX_INDEX}"
)

plt.xlim(
    common_min,
    common_max,
)

plt.ylim(
    -60,
    5,
)

plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()
plt.show()