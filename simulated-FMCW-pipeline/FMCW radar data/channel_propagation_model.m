
#######################################
#######################################
#######################################
## Calculate the received power at the radar based on the radar equation ##
## Johan Holmstedt ##

#######################################
## Apply Propagation Model ##

function received_Voltage = channel_propagation_model(speed_of_light, lambda, sampling_rate, Antenna_Gain, transmitted_Voltage, target_range, target_RCS)

    time_delay = 2*target_range/speed_of_light;
    shift_number = round(time_delay/sampling_rate);
    received_Voltage = zeros(1,length(transmitted_Voltage));
    Amp = sqrt((target_RCS*lambda*lambda*Antenna_Gain*Antenna_Gain)/(4*(pi^3)*(target_range^4)));
    received_Voltage(shift_number:end) = Amp*transmitted_Voltage(1:(end - (shift_number - 1)));
    %received_Voltage(1:(shift_number - 1)) = zeros(1,length(received_Voltage(1:(shift_number - 1))));
end

#######################################
## END ##
