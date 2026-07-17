module bgt_master #(
    parameter CONFIGURE_LENGTH = 39,
    parameter CHIRP_SIZE = 64
) (
    
    input clk,
    (* mark_debug = "true" *) input start,
    (* mark_debug = "true" *) input rst,
    
    input MISO,
    input IRQ,
    
    (* mark_debug = "true" *) output wire SCLK,
    (* mark_debug = "true" *) output wire MOSI,
    (* mark_debug = "true" *) output reg SRST,
    (* mark_debug = "true" *) output wire CS_N,
    
    (* mark_debug = "true" *) output reg signed [47:0] adc_output,
    (* mark_debug = "true" *) output reg out_valid
);

    reg [6:0] clk_counter;
    
    localparam IDLE_STATE = 4'd0;
    localparam FIRST_DELAY_STATE = 4'd1;
    localparam RESET_STATE = 4'd2;
    localparam SECOND_DELAY_STATE = 4'd3;
    localparam CONFIGURE_STATE = 4'd4;
    localparam CHIRP_DELAY_STATE = 4'd5;
    localparam FIFO_READ_STATE = 4'd6;
    localparam INACTIVE_STATE = 4'd7;
    (* mark_debug = "true" *) reg [3:0] state;
    
    (* mark_debug = "true" *) reg valid_word;
    (* mark_debug = "true" *) reg [31:0] master_word;
    
    (* mark_debug = "true" *) wire [31:0] bgt_word;
    wire master_ready;
    wire master_valid;
    
    (* mark_debug = "true" *) reg MISO_r;
    (* mark_debug = "true" *) reg IRQ_r;
    
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
    (* mark_debug = "true" *) reg [1:0] configure_state;
    
    (* mark_debug = "true" *) reg [5:0] configure_address;
    (* mark_debug = "true" *) wire [31:0] configure_rom_word;
    config_rom #(
        .FILE("bgt_rom.mem"),
        .LENGTH(CONFIGURE_LENGTH)
    ) config_rom (
        .clk(clk),
        .address(configure_address),
        .rom_out(configure_rom_word)
    );
    
    wire SCLK_B;
    wire CS_N_B;
    wire MOSI_B;
    
    assign SCLK = (state == FIFO_READ_STATE) ? SCLK_B : SCLK_M;
    assign MOSI = (state == FIFO_READ_STATE) ? MOSI_B : MOSI_M;
    assign CS_N = (state == FIFO_READ_STATE) ? CS_N_B : CS_N_M;
    
    reg start_burst_read;
    (* mark_debug = "true" *) wire [11:0] raw_sample;
    (* mark_debug = "true" *) wire sample_valid;
    wire burst_read_ready;
    
    wire signed [11:0] centered_sample;
    assign centered_sample = raw_sample - 12'd2048;
    
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
            adc_output <= 48'd0;
            out_valid <= 1'b0;
            MISO_r <= 1'b0;
            IRQ_r <= 1'b0;
            start_burst_read <= 1'b0;
        end else begin
            
            MISO_r <= MISO;
            IRQ_r <= IRQ;
            
            case(state)
                
                IDLE_STATE: begin
                    valid_word <= 1'b0;
                    master_word <= 32'd0;
                    if(start) begin
                        state <= FIRST_DELAY_STATE;
                    end
                end
                
                FIRST_DELAY_STATE: begin
                    SRST <= 1'b1;
                    clk_counter <= clk_counter + 1;
                    if(clk_counter == 7'd100) begin
                        state <= RESET_STATE;
                        clk_counter <= 7'd0;
                    end
                end
                
                RESET_STATE: begin
                    SRST <= 1'b0;
                    clk_counter <= clk_counter + 1;
                    if(clk_counter == 7'd100) begin
                        state <= SECOND_DELAY_STATE;
                        clk_counter <= 7'd0;
                    end
                end
                
                SECOND_DELAY_STATE: begin
                    SRST <= 1'b1;
                    clk_counter <= clk_counter + 1;
                    if(clk_counter == 7'd100) begin
                        state <= CONFIGURE_STATE;
                        clk_counter <= 7'd0;
                    end
                end
                
                CONFIGURE_STATE: begin
                    
                    case(configure_state)
                        
                        CONFIG_IDLE_STATE: begin
                            if(master_ready) begin
                                master_word <= configure_rom_word;
                                valid_word <= 1'b1;
                                configure_address <= configure_address + 1;
                                configure_state <= CONFIG_ACTIVE_STATE;
                            end
                        end
                        
                        CONFIG_ACTIVE_STATE: begin
                            valid_word <= 1'b0;
                            if(master_valid) begin
                                configure_state <= CONFIG_OUTPUT_STATE;
                            end
                        end
                        
                        CONFIG_OUTPUT_STATE: begin
                            if(configure_address == CONFIGURE_LENGTH) begin
                                state <= CHIRP_DELAY_STATE;
                            end else begin
                                configure_state <= CONFIG_IDLE_STATE;
                            end
                        end
                        
                    endcase;
                    
                end
                
                CHIRP_DELAY_STATE: begin
                    if(IRQ) begin
                        master_word <= 32'hFFC00000;
                        valid_word <= 1'b1;
                        start_burst_read <= 1'b1;
                    end
                    
                    if(master_valid) begin
                        state <= FIFO_READ_STATE;
                    end
                end
                
                FIFO_READ_STATE: begin
                    out_valid <= sample_valid;
                    valid_word <= 1'b0;
                    start_burst_read <= 1'b0;
                    if(burst_read_ready) begin
                        state <= INACTIVE_STATE;
                    end else begin
                        if(sample_valid) begin
                            adc_output <= {{8{centered_sample[11]}}, centered_sample, 4'b0, 24'b0};
                        end
                    end
                end
                
                INACTIVE_STATE: begin
                    out_valid <= 1'b0;
                    adc_output <= 48'd0;
                end
                
            endcase;
        end
    end

endmodule