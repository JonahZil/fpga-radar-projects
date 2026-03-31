module stage_module # (
    parameter D = 4,
    parameter STRIDE = 1
) (
    input clk,
    input rst,
    
    input in_valid,
    input signed [15:0] data_real,
    input signed [15:0] data_imag,
    
    output reg [1:0] twiddle_address,
    input signed [15:0] W_real,
    input signed [15:0] W_imag,
    
    output reg out_valid,
    output reg signed [15:0] out_real,
    output reg signed [15:0] out_imag
);
    
generate

//Edge case for when D = 1, where there is no delay line and trivial multiplication
if(D == 1) begin : GEN_D1

    reg state; //0: WRITE_STATE, 1: READ_STATE
    
    reg signed [15:0] A_real, A_imag;
    
    always @ (posedge clk or posedge rst) begin
        
        if(rst) begin
            state <= 0;
            A_real <= 0; A_imag <= 0;
            twiddle_address <= 0;
        end else begin
            if(in_valid) begin
                state <= ~state;
            end
            if(state == 1'b0 && in_valid) begin
                A_real <= data_real;
                A_imag <= data_imag;
            end
        end     
    end
    
    wire bfu_in_valid = in_valid && state; //Compute the butterfly
    
    wire signed[15:0] bfu_out_A_real, bfu_out_A_imag;
    wire signed[15:0] bfu_out_B_real, bfu_out_B_imag;
    
    wire bfu_out_valid;
    
    reg signed [15:0] A_p_real, A_p_imag;
    reg signed [15:0] B_p_real, B_p_imag;
    reg compute_d; //Compute signal delayed by 1 clock cycle
    reg compute_d2; //Compute signal delayed by 2 clock cycles
    
    butterfly_module bfu (
        .clk(clk),
        .rst(rst),
        
        .A_real(A_real),
        .A_imag(A_imag),
        .B_real(data_real),
        .B_imag(data_imag),
        .W_real(W_real),
        .W_imag(W_imag),
        
        .A_p_real(bfu_out_A_real),
        .A_p_imag(bfu_out_A_imag),
        .B_p_real(bfu_out_B_real),
        .B_p_imag(bfu_out_B_imag),
        
        .in_valid(bfu_in_valid),
        .out_valid(bfu_out_valid)
    );
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            twiddle_address <= 0;
        end else begin
            if(state) begin
                twiddle_address <= twiddle_address + STRIDE;
            end
        end
    end
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            A_p_real <= 0; A_p_imag <= 0;
            B_p_real <= 0; B_p_imag <= 0;
            compute_d <= 0;
            compute_d2 <= 0;
        end else begin
            compute_d <= bfu_out_valid;
            compute_d2 <= compute_d;
            if(bfu_out_valid) begin
                A_p_real <= bfu_out_A_real;
                A_p_imag <= bfu_out_A_imag;
                B_p_real <= bfu_out_B_real;
                B_p_imag <= bfu_out_B_imag;
            end
        end
    end
    
    //Handle outputs
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            out_valid <= 0;
            out_real <= 0;
            out_imag <= 0;
        end else begin
            out_valid <= compute_d || compute_d2;

            if(compute_d) begin
                out_real <= A_p_real;
                out_imag <= A_p_imag;
            end else if(compute_d2) begin
                out_real <= B_p_real;
                out_imag <= B_p_imag;
            end
        end
    end
    
//Generic case for D > 1
end else begin : GEN_DN

    localparam COUNTER_WIDTH = $clog2(D);
    localparam SDF_SIZE = 8;
    
    //Track how many values have been input
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
    
    wire signed[15:0] bfu_out_A_real, bfu_out_A_imag;
    wire signed[15:0] bfu_out_B_real, bfu_out_B_imag;
    
    wire bfu_out_valid;
    
    butterfly_module bfu (
        .clk(clk),
        .rst(rst),
        
        .A_real(real_delay_out),
        .A_imag(imag_delay_out),
        .B_real(data_real),
        .B_imag(data_imag),
        .W_real(W_real),
        .W_imag(W_imag),
        
        .A_p_real(bfu_out_A_real),
        .A_p_imag(bfu_out_A_imag),
        .B_p_real(bfu_out_B_real),
        .B_p_imag(bfu_out_B_imag),
        
        .in_valid(real_delay_valid && imag_delay_valid && state),
        .out_valid(bfu_out_valid)
    );
    
    //Write back to the delay line if [the state is in WRITE_STATE (0) with a valid input] or butterfly valid is high
    assign write_delay = (in_valid && !state) || bfu_out_valid; 
    
    //Data is difference value from BFU (1) or input data (0)
    assign real_delay_data = bfu_out_valid ? bfu_out_B_real : data_real; 
    assign imag_delay_data = bfu_out_valid ? bfu_out_B_imag : data_imag;
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            out_real <= 0;
            out_imag <= 0;
            counter <= 0;
            output_delay_reg <= 0;
            out_valid <= 0;
        end else begin
            
            //Output data is either the sum from BFU (1) or from the delay line (0)
            out_real <= bfu_out_valid ? bfu_out_A_real : real_delay_out;
            out_imag <= bfu_out_valid ? bfu_out_A_imag : imag_delay_out;
            
            //Output is valid if output_delay is high or BFU has a valid sum
            out_valid <= output_delay || bfu_out_valid;
            
            //Shift output_delay register and add write_back from the write_back register to the right
            output_delay_reg <= {output_delay_reg[D-2:0], bfu_out_valid};
            
            //Increment the counter only if the input to the stage is valid
            if(in_valid) begin
                counter <= counter + 1;
            end
            
        end
    end
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            twiddle_address <= 0;
        end else begin
            if(state) begin
                twiddle_address <= twiddle_address + STRIDE;
            end
        end
    end
end

endgenerate

endmodule