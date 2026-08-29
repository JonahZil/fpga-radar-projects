from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

DATA_DIR = Path("python-files/main/data/two-reflector")
FILE_PATTERN = "ab_t{chirp_us}us_50_120.npy"

CHIRP_TIMES_US = np.arange(100, 241, 10)

RX_INDEX = 0
MAX_VALID_FRAMES = 1000

N = 128
FFT_LEN = 8192
ADC_FS = 2e6

C = 3e8
FREQ_START = 58.1e9
FREQ_END = 63.1e9
BANDWIDTH = FREQ_END - FREQ_START

PRIMARY_NOMINAL_M = 0.50
SECOND_NOMINAL_M = 1.29
HARMONIC_ORDER = 2

PRIMARY_SEARCH_M = 0.15
SECOND_SEARCH_M = 0.15
HARMONIC_SEARCH_M = 0.06

MIN_RANGE_M = 0.15
MAX_RANGE_M = 3.0
COMMON_RANGE_STEP_M = 0.001

EPS = 1e-15

window = np.hanning(N)
fft_freq = np.fft.rfftfreq(FFT_LEN, 1.0 / ADC_FS)


def load_valid_frames(filename):
    raw = np.load(filename)

    if raw.ndim != 3:
        raise ValueError(f"{filename}: expected 3D data, got {raw.shape}")

    rx = raw[:, :, RX_INDEX]

    valid = ~(
        np.all(rx == 0, axis=1)
        | np.all(rx == 4095, axis=1)
    )

    return rx[valid].astype(np.float64)


def average_signal(frames):
    return np.mean(frames - 2048.0, axis=0)


def get_range_axis(chirp_us):
    chirp_time = chirp_us * 1e-6
    slope = BANDWIDTH / chirp_time

    return C * fft_freq / (2.0 * slope)


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
    return (
        np.interp(x_new, x, y.real)
        + 1j * np.interp(x_new, x, y.imag)
    )


all_frames = {}
valid_counts = []

for chirp_us in CHIRP_TIMES_US:
    filename = (
        DATA_DIR
        / FILE_PATTERN.format(
            chirp_us=chirp_us
        )
    )

    frames = load_valid_frames(filename)

    all_frames[chirp_us] = frames
    valid_counts.append(len(frames))

    print(
        f"{chirp_us:3d} us: "
        f"{len(frames)} valid / "
        f"{np.load(filename, mmap_mode='r').shape[0]} total"
    )


usable_frames = min(
    MAX_VALID_FRAMES,
    min(valid_counts)
)

train_count = usable_frames // 2
test_count = usable_frames - train_count

print()
print(f"Using {usable_frames} valid frames per chirp")
print(f"Training: {train_count}")
print(f"Testing:  {test_count}")


train_signals = {}
test_signals = {}

for chirp_us in CHIRP_TIMES_US:
    frames = all_frames[chirp_us][:usable_frames]

    train_signals[chirp_us] = average_signal(
        frames[:train_count]
    )

    test_signals[chirp_us] = average_signal(
        frames[train_count:]
    )


primary_peaks = []
second_peaks = []
h2_peaks = []

for chirp_us in CHIRP_TIMES_US:
    signal = train_signals[chirp_us]

    primary_peak = find_peak_range(
        signal,
        chirp_us,
        PRIMARY_NOMINAL_M,
        PRIMARY_SEARCH_M
    )

    second_peak = find_peak_range(
        signal,
        chirp_us,
        SECOND_NOMINAL_M,
        SECOND_SEARCH_M
    )

    h2_peak = find_peak_range(
        signal,
        chirp_us,
        HARMONIC_ORDER * primary_peak,
        HARMONIC_SEARCH_M
    )

    primary_peaks.append(primary_peak)
    second_peaks.append(second_peak)
    h2_peaks.append(h2_peak)


primary_range = np.median(primary_peaks)
second_range = np.median(second_peaks)
h2_range = np.median(h2_peaks)


real_train = []
h2_train = []

for chirp_us in CHIRP_TIMES_US:
    signal = train_signals[chirp_us]

    primary = complex_at_range(
        signal,
        chirp_us,
        primary_range
    )

    second = complex_at_range(
        signal,
        chirp_us,
        second_range
    )

    h2 = complex_at_range(
        signal,
        chirp_us,
        h2_range
    )

    real_train.append(
        second / (primary + EPS)
    )

    h2_train.append(
        h2 / (primary + EPS)
    )


real_train = np.array(real_train)
h2_train = np.array(h2_train)

a_real = np.exp(
    1j * np.angle(real_train)
)

a_h2 = np.exp(
    1j * np.angle(h2_train)
)


