module sdf_pipeline(
    input clk,
    input rst,
    input start_calc,
    
    output signed [15:0] real_bin,
    output signed [15:0] imag_bin,
    output pipeline_valid
);
    
    reg signed [15:0] inputs[31:0];
    initial begin
        inputs[0]  =  19660;
        inputs[1]  =  12176;
        inputs[2]  =  -1039;
        inputs[3]  =  -6198;
        inputs[4]  =  -4634;
        inputs[5]  =  -7406;
        inputs[6]  = -14617;
        inputs[7]  = -13709;
        inputs[8]  =      0;
        inputs[9]  =  13709;
        inputs[10] =  14617;
        inputs[11] =   7406;
        inputs[12] =   4634;
        inputs[13] =   6198;
        inputs[14] =   1039;
        inputs[15] = -12176;
        inputs[16] = -19660;
        inputs[17] = -12176;
        inputs[18] =   1039;
        inputs[19] =   6198;
        inputs[20] =   4634;
        inputs[21] =   7406;
        inputs[22] =  14617;
        inputs[23] =  13709;
        inputs[24] =      0;
        inputs[25] = -13709;
        inputs[26] = -14617;
        inputs[27] =  -7406;
        inputs[28] =  -4634;
        inputs[29] =  -6198;
        inputs[30] =  -1039;
        inputs[31] =  12176;
    end
    
    reg signed [15:0] data_real;
    wire signed [15:0] data_imag = 0;
    reg out_valid;
    
    wire fft_valid;
    wire signed [15:0] out_real;
    wire signed [15:0] out_imag;
    
    sdf_fft_32 fft (
        .clk(clk),
        .rst(rst),
        
        .in_valid(out_valid),
        .data_real(data_real),
        .data_imag(data_imag),
        
        .out_valid(fft_valid),
        .out_real(out_real),
        .out_imag(out_imag)
    );
    
    assign real_bin = out_real;
    assign imag_bin = out_imag;
    assign pipeline_valid = fft_valid;
    
    reg state;
    
    localparam STATE_IDLE = 1'd0;
    localparam STATE_CALCULATE = 1'd1;
    
    reg [4:0] data_counter;
    
    always @(posedge rst or posedge clk) begin
        
        if(rst) begin
            state <= STATE_IDLE;
            data_real <= 0;
            out_valid <= 0;
            data_counter <= 0;
        end else begin
            
            case(state)
                
                STATE_IDLE: begin
                    out_valid <= 0;
                    data_real <= 0;
                    data_counter <= 0;
                    if(start_calc) state <= STATE_CALCULATE; 
                end
                
                STATE_CALCULATE: begin
                    data_real <= inputs[data_counter];
                    out_valid <= 1;
                    if(data_counter == 5'd31) state <= STATE_IDLE;
                    data_counter <= data_counter + 1;
                end
                
            endcase
            
        end
        
    end
    
endmodule