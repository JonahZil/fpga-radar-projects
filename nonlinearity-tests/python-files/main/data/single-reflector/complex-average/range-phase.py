from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt


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
GHOST_SEARCH_HALF_WIDTH_M = 0.10

MIN_RANGE_M = 0.15
MAX_RANGE_M = 3.0
COMMON_RANGE_STEP_M = 0.001

# Effective delay from the start of the FMCW ramp to ADC sample 0.
# Leave at 0 initially if it is not yet known. This is the parameter
# that can make the expected real-target phase vary substantially with
# chirp slope. Once the hardware timing is known, put it here.
ADC_START_OFFSET_US = 0.0

# The real BGT IF is sampled as a real signal, so the measured rFFT phase
# may correspond to either sign of the analytic dechirped phase depending
# on the mixer convention. Start with +1. If a known second real target is
# made less coherent, rerun with -1.
MIXER_PHASE_SIGN = +1.0

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
            f"{filename}: expected "
            f"(frames, samples, receivers), got {raw.shape}"
        )

    if raw.shape[1] != N:
        raise ValueError(
            f"{filename}: expected {N} samples, got {raw.shape[1]}"
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
        + 1j
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


def ideal_real_target_phase(
    range_m,
    chirp_time,
):
    """
    Ideal dechirped FMCW phase for a stationary point target.

    For delay tau = 2R/c and slope S = B/T, the model used here is

        phi(R, T) = sign * [
            2*pi*f_start*tau
            + 2*pi*S*tau*t_adc
            - pi*S*tau^2
        ]

    Only phase differences relative to the measured reference target are
    used later, so any chirp-independent constant phase is irrelevant to
    the coherent-average magnitude.
    """
    slope = BANDWIDTH / chirp_time
    tau = 2.0 * np.asarray(range_m) / C
    t_adc = ADC_START_OFFSET_US * 1e-6

    phase = (
        2.0 * np.pi * FREQ_START * tau
        + 2.0 * np.pi * slope * tau * t_adc
        - np.pi * slope * tau**2
    )

    return MIXER_PHASE_SIGN * phase


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
# COMPLEX DIFFERENCE + MAIN TARGET EXTRACTION
# ============================================================

expected_target_range = REFLECTOR_CM / 100.0
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
        (range_axis >= expected_target_range - TARGET_SEARCH_HALF_WIDTH_M)
        &
        (range_axis <= expected_target_range + TARGET_SEARCH_HALF_WIDTH_M)
    )

    target_bins = np.where(
        target_mask
    )[0]

    if len(target_bins) == 0:
        raise RuntimeError(
            f"No target-search bins for {chirp_us} us"
        )

    target_bin = target_bins[
        np.argmax(
            np.abs(
                diff[target_bins]
            )
        )
    ]

    target_range = range_axis[target_bin]
    target_complex = diff[target_bin]

    records.append(
        {
            "chirp_us": chirp_us,
            "chirp_time": chirp_time,
            "range": range_axis,
            "diff": diff,
            "target_range": target_range,
            "target_complex": target_complex,
        }
    )


# ============================================================
# COMMON RANGE AXIS
# ============================================================

# Keep the same small target-based range shift used in the previous
# analysis. This isolates the change in phase handling.
target_reference_range = np.median(
    [
        record["target_range"]
        for record in records
    ]
)

reference_target_magnitude = np.mean(
    [
        np.abs(
            record["target_complex"]
        )
        for record in records
    ]
)

shifted_ranges = []

for record in records:
    shifted_range = (
        record["range"]
        - record["target_range"]
        + target_reference_range
    )

    shifted_ranges.append(
        shifted_range
    )

common_min = max(
    MIN_RANGE_M,
    max(
        x[0]
        for x in shifted_ranges
    ),
)

