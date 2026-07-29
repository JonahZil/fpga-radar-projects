module atan2_cordic # (
    parameter ITERATIONS = 16,
    parameter ADDR_WIDTH = $clog2(ITERATIONS)
) (
    input clk,
    input rst,

    (* mark_debug = "true" *) input signed [48:0] x,
    (* mark_debug = "true" *) input signed [48:0] y,
    (* mark_debug = "true" *) input in_valid,
    
    (* mark_debug = "true" *) output reg signed [17:0] z_reg,
    (* mark_debug = "true" *) output reg out_valid
);
    
    localparam signed [17:0] PI = 18'sd102944;
    localparam signed [17:0] NEG_PI = -18'sd102944;
    
    (* mark_debug = "true" *) reg signed [50:0] x_reg, y_reg;
    
    (* mark_debug = "true" *) reg [ADDR_WIDTH:0] iteration;
    wire signed [17:0] iteration_angle;
    
    cordic_angle_rom # (
        .FILE("cordic_angles.mem"),
        .ITERATIONS(ITERATIONS)
    ) angle_rom (
        .clk(clk),
        
        .address(iteration[ADDR_WIDTH - 1:0]),
        .rom_out(iteration_angle)
    );
    
    reg [1:0] state;
    localparam IDLE_STATE = 2'd0;
    localparam ITERATE_STATE = 2'd1;
    localparam WAIT_STATE = 2'd2;
    localparam OUT_STATE = 2'd3;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            z_reg <= 18'sd0;
            out_valid <= 1'b0;
            iteration <= 5'd0;
            state <= IDLE_STATE;
        end else begin
            
            case(state)
                
                IDLE_STATE: begin
                    if(in_valid) begin
                        if(x < 0) begin
                            x_reg <= -{{2{x[48]}}, x};
                            y_reg <= -{{2{y[48]}}, y};
                            
                            if(y >= 0) begin
                                z_reg <= PI;
                            end else begin
                                z_reg <= NEG_PI;
                            end
                        end else begin
                            x_reg <= {{2{x[48]}}, x};
                            y_reg <= {{2{y[48]}}, y};
                            z_reg <= 18'sd0;
                        end
                        
                        if ((x == 0) && (y == 0)) begin
                            out_valid <= 1'b1;
                            z_reg <= 18'sd0;
                            state <= OUT_STATE;
                        end else begin
                            state <= ITERATE_STATE;
                        end
                    end
                end
                
                ITERATE_STATE: begin
                    if(iteration == ITERATIONS) begin
                        out_valid <= 1'b1;
                        state <= OUT_STATE;
                    end else begin
                        if(y_reg > 0) begin
                            x_reg <= x_reg + (y_reg >>> iteration);
                            y_reg <= y_reg - (x_reg >>> iteration);
                            z_reg <= z_reg + iteration_angle;
                        end else begin
                            x_reg <= x_reg - (y_reg >>> iteration);
                            y_reg <= y_reg + (x_reg >>> iteration);
                            z_reg <= z_reg - iteration_angle;
                        end
                        iteration <= iteration + 1'd1;
                        state <= WAIT_STATE;
                    end
                end
                
                WAIT_STATE: begin
                    state <= ITERATE_STATE;
                end
                
                OUT_STATE: begin
                    out_valid <= 1'b0;
                    state <= IDLE_STATE;
                    iteration <= 5'd0;
                    z_reg <= 18'sd0;
                end
                
            endcase
            
        end
    end
    
endmodule