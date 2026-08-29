from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

BASE_DIR = Path("python-files/main/data")

FILES = [
    ("two-reflector/a_t100us_50.npy", 100),
    ("two-reflector/a_t110us_50.npy", 110),
    ("two-reflector/a_t120us_50.npy", 120),
    ("two-reflector/a_t130us_50.npy", 130),
    ("two-reflector/a_t140us_50.npy", 140),
    ("two-reflector/a_t150us_50.npy", 150),
    ("two-reflector/a_t160us_50.npy", 160),
    ("two-reflector/a_t170us_50.npy", 170),
    ("two-reflector/a_t180us_50.npy", 180),
    ("two-reflector/a_t190us_50.npy", 190),
    ("two-reflector/a_t200us_50.npy", 200),
    ("two-reflector/a_t210us_50.npy", 210),
    ("two-reflector/a_t220us_50.npy", 220),
    ("two-reflector/a_t230us_50.npy", 230),
    ("two-reflector/a_t240us_50.npy", 240),
]

RX_INDEX = 1
NUM_FFT_FRAMES = 1000

N = 128
FFT_SIZE = 4096

FREQ_START = 58.1e9
FREQ_END = 63.1e9
ADC_SAMPLING_FREQ = 2e6
SPEED_OF_LIGHT = 3e8

# Approximate range of the real reflector
TARGET_RANGE = 0.50

# FFT searches this distance either side of TARGET_RANGE
TARGET_SEARCH_HALF_WIDTH = 0.08

# Harmonics to measure
HARMONICS = [1, 2, 3]


def range_to_frequency(distance, chirp_us):
    chirp_time = chirp_us * 1e-6

    bandwidth = FREQ_END - FREQ_START
    chirp_slope = bandwidth / chirp_time

    beat_frequency = (
        2.0 * chirp_slope * distance
        / SPEED_OF_LIGHT
    )

    return beat_frequency


def frequency_to_range(beat_frequency, chirp_us):
    chirp_time = chirp_us * 1e-6

    bandwidth = FREQ_END - FREQ_START
    chirp_slope = bandwidth / chirp_time

    distance = (
        SPEED_OF_LIGHT * beat_frequency
        / (2.0 * chirp_slope)
    )

    return distance


def load_frames(filename):
    path = BASE_DIR / filename

    raw_frames = np.load(path)

    print(f"\n{filename}")
    print(f"Shape: {raw_frames.shape}")
    print(f"dtype: {raw_frames.dtype}")

    if raw_frames.ndim != 3:
        raise ValueError(
            f"Expected shape (frames, samples, receivers), "
            f"got {raw_frames.shape}"
        )

    if raw_frames.shape[1] != N:
        raise ValueError(
            f"Expected {N} samples per frame, "
            f"got {raw_frames.shape[1]}"
        )

    rx_data = raw_frames[:, :, RX_INDEX]

    frames_to_use = min(
        NUM_FFT_FRAMES,
        rx_data.shape[0]
    )

    rx_data = rx_data[:frames_to_use].astype(np.float64)

    # ADC offset removal
    rx_data -= 2048.0

    return rx_data, frames_to_use


def quadratic_peak_frequency(frequencies, magnitude, peak_index):
    """
    Refine an FFT peak location using 3-point parabolic interpolation
    of the log magnitude.
    """

    if peak_index <= 0 or peak_index >= len(magnitude) - 1:
        return frequencies[peak_index]

    y1 = np.log(magnitude[peak_index - 1] + 1e-15)
    y2 = np.log(magnitude[peak_index] + 1e-15)
    y3 = np.log(magnitude[peak_index + 1] + 1e-15)

    denominator = y1 - 2.0 * y2 + y3

    if abs(denominator) < 1e-15:
        return frequencies[peak_index]

    delta = 0.5 * (y1 - y3) / denominator

    bin_width = frequencies[1] - frequencies[0]

    return frequencies[peak_index] + delta * bin_width


