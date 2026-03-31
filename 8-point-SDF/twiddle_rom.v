module twiddle_rom (
    input clk,
    
    input [1:0] address,
    
    output signed [15:0] W_real,
    output signed [15:0] W_imag
);
    //Twiddle factors ROM
    reg signed [15:0] W_rm[3:0];
    reg signed [15:0] W_im[3:0];

    initial begin
        W_rm[0] = 16'sd32767;
        W_im[0] = 16'sd0;
        W_rm[1] = 16'sd23170;
        W_im[1] = -16'sd23170;
        W_rm[2] = 16'sd0;
        W_im[2] = -16'sd32767;
        W_rm[3] = -16'sd23170;
        W_im[3] = -16'sd23170;
    end
    
    assign W_real = W_rm[address];
    assign W_imag = W_im[address];
    
endmodule