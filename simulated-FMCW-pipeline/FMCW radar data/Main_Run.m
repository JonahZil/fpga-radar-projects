
format long
clear; clc;
pkg load signal

#######################################
#######################################
#######################################
## Main File FMCW Radar Simulation ##
## Johan Holmstedt ##

#######################################
## Sampling Rate ##

sampling_rate = 1e-12;

#######################################
## Declare Radar Simulation Parameters ##

speed_of_light = 3e8;

freq_start = 77*1e9;
freq_end = 81*1e9;
time_chirp = 20*1e-6;
chirp_coeff = (freq_end - freq_start)/time_chirp;

freq_lo = freq_start;
lambda = speed_of_light/(0.5*(freq_end+freq_start));

Antenna_Gain = 3;
If_Amplifier_Gain = 700;
ADC_sampling_Freq = 2*1e8;
ADC_Bits = 12;

ADC_Qn = 1;          ## Optional, ADD quantization noise if set to 1
Bits_out_True = 0;   ## Optional, generate output in bit format if set to 1

range_max = 50;
range_min = 1;
time_delay_max = 2*range_max/speed_of_light;
time_delay_min = 2*range_min/speed_of_light;
freq_delay_max = chirp_coeff*time_delay_max;
freq_delay_min = chirp_coeff*time_delay_min;

## Target and radar cross section
target_range = [2.7 13 27.3 49];
target_RCS = [10 0.1 1 0.05];

#######################################
## Time Grid ##

t = 0:sampling_rate:(time_chirp-sampling_rate);

#######################################
## Run Simulation Model ##

chirp_signal = Chirp_Gen(t, freq_lo, chirp_coeff, time_chirp);

received_chirp_signal = zeros(1, length(t));
for m = 1:length(target_range)
  received_chirp_signal = received_chirp_signal + channel_propagation_model(speed_of_light, lambda, sampling_rate, Antenna_Gain, chirp_signal, target_range(m), target_RCS(m));
end

mixer_signal = mixer(chirp_signal, received_chirp_signal);
If_signal = If_Amp_LowPass_Filter(sampling_rate, mixer_signal, If_Amplifier_Gain);

#######################################
## ADC with optional quantization noise ##

Down_sample_factor = 1/(sampling_rate*ADC_sampling_Freq);
ADC = downsample(If_signal, Down_sample_factor);
ADC = ADC - mean(ADC);

## Add quantization noise
if (ADC_Qn == 1)
  ADC_Delta = 2/(2^ADC_Bits);
  ADC = round(ADC/ADC_Delta);
end

#######################################
## Apply Window

Win = blackmanharris(length(ADC));
ADC_win = ADC.*transpose(Win);
ADC_win = ADC_win - mean(ADC_win);

#######################################
## FFT

FFT_signal = fft(ADC_win);
FFT_freq = ADC_sampling_Freq*(1/length(FFT_signal))*(0:1:length(FFT_signal)-1);
Freq_to_dist = (0.5*speed_of_light/chirp_coeff)*FFT_freq;

#######################################
## PLOT

figure('Color','w');
plot(Freq_to_dist(2:end), 20*log10(FFT_signal(2:end)), 'k', 'LineWidth', 2);   % black thick line
title('Radar Spectrum vs Distance', 'FontSize', 16, 'FontWeight', 'bold');
xlabel('Distance (m)', 'FontSize', 14);
ylabel('Power (dB/Bin)', 'FontSize', 14);
set(gca, 'FontSize', 14, 'LineWidth', 1.2, 'Box', 'on');     % clean axis box
grid on;
grid minor;
xlim([1, 50]);
ylim([-10, 130]);

#######################################
## Output Binary data in binary form from ADC, Optional!

if(Bits_out_True == 1)

  ADC = ADC + (1/2)*(2^ADC_Bits);

  Bits_Out = zeros(length(ADC), ADC_Bits);

  for i = 1:length(ADC)

    temp = ADC(i);
    for n = 1:ADC_Bits

      if(temp >= (2^(ADC_Bits-n)))
        temp = temp - 2^(ADC_Bits-n);
        Bits_Out(i, n) = 1;

      end
    endfor

  endfor

end

#######################################
## END ##

