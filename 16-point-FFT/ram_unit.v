module ram_unit (
    input clk,
    
    input signed [15:0] A,
    input signed [15:0] B,
    
    input [3:0] A_addr,
    input [3:0] B_addr,
    
    input WE_A,
    input WE_B,
    
    output reg signed [15:0] A_p,
    output reg signed [15:0] B_p
);
    
    reg signed [15:0] mem[15:0];
    
    always @ (posedge clk) begin
        if(WE_A) begin
            mem[A_addr] <= A;
        end
        if(WE_B) begin
            mem[B_addr] <= B;
        end
        A_p <= mem[A_addr];
        B_p <= mem[B_addr];
    end
    
endmodule