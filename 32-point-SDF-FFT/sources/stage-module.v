module stage_module # (
    parameter D = 4,
    parameter ADDR_WIDTH = (D <= 1) ? 1 : $clog2(D),
    parameter stage_size = 32
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
//Special case for D = 2, where the butterfly latency is greater than the delay line length
end else if(D == 2) begin : GEN_D2

    reg [1:0] counter;
    
    wire state;
    assign state = counter[1]; //0: WRITE_STATE, 1: READ_STATE
    
    wire signed [15:0] real_delay_data; 
    wire signed [15:0] real_delay_out;
    wire real_delay_valid;
    
    wire signed[15:0] imag_delay_data;
    wire signed[15:0] imag_delay_out;
    wire imag_delay_valid;
    
    wire signed[15:0] bfu_out_A_real, bfu_out_A_imag;
    wire signed[15:0] bfu_out_B_real, bfu_out_B_imag;
    
    wire bfu_out_valid;
    
    reg in_valid_d;
    reg signed [15:0] data_real_d, data_imag_d;
    
    small_delay_line real_delay (
        .clk(clk),
        .rst(rst),
        .data(data_real),
        .in_valid(in_valid),
        .out(real_delay_out),
        .out_valid(real_delay_valid)
    );
    
    small_delay_line imag_delay (
        .clk(clk),
        .rst(rst),
        .data(data_imag),
        .in_valid(in_valid),
        .out(imag_delay_out),
        .out_valid(imag_delay_valid)
    );
    
    butterfly_module bfu (
        .clk(clk),
        .rst(rst),
        .A_real(real_delay_out),
        .A_imag(imag_delay_out),
        .B_real(data_real_d),
        .B_imag(data_imag_d),
        .W_real(W_real),
        .W_imag(W_imag),
        .in_valid(state),
        
        .A_p_real(bfu_out_A_real),
        .A_p_imag(bfu_out_A_imag),
        .B_p_real(bfu_out_B_real),
        .B_p_imag(bfu_out_B_imag),
        .out_valid(bfu_out_valid)
    );
    
    wire signed [15:0] buffer_real;
    wire buffer_real_valid;
    
    wire signed [15:0] buffer_imag;
    wire buffer_imag_valid;
    
    small_output_buffer buffer_r (
        .clk(clk),
        .rst(rst),
        .data(bfu_out_B_real),
        .in_valid(bfu_out_valid),
        .out(buffer_real),
        .out_valid(buffer_real_valid)
    );
    
    small_output_buffer buffer_i (
        .clk(clk),
        .rst(rst),
        .data(bfu_out_B_imag),
        .in_valid(bfu_out_valid),
        .out(buffer_imag),
        .out_valid(buffer_imag_valid)
    );

    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            counter <= 0;
            in_valid_d <= 0;
        end else begin
        
            in_valid_d <= in_valid;
            data_real_d <= data_real;
            data_imag_d <= data_imag;
            
            if(in_valid_d) begin
                counter <= counter + 1;
            end
        end
    end
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            out_valid <= 0;
            out_real <= 0;
            out_imag <= 0;
        end else begin
            if(buffer_real_valid) begin
                out_valid <= 1;
                out_real <= buffer_real;
                out_imag <= buffer_imag;
            end else if(bfu_out_valid) begin
                out_valid <= 1;
                out_real <= bfu_out_A_real;
                out_imag <= bfu_out_A_imag;
            end else begin
                out_valid <= 0;
            end
        end
    end
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            twiddle_address <= 0;
        end else begin
            if(counter < 2 && in_valid) begin
                twiddle_address <= twiddle_address + 1;
            end
        end
    end
        
//Edge case where the delay length is equal to the butterfly latency
end else if(D == 4) begin : GEN_D4

