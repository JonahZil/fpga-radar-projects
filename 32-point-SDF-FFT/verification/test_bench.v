`timescale 1ns / 1ps

module testbench();
    
    reg clk;
    reg rst;
    
    reg signed [15:0] data_real, data_imag;
    reg out_valid;
    reg out_ready;
   
    wire signed [15:0] out_real, out_imag;
    wire fft_valid;
    
    
    wire signed [31:0] UUT_out;
    assign out_real = UUT_out[31:16];
    assign out_imag = UUT_out[15:0];
    
    
    top_io_buffer UUT (
        .clk(clk),
        .rst(rst),
        
        .in_data({data_real, data_imag}),
        .in_valid(out_valid),
        .out_ready(out_ready),
        
        .out_data(UUT_out),
        .out_valid(fft_valid)
    );
    
    
    initial clk = 0;
    always #1 clk = ~clk;
    
    /*
    sdf_fft_32 UUT (
        .clk(clk),
        .rst(rst),
        .in_valid(out_valid),
        .data_real(data_real),
        .data_imag(data_imag),
        .out_valid(fft_valid),
        .out_real(out_real),
        .out_imag(out_imag)
    );
    */
    
    integer i;
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
        
        #1;
        rst = 1;
        #2;
        rst = 0;
        #2;
        
        for(i = 0; i < 32; i = i + 1) begin
            data_real <= inputs[i];
            data_imag <= 16'sd0;
            out_valid <= 1;
            #2;
        end
        out_valid <= 0;
        
        wait(fft_valid);
        #70;
        
        $finish;
    end

endmodule