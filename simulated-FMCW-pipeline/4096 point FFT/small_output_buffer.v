module small_output_buffer (
    input clk,
    input rst,
    
    input signed [23:0] data,
    input in_valid,
    
    output reg signed [23:0] out,
    output reg out_valid
);

    reg signed [23:0] mem0;
    reg out_valid_1;
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            mem0 <= 0;
            out <= 0;
            out_valid_1 <= 0;
        end else begin
            mem0 <= data;
            out <= mem0;
            
            out_valid_1 <= in_valid;
            out_valid <= out_valid_1;
        end
    end
    
endmodule