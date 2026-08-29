module top_io_buffer # (
    parameter N = 64,
    parameter RX_COUNT = 3,
    parameter FRAME_DELAY = 12500000
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
   
    output wire [11:0] out_data,
    output reg out_valid
);
    
    localparam ADDR_WIDTH = $clog2(N * RX_COUNT);
   
    wire write_mem;
    reg [ADDR_WIDTH - 1:0] read_address;
    reg [ADDR_WIDTH - 1:0] write_address;
  
    reg [ADDR_WIDTH:0] load_counter;
    reg [ADDR_WIDTH:0] read_issue_counter;
    
    wire [11:0] driver_output;
    wire driver_valid;
    
    wire buffer_ready;
    assign buffer_ready = (state == STATE_LOAD) && (load_counter == 0);
    
    wire status;
    wire status_valid;
    
    bgt_master #(
        .CONFIGURE_LENGTH(39),
        .CHIRP_SIZE(N * RX_COUNT),
        .FRAME_DELAY(FRAME_DELAY)
    ) bgt_driver (
        .clk(clk),
        .start(start),
        .rst(rst),
        
        .MISO(MISO),
        .IRQ(IRQ),

        .buffer_ready(buffer_ready),
        
        .SCLK(SCLK),
        .MOSI(MOSI),
        .SRST(SRST),
        .CS_N(CS_N),
        
        .adc_output(driver_output),
        .out_valid(driver_valid),
        
        .status(status),
        .status_valid(status_valid)
    );
    
    buffer_module # (
        .SAMPLE_COUNT(N),
        .RX_COUNT(RX_COUNT)
    ) bram (
        .clk(clk),
        .rst(rst),
        
        .write(write_mem),
        .write_address(write_address),
        .data_in(driver_output),
        
        .read_address(read_address),
        .data_out(out_data)
    );

    reg [1:0] state;
    localparam STATE_LOAD = 2'd0;
    localparam STATE_STATUS = 2'd1;
    localparam STATE_OUTPUT = 2'd2;
    
    assign write_mem = state == STATE_LOAD && driver_valid && (load_counter < N * RX_COUNT);
    
    reg bram_valid_d;
    
    //Buffer FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_LOAD;
            read_address <= 0;
            write_address <= 0;
            load_counter <= 0;
            read_issue_counter <= 0;
            bram_valid_d <= 0;
            out_valid <= 0;
        end else begin
            case (state)
                
                //In this state, data sent from the BGT radar gets loaded into the buffer
                STATE_LOAD: begin
                    out_valid <= 0;
    
                    if (driver_valid && load_counter < N * RX_COUNT) begin
                        write_address <= write_address + 1;
                        load_counter <= load_counter + 1;
                    end
                    
                    //If the last value has been input, transition to STATE_OUTPUT
                    if(load_counter == N * RX_COUNT) begin
                        state <= STATE_STATUS;
                        write_address <= 0;
                        read_address <= 0;
                        read_issue_counter <= 1;
                        load_counter <= 0;
                        bram_valid_d <= 0;
                    end
                   
                end
                
                STATE_STATUS: begin
                    if(status_valid) begin
                        if(status) begin
                            state <= STATE_LOAD;
                            read_address <= 0;
                            write_address <= 0;
                            load_counter <= 0;
                            read_issue_counter <= 0;
                            bram_valid_d <= 0;
                            out_valid <= 0;
                        end else begin 
                            state <= STATE_OUTPUT;
                        end
                    end
                end
                
                //In this state, the outputs of the FFT are output to the AXI slave
                STATE_OUTPUT: begin
                
                    out_valid <= bram_valid_d;
                    
                    if(read_issue_counter <= N * RX_COUNT) begin
                        bram_valid_d <= 1;
                    end else begin
                        bram_valid_d <= 0;
                    end
                    
                    if(out_ready) begin
                        if (read_issue_counter < N * RX_COUNT) begin
                            read_address <= read_issue_counter[ADDR_WIDTH - 1:0];
                            read_issue_counter <= read_issue_counter + 1;
                        end else begin
                            //If the last output has been output, go back to STATE_LOAD
                            state <= STATE_LOAD;
                            read_address <= 0;
                            write_address <= 0;
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