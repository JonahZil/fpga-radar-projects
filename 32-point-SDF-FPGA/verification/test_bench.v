`timescale 1ns / 1ps

module testbench();
    
    reg clk;
    reg rst;
    
    reg button;
    
    wire signed [15:0] real_data;
    wire signed [15:0] imag_data;
    wire out_valid;
    
    sdf_pipeline UUT(
        .clk(clk),
        .rst(rst),
        .start_calc(button),
        
        .real_bin(real_data),
        .imag_bin(imag_data),
        .pipeline_valid(out_valid)
    );
    
    initial clk = 0;
    always #1 clk = ~clk;
    
    initial begin
        #1;
        rst = 1;
        #2;
        rst = 0;
        button = 1;
        #2;
        button = 0;
        wait(out_valid);
        #66;
        $finish;
    end
    
    /*
    initial clk = 0;
    always #1 clk = ~clk;
    
    reg in_valid;
    reg signed [15:0] data_real;
    reg signed [15:0] data_imag;
    
    wire stage_three_valid;
    wire signed [15:0] stage_three_real;
    wire signed [15:0] stage_three_imag;
    
    wire [1:0] stage_three_W_addr;
    wire signed [15:0] W3_r;
    wire signed [15:0] W3_i;
    
    twiddle_rom #(.D(4), .FILE("tw_s3.mem")) rom3 (
        .address(stage_three_W_addr),
        .W_real(W3_r),
        .W_imag(W3_i)
    );
    
    stage_module #(.D(4)) stage_three (
        .clk(clk),
        .rst(rst),
        
        .in_valid(in_valid),
        .data_real(data_real),
        .data_imag(data_imag),
        
        .twiddle_address(stage_three_W_addr),
        .W_real(W3_r),
        .W_imag(W3_i),
        
        .out_valid(stage_three_valid),
        .out_real(stage_three_real),
        .out_imag(stage_three_imag)
    );
    reg signed [15:0] inputs[31:0];
    integer i;
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
        
        #1;
        rst = 1;
        #2;
        rst = 0;
        #2;
        for(i = 0; i < 32; i = i + 1) begin
            data_real <= inputs[i];
            data_imag <= 0;
            in_valid <= 1;
            #2;
        end
        in_valid <= 0;
        #30;
        $finish; 
    end
    */
endmodule