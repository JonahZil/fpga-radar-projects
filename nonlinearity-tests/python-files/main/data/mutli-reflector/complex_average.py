from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

DATA_DIR = Path("python-files/main/data/two-reflector")
CHIRP_TIMES_US = np.arange(100, 241, 10)
REFERENCE_CHIRP_US = 120
REFERENCE_FILES = 15

FILE_PATTERN = "ab_t{chirp_us}us_50_120.npy"
REFERENCE_PATTERN = "ab_t120us_50_120_{index}.npy"

RX_INDEX = 0
NUM_FRAMES = 1000

N = 128
FFT_LEN = 8192
ADC_FS = 2e6

C = 3e8
FREQ_START = 58.1e9
FREQ_END = 63.1e9
BANDWIDTH = FREQ_END - FREQ_START

TARGET_RANGE_M = 0.50
TARGET_SEARCH_HALF_WIDTH_M = 0.25
MIN_RANGE_M = 0.15
MAX_RANGE_M = 3.0
COMMON_RANGE_STEP_M = 0.001
EPS = 1e-15

hann_window = np.hanning(N)
fft_freq = np.fft.rfftfreq(FFT_LEN, d=1.0 / ADC_FS)


def load_valid_signal(filename):
    raw = np.load(filename)

    if raw.ndim != 3 or raw.shape[1] != N:
        raise ValueError(f"{filename}: unexpected shape {raw.shape}")
    if RX_INDEX >= raw.shape[2]:
        raise ValueError(f"{filename}: RX_INDEX={RX_INDEX} unavailable")

    signal = raw[:, :, RX_INDEX]
    valid = ~(
        np.all(signal == 0, axis=1)
        | np.all(signal == 4095, axis=1)
    )
    signal = signal[valid][:NUM_FRAMES].astype(np.float64)

    if len(signal) == 0:
        raise ValueError(f"{filename}: no valid frames")

    return signal - 2048.0


def average_fft(filename):
    signal = load_valid_signal(filename)
    average_signal = np.mean(signal, axis=0) * hann_window
    return np.fft.rfft(average_signal, n=FFT_LEN)


def frequency_to_range(frequency, chirp_us):
    slope = BANDWIDTH / (chirp_us * 1e-6)
    return C * frequency / (2.0 * slope)


def interp_complex(x_new, x, y):
    return np.interp(x_new, x, y.real) + 1j * np.interp(x_new, x, y.imag)


def find_target(spectrum, range_axis):
    mask = np.abs(range_axis - TARGET_RANGE_M) <= TARGET_SEARCH_HALF_WIDTH_M
    bins = np.where(mask)[0]
    target_bin = bins[np.argmax(np.abs(spectrum[bins]))]
    return range_axis[target_bin], spectrum[target_bin]


records = []

for chirp_us in CHIRP_TIMES_US:
    spectrum = average_fft(
        DATA_DIR / FILE_PATTERN.format(chirp_us=chirp_us)
    )
    range_axis = frequency_to_range(fft_freq, chirp_us)
    target_range, target_complex = find_target(spectrum, range_axis)
    records.append((range_axis, spectrum, target_range, target_complex))

target_reference_range = np.median([record[2] for record in records])
aligned_ranges = [
    record[0] - record[2] + target_reference_range
    for record in records
]

reference_signals = [
    load_valid_signal(
        DATA_DIR / REFERENCE_PATTERN.format(index=index)
    )
    for index in range(1, REFERENCE_FILES + 1)
]
reference_signal = np.concatenate(reference_signals, axis=0)
reference_spectrum = np.fft.rfft(
    np.mean(reference_signal, axis=0) * hann_window,
    n=FFT_LEN,
)
reference_range = frequency_to_range(fft_freq, REFERENCE_CHIRP_US)
reference_target_range, reference_target_complex = find_target(
    reference_spectrum,
    reference_range,
)
aligned_reference_range = (
    reference_range - reference_target_range + target_reference_range
)

all_ranges = aligned_ranges + [aligned_reference_range]
common_min = max(MIN_RANGE_M, max(x[0] for x in all_ranges))
common_max = min(MAX_RANGE_M, min(x[-1] for x in all_ranges))
common_range = np.arange(
    common_min,
    common_max + 0.5 * COMMON_RANGE_STEP_M,
    COMMON_RANGE_STEP_M,
)

normalized_spectra = np.stack([
    interp_complex(
        common_range,
        aligned_range,
        spectrum / (target_complex + EPS),
    )
    for aligned_range, (_, spectrum, _, target_complex)
    in zip(aligned_ranges, records)
])

reference_common = interp_complex(
    common_range,
    aligned_reference_range,
    reference_spectrum / (reference_target_complex + EPS),
)

reference_db = 20.0 * np.log10(np.abs(reference_common) + EPS)
magnitude_average_db = 20.0 * np.log10(
    np.mean(np.abs(normalized_spectra), axis=0) + EPS
)
complex_average_db = 20.0 * np.log10(
    np.abs(np.mean(normalized_spectra, axis=0)) + EPS
)


plt.close("all")
fig, ax = plt.subplots(figsize=(12, 7))

ax.plot(
    common_range,
    reference_db,
    linewidth=1.5,
    label=f"120 us reference ({len(reference_signal)} valid chirps)",
)
ax.plot(
    common_range,
    magnitude_average_db,
    linewidth=1.5,
    label="15 chirp lengths — magnitude average",
)
ax.plot(
    common_range,
    complex_average_db,
    linewidth=1.5,
    label="15 chirp lengths — complex average",
)

ax.set_xlabel("Aligned Range (m)")
ax.set_ylabel("Magnitude Relative to 50 cm Reflector (dBc)")
ax.set_title(f"Two-Reflector Averaging Comparison — RX{RX_INDEX}")
ax.set_xlim(common_min, common_max)
ax.set_ylim(-60, 5)
ax.grid(True)
ax.minorticks_on()
ax.legend()
fig.tight_layout()
plt.show()