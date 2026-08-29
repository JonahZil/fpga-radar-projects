from pathlib import Path
from itertools import combinations

import numpy as np
import matplotlib.pyplot as plt


DATA_DIR = Path("python-files/main/data/chirp-lengths")

CHIRP_TIMES_US = np.arange(100, 241, 10)

REFLECTOR_CM = 50
EMPTY_DISTANCE_CM = 0

FILE_PATTERN = "t{chirp_us}us-{distance_cm}.npy"

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
TARGET_EXCLUSION_HALF_WIDTH_M = 0.20

GHOST_SEARCH_HALF_WIDTH_M = 0.10

MIN_RANGE_M = 0.15
MAX_RANGE_M = 3.0

COMMON_RANGE_STEP_M = 0.001

EPS = 1e-15

hann_window = np.hanning(N)

fft_freq = np.fft.rfftfreq(
    FFT_LEN,
    d=1.0 / ADC_FS,
)


def process_file(filename):
    raw = np.load(filename)

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


def to_db(
    magnitude,
    reference,
):
    return (
        20.0
        * np.log10(
            magnitude
            / (reference + EPS)
            + EPS
        )
    )


expected_target_range = (
    REFLECTOR_CM / 100.0
)


# ============================================================
# LOAD EMPTY-ROOM SPECTRA
# ============================================================

empty_spectra = {}

for chirp_us in CHIRP_TIMES_US:

    filename = (
        DATA_DIR
        / FILE_PATTERN.format(
            chirp_us=chirp_us,
            distance_cm=EMPTY_DISTANCE_CM,
        )
    )

    empty_spectra[chirp_us] = process_file(
        filename
    )


# ============================================================
# PROCESS REFLECTOR MEASUREMENTS
# ============================================================

records = []

for chirp_us in CHIRP_TIMES_US:

    chirp_time = chirp_us * 1e-6

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
        - empty_spectra[chirp_us]
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
# COMMON RANGE AXIS
# ============================================================

common_min = max(
    MIN_RANGE_M,
    max(
        r["range"][0]
        for r in records
    ),
)

common_max = min(
    MAX_RANGE_M,
    min(
        r["range"][-1]
        for r in records
    ),
)

common_range = np.arange(
    common_min,
    common_max
    + 0.5 * COMMON_RANGE_STEP_M,
    COMMON_RANGE_STEP_M,
)


# ============================================================
# INTERPOLATE AND PHASE ALIGN
# ============================================================

raw_spectra = []
phase_aligned_spectra = []

target_ranges = []
target_magnitudes = []


for record in records:

    raw_common = interp_complex(
        common_range,
        record["range"],
        record["diff"],
    )

    target_phase = np.angle(
        record["target_complex"]
    )

    phase_aligned = (
        raw_common
        * np.exp(
            -1j * target_phase
        )
    )

    raw_spectra.append(
        raw_common
    )

    phase_aligned_spectra.append(
        phase_aligned
    )

    target_ranges.append(
        record["target_range"]
    )

    target_magnitudes.append(
        np.abs(
            record["target_complex"]
        )
    )


raw_spectra = np.stack(
    raw_spectra,
    axis=0,
)

phase_aligned_spectra = np.stack(
    phase_aligned_spectra,
    axis=0,
)

target_ranges = np.array(
    target_ranges
)

target_magnitudes = np.array(
    target_magnitudes
)


# Precompute magnitudes.
raw_magnitudes = np.abs(
    raw_spectra
)


target_reference_range = np.median(
    target_ranges
)


# ============================================================
# MASKS
# ============================================================

target_mask_common = (
    np.abs(
        common_range
        - target_reference_range
    )
    <= 0.05
)


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


# ============================================================
# ANALYZE ONE COMBINATION
# ============================================================

def analyze_combination(indices):

    indices = np.asarray(
        indices,
        dtype=int,
    )

    # --------------------------------------------------------
    # Magnitude-average control
    # --------------------------------------------------------

    control = np.mean(
        raw_magnitudes[indices],
        axis=0,
    )


    # --------------------------------------------------------
    # Phase-aligned complex fusion
    # --------------------------------------------------------

    fused = np.abs(
        np.mean(
            phase_aligned_spectra[indices],
            axis=0,
        )
    )


    # Use the mean target magnitude of this subset
    # as a common reference for both methods.
    reference = np.mean(
        target_magnitudes[indices]
    )


    control_db = to_db(
        control,
        reference,
    )

    fused_db = to_db(
        fused,
        reference,
    )


    # --------------------------------------------------------
    # Target preservation
    # --------------------------------------------------------

    target_before = np.max(
        control_db[
            target_mask_common
        ]
    )

    target_after = np.max(
        fused_db[
            target_mask_common
        ]
    )

    target_loss = (
        target_before
        - target_after
    )


    # --------------------------------------------------------
    # Strongest residual
    # --------------------------------------------------------

    strongest_before = np.max(
        control_db[
            background_mask
        ]
    )

    strongest_after = np.max(
        fused_db[
            background_mask
        ]
    )

    strongest_suppression = (
        strongest_before
        - strongest_after
    )


    # --------------------------------------------------------
    # Harmonics H2-H5
    # --------------------------------------------------------

    subset_target_range = np.median(
        target_ranges[indices]
    )

    harmonic_suppression = {}


    for order in range(2, 6):

        expected_ghost_range = (
            order
            * subset_target_range
        )

        if not (
            common_min
            <= expected_ghost_range
            <= common_max
        ):
            harmonic_suppression[
                order
            ] = np.nan

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
            harmonic_suppression[
                order
            ] = np.nan

            continue


        # Locate the ghost using only the
        # unsuppressed magnitude control.
        peak_bin = ghost_bins[
            np.argmax(
                control_db[
                    ghost_bins
                ]
            )
        ]


        suppression = (
            control_db[peak_bin]
            - fused_db[peak_bin]
        )


        harmonic_suppression[
            order
        ] = suppression


    return {
        "strongest_suppression":
            strongest_suppression,

        "target_loss":
            target_loss,

        "harmonics":
            harmonic_suppression,
    }


