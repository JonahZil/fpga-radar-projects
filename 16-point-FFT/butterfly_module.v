module butterfly_module (
    input signed [15:0] A_real,
    input signed [15:0] A_imag,
    input signed [15:0] B_real,
    input signed [15:0] B_imag,
    input signed [15:0] W_real,
    input signed [15:0] W_imag,
    
    input input_ready,
    input out_ready,
    input clk,
    input rst,
    
    output reg signed [15:0] res_Ar,
    output reg signed [15:0] res_Ai,
    output reg signed [15:0] res_Br,
    output reg signed [15:0] res_Bi,
    
    output reg out_valid
);  
    
    localparam STATE_LOAD = 2'd0; 
    localparam STATE_MULT = 2'd1;
    localparam STATE_ADD = 2'd2;
    localparam STATE_OUT = 2'd3;
    
    reg [1:0] state;
    
    reg signed [15:0] A_real_r, A_imag_r;
    reg signed [15:0] B_real_r, B_imag_r;
    reg signed [15:0] W_real_r, W_imag_r;
    
    reg signed [31:0] ac, bd, ad, bc;
    
    reg signed [15:0] BW_real, BW_imag;
        
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
            state <= STATE_LOAD;
            A_real_r <= 16'sd0; A_imag_r <= 16'sd0;
            B_real_r <= 16'sd0; B_imag_r <= 16'sd0;
            W_real_r <= 16'sd0; W_imag_r <= 16'sd0;
            
            ac <= 32'sd0; bd <= 32'sd0; ad <= 32'sd0; bc <= 32'sd0;
            
            BW_real <= 16'sd0;
            BW_imag <= 16'sd0;
            
            res_Ar <= 16'sd0; res_Ai <= 16'sd0; res_Br <= 16'sd0; res_Bi <= 16'sd0;
            
            out_valid <= 1'b0;
        end else begin
            case(state)
                
                STATE_LOAD: begin
                    out_valid <= 1'b0;
                    if(input_ready) begin
                        A_real_r <= A_real;
                        A_imag_r <= A_imag;
                        B_real_r <= B_real;
                        B_imag_r <= B_imag;
                        W_real_r <= W_real;
                        W_imag_r <= W_imag;
                        state <= STATE_MULT;
                    end 
                end 
                
                STATE_MULT: begin 
                    ac <= B_real_r * W_real_r;
                    bd <= B_imag_r * W_imag_r;
                    ad <= B_real_r * W_imag_r;
                    bc <= B_imag_r * W_real_r;
                    
                    state <= STATE_ADD;
                end
                
                STATE_ADD: begin
                    BW_real <= saturate16(((ac - bd) + 32'sd16384) >>> 15);
                    BW_imag <= saturate16(((ad + bc) + 32'sd16384) >>> 15);
                    
                    state <= STATE_OUT;
                end
                
                STATE_OUT: begin
                    res_Ar <= saturate16((A_real_r + BW_real) >>> 1);
                    res_Ai <= saturate16((A_imag_r + BW_imag) >>> 1);
                    res_Br <= saturate16((A_real_r - BW_real) >>> 1);
                    res_Bi <= saturate16((A_imag_r - BW_imag) >>> 1);
                    
                    out_valid <= 1'b1;
                    if(out_ready) begin
                        out_valid <= 1'b0;
                        state <= STATE_LOAD;   
                    end
                end
                
                default: begin 
                    state <= STATE_LOAD;
                    out_valid <= 1'b0;
                end
            endcase
        end
    end
    
endmodule