def find_fundamental_frequency(rx_data, chirp_us):
    """
    Locate the actual fundamental target frequency near TARGET_RANGE.
    """

    window = np.hanning(N)

    fft_data = np.fft.rfft(
        rx_data * window,
        n=FFT_SIZE,
        axis=1
    )

    average_magnitude = np.mean(
        np.abs(fft_data),
        axis=0
    )

    frequencies = np.fft.rfftfreq(
        FFT_SIZE,
        d=1.0 / ADC_SAMPLING_FREQ
    )

    low_range = TARGET_RANGE - TARGET_SEARCH_HALF_WIDTH
    high_range = TARGET_RANGE + TARGET_SEARCH_HALF_WIDTH

    low_frequency = range_to_frequency(
        low_range,
        chirp_us
    )

    high_frequency = range_to_frequency(
        high_range,
        chirp_us
    )

    mask = (
        (frequencies >= low_frequency)
        & (frequencies <= high_frequency)
    )

    indices = np.flatnonzero(mask)

    if len(indices) == 0:
        raise ValueError(
            f"No FFT bins found around target for {chirp_us} us"
        )

    local_peak = np.argmax(
        average_magnitude[indices]
    )

    peak_index = indices[local_peak]

    refined_frequency = quadratic_peak_frequency(
        frequencies,
        average_magnitude,
        peak_index
    )

    return refined_frequency


def fit_harmonics(rx_data, fundamental_frequency):
    """
    Jointly fit sinusoids at

        f_b, 2*f_b, 3*f_b, ...

    directly to each raw frame.

    This avoids phase errors caused by selecting the nearest FFT bin.
    """

    t = np.arange(N) / ADC_SAMPLING_FREQ

    active_harmonics = []

    columns = [
        np.ones(N)
    ]

    for harmonic in HARMONICS:

        frequency = (
            harmonic * fundamental_frequency
        )

        if frequency >= ADC_SAMPLING_FREQ / 2:
            print(
                f"Skipping H{harmonic}: "
                f"{frequency / 1e3:.2f} kHz exceeds Nyquist"
            )
            continue

        active_harmonics.append(harmonic)

        angle = 2.0 * np.pi * frequency * t

        columns.append(
            np.cos(angle)
        )

        columns.append(
            np.sin(angle)
        )

    design_matrix = np.column_stack(columns)

    # Solve all frames simultaneously.
    #
    # Model:
    #
    # x(t) = DC
    #      + a1 cos(wt) + b1 sin(wt)
    #      + a2 cos(2wt) + b2 sin(2wt)
    #      + ...
    #
    coefficients = np.linalg.lstsq(
        design_matrix,
        rx_data.T,
        rcond=None
    )[0]

    results = {}

    row = 1

    for harmonic in active_harmonics:

        cos_coefficient = coefficients[row]
        sin_coefficient = coefficients[row + 1]

        row += 2

        # If
        #
        # x = A cos(wt + phi)
        #
        # then
        #
        # x = A cos(phi) cos(wt)
        #   - A sin(phi) sin(wt)
        #
        # so the complex phasor is:
        #
        # A * exp(j phi) = a - j*b
        #
        phasors = (
            cos_coefficient
            - 1j * sin_coefficient
        )

        average_phasor = np.mean(phasors)

        average_amplitude = np.mean(
            np.abs(phasors)
        )

        phase = np.angle(
            average_phasor
        )

        # 1.0 = perfectly phase coherent across frames
        # 0.0 = completely incoherent
        coherence = (
            np.abs(average_phasor)
            / (average_amplitude + 1e-15)
        )

        results[harmonic] = {
            "frequency": (
                harmonic * fundamental_frequency
            ),
            "phase": phase,
            "amplitude": average_amplitude,
            "coherence": coherence,
        }

    return results


def unwrap_columns(phases):
    """
    Unwrap each harmonic independently across chirp lengths.
    """

    output = np.full_like(
        phases,
        np.nan,
        dtype=np.float64
    )

    for column in range(phases.shape[1]):

        valid = np.isfinite(
            phases[:, column]
        )

        if np.any(valid):
            output[valid, column] = np.unwrap(
                phases[valid, column]
            )

    return output


# ============================================================
# ANALYZE FILES
# ============================================================

records = []

for filename, chirp_us in FILES:

    rx_data, frames_used = load_frames(
        filename
    )

    fundamental_frequency = find_fundamental_frequency(
        rx_data,
        chirp_us
    )

    measured_range = frequency_to_range(
        fundamental_frequency,
        chirp_us
    )

    harmonic_results = fit_harmonics(
        rx_data,
        fundamental_frequency
    )

    records.append({
        "filename": filename,
        "chirp_us": chirp_us,
        "frames_used": frames_used,
        "fundamental_frequency": fundamental_frequency,
        "measured_range": measured_range,
        "harmonics": harmonic_results,
    })


