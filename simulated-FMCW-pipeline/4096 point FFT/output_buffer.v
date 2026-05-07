module output_buffer (
    input clk,
    input rst,
    input write,
    input signed [23:0] data,
    output reg signed [23:0] out
);

    reg signed [23:0] mem0, mem1, mem2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem0 <= 0;
            mem1 <= 0;
            mem2 <= 0;
            out  <= 0;
        end else if (write) begin
            out <= mem2;
            mem2 <= mem1;
            mem1 <= mem0;
            mem0 <= data;
        end
    end

endmodule