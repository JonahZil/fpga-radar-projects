module butterfly_module (
    input clk,
    input rst,
    input signed [15:0] A_real,
    input signed [15:0] A_imag,
    input signed [15:0] B_real,
    input signed [15:0] B_imag,
    input signed [15:0] W_real,
    input signed [15:0] W_imag,
    input in_valid,
    
    output reg signed [15:0] A_p_real,
    output reg signed [15:0] A_p_imag,
    output reg signed [15:0] B_p_real,
    output reg signed [15:0] B_p_imag,
    output wire out_valid
);

    function signed [15:0] saturate16;
        input signed [31:0] x;
        begin
            if(x > 32'sd32767) saturate16 = 16'sh7FFF;
            else if(x < -32'sd32768) saturate16 = 16'sh8000;
            else saturate16 = x[15:0];
        end
    endfunction   

    //Scaled sum and difference
    reg signed [15:0] sum_real;
    reg signed [15:0] sum_imag;   
    reg signed [15:0] diff_real;
    reg signed [15:0] diff_imag;
    
    wire signed [16:0] sum_real_w  = A_real + B_real;
    wire signed [16:0] sum_imag_w  = A_imag + B_imag;
    wire signed [16:0] diff_real_w = A_real - B_real;
    wire signed [16:0] diff_imag_w = A_imag - B_imag;
    
    //Delayed sums for alignment
    reg signed [15:0] sum_real_d;
    reg signed [15:0] sum_imag_d;
    
    //Delayed twiddles for alignment
    reg signed [15:0] W_real_d;
    reg signed [15:0] W_imag_d;
    
    //Complex multiply parts
    reg signed [31:0] ac;
    reg signed [31:0] bd;
    reg signed [31:0] ad;
    reg signed [31:0] bc;
    
    //Valid pipeline
    reg [2:0] valid_reg;
    assign out_valid = valid_reg[2];
    
    always @(posedge clk or posedge rst) begin
    
        if(rst) begin
            sum_real <= 0;
            sum_imag <= 0;
            diff_real <= 0;
            diff_imag <= 0; 
            sum_real_d <= 0;
            sum_imag_d <= 0;
            ac <= 0;
            bd <= 0;
            ad <= 0;
            bc <= 0;
            A_p_real <= 0;
            A_p_imag <= 0;
            B_p_real <= 0;
            B_p_imag <= 0;
            W_real_d <= 0;
            W_imag_d <= 0;
            valid_reg <= 3'b000;
        end else begin
        
            valid_reg <= {valid_reg[1:0], in_valid};

            sum_real  <= sum_real_w  >>> 1;
            sum_imag  <= sum_imag_w  >>> 1;
            diff_real <= diff_real_w >>> 1;
            diff_imag <= diff_imag_w >>> 1;
            
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
            
            //Rounded and scaled complex multiply
            B_p_real <= saturate16(((ac - bd) + 32'sd16384) >>> 15);
            B_p_imag <= saturate16(((ad + bc) + 32'sd16384) >>> 15);
        
        end
    
    end
    
endmodule