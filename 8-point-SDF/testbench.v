`timescale 1ns / 1ps

module testbench();
    
    reg clk;
    reg rst;
    
    reg out_valid;
    reg signed [15:0] real_data;
    reg signed [15:0] imag_data;
    
    wire fft_valid;
    wire signed [15:0] real_data_out;
    wire signed [15:0] imag_data_out;
    
    /*
    reg signed [15:0] A_r, A_i, B_r, B_i, W_r, W_i;
    wire signed[15:0] bfu_out_A_real, bfu_out_A_imag;
    wire signed[15:0] bfu_out_B_real, bfu_out_B_imag;
    wire bfu_valid;
    
    butterfly_module UUT (
        .clk(clk),
        .rst(rst),
        
        .A_real(A_r),
        .A_imag(A_i),
        .B_real(B_r),
        .B_imag(B_i),
        .W_real(W_r),
        .W_imag(W_i),
        
        .A_p_real(bfu_out_A_real),
        .A_p_imag(bfu_out_A_imag),
        .B_p_real(bfu_out_B_real),
        .B_p_imag(bfu_out_B_imag),
        
        .in_valid(out_valid),
        .out_valid(bfu_valid)
    );
    
    initial clk = 0;
    always #1 clk = ~clk;
    
    initial begin
        A_r <= 0; A_i <= 0; B_r <= 0; B_i <= 0; W_r <= 0; W_i <= 0;
        
        #1;
        rst <= 1;
        #2;
        rst <= 0;
        #2;
        
        A_r <= 16'h3fff;
        A_i <= 0;
        B_r <= 16'h2d40;
        B_i <= 16'h2d40;
        W_r <= 0;
        W_i <= 16'h8001;
        
        #10;
        out_valid <= 1;
        #2;
        out_valid <= 0;
        
        wait(bfu_valid == 1);
        #2;
        $finish;
    end
    */
    
    small_sdf UUT (
        .clk(clk),
        .rst(rst),
        
        .in_valid(out_valid),
        .data_real(real_data),
        .data_imag(imag_data),
        
        .out_valid(fft_valid),
        .out_real(real_data_out),
        .out_imag(imag_data_out)
    );

    initial clk = 0;
    always #1 clk = ~clk;
    
    function real q15_to_real;
        input signed [15:0] q15;
        begin
            q15_to_real = q15 / 32768.0;
        end
    endfunction
    
    integer j;
    integer i;
    reg signed [15:0] inputs[7:0];
    
    initial begin
        
        inputs[0] = 32767;
        inputs[1] = 23170;
        inputs[2] = 0;
        inputs[3] = -23170;
        inputs[4] = -32768;
        inputs[5] = -23170;
        inputs[6] = 0;
        inputs[7] = 23170;
        
        /*
        inputs[0] = 16'sd32767;
        inputs[1] = 16'sd32767;
        inputs[2] = 16'sd32767;
        inputs[3] = 16'sd32767;
        inputs[4] = 16'sd32767;
        inputs[5] = 16'sd32767;
        inputs[6] = 16'sd32767;
        inputs[7] = 16'sd32767;
        */
        #1;
        out_valid <= 0;
        real_data <= 0;
        imag_data <= 0;
        rst <= 1;
        #2;
        rst <= 0;
        #2;
        
        for(i = 0; i < 8; i = i + 1) begin
            real_data <= inputs[i];
            imag_data <= 0;
            out_valid <= 1;
            #2;
        end
        out_valid <= 0;
        
        #32;
        $display(fft_valid);
        
        for(j = 0; j < 8; j = j + 1) begin        
            $display("Bin: %0d  Real: %f", j, q15_to_real(real_data_out));
            $display("Bin: %0d  Imaginary: %f", j, q15_to_real(imag_data_out));
            #2;
        end
        $finish;
    end
    
endmodule