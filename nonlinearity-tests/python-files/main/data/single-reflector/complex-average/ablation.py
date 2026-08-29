from pathlib import Path
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

    if raw.ndim != 3:
        raise ValueError(
            f"{filename}: expected "
            f"(frames, samples, receivers), got {raw.shape}"
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


def to_db(
    magnitude,
    reference,
):
    return (
        20.0
        * np.log10(
            magnitude / (reference + EPS)
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

    empty_spectra[chirp_us] = (
        process_file(filename)
    )


# ============================================================
# COMPLEX DIFFERENCE + TARGET EXTRACTION
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


target_reference_range = np.median(
    [
        r["target_range"]
        for r in records
    ]
)

target_magnitudes = np.array(
    [
        np.abs(
            r["target_complex"]
        )
        for r in records
    ]
)

reference_target_magnitude = np.mean(
    target_magnitudes
)


# ============================================================
# FIND COMMON SUPPORT
# ============================================================

unshifted_ranges = [
    r["range"]
    for r in records
]

shifted_ranges = [
    (
        r["range"]
        - r["target_range"]
        + target_reference_range
    )
    for r in records
]


common_min = max(
    MIN_RANGE_M,
    max(
        x[0]
        for x in unshifted_ranges
    ),
    max(
        x[0]
        for x in shifted_ranges
    ),
)

common_max = min(
    MAX_RANGE_M,
    min(
        x[-1]
        for x in unshifted_ranges
    ),
    min(
        x[-1]
        for x in shifted_ranges
    ),
)


common_range = np.arange(
    common_min,
    common_max
    + 0.5 * COMMON_RANGE_STEP_M,
    COMMON_RANGE_STEP_M,
)


# ============================================================
# BUILD DIFFERENT VERSIONS OF EACH CHIRP
# ============================================================

raw_no_shift = []
phase_no_shift = []

raw_shift = []
phase_shift = []
normalized_shift = []


for record in records:

    diff = record["diff"]

    target_complex = (
        record["target_complex"]
    )

    target_phase = np.angle(
        target_complex
    )

    phase_rotation = np.exp(
        -1j * target_phase
    )

    shifted_range = (
        record["range"]
        - record["target_range"]
        + target_reference_range
    )


    # --------------------------------------------------------
    # 1. Raw spectrum, no range shift
    # --------------------------------------------------------

    raw_no_shift.append(
        interp_complex(
            common_range,
            record["range"],
            diff,
        )
    )


    # --------------------------------------------------------
    # 2. Phase alignment only, no range shift
    # --------------------------------------------------------

    phase_no_shift.append(
        interp_complex(
            common_range,
            record["range"],
            diff * phase_rotation,
        )
    )


    # --------------------------------------------------------
    # 3. Range shift only
    # --------------------------------------------------------

    raw_shift.append(
        interp_complex(
            common_range,
            shifted_range,
            diff,
        )
    )


    # --------------------------------------------------------
    # 4. Phase alignment + range shift
    # --------------------------------------------------------

    phase_shift.append(
        interp_complex(
            common_range,
            shifted_range,
            diff * phase_rotation,
        )
    )


    # --------------------------------------------------------
    # 5. Full complex target normalization + range shift
    #
    # Rescale by mean target magnitude so the units remain
    # comparable with the phase-only cases.
    # --------------------------------------------------------

    normalized = (
        diff
        / (
            target_complex
            + EPS
        )
        * reference_target_magnitude
    )

    normalized_shift.append(
        interp_complex(
            common_range,
            shifted_range,
            normalized,
        )
    )


raw_no_shift = np.stack(
    raw_no_shift
)

phase_no_shift = np.stack(
    phase_no_shift
)

raw_shift = np.stack(
    raw_shift
)

phase_shift = np.stack(
    phase_shift
)

normalized_shift = np.stack(
    normalized_shift
)


# ============================================================
# FUSION
# ============================================================

# Magnitude controls
mag_control_no_shift = np.mean(
    np.abs(
        raw_no_shift
    ),
    axis=0,
)

mag_control_shift = np.mean(
    np.abs(
        raw_shift
    ),
    axis=0,
)

mag_control_normalized = np.mean(
    np.abs(
        normalized_shift
    ),
    axis=0,
)


# Raw complex average
raw_complex_no_shift = np.abs(
    np.mean(
        raw_no_shift,
        axis=0,
    )
)


# Phase-only complex average, without range shift
phase_complex_no_shift = np.abs(
    np.mean(
        phase_no_shift,
        axis=0,
    )
)


# Phase-only complex average, with range shift
phase_complex_shift = np.abs(
    np.mean(
        phase_shift,
        axis=0,
    )
)


# Full target normalization + range shift
full_normalized_shift = np.abs(
    np.mean(
        normalized_shift,
        axis=0,
    )
)


# ============================================================
# CONVERT TO COMMON dB REFERENCE
# ============================================================

spectra = {
    "Magnitude control":
        to_db(
            mag_control_no_shift,
            reference_target_magnitude,
        ),

    "Raw complex":
        to_db(
            raw_complex_no_shift,
            reference_target_magnitude,
        ),

    "Phase only":
        to_db(
            phase_complex_no_shift,
            reference_target_magnitude,
        ),

    "Phase + shift":
        to_db(
            phase_complex_shift,
            reference_target_magnitude,
        ),

    "Full normalization":
        to_db(
            full_normalized_shift,
            reference_target_magnitude,
        ),
}


# ============================================================
# TARGET AND STRONGEST-RESIDUAL METRICS
# ============================================================

target_eval_mask = (
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


print(
    "Method              | Target | "
    "Strongest residual | Target/ghost margin"
)

print(
    "-" * 69
)


for name, spectrum_db in spectra.items():

    target_db = np.max(
        spectrum_db[
            target_eval_mask
        ]
    )

    strongest_db = np.max(
        spectrum_db[
            background_mask
        ]
    )

    margin_db = (
        target_db
        - strongest_db
    )

    print(
        f"{name:<19} | "
        f"{target_db:6.2f} | "
        f"{strongest_db:18.2f} | "
        f"{margin_db:19.2f}"
    )


# ============================================================
# HARMONIC ABLATION
# ============================================================

no_shift_control_db = to_db(
    mag_control_no_shift,
    reference_target_magnitude,
)

shift_control_db = to_db(
    mag_control_shift,
    reference_target_magnitude,
)

normalized_control_db = to_db(
    mag_control_normalized,
    reference_target_magnitude,
)


raw_complex_db = spectra[
    "Raw complex"
]

phase_no_shift_db = spectra[
    "Phase only"
]

phase_shift_db = spectra[
    "Phase + shift"
]

full_normalized_db = spectra[
    "Full normalization"
]


print()
print(
    "Ghost | Raw complex | Phase only | "
    "Phase + shift | Full normalization"
)

print(
    "      | suppression | suppression | "
    "suppression    | suppression"
)

print(
    "-" * 74
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

    bins = np.where(
        ghost_mask
    )[0]

    if len(bins) == 0:
        continue


    # Peak locations are chosen from the magnitude controls,
    # not from the suppressed spectra.

    no_shift_peak = bins[
        np.argmax(
            no_shift_control_db[
                bins
            ]
        )
    ]

    shift_peak = bins[
        np.argmax(
            shift_control_db[
                bins
            ]
        )
    ]

    normalized_peak = bins[
        np.argmax(
            normalized_control_db[
                bins
            ]
        )
    ]


    raw_suppression = (
        no_shift_control_db[
            no_shift_peak
        ]
        - raw_complex_db[
            no_shift_peak
        ]
    )

    phase_only_suppression = (
        no_shift_control_db[
            no_shift_peak
        ]
        - phase_no_shift_db[
            no_shift_peak
        ]
    )

    phase_shift_suppression = (
        shift_control_db[
            shift_peak
        ]
        - phase_shift_db[
            shift_peak
        ]
    )

    full_suppression = (
        normalized_control_db[
            normalized_peak
        ]
        - full_normalized_db[
            normalized_peak
        ]
    )


    print(
        f"H{order:<4d} | "
        f"{raw_suppression:11.2f} | "
        f"{phase_only_suppression:11.2f} | "
        f"{phase_shift_suppression:14.2f} | "
        f"{full_suppression:18.2f}"
    )


# ============================================================
# MOST IMPORTANT VISUAL COMPARISON
# ============================================================

plt.figure(
    figsize=(12, 7)
)

plt.plot(
    common_range,
    shift_control_db,
    linewidth=1.5,
    label="Mean magnitude",
)

plt.plot(
    common_range,
    phase_shift_db,
    linewidth=1.5,
    label="Phase-aligned complex average",
)

plt.axvline(
    target_reference_range,
    linestyle="--",
    linewidth=1.0,
    label="Target",
)

plt.xlabel(
    "Aligned Range (m)"
)

plt.ylabel(
    "Magnitude Relative to Mean Target (dB)"
)

plt.title(
    f"Reflector {REFLECTOR_CM} cm — "
    f"Phase-Only Chirp-Diversity Fusion — RX{RX_INDEX}"
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