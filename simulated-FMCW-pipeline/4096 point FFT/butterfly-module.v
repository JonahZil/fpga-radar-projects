module butterfly_module #(
    parameter SCALE_BFU = 1
) (
    input clk,
    input rst,

    input signed [23:0] A_real,
    input signed [23:0] A_imag,
    input signed [23:0] B_real,
    input signed [23:0] B_imag,

    input signed [15:0] W_real,
    input signed [15:0] W_imag,

    input in_valid,
    
    output reg signed [23:0] A_p_real,
    output reg signed [23:0] A_p_imag,
    output reg signed [23:0] B_p_real,
    output reg signed [23:0] B_p_imag,

    output wire out_valid
);

    function signed [23:0] saturate24;
        input signed [39:0] x;
        begin
            if (x > 40'sd8388607)
                saturate24 = 24'sh7FFFFF;
            else if (x < -40'sd8388608)
                saturate24 = 24'sh800000;
            else
                saturate24 = x[23:0];
        end
    endfunction   

    //Sum/difference
    wire signed [24:0] sum_real_w  = A_real + B_real;
    wire signed [24:0] sum_imag_w  = A_imag + B_imag;
    wire signed [24:0] diff_real_w = A_real - B_real;
    wire signed [24:0] diff_imag_w = A_imag - B_imag;

    reg signed [23:0] sum_real;
    reg signed [23:0] sum_imag;   
    reg signed [23:0] diff_real;
    reg signed [23:0] diff_imag;
    
    //Delayed sums and twiddles for alignment
    reg signed [23:0] sum_real_d;
    reg signed [23:0] sum_imag_d;
    reg signed [15:0] W_real_d;
    reg signed [15:0] W_imag_d;
    
    //24 bit data * 16 bit twiddle
    reg signed [39:0] ac;
    reg signed [39:0] bd;
    reg signed [39:0] ad;
    reg signed [39:0] bc;
    
    //Valid pipeline
    reg [2:0] valid_reg;
    assign out_valid = valid_reg[2];
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_real  <= 24'sd0;
            sum_imag  <= 24'sd0;
            diff_real <= 24'sd0;
            diff_imag <= 24'sd0; 

            sum_real_d <= 24'sd0;
            sum_imag_d <= 24'sd0;

            ac <= 40'sd0;
            bd <= 40'sd0;
            ad <= 40'sd0;
            bc <= 40'sd0;

            A_p_real <= 24'sd0;
            A_p_imag <= 24'sd0;
            B_p_real <= 24'sd0;
            B_p_imag <= 24'sd0;

            W_real_d <= 16'sd0;
            W_imag_d <= 16'sd0;

            valid_reg <= 3'b000;
        end else begin
            valid_reg <= {valid_reg[1:0], in_valid};

            if (SCALE_BFU) begin
                sum_real  <= sum_real_w  >>> 1;
                sum_imag  <= sum_imag_w  >>> 1;
                diff_real <= diff_real_w >>> 1;
                diff_imag <= diff_imag_w >>> 1;
            end else begin
                sum_real  <= sum_real_w[23:0];
                sum_imag  <= sum_imag_w[23:0];
                diff_real <= diff_real_w[23:0];
                diff_imag <= diff_imag_w[23:0];
            end
            
            W_real_d <= W_real;
            W_imag_d <= W_imag;

            ac <= diff_real * W_real_d;
            bd <= diff_imag * W_imag_d;
            ad <= diff_real * W_imag_d;
            bc <= diff_imag * W_real_d;
            
            sum_real_d <= sum_real;
            sum_imag_d <= sum_imag;
            A_p_real <= sum_real_d;
            A_p_imag <= sum_imag_d;

            B_p_real <= saturate24(((ac - bd) + 40'sd16384) >>> 15);
            B_p_imag <= saturate24(((ad + bc) + 40'sd16384) >>> 15);
        end
    end
    
endmodule