from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

BASE_DIR = Path("python-files/main/data")


FILES = [
    #("two-reflector/noref_t100us.npy", 100),
    #("two-reflector/noref_t110us.npy", 110),
    #("two-reflector/noref_t120us.npy", 120),
    #("two-reflector/noref_t130us.npy", 130),
    #("two-reflector/noref_t140us.npy", 140),
    #("two-reflector/noref_t150us.npy", 150),
    #("two-reflector/noref_t160us.npy", 160),
    #("two-reflector/noref_t170us.npy", 170),
    #("two-reflector/noref_t180us.npy", 180),
    #("two-reflector/noref_t190us.npy", 190),
    #("two-reflector/noref_t200us.npy", 200),
    #("two-reflector/noref_t210us.npy", 210),
    #("two-reflector/noref_t220us.npy", 220),
    #("two-reflector/noref_t230us.npy", 230),
    #("two-reflector/noref_t240us.npy", 240),

    ("two-reflector/ab_t100us_50_120.npy", 100),
    ("two-reflector/a_t100us_50.npy", 100),
    ("two-reflector/b_t100us_120.npy", 100),
    
]

RX_INDEX = 0
NUM_FFT_FRAMES = 1000

N = 128
FFT_SIZE = 4096

FREQ_START = 58.1e9
FREQ_END = 63.1e9
ADC_SAMPLING_FREQ = 2e6
SPEED_OF_LIGHT = 3e8

PLOT_MAX_DISTANCE = 4.0

X_AXIS = "range"


def calculate_fft(filename, num_frames, rx_index):
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

    # Remove frames that are entirely zero across all samples
    # and all receivers.
    zero_frames = np.all(raw_frames == 0, axis=(1, 2))
    num_removed = np.sum(zero_frames)

    raw_frames = raw_frames[~zero_frames]

    print(
        f"Removed {num_removed} all-zero frames "
        f"({100 * num_removed / (len(raw_frames) + num_removed):.2f}%)"
    )

    rx_data = raw_frames[:, :, rx_index]

    frames_to_use = min(num_frames, rx_data.shape[0])
    rx_data = rx_data[:frames_to_use].astype(np.float64)

    rx_data -= 2048.0

    window = np.hanning(N)
    windowed = rx_data * window

    fft_data = np.fft.rfft(
        windowed,
        n=FFT_SIZE,
        axis=1
    )

    magnitude = np.abs(fft_data)

    average_magnitude = np.mean(
        magnitude,
        axis=0
    )

    average_db = 20 * np.log10(
        average_magnitude + 1e-12
    )

    beat_frequency = np.fft.rfftfreq(
        FFT_SIZE,
        d=1.0 / ADC_SAMPLING_FREQ
    )

    return beat_frequency, average_db, frames_to_use


def frequency_to_range(beat_frequency, chirp_us):
    chirp_time = chirp_us * 1e-6

    bandwidth = FREQ_END - FREQ_START
    chirp_slope = bandwidth / chirp_time

    distance = (
        SPEED_OF_LIGHT * beat_frequency
        / (2.0 * chirp_slope)
    )

    return distance


plt.figure(figsize=(12, 6))

for filename, chirp_us in FILES:

    beat_frequency, average_db, frames_used = calculate_fft(
        filename,
        NUM_FFT_FRAMES,
        RX_INDEX
    )

    if X_AXIS == "range":

        distance = frequency_to_range(
            beat_frequency,
            chirp_us
        )

        mask = (
            (distance > 0)
            & (distance <= PLOT_MAX_DISTANCE)
        )

        plt.plot(
            distance[mask],
            average_db[mask],
            label=f"{chirp_us} us"
        )

    elif X_AXIS == "frequency":

        mask = beat_frequency > 0

        plt.plot(
            beat_frequency[mask] / 1e3,
            average_db[mask],
            label=f"{chirp_us} us"
        )

    else:
        raise ValueError(
            'X_AXIS must be "range" or "frequency"'
        )

    print(
        f"Using RX{RX_INDEX}, "
        f"{frames_used} frames, "
        f"{chirp_us} us chirp"
    )


if X_AXIS == "range":
    plt.xlabel("Range (m)")
    plt.xlim(0, PLOT_MAX_DISTANCE)
else:
    plt.xlabel("Beat Frequency (kHz)")

plt.ylabel("Magnitude (dB)")
plt.title(
    f"Average FFT - RX{RX_INDEX} - "
    f"{NUM_FFT_FRAMES} frames"
)

plt.grid(True)
plt.minorticks_on()
plt.legend()
plt.tight_layout()
plt.show()