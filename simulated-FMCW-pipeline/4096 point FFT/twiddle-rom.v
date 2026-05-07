module twiddle_rom #(
    parameter D = 16,
    parameter FILE = ""
)(
    input clk,
    input  [ADDR_WIDTH-1:0] address,
    output signed [15:0] W_real,
    output signed [15:0] W_imag
);

    localparam ADDR_WIDTH = (D <= 1) ? 1 : $clog2(D);
    wire [31:0] ROM_out;
    
    //Internal ROM module
    xpm_memory_sprom #(
        .ADDR_WIDTH_A        (ADDR_WIDTH),
        .AUTO_SLEEP_TIME     (0),
        .CASCADE_HEIGHT      (0),
        .ECC_MODE            ("no_ecc"),
        .MEMORY_INIT_FILE    (FILE),
        .MEMORY_INIT_PARAM   (""),
        .MEMORY_OPTIMIZATION ("true"),
        .MEMORY_PRIMITIVE    ("block"),
        .MEMORY_SIZE         (32*D),
        .MESSAGE_CONTROL     (0),
        .READ_DATA_WIDTH_A   (32),
        .READ_LATENCY_A      (1),
        .READ_RESET_VALUE_A  ("0"),
        .RST_MODE_A          ("SYNC"),
        .SIM_ASSERT_CHK      (0),
        .USE_MEM_INIT        (1),
        .WAKEUP_TIME         ("disable_sleep")
    ) tw_rom (
        .clka   (clk),
        .rsta   (1'b0),
        .ena    (1'b1),
        .regcea (1'b1),
        .addra  (address),
        .douta  (ROM_out),
        .dbiterra(),
        .sbiterra(),
        .injectdbiterra(1'b0),
        .injectsbiterra(1'b0),
        .sleep  (1'b0)
    );

    assign W_real = ROM_out[31:16];
    assign W_imag = ROM_out[15:0];

endmodule