common_max = min(
    MAX_RANGE_M,
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
# BUILD THREE VERSIONS OF EACH CHIRP
# ============================================================

raw_common = []
global_aligned_common = []
per_bin_aligned_common = []

# The per-bin model only needs to correct phase DIFFERENCES across
# chirp settings.  Any phase that is identical for every chirp at a
# given range cannot change the coherent-average magnitude, so we
# reference the model to one chirp.  This also removes the enormous
# carrier-phase gradient 2*pi*f_start*tau from the correction.
reference_model_chirp_time = records[0]["chirp_time"]


def target_relative_model_phase(range_m, chirp_time):
    """Ideal phase at range_m relative to the fixed main-target range."""
    return (
        ideal_real_target_phase(range_m, chirp_time)
        - ideal_real_target_phase(target_reference_range, chirp_time)
    )


reference_model_phase = target_relative_model_phase(
    common_range,
    reference_model_chirp_time,
)


for record, shifted_range in zip(
    records,
    shifted_ranges,
):
    diff = record["diff"]
    chirp_time = record["chirp_time"]
    target_phase = np.angle(
        record["target_complex"]
    )

    # --------------------------------------------------------
    # 1. Put every chirp on the SAME aligned range grid first.
    # --------------------------------------------------------

    spectrum_common = interp_complex(
        common_range,
        shifted_range,
        diff,
    )

    raw_common.append(
        spectrum_common
    )

    # --------------------------------------------------------
    # 2. OLD METHOD
    # One measured phase rotation for the entire chirp.
    # --------------------------------------------------------

    global_aligned = (
        spectrum_common
        * np.exp(-1j * target_phase)
    )

    global_aligned_common.append(
        global_aligned
    )

    # --------------------------------------------------------
    # 3. NEW METHOD
    #
    # After the old target rotation, a genuine target at range R
    # should retain the ideal target-relative phase
    #
    #   g_k(R) = phi(R, T_k) - phi(R_ref, T_k).
    #
    # Only the CHANGE of g_k with chirp setting matters for
    # coherent averaging.  Therefore rotate by
    #
    #   g_k(R) - g_refchirp(R).
    #
    # This guarantees zero extra correction at the main target and
    # avoids injecting a huge chirp-independent carrier-phase ramp.
    # --------------------------------------------------------

    current_model_phase = target_relative_model_phase(
        common_range,
        chirp_time,
    )

    extra_phase = (
        current_model_phase
        - reference_model_phase
    )

    per_bin_aligned = (
        global_aligned
        * np.exp(-1j * extra_phase)
    )

    per_bin_aligned_common.append(
        per_bin_aligned
    )


raw_common = np.stack(
    raw_common,
    axis=0,
)

global_aligned_common = np.stack(
    global_aligned_common,
    axis=0,
)

per_bin_aligned_common = np.stack(
    per_bin_aligned_common,
    axis=0,
)


# ============================================================
# FUSION
# ============================================================

magnitude_control = np.mean(
    np.abs(
        raw_common
    ),
    axis=0,
)

old_global_fused = np.abs(
    np.mean(
        global_aligned_common,
        axis=0,
    )
)

new_per_bin_fused = np.abs(
    np.mean(
        per_bin_aligned_common,
        axis=0,
    )
)

old_coherence = (
    old_global_fused
    / (
        magnitude_control
        + EPS
    )
)

new_coherence = (
    new_per_bin_fused
    / (
        magnitude_control
        + EPS
    )
)


# ============================================================
# dB SPECTRA
# ============================================================

control_db = to_db(
    magnitude_control,
    reference_target_magnitude,
)

old_db = to_db(
    old_global_fused,
    reference_target_magnitude,
)

new_db = to_db(
    new_per_bin_fused,
    reference_target_magnitude,
)

old_suppression_db = (
    control_db
    - old_db
)

new_suppression_db = (
    control_db
    - new_db
)


# ============================================================
# METRICS
# ============================================================

target_eval_mask = (
    np.abs(
        common_range
        - target_reference_range
    )
    <= TARGET_EVAL_HALF_WIDTH_M
)

background_mask = (
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


def summarize_method(
    name,
    spectrum_db,
):
    target_db = np.max(
        spectrum_db[
            target_eval_mask
        ]
    )

    p95_db = np.percentile(
        spectrum_db[
            background_mask
        ],
        95,
    )

    strongest_db = np.max(
        spectrum_db[
            background_mask
        ]
    )

    return {
        "name": name,
        "target": target_db,
        "p95": p95_db,
        "strongest": strongest_db,
    }


control_stats = summarize_method(
    "Magnitude control",
    control_db,
)

old_stats = summarize_method(
    "Old global phase",
    old_db,
)

new_stats = summarize_method(
    "New per-bin phase",
    new_db,
)


print()
print("============================================================")
print("PER-BIN EXPECTED REAL-TARGET PHASE FUSION")
print("============================================================")
print(
    f"Reflector: {REFLECTOR_CM} cm | "
    f"RX{RX_INDEX} | "
    f"ADC start offset: {ADC_START_OFFSET_US:.3f} us | "
    f"phase sign: {MIXER_PHASE_SIGN:+.0f}"
)
print(
    f"Measured target reference range: "
    f"{target_reference_range:.4f} m"
)
print()

print(
    "Method               | Target (dBc) | "
    "P95 background | Strongest residual"
)
print("-" * 72)

for stats in [
    control_stats,
    old_stats,
    new_stats,
]:
    print(
        f"{stats['name']:<20} | "
        f"{stats['target']:12.2f} | "
        f"{stats['p95']:14.2f} | "
        f"{stats['strongest']:18.2f}"
    )

print()
print(
    f"Old global median background suppression: "
    f"{np.median(old_suppression_db[background_mask]):.2f} dB"
)
print(
    f"New per-bin median background suppression: "
    f"{np.median(new_suppression_db[background_mask]):.2f} dB"
)

print(
    f"Old global strongest-residual suppression: "
    f"{control_stats['strongest'] - old_stats['strongest']:.2f} dB"
)
print(
    f"New per-bin strongest-residual suppression: "
    f"{control_stats['strongest'] - new_stats['strongest']:.2f} dB"
)

print()
print("Harmonic-region comparison")
print(
    "Ghost | Range (m) | Control | Old global | "
    "New per-bin | Old supp. | New supp. | New coherence"
)
print("-" * 101)

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

    peak_bin = ghost_bins[
        np.argmax(
            control_db[
                ghost_bins
            ]
        )
    ]

    print(
        f"H{order:<4d} | "
        f"{common_range[peak_bin]:9.3f} | "
        f"{control_db[peak_bin]:7.2f} | "
        f"{old_db[peak_bin]:10.2f} | "
        f"{new_db[peak_bin]:11.2f} | "
        f"{old_suppression_db[peak_bin]:9.2f} | "
        f"{new_suppression_db[peak_bin]:9.2f} | "
        f"{new_coherence[peak_bin]:13.3f}"
    )


# ============================================================
# DIAGNOSTIC: HOW DIFFERENT IS THE NEW ROTATION?
# ============================================================

# This is now the actual extra correction applied relative to the old
# global method.  With ADC_START_OFFSET_US = 0, it should be small.
# If it is hundreds of degrees, something is wrong with the model or
# range registration.

print()
print("Extra model phase excursion across chirps")
print("Range (m) | Excursion (deg)")
print("-" * 29)

for test_range in np.arange(
    0.5,
    min(common_max, 3.0) + 0.001,
    0.5,
):
    reference_phase = target_relative_model_phase(
        test_range,
        reference_model_chirp_time,
    )

    extra_phases = []

    for record in records:
        current_phase = target_relative_model_phase(
            test_range,
            record["chirp_time"],
        )

        extra_phases.append(
            current_phase - reference_phase
        )

    extra_phases = np.unwrap(
        np.asarray(extra_phases)
    )

    excursion_deg = np.degrees(
        np.ptp(extra_phases)
    )

    print(
        f"{test_range:9.3f} | "
        f"{excursion_deg:15.2f}"
    )


# ============================================================
# PLOT: SPECTRUM COMPARISON
# ============================================================

plt.figure(
    figsize=(12, 7)
)

plt.plot(
    common_range,
    control_db,
    linewidth=1.4,
    label="Mean magnitude",
)

plt.plot(
    common_range,
    old_db,
    linewidth=1.4,
    label="Old: one phase rotation per chirp",
)

plt.plot(
    common_range,
    new_db,
    linewidth=1.4,
    label="New: expected phase at each range bin",
)

plt.axvline(
    target_reference_range,
    linestyle="--",
    linewidth=1.0,
    label="Main target",
)

plt.xlabel(
    "Aligned Range (m)"
)

plt.ylabel(
    "Magnitude Relative to Mean Target (dB)"
)

plt.title(
    f"Reflector {REFLECTOR_CM} cm — "
    f"Global vs Per-Bin Phase Alignment — RX{RX_INDEX}"
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


# ============================================================
# PLOT: COHERENCE COMPARISON
# ============================================================

plt.figure(
    figsize=(12, 5)
)

plt.plot(
    common_range,
    old_coherence,
    linewidth=1.3,
    label="Old global alignment",
)

plt.plot(
    common_range,
    new_coherence,
    linewidth=1.3,
    label="New per-bin alignment",
)

plt.axvline(
    target_reference_range,
    linestyle="--",
    linewidth=1.0,
    label="Main target",
)

plt.xlabel(
    "Aligned Range (m)"
)

plt.ylabel(
    "Coherence"
)

plt.title(
    f"Chirp-to-Chirp Phase Coherence — RX{RX_INDEX}"
)

plt.xlim(
    common_min,
    common_max,
)

plt.ylim(
    0,
    1.05,
)

plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()
plt.show()