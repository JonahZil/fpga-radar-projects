module small_delay_line (
    input clk,
    input rst,
    
    input signed [23:0] data,
    input in_valid,
    
    output reg signed [23:0] out,
    output reg out_valid
);

    reg signed [23:0] mem0, mem1;
    reg out_valid_1, out_valid_2;
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            mem0 <= 0;
            mem1 <= 0;
            out <= 0;
            out_valid_1 <= 0;
        end else begin
            mem0 <= data;
            mem1 <= mem0;
            out <= mem1;
            
            out_valid_1 <= in_valid;
            out_valid_2 <= out_valid_1;
            out_valid <= out_valid_2;
        end
    end
endmodule
