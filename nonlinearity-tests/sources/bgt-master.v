module bgt_master #(
    parameter CONFIGURE_LENGTH = 32, //How many configurations need to be done
    parameter CHIRP_SIZE = 64,
    parameter RX_CNT = 3,
    parameter FRAME_DELAY = 2500000,
    parameter CHIRP_REPEAT_COUNT = 15,
    parameter CHIRP_COUNT = 1000,
    parameter DISCARD_CHIRP_COUNT = 500,
    parameter CONFIGURE_DELAY = 50000
) (
    input clk,
    input start,
    input rst,
    
    input MISO,
    input IRQ,
    
    input buffer_ready,
    
    output wire SCLK,
    output wire MOSI,
    output reg SRST,
    output wire CS_N,
    
    output reg [11:0] adc_output,
    output reg out_valid,
    
    output reg status,
    output reg status_valid
);
    
    reg [6:0] clk_counter; 
    reg [31:0] delay_counter;
    
    localparam IDLE_STATE = 4'd0;
    localparam FIRST_DELAY_STATE = 4'd1;
    localparam RESET_STATE = 4'd2;
    localparam SECOND_DELAY_STATE = 4'd3;
    localparam CONFIGURE_STATE = 4'd4;
    localparam CONFIGURE_DELAY_STATE = 4'd5;
    localparam CHIRP_DELAY_STATE = 4'd6;
    localparam FIFO_READ_STATE = 4'd7;
    localparam STATUS_READ_STATE = 4'd8;
    localparam UART_DELAY_STATE = 4'd9;
    localparam FPGA_RESET_STATE = 4'd10;
    localparam SOFT_RESET_STATE = 4'd11;
    localparam PACR_WRITE_STATE = 4'd12;
    localparam FRAME_START_STATE = 4'd13;
    reg [3:0] state;
    
    reg valid_word;
    reg [31:0] master_word;
    
    wire [31:0] bgt_word; //The output of the BGT
    wire master_ready;
    wire master_valid;
    
    wire SCLK_M;
    wire CS_N_M;
    wire MOSI_M;
    
    spi_master master(
        .clk(clk),
        .rst(rst),
        
        .in_valid(valid_word),
        .in_data(master_word),
        .out_ready(1'b1),
        
        .MISO(MISO),
        .SCLK(SCLK_M),
        .CS_N(CS_N_M),
        .MOSI(MOSI_M),
        
        .out_data(bgt_word),
        .in_ready(master_ready),
        .out_valid(master_valid)
    );
    
    localparam CONFIG_IDLE_STATE = 2'd0;
    localparam CONFIG_ACTIVE_STATE = 2'd1;
    localparam CONFIG_OUTPUT_STATE = 2'd2;
    reg [1:0] configure_state;
    
    localparam TOTAL_CONFIG_LENGTH = CONFIGURE_LENGTH * CHIRP_REPEAT_COUNT;
    localparam CONFIG_ADDR_WIDTH = $clog2(TOTAL_CONFIG_LENGTH);
    
    reg [5:0] configure_count;
    reg [15:0] chirp_count;
    reg [7:0] repeat_count;
    
    reg [CONFIG_ADDR_WIDTH - 1:0] configure_address;
    wire [31:0] configure_rom_word;
    config_rom #(
        .FILE("t120us_15.mem"),
        .LENGTH(TOTAL_CONFIG_LENGTH),
        .CONFIG_ADDR_WIDTH(CONFIG_ADDR_WIDTH)
    ) config_rom (
        .clk(clk),
        .address(configure_address),
        .rom_out(configure_rom_word)
    );
    
    reg [15:0] configure_delay_count;
    
    wire SCLK_B;
    wire CS_N_B;
    wire MOSI_B;
    
    assign SCLK = (state == FIFO_READ_STATE) ? SCLK_B : SCLK_M;
    assign MOSI = (state == FIFO_READ_STATE) ? MOSI_B : MOSI_M;
    assign CS_N = (state == FIFO_READ_STATE) ? CS_N_B : CS_N_M;
    
    reg start_burst_read;
    wire [11:0] raw_sample;
    wire sample_valid;
    
    wire burst_read_ready;
    
    wire invalid_sample;
    assign invalid_sample = bgt_word[23] | bgt_word[19];
    
    burst_spi_master #(
        .CHIRP_SIZE(CHIRP_SIZE)
    ) burst_reader (
        .clk(clk),
        .rst(rst),
        .MISO(MISO),
        
        .SCLK(SCLK_B),
        .CS_N(CS_N_B),
        .MOSI(MOSI_B),
        
        .start_burst(start_burst_read),
        .out_data(raw_sample),
        .out_valid(sample_valid),
        .in_ready(burst_read_ready)
    );
    
    always @(posedge clk) begin
        
        if(rst) begin
            SRST <= 1'b1;
            state <= IDLE_STATE;
            clk_counter <= 7'd0;
            valid_word  <= 1'b0;
            master_word <= 32'd0;
            configure_address <= 6'd0;
            configure_state <= 2'd0;
            adc_output <= 12'd0;
            out_valid <= 1'b0;
            start_burst_read <= 1'b0;
            delay_counter <= 32'd0;
            configure_count <= 6'd0;
            chirp_count <= 16'd0;
            repeat_count <= 8'd0;
            configure_delay_count <= 16'd0;
            status_valid <= 1'b0;
            status <= 1'b0;
        end else begin
            
            case(state)
                
                //In this state, nothing gets sent over SPI until the physical start button is pressed
                IDLE_STATE: begin
                    valid_word <= 1'b0;
                    master_word <= 32'd0;
                    if(start) begin
                        state <= FIRST_DELAY_STATE;
                    end
                end
                
                //In this state, SRST goes high for 1000ns.
                //The following states perform the hardware reset.
                FIRST_DELAY_STATE: begin
                    SRST <= 1'b1;
                    clk_counter <= clk_counter + 1;
                    if(clk_counter == 7'd100) begin
                        state <= RESET_STATE;
                        clk_counter <= 7'd0;
                    end
                end
                
                //SRST goes low for 1000ns
                RESET_STATE: begin
                    SRST <= 1'b0;
                    clk_counter <= clk_counter + 1;
                    if(clk_counter == 7'd100) begin
                        state <= SECOND_DELAY_STATE;
                        clk_counter <= 7'd0;
                    end
                end
                
                //SRST goes high for 1000ns
                SECOND_DELAY_STATE: begin
                    SRST <= 1'b1;
                    clk_counter <= clk_counter + 1;
                    if(clk_counter == 7'd100) begin
                        state <= CONFIGURE_STATE;
                        clk_counter <= 7'd0;
                    end
                end
                
                //In this state, each register is configured according to their respective value in FILE
                CONFIGURE_STATE: begin
                    
                    case(configure_state)
                        
                        //Wait until the SPI master can send a new word
                        CONFIG_IDLE_STATE: begin
                            if(master_ready) begin
                                master_word <= configure_rom_word;
                                valid_word <= 1'b1;
                                configure_address <= configure_address + 1;
                                configure_count <= configure_count + 1;
                                configure_state <= CONFIG_ACTIVE_STATE;
                            end
                        end
                        
                        //Wait until the SPI master has a valid word
                        CONFIG_ACTIVE_STATE: begin
                            valid_word <= 1'b0;
                            if(master_valid) begin
                                configure_state <= CONFIG_OUTPUT_STATE;
                            end
                        end
                        
                        //If the last configuration is sent, switch to CHIRP_DELAY_STATE
                        //Else, wait for next configuration
                        CONFIG_OUTPUT_STATE: begin
                            if(configure_count == CONFIGURE_LENGTH) begin
                                state <= CONFIGURE_DELAY_STATE;
                                configure_count <= 6'd0;
                            end else begin
                                configure_state <= CONFIG_IDLE_STATE;
                            end
                        end
                        
                    endcase;
                    
                end
                
                CONFIGURE_DELAY_STATE: begin
                    configure_delay_count <= configure_delay_count + 1;
                    if(configure_delay_count == CONFIGURE_DELAY) begin
                        state <= CHIRP_DELAY_STATE;
                    end
                end
                
                //In this state, the code waits until IRQ goes high (meaning the FIFO has reached its threshold)
                CHIRP_DELAY_STATE: begin
                    configure_delay_count <= 16'd0;
                    if(IRQ) begin
                        master_word <= 32'hFFC00000;
                        valid_word <= 1'b1;
                        start_burst_read <= 1'b1;
                    end
                    
                    if(master_valid) begin
                        state <= FIFO_READ_STATE;
                    end
                end
                
                //In this state, the FIFO data, which is sent over burst mode, is read and output to the io buffer
                FIFO_READ_STATE: begin
                    valid_word <= 1'b0;
                    start_burst_read <= 1'b0;
                    //If the burst reader is done, switch to UART_DELAY_STATE
                    if(burst_read_ready) begin
                        out_valid <= 1'b0;
                        state <= STATUS_READ_STATE;
                    end else begin
                        //If the burst reader has a valid sample, output it
                        if(sample_valid) begin
                            adc_output <= raw_sample;
                            out_valid <= 1'b1;
                        end else begin
                            out_valid <= 1'b0;
                        end
                    end
                end
                
                STATUS_READ_STATE: begin
                    if(master_ready) begin
                        master_word <= 32'hBE000000;
                        valid_word <= 1'b1;
                    end else begin
                        valid_word <= 1'b0;
                    end
                    
                    if(master_valid) begin
                        status <= invalid_sample;
                        status_valid <= 1'b1;
                        if(~invalid_sample) begin
                            chirp_count <= chirp_count + 1;
                        end
                        state <= UART_DELAY_STATE;
                    end
                end
                
                //In this state, the BGT master is reset while the top io buffer computes and while data is sent over UART.
                //The delay is set by FRAME_DELAY
                UART_DELAY_STATE: begin
                    out_valid <= 1'b0;
                    adc_output <= 12'd0;
                    
                    if(delay_counter < FRAME_DELAY - 1) begin
                        delay_counter <= delay_counter + 1;
                    end else if (buffer_ready) begin
                        if(chirp_count == CHIRP_COUNT + DISCARD_CHIRP_COUNT) begin
                            if(repeat_count == CHIRP_REPEAT_COUNT - 1) begin
                                status_valid <= 1'b0;
                                state <= IDLE_STATE;
                            end else begin
                                repeat_count <= repeat_count + 1;
                                status_valid <= 1'b0;
                                state <= FIRST_DELAY_STATE;
                                chirp_count <= 16'd0;
                                delay_counter <= 32'd0;
                            end
                        end else begin
                            state <= SOFT_RESET_STATE;
                        end
                    end
                end
           
                //In this state, the BGT resets the FIFO and FSM
                SOFT_RESET_STATE: begin
                    status_valid <= 1'b0;
                    status <= 1'b0;
                    if(master_ready) begin
                        master_word <= 32'h011E827C;
                        valid_word <= 1'b1;
                    end else begin
                        valid_word <= 1'b0;
                    end
                    
                    if(master_valid) begin
                        state <= PACR_WRITE_STATE;
                    end
                end
                
                //In this state, PACR1 is written to as needed after FSM reset
                PACR_WRITE_STATE: begin
                    if(master_ready) begin
                        master_word <= 32'h09E967FD;
                        valid_word <= 1'b1;
                    end else begin
                        valid_word <= 1'b0;
                    end
                    
                    if(master_valid) begin
                        state <= FRAME_START_STATE;
                    end
                end
                
                //In this state, FRAME_START is asserted in the BGT and the FSM resets to CHIRP_DELAY_STATE
                FRAME_START_STATE: begin
                    if(master_ready) begin
                        master_word <= 32'h011E8271;
                        valid_word <= 1'b1;
                    end else begin
                        valid_word <= 1'b0;
                    end
                    
                    if(master_valid) begin
                        state <= CONFIGURE_DELAY_STATE;
                        delay_counter <= 32'd0;
                    end
                end
                
            endcase;
        end
    end

endmodule