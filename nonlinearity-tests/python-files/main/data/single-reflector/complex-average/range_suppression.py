from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import find_peaks


# ============================================================
# SETTINGS
# ============================================================

DATA_DIR = Path("python-files/main/data/two-reflector")
CHIRP_TIMES_US = np.arange(100, 241, 10)

REFLECTOR_CM = 50
EMPTY_CM = 0
RX_INDEX = 0

FILE_PATTERN = "ab_t{chirp_us}us_{distance_cm}_120.npy"

NUM_FRAMES = 1000
N = 128
FFT_LEN = 8192
ADC_FS = 2e6

C = 3e8
FREQ_START = 58.1e9
FREQ_END = 63.1e9
BANDWIDTH = FREQ_END - FREQ_START

MIN_RANGE_M = 0.15
MAX_RANGE_M = 3.0
RANGE_STEP_M = 0.001

TARGET_SEARCH_HALF_WIDTH_M = 0.20
TARGET_EXCLUSION_HALF_WIDTH_M = 0.20

# Used only to choose evaluation points
ARTIFACT_MIN_DIFF_OVER_EMPTY_DB = 8.0
REAL_TARGET_MAX_DIFF_OVER_EMPTY_DB = 3.0
MIN_PEAK_PROMINENCE_DB = 1.5
MIN_POINT_SPACING_M = 0.12

NUM_ARTIFACTS = 4
NUM_REAL_TARGETS = 4

# Physical phase model
ADC_START_OFFSET_US = 3.8756
MIXER_PHASE_SIGN = +1.0

EPS = 1e-15

window = np.hanning(N)
fft_freq = np.fft.rfftfreq(
    FFT_LEN,
    d=1.0 / ADC_FS,
)


# ============================================================
# HELPERS
# ============================================================

def load_spectrum(path):
    raw = np.load(path)

    frames = min(
        NUM_FRAMES,
        raw.shape[0],
    )

    x = raw[
        :frames,
        :,
        RX_INDEX,
    ].astype(float)

    x = np.mean(
        x - 2048.0,
        axis=0,
    )

    x *= window

    return np.fft.rfft(
        x,
        n=FFT_LEN,
    )


def range_axis(chirp_us):
    chirp_time = chirp_us * 1e-6
    slope = BANDWIDTH / chirp_time

    return (
        C * fft_freq
        / (2.0 * slope)
    )


def interp_complex(x_new, x, y):
    return (
        np.interp(
            x_new,
            x,
            y.real,
        )
        +
        1j
        * np.interp(
            x_new,
            x,
            y.imag,
        )
    )


def to_db(x, reference):
    return (
        20.0
        * np.log10(
            x / (reference + EPS)
            + EPS
        )
    )


def ideal_target_phase(
    range_m,
    chirp_us,
):
    chirp_time = chirp_us * 1e-6
    slope = BANDWIDTH / chirp_time

    tau = (
        2.0
        * np.asarray(range_m)
        / C
    )

    t_adc = (
        ADC_START_OFFSET_US
        * 1e-6
    )

    phase = (
        2.0 * np.pi
        * FREQ_START
        * tau
        +
        2.0 * np.pi
        * slope
        * tau
        * t_adc
        -
        np.pi
        * slope
        * tau**2
    )

    return (
        MIXER_PHASE_SIGN
        * phase
    )


def choose_points(
    spectrum_db,
    valid_mask,
    condition,
    count,
):
    peaks, _ = find_peaks(
        spectrum_db,
        prominence=MIN_PEAK_PROMINENCE_DB,
    )

    candidates = [
        b
        for b in peaks
        if (
            valid_mask[b]
            and condition(b)
        )
    ]

    candidates.sort(
        key=lambda b: spectrum_db[b],
        reverse=True,
    )

    selected = []

    for b in candidates:

        far_enough = all(
            abs(
                common_range[b]
                - common_range[s]
            )
            >= MIN_POINT_SPACING_M
            for s in selected
        )

        if far_enough:
            selected.append(b)

        if len(selected) == count:
            break

    return selected


# ============================================================
# LOAD REFLECTOR DATA
#
# No empty-room data is used here.
# ============================================================

expected_target_range = (
    REFLECTOR_CM / 100.0
)

records = []