localparam COUNTER_WIDTH = $clog2(D);
    localparam LAST_DELAY = (2 * D) - 5;
    localparam STAGE_WIDTH = $clog2(stage_size) - 1;
    
    //Track how many values have been input
    reg [COUNTER_WIDTH:0] counter;

    wire state;
    assign state = counter[COUNTER_WIDTH]; //0: WRITE_STATE, 1: READ_STATE
    
    wire write_delay; //Write a value to the delay line
    
    wire signed [15:0] real_delay_data; 
    wire signed [15:0] real_delay_out;
    
    wire signed[15:0] imag_delay_data;
    wire signed[15:0] imag_delay_out;
    
    wire signed[15:0] bfu_out_A_real, bfu_out_A_imag;
    wire signed[15:0] bfu_out_B_real, bfu_out_B_imag;
    
    wire bfu_out_valid;
    reg bfu_out_valid_d;
    
    reg in_valid_d;
    reg signed [15:0] data_real_d;
    reg signed [15:0] data_imag_d;
    reg signed [15:0] bfu_out_A_real_d, bfu_out_A_imag_d;
    
    assign write_delay = (!state) || bfu_out_valid;
    
    assign real_delay_data = data_real;
    assign imag_delay_data = data_imag;
    
    //Delay line for the real values
    delay_line #(
        .length(D)
    ) real_delay ( 
        .clk(clk),
        .rst(rst),
        .write(write_delay),
        .data(real_delay_data),
        .out(real_delay_out)
    );
    
    //Delay line for the imaginary values
    delay_line #(
        .length(D)
    ) imag_delay (
        .clk(clk),
        .rst(rst),
        .write(write_delay),
        .data(imag_delay_data),
        .out(imag_delay_out)
    );
    
    butterfly_module bfu (
        .clk(clk),
        .rst(rst),
        .A_real(real_delay_out),
        .A_imag(imag_delay_out),
        .B_real(data_real_d),
        .B_imag(data_imag_d),
        .W_real(W_real),
        .W_imag(W_imag),
        .in_valid(state),
        
        .A_p_real(bfu_out_A_real),
        .A_p_imag(bfu_out_A_imag),
        .B_p_real(bfu_out_B_real),
        .B_p_imag(bfu_out_B_imag),
        .out_valid(bfu_out_valid)
    );
    
    wire signed [15:0] real_buffer_out, imag_buffer_out;
    reg [3:0] buffer_valid;
    reg buffer_out_valid;
    
    delay_line #(
        .length(D)
    ) real_buffer (
        .clk(clk),
        .rst(rst),
        .write(bfu_out_valid),
        .data(bfu_out_B_real),
        .out(real_buffer_out)
    );
    
    delay_line #(
        .length(D)
    ) imag_buffer (
        .clk(clk),
        .rst(rst),
        .write(bfu_out_valid),
        .data(bfu_out_B_imag),
        .out(imag_buffer_out)
    );
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            out_valid <= 0;
            out_real <= 0;
            out_imag <= 0;
            buffer_valid <= 4'b0000;
            buffer_out_valid <= 0;
        end else begin
            buffer_valid <= {buffer_valid[2:0], bfu_out_valid};
            buffer_out_valid <= buffer_valid[3];
            
            out_valid <= buffer_out_valid || bfu_out_valid_d;
            if(bfu_out_valid_d) begin
                out_real <= bfu_out_A_real_d;
                out_imag <= bfu_out_A_imag_d;
            end else if(buffer_out_valid) begin
                out_real <= real_buffer_out;
                out_imag <= imag_buffer_out;
            end else begin
                out_real <= 0;
                out_imag <= 0;
            end
            
        end
    end 
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            counter <= 0;
            bfu_out_valid_d <= 0;
            in_valid_d <= 0;
            data_real_d <= 0;
            data_imag_d <= 0;
            bfu_out_A_real_d <= 0;
            bfu_out_A_imag_d <= 0;

        end else begin
        
            in_valid_d <= in_valid;
            data_real_d <= data_real;
            data_imag_d <= data_imag;
            bfu_out_A_real_d <= bfu_out_A_real;
            bfu_out_A_imag_d <= bfu_out_A_imag;
            bfu_out_valid_d <= bfu_out_valid;
            
            //Increment the counter only if the input to the stage is valid
            if(in_valid_d) begin
                counter <= counter + 1;
            end
            
        end
    end
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            twiddle_address <= 0;
        end else if((counter >= D - 1) && (counter <= D + (D - 2))) begin
            twiddle_address <= twiddle_address + 1;
        end
    end

