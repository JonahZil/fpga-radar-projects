from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt


# ============================================================
# SETTINGS
# ============================================================

DATA_DIR = Path("python-files/main/data/chirp-lengths")

CHIRP_TIMES_US = np.arange(100, 241, 10)

REFLECTOR_DISTANCES_CM = [
    50,
    100,
    150,
]

RX_INDEX = 0

FILE_PATTERN = "t{chirp_us}us-{distance_cm}.npy"

NUM_FRAMES = 1000

N = 128
FFT_LEN = 8192
ADC_FS = 2e6

C = 3e8

FREQ_START = 58.1e9
FREQ_END = 63.1e9
BANDWIDTH = FREQ_END - FREQ_START

TARGET_SEARCH_HALF_WIDTH_M = 0.25

EPS = 1e-15

window = np.hanning(N)
sample_index = np.arange(N)

fft_freq = np.fft.rfftfreq(
    FFT_LEN,
    d=1.0 / ADC_FS,
)


# ============================================================
# HELPERS
# ============================================================

def load_signal(filename):

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

    signal = np.mean(
        signal,
        axis=0,
    )

    signal *= window

    return signal


def chirp_slope(chirp_us):

    return (
        BANDWIDTH
        / (chirp_us * 1e-6)
    )


def frequency_to_range(
    frequency,
    chirp_us,
):

    slope = chirp_slope(
        chirp_us
    )

    return (
        C * frequency
        / (2.0 * slope)
    )


def range_to_frequency(
    range_m,
    chirp_us,
):

    slope = chirp_slope(
        chirp_us
    )

    return (
        2.0
        * slope
        * range_m
        / C
    )


def dft_at_frequency(
    signal,
    frequency,
):

    rotation = np.exp(
        -2j
        * np.pi
        * frequency
        * sample_index
        / ADC_FS
    )

    return np.sum(
        signal
        * rotation
    )


def target_delay(range_m):

    return (
        2.0
        * range_m
        / C
    )


# ============================================================
# FIRST PASS:
# FIND ACTUAL REFLECTOR RANGE
# ============================================================

target_ranges = {}

signals = {}


for distance_cm in REFLECTOR_DISTANCES_CM:

    expected_range = (
        distance_cm / 100.0
    )

    detected_ranges = []

    signals[
        distance_cm
    ] = {}


    for chirp_us in CHIRP_TIMES_US:

        filename = (
            DATA_DIR
            / FILE_PATTERN.format(
                chirp_us=chirp_us,
                distance_cm=distance_cm,
            )
        )

        signal = load_signal(
            filename
        )

        signals[
            distance_cm
        ][
            chirp_us
        ] = signal


        spectrum = np.fft.rfft(
            signal,
            n=FFT_LEN,
        )

        ranges = frequency_to_range(
            fft_freq,
            chirp_us,
        )


        mask = (
            np.abs(
                ranges
                - expected_range
            )
            <= TARGET_SEARCH_HALF_WIDTH_M
        )

        bins = np.where(
            mask
        )[0]

        target_bin = bins[
            np.argmax(
                np.abs(
                    spectrum[bins]
                )
            )
        ]

        detected_ranges.append(
            ranges[target_bin]
        )


    # One fixed physical range is used
    # for the entire chirp sweep.
    target_ranges[
        distance_cm
    ] = np.median(
        detected_ranges
    )


# ============================================================
# MEASURE TARGET PHASE
# ============================================================

slopes = np.array([
    chirp_slope(chirp_us)
    for chirp_us in CHIRP_TIMES_US
])


phase_data = {}


for distance_cm in REFLECTOR_DISTANCES_CM:

    fixed_range = (
        target_ranges[
            distance_cm
        ]
    )

    phases = []


    for chirp_us in CHIRP_TIMES_US:

        signal = (
            signals[
                distance_cm
            ][
                chirp_us
            ]
        )

        frequency = (
            range_to_frequency(
                fixed_range,
                chirp_us,
            )
        )

        target_complex = (
            dft_at_frequency(
                signal,
                frequency,
            )
        )

        phases.append(
            np.angle(
                target_complex
            )
        )


    phase_data[
        distance_cm
    ] = np.unwrap(
        phases
    )


# ============================================================
# INDIVIDUAL LINEAR FITS
# ============================================================

slope_center = np.mean(
    slopes
)

slope_offset = (
    slopes
    - slope_center
)


individual_results = []


for distance_cm in REFLECTOR_DISTANCES_CM:

    range_m = (
        target_ranges[
            distance_cm
        ]
    )

    phase = (
        phase_data[
            distance_cm
        ]
    )


    phase_slope, intercept = np.polyfit(
        slope_offset,
        phase,
        1,
    )


    predicted = (
        intercept
        + phase_slope
        * slope_offset
    )


    residual = (
        phase
        - predicted
    )

    ss_res = np.sum(
        residual**2
    )

    ss_tot = np.sum(
        (
            phase
            - np.mean(phase)
        )**2
    )

    r2 = (
        1.0
        - ss_res
        / (ss_tot + EPS)
    )


    tau = target_delay(
        range_m
    )


    # Model:
    #
    # m = sign * (
    #       2*pi*tau*t_adc
    #       - pi*tau^2
    #     )
    #
    # Solve for both possible phase signs.


    t_adc_plus = (
        phase_slope
        + np.pi * tau**2
    ) / (
        2.0
        * np.pi
        * tau
    )


    t_adc_minus = (
        -phase_slope
        + np.pi * tau**2
    ) / (
        2.0
        * np.pi
        * tau
    )


    individual_results.append(
        {
            "distance_cm":
                distance_cm,

            "range":
                range_m,

            "phase_slope":
                phase_slope,

            "intercept":
                intercept,

            "r2":
                r2,

            "t_plus":
                t_adc_plus,

            "t_minus":
                t_adc_minus,
        }
    )


