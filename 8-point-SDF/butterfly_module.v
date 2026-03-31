module butterfly_module (
    input clk,
    input rst,
    
    input signed [15:0] A_real,
    input signed [15:0] A_imag,
    input signed [15:0] B_real,
    input signed [15:0] B_imag,
    input signed [15:0] W_real,
    input signed [15:0] W_imag,
    
    output reg signed [15:0] A_p_real,
    output reg signed [15:0] A_p_imag,
    output reg signed [15:0] B_p_real,
    output reg signed [15:0] B_p_imag,
    
    input in_valid,
    output reg out_valid
);
    //Stage 1: Raw sums/differences
    reg signed [31:0] sum_real, sum_imag, diff_real, diff_imag;
    
    //Stage 2: Scaled sums/differences
    reg signed [15:0] sum_real_s, sum_imag_s, diff_real_s, diff_imag_s;
    
    //Stage 3: Partial products for complex multiplication
    reg signed [31:0] ac, bd, ad, bc;
    
    //Delay A' output to align with B'
    reg signed [15:0] A_p_real_d, A_p_imag_d;
    
    //Delay twiddle factors to align with stage 3
    reg signed [15:0] W_real_d1, W_imag_d1;
    reg signed [15:0] W_real_d2, W_imag_d2;
    
    //4-cycle pipeline
    reg [3:0] valid_reg;

    function signed [15:0] saturate16;
        input signed [31:0] x;
        begin
            if(x > 32'sd32767) saturate16 = 16'sh7FFF;
            else if(x < -32'sd32768) saturate16 = 16'sh8000;
            else saturate16 = x[15:0];
        end
    endfunction   

    
    wire signed [31:0] sum_r_w  = $signed({{16{A_real[15]}}, A_real}) +
                            $signed({{16{B_real[15]}}, B_real});
    
    wire signed [31:0] sum_i_w  = $signed({{16{A_imag[15]}}, A_imag}) +
                            $signed({{16{B_imag[15]}}, B_imag});
                            
    wire signed [31:0] diff_r_w  = $signed({{16{A_real[15]}}, A_real}) -
                            $signed({{16{B_real[15]}}, B_real});
    
    wire signed [31:0] diff_i_w  = $signed({{16{A_imag[15]}}, A_imag}) -
                            $signed({{16{B_imag[15]}}, B_imag});
    
    always @ (posedge clk or posedge rst) begin
        
        if(rst) begin
            
            ac <= 0; bd <= 0; ad <= 0; bc <= 0;
            
            sum_real <= 0; sum_imag <= 0; diff_real <= 0; diff_imag <= 0;
            
            sum_real_s <= 0; sum_imag_s <= 0; diff_real_s <= 0; diff_imag_s <= 0;
            
            A_p_real <= 0; A_p_imag <= 0; B_p_real <= 0; B_p_imag <= 0;
            
            A_p_real_d <= 0; A_p_imag_d <= 0;
            W_real_d1 <= 0; W_imag_d1 <= 0; 
            W_real_d2 <= 0; W_imag_d2 <= 0;
            
            out_valid <= 0;
            valid_reg <= 4'b0000;
        end else begin
            valid_reg <= {valid_reg[2:0], in_valid};
            out_valid <= valid_reg[2];
            
            //Stage 1: Compute raw sum/diff
            if(in_valid) begin
                sum_real <= sum_r_w;
                sum_imag <= sum_i_w;
                diff_real <= diff_r_w;
                diff_imag <= diff_i_w;
                
                W_real_d1 <= W_real;
                W_imag_d1 <= W_imag;
            end
            
            //Stage 2: Scale sum/diff
            if(valid_reg[0]) begin
                sum_real_s <= saturate16($signed(sum_real) >>> 1);
                sum_imag_s <= saturate16($signed(sum_imag) >>> 1);
                diff_real_s <= saturate16($signed(diff_real) >>> 1);
                diff_imag_s <= saturate16($signed(diff_imag) >>> 1);
                
                W_real_d2 <= W_real_d1;
                W_imag_d2 <= W_imag_d1;
            end
            
            //Stage 3: 
            //A' is the scaled sum
            //Calculate the partial products for (A - B)W
            if(valid_reg[1]) begin
                A_p_real_d <= sum_real_s;
                A_p_imag_d <= sum_imag_s;
                
                ac <= diff_real_s * W_real_d2;
                bd <= diff_imag_s * W_imag_d2;
                ad <= diff_real_s * W_imag_d2;
                bc <= diff_imag_s * W_real_d2;
            end
            
            //Stage 4: Calculate the final B' value
            if(valid_reg[2]) begin
                A_p_real <= A_p_real_d;
                A_p_imag <= A_p_imag_d;
                B_p_real <= saturate16(((ac - bd) + 32'sd16384) >>> 15);
                B_p_imag <= saturate16(((ad + bc) + 32'sd16384) >>> 15);
            end
            
        end  
    end 
    
endmodule