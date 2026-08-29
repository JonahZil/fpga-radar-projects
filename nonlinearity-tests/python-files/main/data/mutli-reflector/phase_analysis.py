from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

DATA_DIR = Path("python-files/main/data/two-reflector")
FILE_PATTERN = "ab_t{chirp_us}us_50_120.npy"

CHIRP_TIMES_US = np.arange(100, 241, 10)

RX_INDEX = 0
NUM_FRAMES = 1000

N = 128
FFT_LEN = 8192
ADC_FS = 2e6

C = 3e8
FREQ_START = 58.1e9
FREQ_END = 63.1e9
BANDWIDTH = FREQ_END - FREQ_START

PRIMARY_NOMINAL_M = 0.50
SECOND_NOMINAL_M = 1.29

PRIMARY_SEARCH_M = 0.15
SECOND_SEARCH_M = 0.15

MIN_RANGE_M = 0.15
MAX_RANGE_M = 3.0
COMMON_RANGE_STEP_M = 0.001

EPS = 1e-15

window = np.hanning(N)
fft_freq = np.fft.rfftfreq(FFT_LEN, 1.0 / ADC_FS)


def load_signal(filename):
    raw = np.load(filename)

    rx = raw[:, :, RX_INDEX]

    valid = ~(
        np.all(rx == 0, axis=1)
        | np.all(rx == 4095, axis=1)
    )

    rx = rx[valid]

    if len(rx) < NUM_FRAMES:
        print(f"{filename.name}: {len(rx)} valid frames")

    rx = rx[:NUM_FRAMES].astype(np.float64)
    rx -= 2048.0

    return np.mean(rx, axis=0)


def get_range_axis(chirp_us):
    chirp_time = chirp_us * 1e-6
    slope = BANDWIDTH / chirp_time

    return (
        C * fft_freq
        / (2.0 * slope)
    )


def get_spectrum(signal):
    return np.fft.rfft(
        signal * window,
        n=FFT_LEN
    )


def find_peak_range(signal, chirp_us, center, half_width):
    spectrum = get_spectrum(signal)
    ranges = get_range_axis(chirp_us)

    mask = (
        (ranges >= center - half_width)
        & (ranges <= center + half_width)
    )

    bins = np.where(mask)[0]

    peak_bin = bins[
        np.argmax(np.abs(spectrum[bins]))
    ]

    return ranges[peak_bin]


def complex_at_range(signal, chirp_us, target_range):
    chirp_time = chirp_us * 1e-6
    slope = BANDWIDTH / chirp_time

    beat_frequency = (
        2.0 * slope * target_range / C
    )

    n = np.arange(N)

    basis = np.exp(
        -1j
        * 2.0
        * np.pi
        * beat_frequency
        * n
        / ADC_FS
    )

    return np.sum(
        signal * window * basis
    )


def interp_complex(x_new, x, y):
    real = np.interp(
        x_new,
        x,
        y.real
    )

    imag = np.interp(
        x_new,
        x,
        y.imag
    )

    return real + 1j * imag


signals = {}
primary_peaks = []
second_peaks = []

for chirp_us in CHIRP_TIMES_US:

    filename = (
        DATA_DIR
        / FILE_PATTERN.format(
            chirp_us=chirp_us
        )
    )

    signal = load_signal(filename)

    signals[chirp_us] = signal

    primary_peaks.append(
        find_peak_range(
            signal,
            chirp_us,
            PRIMARY_NOMINAL_M,
            PRIMARY_SEARCH_M
        )
    )

    second_peaks.append(
        find_peak_range(
            signal,
            chirp_us,
            SECOND_NOMINAL_M,
            SECOND_SEARCH_M
        )
    )


primary_reference_range = np.median(
    primary_peaks
)

second_reference_range = np.median(
    second_peaks
)


records = []

for chirp_us, primary_peak in zip(
    CHIRP_TIMES_US,
    primary_peaks
):

    signal = signals[chirp_us]

    spectrum = get_spectrum(signal)
    ranges = get_range_axis(chirp_us)

    primary_complex = complex_at_range(
        signal,
        chirp_us,
        primary_reference_range
    )

    second_complex = complex_at_range(
        signal,
        chirp_us,
        second_reference_range
    )

    normalized = (
        spectrum
        / (primary_complex + EPS)
    )

    second_relative_phase = np.angle(
        second_complex
        * np.conj(primary_complex)
    )

    aligned_range = (
        ranges
        - primary_peak
        + primary_reference_range
    )

    records.append(
        {
            "range": aligned_range,
            "spectrum": normalized,
            "second_phase": second_relative_phase
        }
    )