# Sort by chirp length
records.sort(
    key=lambda x: x["chirp_us"]
)

chirp_lengths = np.array([
    record["chirp_us"]
    for record in records
])


# ============================================================
# PRINT FUNDAMENTAL FREQUENCIES
# ============================================================

print("\n")
print("=" * 70)
print("FUNDAMENTAL TARGET")
print("=" * 70)

print(
    "Chirp | Fundamental | Measured range"
)

print("-" * 70)

for record in records:

    print(
        f"{record['chirp_us']:5d} | "
        f"{record['fundamental_frequency'] / 1e3:10.3f} kHz | "
        f"{record['measured_range']:8.4f} m"
    )


# ============================================================
# BUILD PHASE AND COHERENCE MATRICES
# ============================================================

num_chirps = len(records)
num_harmonics = len(HARMONICS)

phases = np.full(
    (num_chirps, num_harmonics),
    np.nan
)

coherences = np.full(
    (num_chirps, num_harmonics),
    np.nan
)

for i, record in enumerate(records):

    for j, harmonic in enumerate(HARMONICS):

        if harmonic in record["harmonics"]:

            phases[i, j] = (
                record["harmonics"][harmonic]["phase"]
            )

            coherences[i, j] = (
                record["harmonics"][harmonic]["coherence"]
            )


# ============================================================
# PRINT ABSOLUTE PHASE
# ============================================================

print("\n")
print("=" * 100)
print("ABSOLUTE HARMONIC PHASE")
print("=" * 100)

header = "Chirp"

for harmonic in HARMONICS:
    header += f" | H{harmonic:1d} phase"

print(header)
print("-" * 100)

for i, chirp_us in enumerate(chirp_lengths):

    line = f"{chirp_us:5d}"

    for j in range(num_harmonics):

        if np.isfinite(phases[i, j]):

            phase_deg = np.degrees(
                phases[i, j]
            )

            line += f" | {phase_deg:8.2f}°"

        else:
            line += " |      N/A"

    print(line)


# ============================================================
# PLOT ABSOLUTE HARMONIC PHASE
# ============================================================

phase_deg = np.degrees(phases)

plt.figure(figsize=(11, 6))

for j, harmonic in enumerate(HARMONICS):

    plt.plot(
        chirp_lengths,
        phase_deg[:, j],
        marker="o",
        label=f"H{harmonic}"
    )

plt.axhline(
    0,
    linewidth=1
)

plt.xlabel("Chirp length (us)")
plt.ylabel("Absolute phase (degrees)")

plt.title(
    f"Absolute harmonic phase - RX{RX_INDEX}"
)

plt.ylim(-180, 180)
plt.yticks(np.arange(-180, 181, 45))
plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()


# ============================================================
# PLOT ABSOLUTE HARMONIC PHASE IN POLAR FORM
# ============================================================

fig = plt.figure(figsize=(9, 9))
ax = fig.add_subplot(111, projection="polar")

for j, harmonic in enumerate(HARMONICS):

    valid = np.isfinite(phases[:, j])

    ax.plot(
        phases[valid, j],
        chirp_lengths[valid],
        marker="o",
        label=f"H{harmonic}"
    )

ax.set_theta_zero_location("E")
ax.set_theta_direction(1)
ax.set_thetalim(-np.pi, np.pi)
ax.set_thetagrids(
    np.arange(0, 360, 45),
    labels=["0°", "45°", "90°", "135°", "180°", "-135°", "-90°", "-45°"]
)
ax.set_rlabel_position(135)
ax.set_xlabel("Phase angle")
ax.set_ylabel("Chirp length (us)")
ax.set_title(
    f"Absolute harmonic phase in polar form - RX{RX_INDEX}\n"
    f"(radius = chirp length, angle = phase)"
)
ax.grid(True)
ax.legend(loc="upper right", bbox_to_anchor=(1.20, 1.10))
plt.tight_layout()


# ============================================================
# PRINT COHERENCE
# ============================================================

