module burst_spi_master #(
    parameter CHIRP_SIZE = 32
) (
    input clk,
    input rst,
    
    input MISO,
    output reg SCLK,
    output reg CS_N,
    output reg MOSI,
    
    input start_burst,
    
    (* mark_debug = "true" *) output reg [11:0] out_data,
    (* mark_debug = "true" *) output reg out_valid,
    output reg in_ready
);
    
    localparam IDLE_STATE = 2'd0;
    localparam DELAY_STATE = 2'd1;
    localparam ACTIVE_STATE = 2'd2;
    reg [1:0]state;
    
    reg [1:0] clk_counter;
    reg [3:0] data_counter;
    
    localparam CHIRP_WIDTH = $clog2(CHIRP_SIZE);
    reg [CHIRP_WIDTH - 1:0] sample_count;
    
    reg[7:0] delay_counter;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            SCLK <= 1'b0;
            CS_N <= 1'b1;
            MOSI <= 1'b0;
            in_ready <= 1'b0;
            out_valid <= 1'b0;
            out_data <= 12'd0;
            
            clk_counter <= 2'd3;
            data_counter <= 4'd15;
            
            state <= IDLE_STATE;
            sample_count <= 0;
            delay_counter <= 8'd0;
        end else begin
            case(state)
            
                IDLE_STATE: begin
                    out_valid <= 1'b0;
                    CS_N <= 1'b1;
                    in_ready <= 1'b1;
                    if(start_burst) begin
                        state <= DELAY_STATE;
                        in_ready <= 1'b0;
                    end
                end
                
                DELAY_STATE: begin
                    if(delay_counter == 8'd127) begin
                        state <= ACTIVE_STATE;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                ACTIVE_STATE: begin
                    clk_counter <= clk_counter + 1;
                        
                    case(clk_counter)
                        
                        //Hold SCLK low
                        0: begin
                            out_valid <= 1'b0;
                        end
                        
                        //SCLK rising edge, sample MISO bit
                        1: begin
                            out_data <= {out_data[10:0], MISO};
                            SCLK <= 1'b1;
                        end
                        
                        //Hold, MISO updates
                        2: begin
                        
                        end
                        
                        //SCLK falling edge
                        //Transition to IDLE state if 12 bits have been sent and it's the last sample
                        3: begin
                            SCLK <= 1'b0;
                            CS_N <= 1'b0;
                            
                            if(data_counter == 4'd11) begin
                                out_valid <= 1'b1;
                                if(sample_count == CHIRP_SIZE - 1) begin
                                    state <= IDLE_STATE;
                                end else begin
                                    data_counter <= 0;
                                    sample_count <= sample_count + 1;
                                end
                                
                            end else begin
                                data_counter <= data_counter + 1;
                            end
                        end
                       
                    endcase;
                end   
            endcase;
        end
    end
    
endmodule