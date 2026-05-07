
#######################################
#######################################
#######################################
## Generate the Blackman-Harris window coefficients of length n ##
## Johan Holmstedt ##

#######################################
## Apply Window ##

function w = blackmanharris(n)

    a0 = 0.35875;
    a1 = 0.48829;
    a2 = 0.14128;
    a3 = 0.01168;
    w = a0 - a1*cos(2*pi*(0:n-1)'/(n-1)) + a2*cos(4*pi*(0:n-1)'/(n-1)) - a3*cos(6*pi*(0:n-1)'/(n-1));
end

#######################################
## END ##
