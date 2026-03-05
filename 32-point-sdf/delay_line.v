module delay_line # (
    parameter length = 4
) (
    input clk,
    input rst,
    
    input read,
    input write,
    input signed [15:0] data,
    
    output reg signed [15:0] out,
    output reg out_valid
);

    localparam ADDR_WIDTH = (length > 1) ? $clog2(length) : 0;
    
    reg [ADDR_WIDTH - 1:0] pointer;
    reg signed [15:0] mem [0:length - 1];
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            pointer <= 0;
            out <= 0;
            out_valid <= 0;
        end else begin
            if(read) begin
                out_valid <= 1;
                //Output old data at old pointer
                out <= mem[pointer];
            end else begin
                out_valid <= 0;
            end
            
            if(write) begin
                //Input new data at old pointer
                mem[pointer] <= data;
                
                //Increment pointer  
                pointer <= pointer + 1;
            end
        end
    end

endmodule