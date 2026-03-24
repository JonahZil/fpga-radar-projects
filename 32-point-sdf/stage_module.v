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
    
    localparam COUNTER_WIDTH = (D > 1) ? $clog2(D) : 0;
    
    //One cycle delay of inputs to account for non-blocking assigments
    reg in_valid_d;
    reg signed [15:0] data_real_d;
    reg signed [15:0] data_imag_d;
    
    reg [COUNTER_WIDTH:0] counter;
    
    wire state;
    assign state = counter[COUNTER_WIDTH]; //0: WRITE_STATE, 1: READ_STATE
    
    reg [D - 1:0] output_delay_reg; //Account for latency in delay line to output difference values in delay line 
    
    wire output_delay; //Output the delay line to the next stage
    assign output_delay = output_delay_reg[D - 1];
    
    wire write_delay; //Write a value to the delay line
    wire read_delay; //Read a value from the delay line
    
    wire signed [15:0] real_delay_data; 
    wire signed [15:0] real_delay_out;
    wire real_delay_valid; 
    
    wire signed[15:0] imag_delay_data;
    wire signed[15:0] imag_delay_out;
    wire imag_delay_valid;
    
    //Delay line for the real values
    delay_line #(
        .length(D)
    ) real_delay ( 
        .clk(clk),
        .rst(rst),
        .write(write_delay),
        .data(real_delay_data),
        .out(real_delay_out),
        .out_valid(real_delay_valid)
    );
    
    //Delay line for the imaginary values
    delay_line #(
        .length(D)
    ) imag_delay (
        .clk(clk),
        .rst(rst),
        .write(write_delay),
        .data(imag_delay_data),
        .out(imag_delay_out),
        .out_valid(imag_delay_valid)
    );
    
    wire signed[15:0] twiddle_real, twiddle_imag;
    assign twiddle_real = 16'sd1000;
    assign twiddle_imag = 16'sd1000;
    
    wire signed[15:0] bfu_out_A_real, bfu_out_A_imag;
    wire signed[15:0] bfu_out_B_real, bfu_out_B_imag;
    
    wire bfu_out_valid;
    
    butterfly_module bfu (
        .clk(clk),
        .rst(rst),
        
        .A_real(real_delay_out),
        .A_imag(imag_delay_out),
        .B_real(data_real_d),
        .B_imag(data_imag_d),
        .W_real(twiddle_real),
        .W_imag(twiddle_imag),
        
        .A_p_real(bfu_out_A_real),
        .A_p_imag(bfu_out_A_imag),
        .B_p_real(bfu_out_B_real),
        .B_p_imag(bfu_out_B_imag),
        
        .in_valid(real_delay_valid && imag_delay_valid && state),
        .out_valid(bfu_out_valid)
    );
    //Write back to the delay line if the state is in WRITE (0) or write_back is high, and stage has started
    assign write_delay = (!state && in_valid) || bfu_out_valid; 
    
    //Data is difference value from BFU (1) or input data (0)
    assign real_delay_data = bfu_out_valid ? bfu_out_B_real : data_real; 
    assign imag_delay_data = bfu_out_valid ? bfu_out_B_imag : data_imag;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            out_real <= 0;
            out_imag <= 0;
            counter <= 0;
            output_delay_reg <= 0;
            out_valid <= 0;
            in_valid_d <= 0;
            data_imag_d <= 0;
            data_imag_d <= 0;
        end else begin
        
            data_real_d <= data_real;
            data_imag_d <= data_imag;
            in_valid_d <= in_valid;
            
            //Output data is either the sum from BFU (1) or from the delay line (0)
            out_real <= bfu_out_valid ? bfu_out_A_real : real_delay_out;
            out_imag <= bfu_out_valid ? bfu_out_A_imag : imag_delay_out;
            
            //Output is valid if output_delay is high or BFU has a valid sum
            out_valid <= output_delay || bfu_out_valid;
            
            //Shift output_delay register and add write_back from the write_back register to the right
            output_delay_reg <= (output_delay_reg <<< 1) + bfu_out_valid;
            
            //Increment the counter only if the input to the stage is valid
            if(in_valid_d) begin
                counter <= counter + 1;
            end
            
        end
    end
    
endmodule