from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import find_peaks


# ============================================================
# SETTINGS
# ============================================================

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
TARGET_EVAL_HALF_WIDTH_M = 0.05
TARGET_EXCLUSION_HALF_WIDTH_M = 0.20

MIN_RANGE_M = 0.15
MAX_RANGE_M = 3.0
COMMON_RANGE_STEP_M = 0.001

# Evaluation-only peak selection.
ARTIFACT_MIN_PROMINENCE_DB = 1.5
BACKGROUND_MIN_PROMINENCE_DB = 1.5

ARTIFACT_MIN_LEVEL_DBC = -50.0
BACKGROUND_MIN_LEVEL_DBC = -50.0

# An automatically selected artifact must have the empty-room response
# at least this far below the reflector-induced difference response.
CLEAN_BACKGROUND_MARGIN_DB = 8.0

# Reject an artifact candidate if an empty-room peak lies this close.
BACKGROUND_PEAK_GUARD_M = 0.06

MAX_ARTIFACT_POINTS = 6
MAX_BACKGROUND_POINTS = 6

# Optional manual evaluation points. Leave empty for automatic selection.
# These lists affect ONLY evaluation; they are never used by the fusion.
MANUAL_ARTIFACT_RANGES_M = []
MANUAL_BACKGROUND_RANGES_M = []

EPS = 1e-15

hann_window = np.hanning(N)
fft_freq = np.fft.rfftfreq(
    FFT_LEN,
    d=1.0 / ADC_FS,
)


# ============================================================
# HELPERS
# ============================================================

def process_file(filename):
    raw = np.load(filename)

    if raw.ndim != 3:
        raise ValueError(
            f"{filename}: expected (frames, samples, receivers), "
            f"got {raw.shape}"
        )

    if raw.shape[1] != N:
        raise ValueError(
            f"{filename}: expected {N} samples, got {raw.shape[1]}"
        )

    if RX_INDEX >= raw.shape[2]:
        raise ValueError(
            f"{filename}: RX_INDEX={RX_INDEX} unavailable"
        )

    frames = min(NUM_FRAMES, raw.shape[0])

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


def frequency_to_range(frequency, chirp_time):
    slope = BANDWIDTH / chirp_time
    return C * frequency / (2.0 * slope)


def interp_complex(x_new, x, y):
    real = np.interp(x_new, x, y.real)
    imag = np.interp(x_new, x, y.imag)
    return real + 1j * imag


def to_db(magnitude, reference):
    return 20.0 * np.log10(
        magnitude / (reference + EPS) + EPS
    )


def nearest_bin(range_axis, range_m):
    return int(
        np.argmin(
            np.abs(range_axis - range_m)
        )
    )


def find_peaks_on_mask(
    spectrum_db,
    mask,
    prominence_db,
):
    valid_bins = np.where(mask)[0]

    if len(valid_bins) == 0:
        return np.array([], dtype=int)

    local_peaks, _ = find_peaks(
        spectrum_db[valid_bins],
        prominence=prominence_db,
    )

    return valid_bins[local_peaks]


def evaluate_bin(
    label,
    bin_index,
    common_range,
    control_db,
    fused_db,
    empty_db,
    diff_db,
):
    before = control_db[bin_index]
    after = fused_db[bin_index]

    return {
        "label": label,
        "range": common_range[bin_index],
        "before": before,
        "after": after,
        "suppression": before - after,
        "empty": empty_db[bin_index],
        "difference": diff_db[bin_index],
        "diff_minus_empty": (
            diff_db[bin_index]
            - empty_db[bin_index]
        ),
    }


def print_table(title, rows):
    print()
    print(title)
    print(
        "Point              | Range (m) | Before |  After | "
        "Supp. |  Empty | Diff-only | Diff-Empty"
    )
    print("-" * 93)

    if len(rows) == 0:
        print("No points satisfied the selection criteria.")
        return

    for row in rows:
        print(
            f"{row['label']:<18} | "
            f"{row['range']:9.3f} | "
            f"{row['before']:6.2f} | "
            f"{row['after']:6.2f} | "
            f"{row['suppression']:5.2f} | "
            f"{row['empty']:6.2f} | "
            f"{row['difference']:9.2f} | "
            f"{row['diff_minus_empty']:10.2f}"
        )


# ============================================================
# LOAD DATA
#
# IMPORTANT:
#   reflector_spectra are the ONLY spectra used by the algorithm.
#
#   empty_spectra are loaded only for post-hoc evaluation / labeling.
# ============================================================

reflector_spectra = {}
empty_spectra = {}

