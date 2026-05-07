
#######################################
#######################################
#######################################
## Intermediate Frequency (IF) Amplifier and Low Pass Filter ##
## Johan Holmstedt ##

#######################################
## Apply Amplifier and Filter ##

function If_signal = If_Amp_LowPass_Filter(sampling_rate, mixer_signal, If_Amplifier_Gain)

    order = 2;
    cutoff_freq = 160*1e6;
    sampling_freq = 1/sampling_rate;
    normalized_cutoff = cutoff_freq / (sampling_freq / 2);
    [b, a] = butter(order, normalized_cutoff, 'low');
    If_signal = filter(b, a, mixer_signal);
    If_signal = If_Amplifier_Gain*If_signal;

end

#######################################
## END ##
