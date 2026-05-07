module top_io_buffer # (
    parameter N = 32
) (
    input clk,
    input rst,
    
    (* mark_debug = "true" *) input signed [47:0] in_data,
    (* mark_debug = "true" *) input in_valid,
    (* mark_debug = "true" *) input out_ready,
    
    (* mark_debug = "true" *) output signed [47:0] out_data,
    (* mark_debug = "true" *) output reg out_valid,
    (* mark_debug = "true" *) output reg in_ready
);
    
    localparam ADDR_WIDTH = $clog2(N);
    
    (* mark_debug = "true" *) wire signed [47:0] bram_data_i;
    (* mark_debug = "true" *) wire signed [47:0] bram_data_o;
    
    (* mark_debug = "true" *) wire write_mem;
    (* mark_debug = "true" *) reg [ADDR_WIDTH:0] read_address;
    (* mark_debug = "true" *) reg [ADDR_WIDTH:0] write_address;
   
    (* mark_debug = "true" *) reg [ADDR_WIDTH + 1:0] load_counter;
    (* mark_debug = "true" *) reg [ADDR_WIDTH + 1:0] read_issue_counter;
    
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A        (ADDR_WIDTH),
        .ADDR_WIDTH_B        (ADDR_WIDTH),
        .AUTO_SLEEP_TIME     (0),
        .BYTE_WRITE_WIDTH_A  (48),
        .CASCADE_HEIGHT      (0),
        .CLOCKING_MODE       ("common_clock"),
        .ECC_MODE            ("no_ecc"),
        .MEMORY_INIT_FILE    ("none"),
        .MEMORY_INIT_PARAM   ("0"),
        .MEMORY_OPTIMIZATION ("true"),
        .MEMORY_PRIMITIVE    ("block"),
        .MEMORY_SIZE         (48 * N),
        .MESSAGE_CONTROL     (0),
        .READ_DATA_WIDTH_B   (48),
        .READ_LATENCY_B      (1),
        .READ_RESET_VALUE_B  ("0"),
        .RST_MODE_A          ("SYNC"),
        .RST_MODE_B          ("SYNC"),
        .SIM_ASSERT_CHK      (0),
        .USE_EMBEDDED_CONSTRAINT (0),
        .USE_MEM_INIT        (1),
        .WAKEUP_TIME         ("disable_sleep"),
        .WRITE_DATA_WIDTH_A  (48),
        .WRITE_MODE_B        ("read_first")
    ) mem (
        .clka           (clk),
        .ena            (1'b1),
        .wea            (write_mem),
        .addra          (write_address),
        .dina           (bram_data_i),

        .clkb           (clk),
        .enb            (1'b1),
        .addrb          (read_address),
        .doutb          (bram_data_o),

        .rstb           (rst),
        .regceb         (1'b1),

        .injectdbiterra (1'b0),
        .injectsbiterra (1'b0),
        .sleep          (1'b0),
        .dbiterrb       (),
        .sbiterrb       ()
    );
    
    (* mark_debug = "true" *) reg fft_in_valid;
    (* mark_debug = "true" *) wire fft_out_valid;
    (* mark_debug = "true" *) wire signed [23:0] fft_out_real;
    (* mark_debug = "true" *) wire signed [23:0] fft_out_imag;
    
    sdf_fft_128 fft (
        .clk(clk),
        .rst(rst),
        
        .in_valid(fft_in_valid),
        .data_real(bram_data_o[47:24]),
        .data_imag(bram_data_o[23:0]),
        
        .out_valid(fft_out_valid),
        .out_real(fft_out_real),
        .out_imag(fft_out_imag)
    );

    (* mark_debug = "true" *) reg [1:0] state;
    localparam STATE_LOAD = 2'd0;
    localparam STATE_FFT = 2'd1;
    localparam STATE_OUTPUT = 2'd2;
    
    assign write_mem = ((state == STATE_LOAD) && in_valid) || ((state == STATE_FFT)  && fft_out_valid);
    
    assign bram_data_i = (state == STATE_LOAD) ? in_data : {fft_out_real, fft_out_imag};
    
    assign out_data = bram_data_o;
    
    (* mark_debug = "true" *) reg bram_valid_d;
    
    (* mark_debug = "true" *) reg [ADDR_WIDTH:0] buffer_consume_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buffer_consume_count <= 0;
        end else begin
            if (state == STATE_LOAD) begin
                buffer_consume_count <= 0;
            end else if (state == STATE_OUTPUT && out_valid && out_ready) begin
                buffer_consume_count <= buffer_consume_count + 1;
            end
        end
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_LOAD;
            read_address <= 0;
            write_address <= 0;
            fft_in_valid <= 0;
            load_counter <= 0;
            read_issue_counter <= 0;
            bram_valid_d <= 0;
            out_valid <= 0;
            in_ready <= 0;
        end else begin
            case (state)
    
                STATE_LOAD: begin
                    fft_in_valid <= 0;
                    out_valid <= 0;
                    in_ready <= 1;
    
                    if (in_valid && load_counter < N) begin
                        write_address <= write_address + 1;
                        load_counter <= load_counter + 1;
                    end
                    
                    if(load_counter == N) begin
                        state <= STATE_FFT;
                        write_address <= 0;
                        read_address <= 0;
                        read_issue_counter <= 0;
                        in_ready <= 0;
                        load_counter <= 0;
                        bram_valid_d <= 0;
                    end
                   
                end
                
                
                STATE_FFT: begin
                    if (read_issue_counter < N) begin
                        read_address <= read_issue_counter[ADDR_WIDTH:0];
                        read_issue_counter <= read_issue_counter + 1;
                        bram_valid_d <= 1;
                    end else begin
                        bram_valid_d <= 0;
                    end
    
                    fft_in_valid <= bram_valid_d;
                    
                    if(fft_out_valid) begin
                        write_address <= write_address + 1;
                    end
                    
                    if(write_address == N - 1) begin
                        state <= STATE_OUTPUT;
                        load_counter <= 0;
                        read_address <= 0;
                        read_issue_counter <= 1;
                        bram_valid_d <= 0;
                    end
                end
                
                STATE_OUTPUT: begin
                
                    out_valid <= bram_valid_d;
                    
                    if(read_issue_counter <= N) begin
                        bram_valid_d <= 1;
                    end else begin
                        bram_valid_d <= 0;
                    end
                    
                    if(out_ready) begin
                        if (read_issue_counter < N) begin
                            read_address <= read_issue_counter[ADDR_WIDTH - 1:0];
                            read_issue_counter <= read_issue_counter + 1;
                        end else begin
                            state <= STATE_LOAD;
                        end
                    end
                end
                
            endcase
        end
    end

endmodule