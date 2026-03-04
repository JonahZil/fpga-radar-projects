module stage_module # (
    parameter D = 4
) (
    input clk,
    input rst,
    
    input in_valid,
    input signed [15:0] data_real,
    input signed [15:0] data_imag,
    
    output reg out_valid,
    output reg signed [15:0] out_real,
    output reg signed [15:0] out_imag
);
    
    localparam COUNTER_WIDTH = (D > 1) ? $clog2(D) + 1 : 1;
    
    reg [COUNTER_WIDTH:0] counter;
    
    reg state;
    
    localparam WRITE_STATE = 1'd0;
    localparam READ_STATE = 1'd1;
    
    reg [D:0] write_back_reg; //Account for latency in butterfly module to write back difference in delay line
    reg [D:0] output_delay_reg; //Account for latency in delay line to output difference values in delay line 
    
    wire write_back;
    assign write_back = write_back_reg[D];
    
    wire output_delay;
    assign output_delay = output_delay_reg[D];
    
    reg advance_delay;
    
    wire signed [15:0] real_delay_data;
    wire signed [15:0] real_delay_out;
    wire real_delay_valid;
    
    wire signed[15:0] imag_delay_data;
    wire signed[15:0] imag_delay_out;
    wire imag_delay_valid;
    
    delay_line #(
        .length(D)
    ) real_delay ( 
        .clk(clk),
        .rst(rst),
        .advance_valid(advance_delay),
        .data(real_delay_data),
        .out(real_delay_out),
        .out_valid(real_delay_valid)
    );
    
    delay_line #(
        .length(D)
    ) imag_delay (
        .clk(clk),
        .rst(rst),
        .advance_valid(advance_delay),
        .data(imag_delay_data),
        .out(imag_delay_out),
        .out_valid(imag_delay_valid)
    );
    
    wire signed[15:0] bfu_A_real, bfu_A_imag;    
    wire signed[15:0] bfu_B_real, bfu_B_imag; 
    wire signed[15:0] twiddle_real, twiddle_imag;
    
    wire signed[15:0] bfu_out_A_real, bfu_out_A_imag;
    wire signed[15:0] bfu_out_B_real, bfu_out_B_imag;
    
    reg bfu_in_valid;
    wire bfu_out_valid;
    
    butterfly_module bfu (
        .clk(clk),
        .rst(rst),
        
        .A_real(bfu_A_real),
        .A_imag(bfu_A_imag),
        .B_real(bfu_B_real),
        .B_imag(bfu_B_imag),
        .W_real(twiddle_real),
        .W_imag(twiddle_imag),
        
        .A_p_real(bfu_out_A_real),
        .A_p_imag(bfu_out_A_imag),
        .B_p_real(bfu_out_B_real),
        .B_p_imag(bfu_out_B_imag),
        
        .in_valid(bfu_in_valid),
        .out_valid(bfu_out_valid)
    );
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
        
        end else begin
        
        end
    end
    
endmodule