common_min = max(
    MIN_RANGE_M,
    max(
        record["range"][0]
        for record in records
    )
)

common_max = min(
    MAX_RANGE_M,
    min(
        record["range"][-1]
        for record in records
    )
)

common_range = np.arange(
    common_min,
    common_max + 0.5 * COMMON_RANGE_STEP_M,
    COMMON_RANGE_STEP_M
)


spectra = []
second_phases = []

for record in records:

    spectra.append(
        interp_complex(
            common_range,
            record["range"],
            record["spectrum"]
        )
    )

    second_phases.append(
        record["second_phase"]
    )


spectra = np.stack(
    spectra,
    axis=0
)

second_phases = np.array(
    second_phases
)


magnitude_average = np.mean(
    np.abs(spectra),
    axis=0
)

primary_complex_average = np.abs(
    np.mean(
        spectra,
        axis=0
    )
)


second_phase_rotation = np.exp(
    -1j * second_phases
)

second_aligned_spectra = (
    spectra
    * second_phase_rotation[:, None]
)

second_complex_average = np.abs(
    np.mean(
        second_aligned_spectra,
        axis=0
    )
)


magnitude_db = (
    20.0
    * np.log10(
        magnitude_average + EPS
    )
)

primary_complex_db = (
    20.0
    * np.log10(
        primary_complex_average + EPS
    )
)

second_complex_db = (
    20.0
    * np.log10(
        second_complex_average + EPS
    )
)


second_bin = np.argmin(
    np.abs(
        common_range
        - second_reference_range
    )
)

h2_range = (
    2.0
    * primary_reference_range
)

h2_bin = np.argmin(
    np.abs(
        common_range
        - h2_range
    )
)


print()
print("PHASE-ALIGNED AVERAGING")
print("=======================")

print(
    f"Primary range:       "
    f"{primary_reference_range:.4f} m"
)

print(
    f"Second target range: "
    f"{second_reference_range:.4f} m"
)

print(
    f"H2 range:            "
    f"{common_range[h2_bin]:.4f} m"
)

print()

print("SECOND REAL REFLECTOR")
print(
    f"Magnitude average:       "
    f"{magnitude_db[second_bin]:.2f} dBc"
)

print(
    f"50 cm complex average:   "
    f"{primary_complex_db[second_bin]:.2f} dBc"
)

print(
    f"Second-target aligned:   "
    f"{second_complex_db[second_bin]:.2f} dBc"
)

print()

print("H2")
print(
    f"Magnitude average:       "
    f"{magnitude_db[h2_bin]:.2f} dBc"
)

print(
    f"50 cm complex average:   "
    f"{primary_complex_db[h2_bin]:.2f} dBc"
)

print(
    f"Second-target aligned:   "
    f"{second_complex_db[h2_bin]:.2f} dBc"
)

print()

print(
    f"Second target loss after alignment: "
    f"{magnitude_db[second_bin] - second_complex_db[second_bin]:.2f} dB"
)

print(
    f"H2 suppression after alignment:     "
    f"{magnitude_db[h2_bin] - second_complex_db[h2_bin]:.2f} dB"
)


plt.figure(figsize=(12, 7))

plt.plot(
    common_range,
    magnitude_db,
    linewidth=1.5,
    label="Magnitude average"
)

plt.plot(
    common_range,
    primary_complex_db,
    linewidth=1.5,
    label="50 cm phase-aligned complex average"
)

plt.plot(
    common_range,
    second_complex_db,
    linewidth=1.5,
    label="Second-reflector phase-aligned complex average"
)

plt.axvline(
    primary_reference_range,
    linestyle="--",
    linewidth=1.0
)

plt.axvline(
    second_reference_range,
    linestyle="--",
    linewidth=1.0
)

plt.axvline(
    h2_range,
    linestyle=":",
    linewidth=1.0
)

plt.xlabel("Range (m)")
plt.ylabel("Magnitude relative to primary target (dBc)")

plt.title(
    f"Phase Alignment Comparison — RX{RX_INDEX}"
)

plt.xlim(
    common_min,
    common_max
)

plt.ylim(
    -60,
    5
)

plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()
plt.show()