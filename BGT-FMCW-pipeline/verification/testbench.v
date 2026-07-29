`timescale 1ns / 1ps

module testbench();
    
    reg clk;
    reg rst;
    reg start;
    
    reg MISO;
    reg IRQ;
    
    wire SCLK;
    wire MOSI;
    wire SRST;
    wire CS_N;
    
    reg out_ready;
    
    initial clk = 0;
    always #1 clk = ~clk;
    initial MISO = 1;
    initial out_ready = 1;
    
    top_io_buffer UUT (
        .clk(clk),
        .start(start),
        .rst(rst),
        
        .MISO(MISO),
        .IRQ(IRQ),
        
        .SCLK(SCLK),
        .MOSI(MOSI),
        .SRST(SRST),
        .CS_N(CS_N),
        
        .out_ready(out_ready),
        .out_data(),
        .out_valid()
    );
    
    initial begin
        #10;
        IRQ <= 1'b0;
        rst <= 1'b1;
        MISO <= 1'b1;
        #2;
        
        rst <= 1'b0;
        
        #20;
        
        start <= 1'b1;
        
        #11504;
        
        IRQ <= 1'b1;
       
    end
    
endmodule