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
    
    initial out_ready = 0;
    always begin
        #2;
        out_ready = 1;
        #2;
        out_ready = 0;
    end
    
    initial MISO = 0;
    
    /*
    initial begin
        MISO = 0;
        @(negedge CS_N);
    
        forever begin
            MISO = 1;
            #8; 
            MISO = 0;
            #16;
            MISO = 1;
            #8;
            MISO = 0;
            #40;
            MISO = 1;
            #24;
            MISO = 0;
            #16;
            MISO = 1;
            #16;
        end
    end
    */
    
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
        
        MISO <= 1'b1;
        IRQ <= 1'b0;
        rst <= 1'b1;
        
        #2;
        
        rst <= 1'b0;
        
        #20;
        
        start <= 1'b1;
        
        #11504;
        
        IRQ <= 1'b1;
       
    end

endmodule