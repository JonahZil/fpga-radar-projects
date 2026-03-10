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
    //Stage 1: Multiplier results
    reg signed [31:0] ac, bd, ad, bc;
    
    //Delay A path so it lines up with BW
    reg signed [15:0] A_real_d1, A_imag_d1;
    reg signed [15:0] A_real_d2, A_imag_d2;
    
    //Stage 2: B*W result
    reg signed [15:0] BW_real, BW_imag;
    
    //Stage 3: butterfly results before final output
    reg signed [15:0] A_p_real_s3, A_p_imag_s3;
    reg signed [15:0] B_p_real_s3, B_p_imag_s3;
    
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
    
    always @ (posedge clk or posedge rst) begin
        
        if(rst) begin
            
            ac <= 0; bd <= 0; ad <= 0; bc <= 0;
            
            A_real_d1 <= 0; A_imag_d1 <= 0; A_real_d2 <= 0; A_imag_d2 <= 0;
            
            BW_real <= 0; BW_imag <= 0;
            
            A_p_real_s3 <= 0; A_p_imag_s3 <= 0; B_p_real <= 0; B_p_imag <= 0;
            
            A_p_real <= 0; A_p_imag <= 0; B_p_real <= 0; B_p_imag <= 0;
            
            out_valid <= 0;
            valid_reg <= 4'b0000;
        end else begin
            valid_reg <= {valid_reg[2:0], in_valid};
            out_valid <= valid_reg[2];
            
            //Stage 1
            if(in_valid) begin
                ac <= B_real * W_real;
                bd <= B_imag * W_imag;
                ad <= B_real * W_imag;
                bc <= B_imag * W_real;
                
                A_real_d1 <= A_real;
                A_imag_d1 <= A_imag;
            end
            
            //Stage 2
            if(valid_reg[0]) begin
                BW_real <= saturate16(((ac - bd) + 32'sd16384) >>> 15);
                BW_imag <= saturate16(((ad + bc) + 32'sd16384) >>> 15);
                
                A_real_d2 <= A_real_d1;
                A_imag_d2 <= A_imag_d1;
            end
            
            //Stage 3
            if(valid_reg[1]) begin
                A_p_real_s3 <= saturate16(
                 ({{16{A_real_d2[15]}}, A_real_d2} + 
                 {{16{BW_real[15]}}, BW_real}) >>> 1);
                A_p_imag_s3 <= saturate16(
                 ({{16{A_imag_d2[15]}}, A_imag_d2} + 
                 {{16{BW_imag[15]}}, BW_imag}) >>> 1);
                B_p_real_s3 <= saturate16(
                 ({{16{A_real_d2[15]}}, A_real_d2} - 
                 {{16{BW_real[15]}}, BW_real}) >>> 1);
                B_p_imag_s3 <= saturate16(
                 ({{16{A_imag_d2[15]}}, A_imag_d2} - 
                 {{16{BW_imag[15]}}, BW_imag}) >>> 1);
            end
            
            //Stage 4
            if(valid_reg[2]) begin
                A_p_real <= A_p_real_s3;
                A_p_imag <= A_p_imag_s3;
                B_p_real <= B_p_real_s3;
                B_p_imag <= B_p_imag_s3;
            end
            
        end  
    end 
    
endmodule