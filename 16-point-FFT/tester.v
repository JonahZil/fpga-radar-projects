`timescale 1ns / 1ps

module testbench ();
    reg clk;
    reg rst;
    
    reg signed [15:0] x_real;
    reg signed [15:0] x_imag;
    reg out_valid;
    wire in_ready;
    
    wire signed [15:0] X_real;
    wire signed [15:0] X_imag;
    reg out_ready;
    wire in_valid;
    
    reg signed [15:0] inputs[15:0];
    
    fft_module UUT (
    
        .clk(clk),
        .rst(rst),
        
        .x_real(x_real),
        .x_imag(x_imag),
        .out_valid(out_valid),
        .in_ready(in_ready),
        
        .X_real(X_real),
        .X_imag(X_imag),
        .out_ready(out_ready),
        .in_valid(in_valid)

    );
    
    initial clk = 0;
    always #1 clk = ~clk;
    
    integer i;
    integer j;
    
    function real q15_to_real;
        input signed [15:0] q15;
        begin
            q15_to_real = q15 / 32768.0;
        end
    endfunction
    
    initial begin
        clk = 0;
        rst = 0;
        x_real = 0;
        x_imag = 0;
        out_valid = 0;
        out_ready = 0;
        
        //cos(2pix)
        /*
        inputs[0] = 32767;
        inputs[1] = 30274;
        inputs[2] = 23170;
        inputs[3] = 12540;
        inputs[4] = 0;
        inputs[5] = -12540;
        inputs[6] = -23170;
        inputs[7] = -30274;
        inputs[8] = -32768;
        inputs[9] = -30274;
        inputs[10] = -23170;
        inputs[11] = -12540;
        inputs[12] = 0;
        inputs[13] = 12540;
        inputs[14] = 23170;
        inputs[15] = 30274;
        */
        
        //sin(pi/4 * x) + sin(5pi/8 * x)
        inputs[0] = 0;
        inputs[1] = 26722;
        inputs[2] = 4799;
        inputs[3] = 5315;
        inputs[4] = 16384;
        inputs[5] = -17855;
        inputs[6] = -27969;
        inputs[7] = 3552;
        inputs[8] = 0;
        inputs[9] = -3552;
        inputs[10] = 27969;
        inputs[11] = 17855;
        inputs[12] = -16384;
        inputs[13] = -5315;
        inputs[14] = -4799;
        inputs[15] = -26722;
        
        #1;
        rst = 1;
        #1; 
        rst = 0;
        
        #1;
        
        for(i = 0; i < 16; i = i + 1) begin
            x_real = inputs[i];
            out_valid = 1;
            #2;
            out_valid = 0;
            #2;
        end
        
        wait(in_valid == 1);
        #2;
        
        for(j = 0; j < 16; j = j + 1) begin        
            out_ready = 1;
            #2;
            out_ready = 0;
            $display("Index: %0d  Real: %f", j, q15_to_real(X_real));
            $display("Index: %0d  Imaginary: %f", j, q15_to_real(X_imag));
            #8;
        end
        
        $finish;
    end 
    
endmodule