rho = (
    np.abs(np.vdot(a_real, a_h2))
    /
    (
        np.linalg.norm(a_real)
        * np.linalg.norm(a_h2)
    )
)


P_h2 = (
    np.eye(len(CHIRP_TIMES_US), dtype=complex)
    - np.outer(a_h2, np.conj(a_h2))
    / np.vdot(a_h2, a_h2)
)

projected_real = P_h2 @ a_real

denominator = np.vdot(
    a_real,
    projected_real
)

w_null = (
    projected_real
    / denominator
)


w_real = (
    a_real
    / np.vdot(a_real, a_real)
)


real_response = np.vdot(
    w_null,
    a_real
)

h2_response = np.vdot(
    w_null,
    a_h2
)

noise_penalty_db = 10.0 * np.log10(
    len(CHIRP_TIMES_US)
    * np.sum(np.abs(w_null) ** 2)
)


records = []

for chirp_us, primary_peak in zip(
    CHIRP_TIMES_US,
    primary_peaks
):
    signal = test_signals[chirp_us]

    spectrum = get_spectrum(signal)
    ranges = get_range_axis(chirp_us)

    primary = complex_at_range(
        signal,
        chirp_us,
        primary_range
    )

    normalized = (
        spectrum
        / (primary + EPS)
    )

    aligned_range = (
        ranges
        - primary_peak
        + primary_range
    )

    records.append(
        {
            "range": aligned_range,
            "spectrum": normalized
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


test_spectra = []

for record in records:
    test_spectra.append(
        interp_complex(
            common_range,
            record["range"],
            record["spectrum"]
        )
    )

test_spectra = np.stack(
    test_spectra,
    axis=0
)


magnitude_average = np.mean(
    np.abs(test_spectra),
    axis=0
)

real_aligned = np.abs(
    np.sum(
        np.conj(w_real)[:, None]
        * test_spectra,
        axis=0
    )
)

h2_null = np.abs(
    np.sum(
        np.conj(w_null)[:, None]
        * test_spectra,
        axis=0
    )
)


magnitude_db = 20.0 * np.log10(
    magnitude_average + EPS
)

real_aligned_db = 20.0 * np.log10(
    real_aligned + EPS
)

h2_null_db = 20.0 * np.log10(
    h2_null + EPS
)


second_bin = np.argmin(
    np.abs(common_range - second_range)
)

h2_bin = np.argmin(
    np.abs(common_range - h2_range)
)


print()
print("CONSTRAINED H2 NULL")
print("===================")

print(f"Primary range:       {primary_range:.4f} m")
print(f"Second target range: {second_range:.4f} m")
print(f"H2 range:            {h2_range:.4f} m")

print()
print(f"Phase correlation rho:       {rho:.4f}")
print(f"Expected real response:      {abs(real_response):.6f}")
print(f"Expected H2 response:        {abs(h2_response):.6e}")
print(f"Nulling noise penalty:       {noise_penalty_db:.2f} dB")

print()
print("TEST DATA")
print("---------")

print()
print("SECOND REAL REFLECTOR")

print(
    f"Magnitude average:   "
    f"{magnitude_db[second_bin]:.2f} dB"
)

print(
    f"Real phase aligned:  "
    f"{real_aligned_db[second_bin]:.2f} dB"
)

print(
    f"Constrained H2 null: "
    f"{h2_null_db[second_bin]:.2f} dB"
)

print(
    f"Target loss vs magnitude: "
    f"{magnitude_db[second_bin] - h2_null_db[second_bin]:.2f} dB"
)


print()
print("H2")

print(
    f"Magnitude average:   "
    f"{magnitude_db[h2_bin]:.2f} dB"
)

print(
    f"Real phase aligned:  "
    f"{real_aligned_db[h2_bin]:.2f} dB"
)

print(
    f"Constrained H2 null: "
    f"{h2_null_db[h2_bin]:.2f} dB"
)

print(
    f"H2 suppression vs magnitude: "
    f"{magnitude_db[h2_bin] - h2_null_db[h2_bin]:.2f} dB"
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
    real_aligned_db,
    linewidth=1.5,
    label="Real-target phase aligned"
)

plt.plot(
    common_range,
    h2_null_db,
    linewidth=1.5,
    label="Constrained H2 null"
)

plt.axvline(
    primary_range,
    linestyle="--",
    linewidth=1.0,
    label="Primary"
)

plt.axvline(
    second_range,
    linestyle="--",
    linewidth=1.0,
    label="Second reflector"
)

plt.axvline(
    h2_range,
    linestyle=":",
    linewidth=1.0,
    label="H2"
)

plt.xlabel("Range (m)")
plt.ylabel("Magnitude relative to per-chirp primary normalization (dB)")
plt.title(f"Constrained H2 Phase Null — RX{RX_INDEX}")

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