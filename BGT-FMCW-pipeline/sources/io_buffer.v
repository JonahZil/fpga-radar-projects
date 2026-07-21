module top_io_buffer # (
    parameter N = 64
) (
    input clk,
    input rst,
    
    input start,
    
    input MISO,
    input IRQ,
    
    output SCLK,
    output MOSI,
    output SRST,
    output CS_N,

    input out_ready,
   
    output signed [47:0] out_data,
    output reg out_valid
);
    
    localparam ADDR_WIDTH = $clog2(N);
    
    wire signed [47:0] bram_data_i;
    wire signed [47:0] bram_data_o;
   
    wire write_mem;
    reg [ADDR_WIDTH - 1:0] read_address;
    reg [ADDR_WIDTH - 1:0] write_address;
  
    reg [ADDR_WIDTH:0] load_counter;
    reg [ADDR_WIDTH:0] read_issue_counter;
    
    wire signed [47:0] driver_output;
    wire driver_valid;
    
    wire fft_rst;
    wire buffer_ready;
    assign buffer_ready = (state == STATE_LOAD) && (load_counter == 0);
    
    bgt_master #(
        .CONFIGURE_LENGTH(39),
        .CHIRP_SIZE(64),
        .FRAME_DELAY(5000000)
    ) bgt_driver (
        .clk(clk),
        .start(start),
        .rst(rst),
        
        .MISO(MISO),
        .IRQ(IRQ),
        
        .fft_rst(fft_rst),
        .buffer_ready(buffer_ready),
        
        .SCLK(SCLK),
        .MOSI(MOSI),
        .SRST(SRST),
        .CS_N(CS_N),
        
        .adc_output(driver_output),
        .out_valid(driver_valid)
    );
    
    //Internal buffer BRAM module
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
    
    reg fft_in_valid;
    wire fft_out_valid;
    wire signed [23:0] fft_out_real;
    wire signed [23:0] fft_out_imag;
    
    //Instantiation of FFT module
    sdf_fft_64 fft (
        .clk(clk),
        .rst(rst || fft_rst),
        
        .in_valid(fft_in_valid),
        .data_real(bram_data_o[47:24]),
        .data_imag(bram_data_o[23:0]),
        
        .out_valid(fft_out_valid),
        .out_real(fft_out_real),
        .out_imag(fft_out_imag)
    );

    reg [1:0] state;
    localparam STATE_LOAD = 2'd0;
    localparam STATE_FFT = 2'd1;
    localparam STATE_OUTPUT = 2'd2;
    
    assign write_mem = ((state == STATE_LOAD) && driver_valid) || ((state == STATE_FFT)  && fft_out_valid);
    
    assign bram_data_i = (state == STATE_LOAD) ? driver_output : {fft_out_real, fft_out_imag};
    
    assign out_data = bram_data_o;
    
    reg bram_valid_d;
    
    //Buffer FSM
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
        end else begin
            case (state)
                
                //In this state, data sent from the BGT radar gets loaded into the buffer
                STATE_LOAD: begin
                    fft_in_valid <= 0;
                    out_valid <= 0;
    
                    if (driver_valid && load_counter < N) begin
                        write_address <= write_address + 1;
                        load_counter <= load_counter + 1;
                    end
                    
                    //If the last value has been input, transition to STATE_FFT
                    if(load_counter == N) begin
                        state <= STATE_FFT;
                        write_address <= 0;
                        read_address <= 0;
                        read_issue_counter <= 0;
                        load_counter <= 0;
                        bram_valid_d <= 0;
                    end
                   
                end
                
                //In this state, data is sent from the buffer into the FFT.
                //The output of the FFT gets written back into the buffer
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
                    
                    //If the last output has been written into the buffer, switch to STATE_OUTPUT
                    if(write_address == N - 1) begin
                        state <= STATE_OUTPUT;
                        load_counter <= 0;
                        read_address <= 0;
                        read_issue_counter <= 1;
                        bram_valid_d <= 0;
                    end
                end
                
                //In this state, the outputs of the FFT are output to the AXI slave
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
                            //If the last output of the FFT has been output, go back to STATE_LOAD
                            state <= STATE_LOAD;
                            read_address <= 0;
                            write_address <= 0;
                            fft_in_valid <= 0;
                            load_counter <= 0;
                            read_issue_counter <= 0;
                            bram_valid_d <= 0;
                            out_valid <= 0;
                        end
                    end
                end
                
            endcase
        end
    end

endmodule