for chirp_us in CHIRP_TIMES_US:
    reflector_file = (
        DATA_DIR
        / FILE_PATTERN.format(
            chirp_us=chirp_us,
            distance_cm=REFLECTOR_CM,
        )
    )

    empty_file = (
        DATA_DIR
        / FILE_PATTERN.format(
            chirp_us=chirp_us,
            distance_cm=EMPTY_DISTANCE_CM,
        )
    )

    reflector_spectra[chirp_us] = process_file(
        reflector_file
    )

    empty_spectra[chirp_us] = process_file(
        empty_file
    )


# ============================================================
# DEPLOYMENT PATH
#
# NO EMPTY-ROOM SUBTRACTION BELOW THIS POINT.
# The target range and phase are estimated directly from the raw
# reflector-present measurement.
# ============================================================

expected_target_range = REFLECTOR_CM / 100.0
records = []

for chirp_us in CHIRP_TIMES_US:
    chirp_time = chirp_us * 1e-6

    spectrum = reflector_spectra[chirp_us]

    range_axis = frequency_to_range(
        fft_freq,
        chirp_time,
    )

    target_mask = (
        (range_axis >= expected_target_range - TARGET_SEARCH_HALF_WIDTH_M)
        &
        (range_axis <= expected_target_range + TARGET_SEARCH_HALF_WIDTH_M)
    )

    target_bins = np.where(target_mask)[0]

    if len(target_bins) == 0:
        raise RuntimeError(
            f"No target-search bins for {chirp_us} us"
        )

    target_bin = target_bins[
        np.argmax(
            np.abs(spectrum[target_bins])
        )
    ]

    target_range = range_axis[target_bin]
    target_complex = spectrum[target_bin]
    target_phase = np.angle(target_complex)

    records.append(
        {
            "chirp_us": chirp_us,
            "chirp_time": chirp_time,
            "range": range_axis,
            "spectrum": spectrum,
            "target_range": target_range,
            "target_complex": target_complex,
            "target_phase": target_phase,
        }
    )


# ============================================================
# COMMON RANGE SUPPORT
#
# No range shift is performed. This matches the phase-only method.
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
    common_max + 0.5 * COMMON_RANGE_STEP_M,
    COMMON_RANGE_STEP_M,
)


# ============================================================
# RAW PHASE-ONLY FUSION
# ============================================================

raw_common = []
aligned_common = []
target_ranges = []
target_magnitudes = []

for record in records:
    raw_interp = interp_complex(
        common_range,
        record["range"],
        record["spectrum"],
    )

    aligned_interp = (
        raw_interp
        * np.exp(
            -1j * record["target_phase"]
        )
    )

    raw_common.append(raw_interp)
    aligned_common.append(aligned_interp)
    target_ranges.append(record["target_range"])
    target_magnitudes.append(
        np.abs(record["target_complex"])
    )

raw_common = np.stack(
    raw_common,
    axis=0,
)

aligned_common = np.stack(
    aligned_common,
    axis=0,
)

target_ranges = np.asarray(target_ranges)
target_magnitudes = np.asarray(target_magnitudes)

target_reference_range = np.median(target_ranges)
reference_target_magnitude = np.mean(target_magnitudes)

# Control: average magnitude, so phases cannot cancel.
magnitude_control = np.mean(
    np.abs(raw_common),
    axis=0,
)

# Proposed method: phase-align to the raw main target, then complex-average.
complex_fused = np.abs(
    np.mean(
        aligned_common,
        axis=0,
    )
)

control_db = to_db(
    magnitude_control,
    reference_target_magnitude,
)

fused_db = to_db(
    complex_fused,
    reference_target_magnitude,
)

suppression_db = control_db - fused_db


# ============================================================
# EVALUATION PATH
#
# Empty-room data starts being used here, AFTER the algorithm output
# has already been produced.
#
# This path does NOT change target phase, target range, or fusion.
# ============================================================

empty_common = []
diff_common = []

for record in records:
    chirp_us = record["chirp_us"]

    empty = empty_spectra[chirp_us]
    difference = (
        reflector_spectra[chirp_us]
        - empty
    )

    empty_interp = interp_complex(
        common_range,
        record["range"],
        empty,
    )

    diff_interp = interp_complex(
        common_range,
        record["range"],
        difference,
    )

    empty_common.append(empty_interp)
    diff_common.append(diff_interp)

empty_common = np.stack(
    empty_common,
    axis=0,
)

diff_common = np.stack(
    diff_common,
    axis=0,
)

# Use magnitude averages for ground-truth labeling so there is no
# cancellation in the evaluation spectra themselves.
empty_magnitude = np.mean(
    np.abs(empty_common),
    axis=0,
)

diff_magnitude = np.mean(
    np.abs(diff_common),
    axis=0,
)

empty_db = to_db(
    empty_magnitude,
    reference_target_magnitude,
)

diff_db = to_db(
    diff_magnitude,
    reference_target_magnitude,
)


# ============================================================
# MAIN TARGET PRESERVATION
# ============================================================

