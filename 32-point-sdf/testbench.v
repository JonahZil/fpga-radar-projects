`timescale 1ns / 1ps

module testbench();
    
    reg clk;
    reg rst;
    
    reg out_valid;
    reg signed [15:0] real_data;
    reg signed [15:0] imag_data;
    
    wire stage_valid;
    wire signed [15:0] real_data_out;
    wire signed [15:0] imag_data_out;
    
    stage_module UUT (
        .clk(clk),
        .rst(rst),
        
        .in_valid(out_valid),
        .data_real(real_data),
        .data_imag(imag_data),
        
        .out_valid(stage_valid),
        .out_real(real_data_out),
        .out_imag(imag_data_out)
    );
    
    initial clk = 0;
    always #1 clk = ~clk;
    
    initial begin
        #1;
        out_valid <= 0;
        real_data <= 0;
        imag_data <= 0;
        rst <= 1;
        #2;
        rst <= 0;
        #10;
        real_data <= 16'sd1000;
        imag_data <= 16'sd1000;
        out_valid <= 1;
        #2;
        real_data <= 16'sd2000;
        imag_data <= 16'sd2000;
        #2;
        real_data <= 16'sd3000;
        imag_data <= 16'sd3000;
        #2;
        real_data <= 16'sd4000;
        imag_data <= 16'sd4000;
        #2;
        real_data <= 16'sd5000;
        imag_data <= 16'sd5000;
        #2;
        real_data <= 16'sd6000;
        imag_data <= 16'sd6000;
        #2;
        real_data <= 16'sd7000;
        imag_data <= 16'sd7000;
        #2;
        real_data <= 16'sd8000;
        imag_data <= 16'sd8000;
        #2;
        out_valid <= 0;
        #100;
        $finish;
    end
    
endmodule