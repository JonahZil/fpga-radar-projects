
#######################################
#######################################
#######################################
## Mixing Received and Transmit Signals ##
## Johan Holmstedt ##

#######################################
## Apply Mixer ##

function mixer_signal = mixer(chirp_signal, received_chirp_signal)

    mixer_signal = chirp_signal.*received_chirp_signal;

end

#######################################
## END ##
