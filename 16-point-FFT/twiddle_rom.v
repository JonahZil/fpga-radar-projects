module twiddle_rom (
    input clk,
    
    input [2:0] address,
    
    output reg signed [15:0] W_r,
    output reg signed [15:0] W_i
);

    reg signed [15:0] W_rm[7:0];
    reg signed [15:0] W_im[7:0];

    initial begin
        W_rm[0] = 16'sd32767;
        W_im[0] = 16'sd0;
        W_rm[1] = 16'sd30274;
        W_im[1] = -16'sd12540;
        W_rm[2] = 16'sd23170;
        W_im[2] = -16'sd23170;
        W_rm[3] = 16'sd12540;
        W_im[3] = -16'sd30274;
        W_rm[4] = 16'sd0;
        W_im[4] = -16'sd32767;
        W_rm[5] = -16'sd12540;
        W_im[5] = -16'sd30274;
        W_rm[6] = -16'sd23170;
        W_im[6] = -16'sd23170;
        W_rm[7] = -16'sd30274;
        W_im[7] = -16'sd12540;
    end

    always @ (posedge clk) begin
        W_r <= W_rm[address];
        W_i <= W_im[address];
    end

endmodule