for chirp_us in CHIRP_TIMES_US:

    spectrum = load_spectrum(
        DATA_DIR
        / FILE_PATTERN.format(
            chirp_us=chirp_us,
            distance_cm=REFLECTOR_CM,
        )
    )

    ranges = range_axis(
        chirp_us
    )

    target_mask = (
        np.abs(
            ranges
            - expected_target_range
        )
        <= TARGET_SEARCH_HALF_WIDTH_M
    )

    target_bins = np.where(
        target_mask
    )[0]

    target_bin = target_bins[
        np.argmax(
            np.abs(
                spectrum[
                    target_bins
                ]
            )
        )
    ]

    records.append(
        {
            "chirp_us":
                chirp_us,

            "range":
                ranges,

            "spectrum":
                spectrum,

            "detected_target_range":
                ranges[target_bin],
        }
    )


# ============================================================
# FIXED TARGET REFERENCE RANGE
# ============================================================

target_reference_range = np.median(
    [
        record[
            "detected_target_range"
        ]
        for record in records
    ]
)


# ============================================================
# COMMON RANGE AXIS
# ============================================================

common_min = max(
    MIN_RANGE_M,
    max(
        record["range"][0]
        for record in records
    ),
)

common_max = min(
    MAX_RANGE_M,
    min(
        record["range"][-1]
        for record in records
    ),
)

common_range = np.arange(
    common_min,
    common_max
    + 0.5 * RANGE_STEP_M,
    RANGE_STEP_M,
)


# ============================================================
# RAW-DATA FUSION
# ============================================================

raw_spectra = []
global_spectra = []
per_bin_spectra = []

target_magnitudes = []

reference_chirp_us = (
    CHIRP_TIMES_US[0]
)


def relative_real_target_phase(
    range_m,
    chirp_us,
):
    return (
        ideal_target_phase(
            range_m,
            chirp_us,
        )
        -
        ideal_target_phase(
            target_reference_range,
            chirp_us,
        )
    )


reference_model_phase = (
    relative_real_target_phase(
        common_range,
        reference_chirp_us,
    )
)


for record in records:

    chirp_us = (
        record["chirp_us"]
    )

    spectrum_common = (
        interp_complex(
            common_range,
            record["range"],
            record["spectrum"],
        )
    )

    # Measure target phase at the SAME
    # physical range for every chirp.
    target_complex = (
        interp_complex(
            target_reference_range,
            record["range"],
            record["spectrum"],
        )
    )

    target_phase = np.angle(
        target_complex
    )

    target_magnitudes.append(
        np.abs(
            target_complex
        )
    )

    # --------------------------------------------------------
    # 1. Raw spectrum
    # --------------------------------------------------------

    raw_spectra.append(
        spectrum_common
    )

    # --------------------------------------------------------
    # 2. Global target-phase alignment
    # --------------------------------------------------------

    global_aligned = (
        spectrum_common
        * np.exp(
            -1j
            * target_phase
        )
    )

    global_spectra.append(
        global_aligned
    )

    # --------------------------------------------------------
    # 3. Per-range real-target correction
    # --------------------------------------------------------

    current_model_phase = (
        relative_real_target_phase(
            common_range,
            chirp_us,
        )
    )

    extra_phase = (
        current_model_phase
        - reference_model_phase
    )

    per_bin_aligned = (
        global_aligned
        * np.exp(
            -1j
            * extra_phase
        )
    )

    per_bin_spectra.append(
        per_bin_aligned
    )


raw_spectra = np.stack(
    raw_spectra
)

global_spectra = np.stack(
    global_spectra
)

per_bin_spectra = np.stack(
    per_bin_spectra
)


reference_magnitude = np.mean(
    target_magnitudes
)


# ============================================================
# FUSION RESULTS
# ============================================================

magnitude_control = np.mean(
    np.abs(
        raw_spectra
    ),
    axis=0,
)

global_fused = np.abs(
    np.mean(
        global_spectra,
        axis=0,
    )
)

per_bin_fused = np.abs(
    np.mean(
        per_bin_spectra,
        axis=0,
    )
)


control_db = to_db(
    magnitude_control,
    reference_magnitude,
)

global_db = to_db(
    global_fused,
    reference_magnitude,
)

per_bin_db = to_db(
    per_bin_fused,
    reference_magnitude,
)


global_suppression = (
    control_db
    - global_db
)

per_bin_suppression = (
    control_db
    - per_bin_db
)


# ============================================================
# EVALUATION ONLY
#
# Empty-room data first appears here.
# It is NOT used by either fusion method.
# ============================================================

empty_spectra = []
difference_spectra = []


