module hann_rom #(
    parameter FILE = "",
    parameter LENGTH = 256,
    parameter ADDR_WIDTH = $clog2(LENGTH)
)(
    input clk,
   
    input [ADDR_WIDTH - 1:0] address,
    
    output wire [11:0] rom_out
);
    
    xpm_memory_sprom #(
        .ADDR_WIDTH_A        (ADDR_WIDTH),
        .AUTO_SLEEP_TIME     (0),
        .CASCADE_HEIGHT      (0),
        .ECC_MODE            ("no_ecc"),
        .MEMORY_INIT_FILE    (FILE),
        .MEMORY_INIT_PARAM   (""),
        .MEMORY_OPTIMIZATION ("true"),
        .MEMORY_PRIMITIVE    ("block"),
        .MEMORY_SIZE         (12*LENGTH),
        .MESSAGE_CONTROL     (0),
        .READ_DATA_WIDTH_A   (12),
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
        .douta  (rom_out),
        .dbiterra(),
        .sbiterra(),
        .injectdbiterra(1'b0),
        .injectsbiterra(1'b0),
        .sleep  (1'b0)
    );

endmodule