target_eval_mask = (
    np.abs(
        common_range
        - target_reference_range
    )
    <= TARGET_EVAL_HALF_WIDTH_M
)

target_eval_bins = np.where(
    target_eval_mask
)[0]

target_control_bin = target_eval_bins[
    np.argmax(
        control_db[target_eval_bins]
    )
]

main_target_row = evaluate_bin(
    "Main target",
    target_control_bin,
    common_range,
    control_db,
    fused_db,
    empty_db,
    diff_db,
)


# ============================================================
# EVALUATION MASK
# ============================================================

analysis_mask = (
    (common_range >= MIN_RANGE_M)
    &
    (common_range <= common_max)
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
# DETECT EMPTY-ROOM PEAKS
# ============================================================

empty_peak_bins = find_peaks_on_mask(
    empty_db,
    analysis_mask,
    BACKGROUND_MIN_PROMINENCE_DB,
)

empty_peak_bins = np.asarray(
    [
        b
        for b in empty_peak_bins
        if empty_db[b] >= BACKGROUND_MIN_LEVEL_DBC
    ],
    dtype=int,
)


# ============================================================
# SELECT ARTIFACT POINTS
#
# Automatic artifact candidates must:
#   1. be peaks in reflector-minus-empty evaluation data,
#   2. not lie near an empty-room peak,
#   3. have the difference response at least
#      CLEAN_BACKGROUND_MARGIN_DB above the empty-room response.
#
# These rules use background data only to LABEL evaluation points.
# ============================================================

if len(MANUAL_ARTIFACT_RANGES_M) > 0:
    artifact_bins = np.asarray(
        [
            nearest_bin(
                common_range,
                range_m,
            )
            for range_m in MANUAL_ARTIFACT_RANGES_M
        ],
        dtype=int,
    )
else:
    diff_peak_bins = find_peaks_on_mask(
        diff_db,
        analysis_mask,
        ARTIFACT_MIN_PROMINENCE_DB,
    )

    accepted = []

    for b in diff_peak_bins:
        if diff_db[b] < ARTIFACT_MIN_LEVEL_DBC:
            continue

        if (
            diff_db[b]
            - empty_db[b]
            < CLEAN_BACKGROUND_MARGIN_DB
        ):
            continue

        if len(empty_peak_bins) > 0:
            distance_to_empty_peak = np.min(
                np.abs(
                    common_range[empty_peak_bins]
                    - common_range[b]
                )
            )

            if (
                distance_to_empty_peak
                < BACKGROUND_PEAK_GUARD_M
            ):
                continue

        accepted.append(b)

    accepted = sorted(
        accepted,
        key=lambda b: diff_db[b],
        reverse=True,
    )

    artifact_bins = np.asarray(
        accepted[:MAX_ARTIFACT_POINTS],
        dtype=int,
    )


artifact_rows = []

for i, b in enumerate(artifact_bins, start=1):
    artifact_rows.append(
        evaluate_bin(
            f"Artifact {i}",
            b,
            common_range,
            control_db,
            fused_db,
            empty_db,
            diff_db,
        )
    )


# ============================================================
# SELECT REAL BACKGROUND REFLECTOR POINTS
#
# These are peaks detected directly in the empty-room measurement.
# They are evaluated at the SAME ranges in the raw fusion result.
# ============================================================

if len(MANUAL_BACKGROUND_RANGES_M) > 0:
    background_bins = np.asarray(
        [
            nearest_bin(
                common_range,
                range_m,
            )
            for range_m in MANUAL_BACKGROUND_RANGES_M
        ],
        dtype=int,
    )
else:
    ranked_empty_bins = sorted(
        empty_peak_bins,
        key=lambda b: empty_db[b],
        reverse=True,
    )

    background_bins = np.asarray(
        ranked_empty_bins[:MAX_BACKGROUND_POINTS],
        dtype=int,
    )


background_rows = []

for i, b in enumerate(background_bins, start=1):
    background_rows.append(
        evaluate_bin(
            f"Background {i}",
            b,
            common_range,
            control_db,
            fused_db,
            empty_db,
            diff_db,
        )
    )


# ============================================================
# SUMMARY
# ============================================================

print()
print("============================================================")
print("RAW-DATA CHIRP-DIVERSITY SUPPRESSION")
print("============================================================")
print(
    f"Reflector: {REFLECTOR_CM} cm | "
    f"RX{RX_INDEX} | "
    f"chirps: {CHIRP_TIMES_US[0]}-{CHIRP_TIMES_US[-1]} us"
)
print()
print("Target ranges estimated FROM RAW DATA:")

for record in records:
    print(
        f"  {record['chirp_us']:3d} us: "
        f"{record['target_range']:.4f} m"
    )

print()
print(
    "Background subtraction was NOT used for target extraction, "
    "phase alignment, or fusion."
)
print(
    "It was used only after fusion to identify evaluation points."
)

print_table(
    "MAIN TARGET",
    [main_target_row],
)

print_table(
    "ARTIFACTS IN CLEAN BACKGROUND REGIONS",
    artifact_rows,
)

print_table(
    "REAL PEAKS ALREADY PRESENT IN EMPTY ROOM",
    background_rows,
)

if len(artifact_rows) > 0:
    artifact_suppression = np.asarray(
        [
            row["suppression"]
            for row in artifact_rows
        ]
    )

    print()
    print(
        "Artifact suppression: "
        f"median={np.median(artifact_suppression):.2f} dB, "
        f"mean={np.mean(artifact_suppression):.2f} dB, "
        f"min={np.min(artifact_suppression):.2f} dB, "
        f"max={np.max(artifact_suppression):.2f} dB"
    )

if len(background_rows) > 0:
    background_suppression = np.asarray(
        [
            row["suppression"]
            for row in background_rows
        ]
    )

    print(
        "Background-target change: "
        f"median={np.median(background_suppression):.2f} dB, "
        f"mean={np.mean(background_suppression):.2f} dB"
    )

print(
    "Main-target change: "
    f"{main_target_row['suppression']:.2f} dB"
)


# ============================================================
# PLOT 1: ACTUAL RAW-DATA ALGORITHM RESULT
# ============================================================

plt.figure(
    figsize=(13, 7)
)

plt.plot(
    common_range,
    control_db,
    linewidth=1.5,
    label="Mean magnitude — raw data",
)

plt.plot(
    common_range,
    fused_db,
    linewidth=1.5,
    label="Phase-aligned complex average — raw data",
)

plt.axvline(
    target_reference_range,
    linestyle="--",
    linewidth=1.0,
    label="Main target",
)

for i, b in enumerate(artifact_bins):
    plt.axvline(
        common_range[b],
        linestyle=":",
        linewidth=1.0,
        label=(
            "Clean-background artifact"
            if i == 0
            else None
        ),
    )

for i, b in enumerate(background_bins):
    plt.axvline(
        common_range[b],
        linestyle="-.",
        linewidth=1.0,
        label=(
            "Empty-room reflector"
            if i == 0
            else None
        ),
    )

plt.xlabel("Range (m)")
plt.ylabel("Magnitude Relative to Mean Main Target (dBc)")
plt.title(
    f"No-Background-Subtraction Fusion — "
    f"{REFLECTOR_CM} cm Reflector — RX{RX_INDEX}"
)
plt.xlim(common_min, common_max)
plt.ylim(-70, 5)
plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()


# ============================================================
# PLOT 2: EVALUATION-ONLY GROUND TRUTH
# ============================================================

plt.figure(
    figsize=(13, 7)
)

plt.plot(
    common_range,
    empty_db,
    linewidth=1.4,
    label="Empty-room magnitude average",
)

plt.plot(
    common_range,
    diff_db,
    linewidth=1.4,
    label="Reflector minus empty — evaluation only",
)

plt.axvline(
    target_reference_range,
    linestyle="--",
    linewidth=1.0,
    label="Main target",
)

for i, b in enumerate(artifact_bins):
    plt.axvline(
        common_range[b],
        linestyle=":",
        linewidth=1.0,
        label=(
            "Selected artifact"
            if i == 0
            else None
        ),
    )

for i, b in enumerate(background_bins):
    plt.axvline(
        common_range[b],
        linestyle="-.",
        linewidth=1.0,
        label=(
            "Selected background reflector"
            if i == 0
            else None
        ),
    )

plt.xlabel("Range (m)")
plt.ylabel("Magnitude Relative to Raw Main Target (dBc)")
plt.title(
    "Evaluation Ground Truth — Not Used by Suppression Algorithm"
)
plt.xlim(common_min, common_max)
plt.ylim(-70, 5)
plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()


# ============================================================
# PLOT 3: POINT-WISE SUPPRESSION
# ============================================================

plt.figure(
    figsize=(13, 5)
)

plt.plot(
    common_range,
    suppression_db,
    linewidth=1.2,
)

plt.axhline(
    0.0,
    linestyle="--",
    linewidth=1.0,
)

for b in artifact_bins:
    plt.plot(
        common_range[b],
        suppression_db[b],
        marker="o",
    )

for b in background_bins:
    plt.plot(
        common_range[b],
        suppression_db[b],
        marker="x",
    )

plt.xlabel("Range (m)")
plt.ylabel("Suppression (dB)")
plt.title(
    "Suppression at Every Range — "
    "Positive Values Mean the Complex Average Is Lower"
)
plt.xlim(common_min, common_max)
plt.grid(True)
plt.minorticks_on()
plt.tight_layout()

plt.show()