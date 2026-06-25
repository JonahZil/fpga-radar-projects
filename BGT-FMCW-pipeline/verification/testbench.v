`timescale 1ns / 1ps

module testbench();
    
    reg clk;
    reg rst;
    reg start;
    
    wire MISO;
    wire IRQ;
    
    wire SCLK;
    wire MOSI;
    wire SRST;
    wire CS_N;
    
    initial clk = 0;
    always #1 clk = ~clk;
    
    bgt_master UUT (
        .clk(clk),
        .start(start),
        .rst(rst),
        
        .MISO(MISO),
        .IRQ(IRQ),
        
        .SCLK(SCLK),
        .MOSI(MOSI),
        .SRST(SRST),
        .CS_N(CS_N)
    );
    
    initial begin
        #10;
        
        rst <= 1'b1;
        
        #2;
        
        rst <= 1'b0;
        
        #20;
        
        start <= 1'b1;
        
        #2;
       
    end

endmodule