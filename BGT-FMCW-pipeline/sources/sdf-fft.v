module sdf_fft_64 (
    input clk,
    input rst,
    
    input in_valid,
    input signed [23:0] data_real,
    input signed [23:0] data_imag,
    
    output out_valid,
    output signed [23:0] out_real,
    output signed [23:0] out_imag
);
    
    /*
    wire stage_one_valid;
    wire signed [23:0] stage_one_real;
    wire signed [23:0] stage_one_imag;
    
    wire [10:0] stage_one_W_addr;
    wire signed [15:0] W1_r;
    wire signed [15:0] W1_i;
    
    twiddle_rom #(.D(2048), .FILE("tw_s1.mem")) rom1 (
        .clk(clk),
        .address(stage_one_W_addr),
        .W_real(W1_r),
        .W_imag(W1_i)
    );
    
    stage_module #(.D(2048)) stage_one (
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
    wire signed [23:0] stage_two_real;
    wire signed [23:0] stage_two_imag;
    
    wire [9:0] stage_two_W_addr;
    wire signed [15:0] W2_r;
    wire signed [15:0] W2_i;
    
    twiddle_rom #(.D(1024), .FILE("tw_s2.mem")) rom2 (
        .clk(clk),
        .address(stage_two_W_addr),
        .W_real(W2_r),
        .W_imag(W2_i)
    );
    
    stage_module #(.D(1024)) stage_two (
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
    wire signed [23:0] stage_three_real;
    wire signed [23:0] stage_three_imag;
    
    wire [8:0] stage_three_W_addr;
    wire signed [15:0] W3_r;
    wire signed [15:0] W3_i;
    
    twiddle_rom #(.D(512), .FILE("tw_s3.mem")) rom3 (
        .clk(clk),
        .address(stage_three_W_addr),
        .W_real(W3_r),
        .W_imag(W3_i)
    );
    
    stage_module #(.D(512)) stage_three (
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
    wire signed [23:0] stage_four_real;
    wire signed [23:0] stage_four_imag;
    
    wire [7:0] stage_four_W_addr;
    wire signed [15:0] W4_r;
    wire signed [15:0] W4_i;
    
    twiddle_rom #(.D(256), .FILE("tw_s4.mem")) rom4 (
        .clk(clk),
        .address(stage_four_W_addr),
        .W_real(W4_r),
        .W_imag(W4_i)
    );
    
    stage_module #(.D(256)) stage_four (
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
    wire signed [23:0] stage_five_real;
    wire signed [23:0] stage_five_imag;
    
    wire signed [15:0] W5_r;
    wire signed [15:0] W5_i;
    wire [6:0] stage_five_W_addr;
    
    twiddle_rom #(.D(128), .FILE("tw_s5.mem")) rom5 (
        .clk(clk),
        .address(stage_five_W_addr),
        .W_real(W5_r),
        .W_imag(W5_i)
    );
    
    stage_module #(.D(128)) stage_five (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_four_valid),
        .data_real(stage_four_real),
        .data_imag(stage_four_imag),
        
        .twiddle_address(stage_five_W_addr),
        .W_real(W5_r),
        .W_imag(W5_i),
        
        .out_valid(stage_five_valid),
        .out_real(stage_five_real),
        .out_imag(stage_five_imag)
    );
    
    
    wire stage_six_valid;
    wire signed [23:0] stage_six_real;
    wire signed [23:0] stage_six_imag;
    
    wire signed [15:0] W6_r;
    wire signed [15:0] W6_i;
    wire [5:0] stage_six_W_addr;
    
    twiddle_rom #(.D(64), .FILE("tw_s6.mem")) rom6 (
        .clk(clk),
        .address(stage_six_W_addr),
        .W_real(W6_r),
        .W_imag(W6_i)
    );
    
    stage_module #(.D(64)) stage_six (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_five_valid),
        .data_real(stage_five_real),
        .data_imag(stage_five_imag),
        
        .twiddle_address(stage_six_W_addr),
        .W_real(W6_r),
        .W_imag(W6_i),
        
        .out_valid(stage_six_valid),
        .out_real(stage_six_real),
        .out_imag(stage_six_imag)
    );
    */
    wire stage_seven_valid;
    wire signed [23:0] stage_seven_real;
    wire signed [23:0] stage_seven_imag;
    
    wire signed [15:0] W7_r;
    wire signed [15:0] W7_i;
    wire [4:0] stage_seven_W_addr;
    
    twiddle_rom #(.D(32), .FILE("tw_s7.mem")) rom7 (
        .clk(clk),
        .address(stage_seven_W_addr),
        .W_real(W7_r),
        .W_imag(W7_i)
    );
    
    stage_module #(.D(32)) stage_seven (
        .clk(clk),
        .rst(rst),
        
        .in_valid(in_valid),
        .data_real(data_real),
        .data_imag(data_imag),
        
        .twiddle_address(stage_seven_W_addr),
        .W_real(W7_r),
        .W_imag(W7_i),
        
        .out_valid(stage_seven_valid),
        .out_real(stage_seven_real),
        .out_imag(stage_seven_imag)
    );
    
    wire stage_eight_valid;
    wire signed [23:0] stage_eight_real;
    wire signed [23:0] stage_eight_imag;
    
    wire signed [15:0] W8_r;
    wire signed [15:0] W8_i;
    wire [3:0] stage_eight_W_addr;
    
    twiddle_rom #(.D(16), .FILE("tw_s8.mem")) rom8 (
        .clk(clk),
        .address(stage_eight_W_addr),
        .W_real(W8_r),
        .W_imag(W8_i)
    );
    
    stage_module #(.D(16)) stage_eight (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_seven_valid),
        .data_real(stage_seven_real),
        .data_imag(stage_seven_imag),
        
        .twiddle_address(stage_eight_W_addr),
        .W_real(W8_r),
        .W_imag(W8_i),
        
        .out_valid(stage_eight_valid),
        .out_real(stage_eight_real),
        .out_imag(stage_eight_imag)
    );
    
    wire stage_nine_valid;
    wire signed [23:0] stage_nine_real;
    wire signed [23:0] stage_nine_imag;
    
    wire signed [15:0] W9_r;
    wire signed [15:0] W9_i;
    wire [2:0] stage_nine_W_addr;
    
    twiddle_rom #(.D(8), .FILE("tw_s9.mem")) rom9 (
        .clk(clk),
        .address(stage_nine_W_addr),
        .W_real(W9_r),
        .W_imag(W9_i)
    );
    
    stage_module #(.D(8)) stage_nine (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_eight_valid),
        .data_real(stage_eight_real),
        .data_imag(stage_eight_imag),
        
        .twiddle_address(stage_nine_W_addr),
        .W_real(W9_r),
        .W_imag(W9_i),
        
        .out_valid(stage_nine_valid),
        .out_real(stage_nine_real),
        .out_imag(stage_nine_imag)
    );
    
    wire stage_ten_valid;
    wire signed [23:0] stage_ten_real;
    wire signed [23:0] stage_ten_imag;
    
    wire signed [15:0] W10_r;
    wire signed [15:0] W10_i;
    wire [1:0] stage_ten_W_addr;
    
    twiddle_rom #(.D(4), .FILE("tw_s10.mem")) rom10 (
        .clk(clk),
        .address(stage_ten_W_addr),
        .W_real(W10_r),
        .W_imag(W10_i)
    );
    
    stage_module #(.D(4)) stage_ten (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_nine_valid),
        .data_real(stage_nine_real),
        .data_imag(stage_nine_imag),
        
        .twiddle_address(stage_ten_W_addr),
        .W_real(W10_r),
        .W_imag(W10_i),
        
        .out_valid(stage_ten_valid),
        .out_real(stage_ten_real),
        .out_imag(stage_ten_imag)
    );
    
    wire stage_eleven_valid;
    wire signed [23:0] stage_eleven_real;
    wire signed [23:0] stage_eleven_imag;
    
    wire signed [15:0] W11_r;
    wire signed [15:0] W11_i;
    wire stage_eleven_W_addr;
    
    twiddle_rom #(.D(2), .FILE("tw_s11.mem")) rom11 (
        .clk(clk),
        .address(stage_eleven_W_addr),
        .W_real(W11_r),
        .W_imag(W11_i)
    );
    
    stage_module #(.D(2)) stage_eleven (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_ten_valid),
        .data_real(stage_ten_real),
        .data_imag(stage_ten_imag),
        
        .twiddle_address(stage_eleven_W_addr),
        .W_real(W11_r),
        .W_imag(W11_i),
        
        .out_valid(stage_eleven_valid),
        .out_real(stage_eleven_real),
        .out_imag(stage_eleven_imag)
    );
    
    wire stage_twelve_valid;
    wire signed [23:0] stage_twelve_real;
    wire signed [23:0] stage_twelve_imag;
    
    wire signed [15:0] W12_r;
    wire signed [15:0] W12_i;
    wire stage_twelve_W_addr;
    
    stage_module #(.D(1), .SCALE_BFU(1)) stage_twelve (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_eleven_valid),
        .data_real(stage_eleven_real),
        .data_imag(stage_eleven_imag),
        
        .twiddle_address(stage_twelve_W_addr),
        .W_real(W12_r),
        .W_imag(W12_i),
        
        .out_valid(stage_twelve_valid),
        .out_real(stage_twelve_real),
        .out_imag(stage_twelve_imag)
    );
    
    assign out_valid = stage_twelve_valid;
    assign out_real = stage_twelve_real;
    assign out_imag = stage_twelve_imag;
    
endmodule
