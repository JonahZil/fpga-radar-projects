module stage_module # (
    parameter D = 4,
    parameter ADDR_WIDTH = (D <= 1) ? 1 : $clog2(D)
) (
    input clk,
    input rst,
    
    input in_valid,
    input signed [15:0] data_real,
    input signed [15:0] data_imag,
    
    
    output reg [ADDR_WIDTH - 1:0] twiddle_address,
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

    reg signed [15:0] A_p_real, A_p_imag;
    reg signed [15:0] B_p_real, B_p_imag;

    reg compute_d;   // output A'
    reg compute_d2;  // output B'

    function signed [15:0] saturate16;
        input signed [31:0] x;
        begin
            if (x > 32'sd32767)
                saturate16 = 16'sh7FFF;
            else if (x < -32'sd32768)
                saturate16 = 16'sh8000;
            else
                saturate16 = x[15:0];
        end
    endfunction

    wire do_compute = in_valid && state;

    wire signed [31:0] sum_real_w  =
        $signed({{16{A_real[15]}}, A_real}) +
        $signed({{16{data_real[15]}}, data_real});

    wire signed [31:0] sum_imag_w  =
        $signed({{16{A_imag[15]}}, A_imag}) +
        $signed({{16{data_imag[15]}}, data_imag});

    wire signed [31:0] diff_real_w =
        $signed({{16{A_real[15]}}, A_real}) -
        $signed({{16{data_real[15]}}, data_real});

    wire signed [31:0] diff_imag_w =
        $signed({{16{A_imag[15]}}, A_imag}) -
        $signed({{16{data_imag[15]}}, data_imag});

    // Input/state handling and trivial butterfly computation
    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            state <= 1'b0;
            A_real <= 16'sd0;
            A_imag <= 16'sd0;

            A_p_real <= 16'sd0;
            A_p_imag <= 16'sd0;
            B_p_real <= 16'sd0;
            B_p_imag <= 16'sd0;

            compute_d  <= 1'b0;
            compute_d2 <= 1'b0;
        end else begin
            compute_d  <= do_compute;
            compute_d2 <= compute_d;

            if (in_valid) begin
                state <= ~state;
            end

            if (!state && in_valid) begin
                // First sample of the pair
                A_real <= data_real;
                A_imag <= data_imag;
            end

            if (do_compute) begin
                // Second sample of the pair, trivial butterfly
                A_p_real <= saturate16(sum_real_w  >>> 1);
                A_p_imag <= saturate16(sum_imag_w  >>> 1);
                B_p_real <= saturate16(diff_real_w >>> 1);
                B_p_imag <= saturate16(diff_imag_w >>> 1);
            end
            
        end
    end

    // Output: first A', then B'
    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            out_valid <= 1'b0;
            out_real  <= 16'sd0;
            out_imag  <= 16'sd0;
        end else begin
            out_valid <= compute_d || compute_d2;

            if (compute_d) begin
                out_real <= A_p_real;
                out_imag <= A_p_imag;
            end else if (compute_d2) begin
                out_real <= B_p_real;
                out_imag <= B_p_imag;
            end
        end
    end
    
//Generic case for D > 1
end else begin : GEN_DN

    localparam COUNTER_WIDTH = $clog2(D);
    
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
    assign bfu_out_valid = real_delay_valid && imag_delay_valid && state && in_valid;
    
    butterfly_module bfu (
        .A_real(real_delay_out),
        .A_imag(imag_delay_out),
        .B_real(data_real),
        .B_imag(data_imag),
        .W_real(W_real),
        .W_imag(W_imag),
        
        .A_p_real(bfu_out_A_real),
        .A_p_imag(bfu_out_A_imag),
        .B_p_real(bfu_out_B_real),
        .B_p_imag(bfu_out_B_imag)
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
            if(state && in_valid) begin
                if(twiddle_address == D - 1) begin
                    twiddle_address <= 0;
                end else begin
                    twiddle_address <= twiddle_address + 1'b1;
                end
            end
        end
    end
end

endgenerate

endmodule