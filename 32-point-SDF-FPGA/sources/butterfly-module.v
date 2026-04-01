module butterfly_module (
    input signed [15:0] A_real,
    input signed [15:0] A_imag,
    input signed [15:0] B_real,
    input signed [15:0] B_imag,
    input signed [15:0] W_real,
    input signed [15:0] W_imag,
    
    output wire signed [15:0] A_p_real,
    output wire signed [15:0] A_p_imag,
    output wire signed [15:0] B_p_real,
    output wire signed [15:0] B_p_imag
);

    function signed [15:0] saturate16;
        input signed [31:0] x;
        begin
            if(x > 32'sd32767) saturate16 = 16'sh7FFF;
            else if(x < -32'sd32768) saturate16 = 16'sh8000;
            else saturate16 = x[15:0];
        end
    endfunction   

    //Raw sum and difference
    wire signed [31:0] sum_real  = $signed({{16{A_real[15]}}, A_real}) +
                            $signed({{16{B_real[15]}}, B_real});
    
    wire signed [31:0] sum_imag  = $signed({{16{A_imag[15]}}, A_imag}) +
                            $signed({{16{B_imag[15]}}, B_imag});
                            
    wire signed [31:0] diff_real  = $signed({{16{A_real[15]}}, A_real}) -
                            $signed({{16{B_real[15]}}, B_real});
    
    wire signed [31:0] diff_imag  = $signed({{16{A_imag[15]}}, A_imag}) -
                            $signed({{16{B_imag[15]}}, B_imag});
    
    //Scaled and saturated sums and difference to handle growth
    wire signed [15:0] sum_real_s = saturate16(sum_real >>> 1);
    wire signed [15:0] sum_imag_s = saturate16(sum_imag >>> 1);
    wire signed [15:0] diff_real_s = saturate16(diff_real >>> 1);
    wire signed [15:0] diff_imag_s = saturate16(diff_imag >>> 1);
    
    //Complex multiply
    wire signed [31:0] ac = diff_real_s * W_real;
    wire signed [31:0] bd = diff_imag_s * W_imag;
    wire signed [31:0] ad = diff_real_s * W_imag;
    wire signed [31:0] bc = diff_imag_s * W_real;
    
    //Round
    wire signed [31:0] real_round = (ac - bd) + 32'sd16384;
    wire signed [31:0] imag_round = (ad + bc) + 32'sd16384;
    
    assign A_p_real = sum_real_s;
    assign A_p_imag = sum_imag_s;
    assign B_p_real = saturate16(real_round >>> 15);
    assign B_p_imag = saturate16(imag_round >>> 15);
    
endmodule