for record in records:

    chirp_us = (
        record["chirp_us"]
    )

    empty = load_spectrum(
        DATA_DIR
        / FILE_PATTERN.format(
            chirp_us=chirp_us,
            distance_cm=EMPTY_CM,
        )
    )

    empty_spectra.append(
        interp_complex(
            common_range,
            record["range"],
            empty,
        )
    )

    difference_spectra.append(
        interp_complex(
            common_range,
            record["range"],
            record["spectrum"]
            - empty,
        )
    )


empty_magnitude = np.mean(
    np.abs(
        np.stack(
            empty_spectra
        )
    ),
    axis=0,
)

difference_magnitude = np.mean(
    np.abs(
        np.stack(
            difference_spectra
        )
    ),
    axis=0,
)


empty_db = to_db(
    empty_magnitude,
    reference_magnitude,
)

difference_db = to_db(
    difference_magnitude,
    reference_magnitude,
)

difference_over_empty_db = (
    difference_db
    - empty_db
)


valid_evaluation_mask = (
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


artifact_bins = choose_points(
    difference_db,
    valid_evaluation_mask,
    lambda b:
        difference_over_empty_db[b]
        >= ARTIFACT_MIN_DIFF_OVER_EMPTY_DB,
    NUM_ARTIFACTS,
)


real_target_bins = choose_points(
    empty_db,
    valid_evaluation_mask,
    lambda b:
        difference_over_empty_db[b]
        <= REAL_TARGET_MAX_DIFF_OVER_EMPTY_DB,
    NUM_REAL_TARGETS,
)


# ============================================================
# RESULTS
# ============================================================

def at_range(values, range_m):
    return np.interp(
        range_m,
        common_range,
        values,
    )


def print_points(
    title,
    bins,
):
    print()
    print(title)

    print(
        "Range (m) | Global supp. | "
        "Per-bin supp. | Diff-Empty"
    )

    print("-" * 59)

    for b in bins:

        print(
            f"{common_range[b]:9.3f} | "
            f"{global_suppression[b]:12.2f} | "
            f"{per_bin_suppression[b]:13.2f} | "
            f"{difference_over_empty_db[b]:10.2f}"
        )

    if bins:

        print(
            f"Median    | "
            f"{np.median(global_suppression[bins]):12.2f} | "
            f"{np.median(per_bin_suppression[bins]):13.2f} |"
        )


main_global = at_range(
    global_suppression,
    target_reference_range,
)

main_per_bin = at_range(
    per_bin_suppression,
    target_reference_range,
)


print()
print(
    "============================================================"
)

print(
    "GLOBAL VS PER-BIN PHASE CORRECTION"
)

print(
    "============================================================"
)

print(
    f"Reflector: {REFLECTOR_CM} cm | "
    f"RX{RX_INDEX} | "
    f"target: {target_reference_range:.4f} m"
)

print(
    "Background subtraction is used "
    "only to choose evaluation points."
)


print()
print("MAIN TARGET")

print(
    f"Global suppression:  "
    f"{main_global:.3f} dB"
)

print(
    f"Per-bin suppression: "
    f"{main_per_bin:.3f} dB"
)


print_points(
    "CLEAN-BACKGROUND ARTIFACTS",
    artifact_bins,
)

print_points(
    "REAL BACKGROUND TARGETS",
    real_target_bins,
)


# ============================================================
# ONE PLOT
# ============================================================

plt.figure(
    figsize=(12, 7)
)

plt.plot(
    common_range,
    control_db,
    label="Mean magnitude",
)

plt.plot(
    common_range,
    global_db,
    label="Global phase alignment",
)

plt.plot(
    common_range,
    per_bin_db,
    label="Per-bin phase correction",
)


plt.axvline(
    target_reference_range,
    linestyle="--",
    label="Main target",
)


for i, b in enumerate(
    artifact_bins
):

    plt.axvline(
        common_range[b],
        linestyle=":",
        alpha=0.7,
        label=(
            "Artifact"
            if i == 0
            else None
        ),
    )


for i, b in enumerate(
    real_target_bins
):

    plt.axvline(
        common_range[b],
        linestyle="-.",
        alpha=0.7,
        label=(
            "Real background target"
            if i == 0
            else None
        ),
    )


plt.xlabel(
    "Range (m)"
)

plt.ylabel(
    "Magnitude relative to main target (dBc)"
)

plt.title(
    f"Raw-Data Chirp-Diversity Fusion — "
    f"{REFLECTOR_CM} cm — RX{RX_INDEX}"
)

plt.xlim(
    common_min,
    common_max,
)

plt.ylim(
    -70,
    5,
)

plt.grid(True)
plt.legend()
plt.tight_layout()
plt.show()