# ============================================================
# JOINT FIT
#
# One t_adc for all reflector distances.
# Each experiment has its own arbitrary phase intercept.
# ============================================================

def joint_fit(sign):

    num_targets = len(
        REFLECTOR_DISTANCES_CM
    )

    rows = []
    values = []


    for target_index, distance_cm in enumerate(
        REFLECTOR_DISTANCES_CM
    ):

        range_m = (
            target_ranges[
                distance_cm
            ]
        )

        tau = target_delay(
            range_m
        )

        measured_phase = (
            phase_data[
                distance_cm
            ]
        )


        for chirp_index in range(
            len(CHIRP_TIMES_US)
        ):

            ds = slope_offset[
                chirp_index
            ]


            # Model:
            #
            # phi =
            # intercept
            # + sign * ds *
            # (
            #     2*pi*tau*t_adc
            #     - pi*tau^2
            # )
            #
            # Move the known tau^2 part
            # to the measured side.

            corrected_phase = (
                measured_phase[
                    chirp_index
                ]
                +
                sign
                * np.pi
                * tau**2
                * ds
            )


            row = np.zeros(
                num_targets + 1
            )

            # Separate intercept for
            # each reflector experiment.
            row[target_index] = 1.0

            # Shared ADC timing offset.
            row[-1] = (
                sign
                * 2.0
                * np.pi
                * tau
                * ds
            )


            rows.append(
                row
            )

            values.append(
                corrected_phase
            )


    A = np.asarray(
        rows
    )

    b = np.asarray(
        values
    )


    solution, _, _, _ = np.linalg.lstsq(
        A,
        b,
        rcond=None,
    )


    t_adc = solution[-1]


    # Calculate phase prediction error.
    errors = []


    for target_index, distance_cm in enumerate(
        REFLECTOR_DISTANCES_CM
    ):

        range_m = (
            target_ranges[
                distance_cm
            ]
        )

        tau = target_delay(
            range_m
        )

        intercept = solution[
            target_index
        ]

        prediction = (
            intercept
            +
            sign
            * slope_offset
            * (
                2.0
                * np.pi
                * tau
                * t_adc
                -
                np.pi
                * tau**2
            )
        )

        errors.extend(
            phase_data[
                distance_cm
            ]
            - prediction
        )


    errors = np.asarray(
        errors
    )

    rmse = np.sqrt(
        np.mean(
            errors**2
        )
    )


    return (
        t_adc,
        rmse,
    )


joint_plus = joint_fit(
    +1.0
)

joint_minus = joint_fit(
    -1.0
)


# ============================================================
# OUTPUT
# ============================================================

print()
print(
    "============================================================"
)

print(
    "ADC OFFSET FROM MAIN REFLECTOR"
)

print(
    "============================================================"
)

print(
    f"Receiver: RX{RX_INDEX}"
)

print()

print(
    "Nominal | Measured | Phase R^2 | "
    "t_adc +1 (us) | t_adc -1 (us)"
)

print("-" * 68)


for result in individual_results:

    print(
        f"{result['distance_cm']:6d}cm | "
        f"{result['range']:8.4f} | "
        f"{result['r2']:9.4f} | "
        f"{result['t_plus'] * 1e6:13.4f} | "
        f"{result['t_minus'] * 1e6:13.4f}"
    )


print()
print("JOINT ESTIMATE")
print()

print(
    f"Sign +1: "
    f"t_adc = "
    f"{joint_plus[0] * 1e6:.4f} us, "
    f"RMSE = "
    f"{np.degrees(joint_plus[1]):.2f} deg"
)

print(
    f"Sign -1: "
    f"t_adc = "
    f"{joint_minus[0] * 1e6:.4f} us, "
    f"RMSE = "
    f"{np.degrees(joint_minus[1]):.2f} deg"
)


# ============================================================
# PLOT
# ============================================================

plt.figure(
    figsize=(11, 7)
)


for result in individual_results:

    distance_cm = (
        result[
            "distance_cm"
        ]
    )

    measured = np.degrees(
        phase_data[
            distance_cm
        ]
    )

    fitted = np.degrees(
        result["intercept"]
        +
        result["phase_slope"]
        * slope_offset
    )


    plt.plot(
        slopes / 1e12,
        measured,
        "o",
        label=(
            f"{distance_cm} cm measured"
        ),
    )

    plt.plot(
        slopes / 1e12,
        fitted,
        "--",
        label=(
            f"{distance_cm} cm fit"
        ),
    )


plt.xlabel(
    "Chirp slope (THz/s)"
)

plt.ylabel(
    "Unwrapped target phase (deg)"
)

plt.title(
    "Main Reflector Phase vs Chirp Slope"
)

plt.grid(True)
plt.legend()
plt.tight_layout()

plt.show()