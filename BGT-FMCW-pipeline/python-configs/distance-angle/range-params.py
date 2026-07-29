import numpy as np

ADC_sampling_rate = 2e8
N = 256
speed_of_light = 3e8

freq_start = 58.1e9
freq_end = 63.1e9
time_chirp = 160e-6

chirp_coeff = (freq_end - freq_start) / time_chirp

bin_spacing = np.round((speed_of_light * ADC_sampling_rate) / (2 * chirp_coeff * N), 5) * 1e4
print(f'Bin spacing is {bin_spacing} micrometers.')