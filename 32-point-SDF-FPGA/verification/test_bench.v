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
    
endmodule