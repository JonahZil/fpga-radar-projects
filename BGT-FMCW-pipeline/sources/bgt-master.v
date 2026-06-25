module bgt_master(
    
    input clk,
    (* mark_debug = "true" *) input start,
    (* mark_debug = "true" *) input rst,
    
    input MISO,
    input IRQ,
    
    (* mark_debug = "true" *) output wire SCLK,
    (* mark_debug = "true" *) output wire MOSI,
    (* mark_debug = "true" *) output reg SRST,
    (* mark_debug = "true" *) output wire CS_N
);

    reg [6:0] clk_counter;
    
    localparam IDLE_STATE = 3'd0;
    localparam FIRST_DELAY_STATE = 3'd1;
    localparam RESET_STATE = 3'd2;
    localparam SECOND_DELAY_STATE = 3'd3;
    localparam ACTIVE_STATE = 3'd4;
    localparam DEBUG_STATE = 3'd5;
    
    reg [2:0] state;
    
    reg valid_word;
    reg [31:0] master_word;
    
    (* mark_debug = "true" *) wire [31:0] bgt_word;
    wire master_ready;
    wire master_valid;
    
    (* mark_debug = "true" *) reg MISO_r;
    (* mark_debug = "true" *) reg IRQ_r;
    
    spi_master master(
        .clk(clk),
        .rst(rst),
        
        .in_valid(valid_word),
        .in_data(master_word),
        .out_ready(1'b1),
        
        .MISO(MISO),
        .SCLK(SCLK),
        .CS_N(CS_N),
        .MOSI(MOSI),
        
        .out_data(bgt_word),
        .in_ready(master_ready),
        .out_valid(master_valid)
    );
    
    always @(posedge clk) begin
    
        MISO_r <= MISO;
        IRQ_r <= IRQ;
        
        if(rst) begin
            SRST <= 1'b1;
            state <= IDLE_STATE;
            clk_counter <= 7'd0;
            valid_word  <= 1'b0;
            master_word <= 32'd0;
        end else begin
        
            case(state)
                
                IDLE_STATE: begin
                    valid_word <= 1'b0;
                    master_word <= 1'b0;
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
                        state <= ACTIVE_STATE;
                        clk_counter <= 7'd0;
                    end
                end
                
                ACTIVE_STATE: begin
                    master_word <= {7'd2, 1'b0, 24'd0};
                    valid_word <= 1'b1;
                    state <= DEBUG_STATE;
                end
                
                DEBUG_STATE: begin
                    valid_word <= 1'b0;
                    master_word <= 1'b0;
                end
                
            endcase;
        end
    end

endmodule