module twiddle_rom #(
    parameter D = 16,
    parameter ADDR_WIDTH = (D <= 1) ? 1 : $clog2(D),
    parameter FILE = ""
)(
    input  [ADDR_WIDTH-1:0] address,
    output signed [15:0] W_real,
    output signed [15:0] W_imag
);

    reg [31:0] mem [0:D-1];

    //Read from twiddle factor file
    initial begin
        $readmemh(FILE, mem);
    end

    assign W_real = mem[address][31:16];
    assign W_imag = mem[address][15:0];

endmodule