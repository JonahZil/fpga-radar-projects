
#######################################
#######################################
#######################################
## Generate the LO chirp signal ##
## Johan Holmstedt ##

#######################################
## Generate Chirp ##

function chrip = Chirp_Gen(t, freq_lo, chirp_coeff, chirp_duration)

    phase = 2*pi*(freq_lo*t + 0.5*chirp_coeff*t.^2);
    chrip = sin(phase);
end

#######################################
## END ##
