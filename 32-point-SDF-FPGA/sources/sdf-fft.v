module sdf_fft_32 (
    input clk,
    input rst,
    
    input in_valid,
    input signed [15:0] data_real,
    input signed [15:0] data_imag,
    
    output out_valid,
    output signed [15:0] out_real,
    output signed [15:0] out_imag
);
    
    wire stage_one_valid;
    wire signed [15:0] stage_one_real;
    wire signed [15:0] stage_one_imag;
    
    wire [3:0] stage_one_W_addr;
    wire signed [15:0] W1_r;
    wire signed [15:0] W1_i;
    
    twiddle_rom #(.D(16), .FILE("tw_s1.mem")) rom1 (
        .address(stage_one_W_addr),
        .W_real(W1_r),
        .W_imag(W1_i)
    );
    
    stage_module #(.D(16)) stage_one (
        .clk(clk),
        .rst(rst),
        
        .in_valid(in_valid),
        .data_real(data_real),
        .data_imag(data_imag),
        
        .twiddle_address(stage_one_W_addr),
        .W_real(W1_r),
        .W_imag(W1_i),
        
        .out_valid(stage_one_valid),
        .out_real(stage_one_real),
        .out_imag(stage_one_imag)
    );
    
    wire stage_two_valid;
    wire signed [15:0] stage_two_real;
    wire signed [15:0] stage_two_imag;
    
    wire [2:0] stage_two_W_addr;
    wire signed [15:0] W2_r;
    wire signed [15:0] W2_i;
    
    twiddle_rom #(.D(8), .FILE("tw_s2.mem")) rom2 (
        .address(stage_two_W_addr),
        .W_real(W2_r),
        .W_imag(W2_i)
    );
    
    stage_module #(.D(8)) stage_two (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_one_valid),
        .data_real(stage_one_real),
        .data_imag(stage_one_imag),
        
        .twiddle_address(stage_two_W_addr),
        .W_real(W2_r),
        .W_imag(W2_i),
        
        .out_valid(stage_two_valid),
        .out_real(stage_two_real),
        .out_imag(stage_two_imag)
    );
    
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
        
        .in_valid(stage_two_valid),
        .data_real(stage_two_real),
        .data_imag(stage_two_imag),
        
        .twiddle_address(stage_three_W_addr),
        .W_real(W3_r),
        .W_imag(W3_i),
        
        .out_valid(stage_three_valid),
        .out_real(stage_three_real),
        .out_imag(stage_three_imag)
    );
    
    wire stage_four_valid;
    wire signed [15:0] stage_four_real;
    wire signed [15:0] stage_four_imag;
    
    wire stage_four_W_addr;
    wire signed [15:0] W4_r;
    wire signed [15:0] W4_i;
    
    twiddle_rom #(.D(2), .FILE("tw_s4.mem")) rom4 (
        .address(stage_four_W_addr),
        .W_real(W4_r),
        .W_imag(W4_i)
    );
    
    stage_module #(.D(2)) stage_four (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_three_valid),
        .data_real(stage_three_real),
        .data_imag(stage_three_imag),
        
        .twiddle_address(stage_four_W_addr),
        .W_real(W4_r),
        .W_imag(W4_i),
        
        .out_valid(stage_four_valid),
        .out_real(stage_four_real),
        .out_imag(stage_four_imag)
    );
    
    wire stage_five_valid;
    wire signed [15:0] stage_five_real;
    wire signed [15:0] stage_five_imag;
    
    wire signed [15:0] s5W_r = 16'sd32767;
    wire signed [15:0] s5W_i = 16'sd0;
    wire stage_five_W_addr;
    
    stage_module #(.D(1)) stage_five (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_four_valid),
        .data_real(stage_four_real),
        .data_imag(stage_four_imag),
        
        .twiddle_address(stage_five_W_addr),
        .W_real(s5W_r),
        .W_imag(s5W_i),
        
        .out_valid(stage_five_valid),
        .out_real(stage_five_real),
        .out_imag(stage_five_imag)
    );
    
    
    assign out_valid = stage_five_valid;
    assign out_real = stage_five_real;
    assign out_imag = stage_five_imag;
    
endmodule
