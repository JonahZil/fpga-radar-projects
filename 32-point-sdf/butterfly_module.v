module butterfly_module  (
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
   
    reg signed [15:0] A_real_r, A_imag_r, B_real_r, B_imag_r, W_real_r, W_imag_r;
    reg signed [31:0] ac, bd, ad, bc;
    
    reg signed [15:0] BW_real, BW_imag;
    
    
    reg [3:0] valid_reg;
    wire out_valid_reg;
    assign out_valid_reg = valid_reg[3];
    
    function signed [15:0] saturate16;
        input signed [31:0] x;
        begin
            if(x > 32'sd32767) saturate16 = 16'sh7FFF;
            else if(x < -32'sd32768) saturate16 = 16'sh8000;
            else saturate16 = x[15:0];
        end
    endfunction   
    
    always @ (*) begin
        out_valid <= valid_reg[3];
    end
    
    always @ (posedge clk or posedge rst) begin
        
        if(rst) begin
            A_real_r <= 0; A_imag_r <= 0;
            B_real_r <= 0; B_imag_r <= 0;
            W_real_r <= 0; W_imag_r <= 0;
            
            ac <= 0; bd <= 0; ad <= 0; bc <= 0;
            
            BW_real <= 0; BW_imag <= 0;
            
            A_p_real <= 0; A_p_imag <= 0; B_p_real <= 0; B_p_imag <= 0;
            
            out_valid <= 0;
            valid_reg <= 0;
        end else begin
            out_valid <= out_valid_reg;
            valid_reg <= {valid_reg[2:0], in_valid};
            
            if(in_valid) begin
                A_real_r <= A_real;
                A_imag_r <= A_imag;
                B_real_r <= B_real;
                B_imag_r <= B_imag;
                W_real_r <= W_real;
                W_imag_r <= W_imag;
            end
            
            ac <= B_real_r * W_real_r;
            bd <= B_imag_r * W_imag_r;
            ad <= B_real_r * W_imag_r;
            bc <= B_imag_r * W_real_r;
            
            BW_real <= saturate16(((ac - bd) + 32'sd16384) >>> 15);
            BW_imag <= saturate16(((ad + bc) + 32'sd16384) >>> 15);
            
            A_p_real <= saturate16((A_real_r + BW_real) >>> 1);
            A_p_imag <= saturate16((A_imag_r + BW_imag) >>> 1);
            B_p_real <= saturate16((A_real_r - BW_real) >>> 1);
            B_p_imag <= saturate16((A_imag_r - BW_imag) >>> 1);
        end  
    end 
    
endmodule