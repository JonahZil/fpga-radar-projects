module ram_module (      
    input clk,

    input signed [15:0] A_re,
    input signed [15:0] A_im,
    input signed [15:0] B_re,
    input signed [15:0] B_im,
    
    input [3:0] A,
    input [3:0] B,   
    
    input WE0,
    input WE1,
    
    input load_one_val,
    
    input read_select,
    
    output reg signed [15:0] A_pr,
    output reg signed [15:0] A_pi,
    output reg signed [15:0] B_pr,
    output reg signed [15:0] B_pi
);

    wire signed [15:0] A_pr_1;
    wire signed [15:0] B_pr_1;
    
    wire signed [15:0] A_pi_1;
    wire signed [15:0] B_pi_1;
    
    wire signed [15:0] A_pr_2;
    wire signed [15:0] B_pr_2;
    
    wire signed [15:0] A_pi_2;
    wire signed [15:0] B_pi_2;
    
    wire WE0_A;
    wire WE0_B;
    wire WE1_A;
    wire WE1_B;
    
    assign WE0_A = WE0;
    assign WE0_B = load_one_val ? 0 : WE0;
    assign WE1_A = WE1;
    assign WE1_B = load_one_val ? 0 : WE1;

    ram_unit real0 (
        .clk(clk),
        .A(A_re),
        .B(B_re),
        .A_addr(A),
        .B_addr(B),
        .WE_A(WE0_A),
        .WE_B(WE0_B),
        .A_p(A_pr_1),
        .B_p(B_pr_1)
    );
    
    ram_unit imag0 (
        .clk(clk),
        .A(A_im),
        .B(B_im),
        .A_addr(A),
        .B_addr(B),
        .WE_A(WE0_A),
        .WE_B(WE0_B),
        .A_p(A_pi_1),
        .B_p(B_pi_1)
    );
    
    ram_unit real1 (
        .clk(clk),
        .A(A_re),
        .B(B_re),
        .A_addr(A),
        .B_addr(B),
        .WE_A(WE1_A),
        .WE_B(WE1_B),
        .A_p(A_pr_2),
        .B_p(B_pr_2)
    );
    
    ram_unit imag1 (
        .clk(clk),
        .A(A_im),
        .B(B_im),
        .A_addr(A),
        .B_addr(B),
        .WE_A(WE1_A),
        .WE_B(WE1_B),
        .A_p(A_pi_2),
        .B_p(B_pi_2)
    );
    
    always @(posedge clk) begin
        if(read_select == 1'b0) begin
            A_pr <= A_pr_1;
            B_pr <= B_pr_1;
            A_pi <= A_pi_1;
            B_pi <= B_pi_1;
        end else begin
            A_pr <= A_pr_2;
            B_pr <= B_pr_2;
            A_pi <= A_pi_2;
            B_pi <= B_pi_2;
        end
    end
    
endmodule