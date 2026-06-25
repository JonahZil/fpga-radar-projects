
module spi_master(
    input clk,
    input rst,
    
    input in_valid,
    input [31:0] in_data,
    input out_ready,
    
    input MISO,
    output reg SCLK,
    output reg CS_N,
    output reg MOSI,
    
    (* mark_debug = "true" *) output reg [31:0] out_data,
    output reg in_ready,
    (* mark_debug = "true" *) output reg out_valid
);
    
    localparam IDLE_STATE = 2'd0;
    localparam ACTIVE_STATE = 2'd1;
    localparam OUTPUT_STATE = 2'd2;
    reg [1:0] state;
    
    reg [1:0] clk_counter;
    reg [5:0] data_counter;
    reg [4:0] write_index;
    
    reg [31:0] in_data_r;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            SCLK <= 1'b0;
            CS_N <= 1'b1;
            MOSI <= 1'b0;
            in_ready <= 1'b0;
            out_valid <= 1'b0;
            out_data <= 32'd0;
            
            clk_counter <= 2'd3;
            data_counter <= 6'd0;
            write_index <= 5'd31;
            
            in_data_r <= 32'd0;
            state <= IDLE_STATE;
        end else begin
            case(state)
            
                IDLE_STATE: begin
                    in_ready <= 1'b1;
                    out_valid <= 1'b0;
                    CS_N <= 1'b1;
                    if(in_valid) begin
                        state <= ACTIVE_STATE;
                        in_data_r <= in_data;
                        in_ready <= 1'b0;
                    end
                end
                
                ACTIVE_STATE: begin
                    clk_counter <= clk_counter + 1;
                        
                    case(clk_counter)
                        
                        //Hold SCLK low
                        0: begin
                        
                        end
                        
                        //SCLK rising edge, sample MISO bit
                        1: begin
                            out_data <= {out_data[30:0], MISO};
                            SCLK <= 1'b1;
                        end
                        
                        //Hold, MISO updates
                        2: begin
                        
                        end
                        
                        //SCLK falling edge, set MOSI bit
                        //Transition to output state if 32 bits have been sent
                        3: begin
                            SCLK <= 1'b0;
                            CS_N <= 1'b0;
                            
                            data_counter <= data_counter + 1;
                            if(data_counter == 6'd32) begin
                                state <= OUTPUT_STATE;
                                out_valid <= 1'b1;
                            end else begin
                                MOSI <= in_data_r[write_index];
                                write_index <= write_index - 1;
                            end
                        end
                       
                    endcase;
                end
                
                OUTPUT_STATE: begin
                    CS_N <= 1'b1;
                    
                    if(out_ready) begin
                        state <= IDLE_STATE;
                        out_valid <= 1'b0;
                    end
                    
                end
                
            endcase;
        end
    end
    
endmodule