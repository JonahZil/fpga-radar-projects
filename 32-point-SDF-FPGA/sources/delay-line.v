module delay_line # (
    parameter length = 4
) (
    input clk,
    input rst,
    
    input write,
    input signed [15:0] data,
    
    output reg signed [15:0] out,
    output reg out_valid
);

    localparam ADDR_WIDTH = $clog2(length);
    
    reg [ADDR_WIDTH - 1:0] pointer;
    reg [length - 1:0] out_delay;
    reg signed [15:0] mem [0:length - 1];
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            pointer <= 0;
            out_delay <= 0;
        end else begin
            
            out_delay <= (out_delay <<< 1) | write;   
            out_valid <= out_delay[length - 1]; 
            out <= mem[pointer];
            
            if(write) begin
                //Input new data at old pointer
                mem[pointer] <= data;

            end 
            
            pointer <= pointer + 1;
        end
    end

endmodule