print("\n")
print("=" * 100)
print("PHASE COHERENCE ACROSS FRAMES")
print("=" * 100)

header = "Chirp"

for harmonic in HARMONICS:
    header += f" | H{harmonic}"

print(header)
print("-" * 100)

for i, chirp_us in enumerate(chirp_lengths):

    line = f"{chirp_us:5d}"

    for j in range(num_harmonics):

        if np.isfinite(coherences[i, j]):
            line += f" | {coherences[i, j]:8.4f}"
        else:
            line += " |      N/A"

    print(line)


# ============================================================
# PHASE CHANGE RELATIVE TO FIRST CHIRP
# ============================================================

unwrapped_phases = unwrap_columns(
    phases
)

phase_change = np.full_like(
    unwrapped_phases,
    np.nan
)

for j in range(num_harmonics):

    valid = np.flatnonzero(
        np.isfinite(unwrapped_phases[:, j])
    )

    if len(valid) > 0:

        reference = unwrapped_phases[
            valid[0],
            j
        ]

        phase_change[:, j] = (
            unwrapped_phases[:, j]
            - reference
        )


phase_change_deg = np.degrees(
    phase_change
)


print("\n")
print("=" * 100)
print(
    f"PHASE CHANGE RELATIVE TO "
    f"{chirp_lengths[0]} us"
)
print("=" * 100)

header = "Chirp"

for harmonic in HARMONICS:
    header += f" | ΔH{harmonic}"

print(header)
print("-" * 100)

for i, chirp_us in enumerate(chirp_lengths):

    line = f"{chirp_us:5d}"

    for j in range(num_harmonics):

        if np.isfinite(phase_change_deg[i, j]):
            line += (
                f" | "
                f"{phase_change_deg[i, j]:8.2f}°"
            )
        else:
            line += " |      N/A"

    print(line)


# ============================================================
# PLOT RAW HARMONIC PHASE CHANGE
# ============================================================

plt.figure(figsize=(11, 6))

for j, harmonic in enumerate(HARMONICS):

    plt.plot(
        chirp_lengths,
        phase_change_deg[:, j],
        marker="o",
        label=f"H{harmonic}"
    )

plt.axhline(
    0,
    linewidth=1
)

plt.xlabel("Chirp length (us)")
plt.ylabel("Phase change (degrees)")

plt.title(
    f"Harmonic phase change - RX{RX_INDEX}"
)

plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()


# ============================================================
# PHI_n - n*PHI_1
# ============================================================

fundamental_index = HARMONICS.index(1)

relative_phase = {}

for j, harmonic in enumerate(HARMONICS):

    if harmonic == 1:
        continue

    residual = np.angle(
        np.exp(
            1j * (
                phases[:, j]
                - harmonic
                * phases[:, fundamental_index]
            )
        )
    )

    residual = np.unwrap(
        residual
    )

    # Show CHANGE in this quantity relative
    # to the first chirp.
    residual -= residual[0]

    relative_phase[harmonic] = np.degrees(
        residual
    )


print("\n")
print("=" * 100)
print("CHANGE IN phi_n - n*phi_1")
print("=" * 100)

header = "Chirp"

for harmonic in HARMONICS:

    if harmonic != 1:
        header += f" | H{harmonic}"

print(header)
print("-" * 100)

for i, chirp_us in enumerate(chirp_lengths):

    line = f"{chirp_us:5d}"

    for harmonic in HARMONICS:

        if harmonic == 1:
            continue

        line += (
            f" | "
            f"{relative_phase[harmonic][i]:8.2f}°"
        )

    print(line)


# ============================================================
# PLOT phi_n - n*phi_1 CHANGE
# ============================================================

plt.figure(figsize=(11, 6))

for harmonic in HARMONICS:

    if harmonic == 1:
        continue

    plt.plot(
        chirp_lengths,
        relative_phase[harmonic],
        marker="o",
        label=f"H{harmonic}"
    )

plt.axhline(
    0,
    linewidth=1
)

plt.xlabel("Chirp length (us)")
plt.ylabel(
    "Change in phase residual (degrees)"
)

plt.title(
    r"Change in $\phi_n - n\phi_1$ "
    f"- RX{RX_INDEX}"
)

plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()

plt.show()