module small_sdf (
    input clk,
    input rst,
    
    input in_valid,
    input signed [15:0] data_real,
    input signed [15:0] data_imag,
    
    output out_valid,
    output signed [15:0] out_real,
    output signed [15:0] out_imag
);

    wire signed [15:0] W_real;
    wire signed [15:0] W_imag;
    wire [1:0] W_address;
    
    twiddle_rom W_rom (
        .clk(clk),
        
        .address(W_address),
        
        .W_real(W_real),
        .W_imag(W_imag)
    );

    wire [1:0] stage_one_W_addr;
    
    wire stage_one_valid;
    wire signed [15:0] stage_one_real;
    wire signed [15:0] stage_one_imag;
    
    stage_module #(
        .D(4),
        .STRIDE(1)
    ) stage_one (
        .clk(clk),
        .rst(rst),
        
        .in_valid(in_valid),
        .data_real(data_real),
        .data_imag(data_imag),
        
        .twiddle_address(stage_one_W_addr),
        .W_real(W_real),
        .W_imag(W_imag),
        
        .out_valid(stage_one_valid),
        .out_real(stage_one_real),
        .out_imag(stage_one_imag)
    );
    
    wire [1:0] stage_two_W_addr;
    
    wire stage_two_valid;
    wire signed [15:0] stage_two_real;
    wire signed [15:0] stage_two_imag;
    
    stage_module #(
        .D(2),
        .STRIDE(2)
    ) stage_two (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_one_valid),
        .data_real(stage_one_real),
        .data_imag(stage_one_imag),
        
        .twiddle_address(stage_two_W_addr),
        .W_real(W_real),
        .W_imag(W_imag),
        
        .out_valid(stage_two_valid),
        .out_real(stage_two_real),
        .out_imag(stage_two_imag)
    );

    wire [1:0] stage_three_W_addr;
    
    wire stage_three_valid;
    wire signed [15:0] stage_three_real;
    wire signed [15:0] stage_three_imag;
    
    stage_module #(
        .D(1),
        .STRIDE(4)
    ) stage_three (
        .clk(clk),
        .rst(rst),
        
        .in_valid(stage_two_valid),
        .data_real(stage_two_real),
        .data_imag(stage_two_imag),
        
        .twiddle_address(stage_three_W_addr),
        .W_real(W_real),
        .W_imag(W_imag),
        
        .out_valid(stage_three_valid),
        .out_real(stage_three_real),
        .out_imag(stage_three_imag)
    );
    
    assign W_address = stage_one_W_addr + stage_two_W_addr + stage_three_W_addr;
    
    assign out_valid = stage_three_valid;
    assign out_real = stage_three_real;
    assign out_imag = stage_three_imag;
    
endmodule