//Generic case for D > 4
end else begin : GEN_DN

    localparam COUNTER_WIDTH = $clog2(D);
    localparam LAST_COUNT = (2 * D) - 1;
    localparam LAST_DELAY = (2 * D) - 5;
    localparam STAGE_WIDTH = $clog2(stage_size) - 1;
    
    //Track how many values have been input
    reg [COUNTER_WIDTH:0] counter;
    
    //Track how many values have been output in each block
    reg [COUNTER_WIDTH:0] output_counter;
    
    //Track how many values have been output in total
    reg [STAGE_WIDTH:0] global_output_counter;

    wire state;
    assign state = counter[COUNTER_WIDTH]; //0: WRITE_STATE, 1: READ_STATE
    
    wire write_delay; //Write a value to the delay line
    
    wire signed [15:0] real_delay_data; 
    wire signed [15:0] real_delay_out;
    
    wire signed[15:0] imag_delay_data;
    wire signed[15:0] imag_delay_out;
    
    wire signed[15:0] bfu_out_A_real, bfu_out_A_imag;
    wire signed[15:0] bfu_out_B_real, bfu_out_B_imag;
    
    wire bfu_out_valid;
    
    wire write_buffer;
    reg read_buffer;
    wire signed [15:0] buffer_r, buffer_i;
    
    reg in_valid_d;
    reg signed [15:0] data_real_d;
    reg signed [15:0] data_imag_d;
    reg signed [15:0] bfu_out_A_real_d, bfu_out_A_imag_d;
    
    assign write_delay = (!state) || bfu_out_valid;
    
    assign real_delay_data = (state && !write_buffer) ? bfu_out_B_real : data_real;
    assign imag_delay_data = (state && !write_buffer) ? bfu_out_B_imag : data_imag;
    
    assign write_buffer = (!state && bfu_out_valid) || (counter == LAST_COUNT);
    
    //Delay line for the real values
    delay_line #(
        .length(D)
    ) real_delay ( 
        .clk(clk),
        .rst(rst),
        .write(write_delay),
        .data(real_delay_data),
        .out(real_delay_out)
    );
    
    //Delay line for the imaginary values
    delay_line #(
        .length(D)
    ) imag_delay (
        .clk(clk),
        .rst(rst),
        .write(write_delay),
        .data(imag_delay_data),
        .out(imag_delay_out)
    );
    
    butterfly_module bfu (
        .clk(clk),
        .rst(rst),
        .A_real(real_delay_out),
        .A_imag(imag_delay_out),
        .B_real(data_real_d),
        .B_imag(data_imag_d),
        .W_real(W_real),
        .W_imag(W_imag),
        .in_valid(state),
        
        .A_p_real(bfu_out_A_real),
        .A_p_imag(bfu_out_A_imag),
        .B_p_real(bfu_out_B_real),
        .B_p_imag(bfu_out_B_imag),
        .out_valid(bfu_out_valid)
    );
    
    output_buffer buffer_real (
        .clk(clk),
        .rst(rst),
        .write(write_buffer || read_buffer),
        .data(bfu_out_B_real),
        .out(buffer_r)
    );
    
    output_buffer buffer_imag (
        .clk(clk),
        .rst(rst),
        .write(write_buffer || read_buffer),
        .data(bfu_out_B_imag),
        .out(buffer_i)
    );
    
    reg [1:0] output_state;
    localparam IDLE_STATE = 2'd0;
    localparam SUM_STATE = 2'd1;
    localparam DELAY_STATE = 2'd2;
    localparam BUFFER_STATE = 2'd3;
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            out_real <= 0;
            out_imag <= 0;
            out_valid <= 0;
            output_state <= 0;
            output_counter <= 0;
            global_output_counter <= 0;
        end else begin
            
            global_output_counter <= global_output_counter + out_valid;
            
            case(output_state)
                
                IDLE_STATE: begin
                    out_valid <= 0;
                    read_buffer <= 0;
                    output_counter <= 0;
                    if(bfu_out_valid) begin
                        output_state <= SUM_STATE;
                    end
                end
                
                SUM_STATE: begin
                    out_valid <= 1;
                    out_real <= bfu_out_A_real_d;
                    out_imag <= bfu_out_A_imag_d;
                    output_counter <= output_counter + 1;
                    
                    if(output_counter == D - 1) begin
                        if(D > 4) begin
                            output_state <= DELAY_STATE;
                        end else begin
                            output_state <= BUFFER_STATE;
                            read_buffer <= 1;
                        end
                    end
                end
                
                DELAY_STATE: begin
                    out_real <= real_delay_out;
                    out_imag <= imag_delay_out;
                    output_counter <= output_counter + 1;
                    
                    if(output_counter == LAST_DELAY) begin
                        output_state <= BUFFER_STATE;
                        read_buffer <= 1;
                    end
                end
                
                BUFFER_STATE: begin
                    out_real <= buffer_r;
                    out_imag <= buffer_i;
                    output_counter <= output_counter + 1;
                    
                    if(output_counter == LAST_COUNT) begin
                        if(global_output_counter != stage_size - 2) begin
                            output_state <= SUM_STATE;
                        end else begin
                            output_state <= IDLE_STATE;
                        end
                        output_counter <= 0;
                        read_buffer <= 0;
                    end
                end
                
            endcase
            
        end
    end
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            counter <= 0;
            read_buffer <= 0;
        end else begin
        
            in_valid_d <= in_valid;
            data_real_d <= data_real;
            data_imag_d <= data_imag;
            bfu_out_A_real_d <= bfu_out_A_real;
            bfu_out_A_imag_d <= bfu_out_A_imag;
            
            //Increment the counter only if the input to the stage is valid
            if(in_valid_d) begin
                counter <= counter + 1;
            end
            
        end
    end
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            twiddle_address <= 0;
        end else if((counter >= D - 1) && (counter <= D + (D - 2))) begin
            twiddle_address <= twiddle_address + 1;
        end
    end
end

endgenerate

endmodule