# ============================================================
# TEST EVERY POSSIBLE COMBINATION
# ============================================================

results_by_count = {}


for num_chirps in range(
    2,
    len(CHIRP_TIMES_US) + 1,
):

    count_results = []


    for combo in combinations(
        range(
            len(CHIRP_TIMES_US)
        ),
        num_chirps,
    ):

        result = analyze_combination(
            combo
        )

        result["indices"] = combo

        count_results.append(
            result
        )


    results_by_count[
        num_chirps
    ] = count_results


# ============================================================
# SUMMARY
# ============================================================

print(
    " N | Combos | Median |   P10 |   P90 |  Best | "
    "Med H2 | Med H3 | Med H4 | Med H5"
)

print(
    "-" * 91
)


summary_n = []
summary_median = []
summary_p10 = []
summary_p90 = []


for num_chirps in range(
    2,
    len(CHIRP_TIMES_US) + 1,
):

    results = results_by_count[
        num_chirps
    ]


    strongest = np.array(
        [
            r[
                "strongest_suppression"
            ]
            for r in results
        ]
    )


    harmonic_medians = []

    for order in range(2, 6):

        values = np.array(
            [
                r["harmonics"][order]
                for r in results
            ],
            dtype=float,
        )

        values = values[
            np.isfinite(values)
        ]

        if len(values) > 0:

            harmonic_medians.append(
                np.median(values)
            )

        else:

            harmonic_medians.append(
                np.nan
            )


    median_value = np.median(
        strongest
    )

    p10_value = np.percentile(
        strongest,
        10,
    )

    p90_value = np.percentile(
        strongest,
        90,
    )

    best_value = np.max(
        strongest
    )


    summary_n.append(
        num_chirps
    )

    summary_median.append(
        median_value
    )

    summary_p10.append(
        p10_value
    )

    summary_p90.append(
        p90_value
    )


    print(
        f"{num_chirps:2d} | "
        f"{len(results):6d} | "
        f"{median_value:6.2f} | "
        f"{p10_value:5.2f} | "
        f"{p90_value:5.2f} | "
        f"{best_value:5.2f} | "
        f"{harmonic_medians[0]:6.2f} | "
        f"{harmonic_medians[1]:6.2f} | "
        f"{harmonic_medians[2]:6.2f} | "
        f"{harmonic_medians[3]:6.2f}"
    )


# ============================================================
# BEST COMBINATION FOR EACH N
# ============================================================

print()
print(
    "Best chirp combination for each N"
)

print(
    "-" * 60
)


for num_chirps in range(
    2,
    len(CHIRP_TIMES_US) + 1,
):

    results = results_by_count[
        num_chirps
    ]


    best = max(
        results,
        key=lambda x:
            x[
                "strongest_suppression"
            ],
    )


    chirps = [
        int(
            CHIRP_TIMES_US[i]
        )
        for i in best["indices"]
    ]


    print(
        f"N={num_chirps:2d} | "
        f"{best['strongest_suppression']:6.2f} dB | "
        f"{chirps}"
    )


# ============================================================
# ALL PAIRS, RANKED
# ============================================================

pair_results = sorted(
    results_by_count[2],
    key=lambda x:
        x[
            "strongest_suppression"
        ],
    reverse=True,
)


print()
print(
    "Top 10 chirp pairs"
)

print(
    "-" * 60
)


for result in pair_results[:10]:

    i, j = result["indices"]

    print(
        f"{int(CHIRP_TIMES_US[i]):3d} us + "
        f"{int(CHIRP_TIMES_US[j]):3d} us | "
        f"{result['strongest_suppression']:6.2f} dB"
    )


# ============================================================
# MAIN RESULT PLOT
# ============================================================

summary_n = np.array(
    summary_n
)

summary_median = np.array(
    summary_median
)

summary_p10 = np.array(
    summary_p10
)

summary_p90 = np.array(
    summary_p90
)


plt.figure(
    figsize=(10, 6)
)

plt.plot(
    summary_n,
    summary_median,
    marker="o",
    linewidth=1.8,
    label="Median over all combinations",
)

plt.fill_between(
    summary_n,
    summary_p10,
    summary_p90,
    alpha=0.2,
    label="10th–90th percentile",
)

plt.xlabel(
    "Number of Different Chirp Durations"
)

plt.ylabel(
    "Strongest-Residual Suppression (dB)"
)

plt.title(
    f"Reflector {REFLECTOR_CM} cm — "
    f"Suppression vs Chirp Diversity — RX{RX_INDEX}"
)

plt.xticks(
    summary_n
)

plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()

plt.show()