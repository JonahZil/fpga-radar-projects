module buffer_module # (
    parameter SAMPLE_COUNT = 256,
    parameter ADDR_WIDTH = $clog2(SAMPLE_COUNT)
) (
    input clk,
    input rst,
    
    input write,
    input [ADDR_WIDTH - 1:0] write_address,
    input signed [47:0] data_in,
    
    input [ADDR_WIDTH - 1:0] read_address,
    output wire [47:0] data_out
);
    
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A        (ADDR_WIDTH),
        .ADDR_WIDTH_B        (ADDR_WIDTH),
        .AUTO_SLEEP_TIME     (0),
        .BYTE_WRITE_WIDTH_A  (48),
        .CASCADE_HEIGHT      (0),
        .CLOCKING_MODE       ("common_clock"),
        .ECC_MODE            ("no_ecc"),
        .MEMORY_INIT_FILE    ("none"),
        .MEMORY_INIT_PARAM   ("0"),
        .MEMORY_OPTIMIZATION ("true"),
        .MEMORY_PRIMITIVE    ("block"),
        .MEMORY_SIZE         (48 * SAMPLE_COUNT),
        .MESSAGE_CONTROL     (0),
        .READ_DATA_WIDTH_B   (48),
        .READ_LATENCY_B      (1),
        .READ_RESET_VALUE_B  ("0"),
        .RST_MODE_A          ("SYNC"),
        .RST_MODE_B          ("SYNC"),
        .SIM_ASSERT_CHK      (0),
        .USE_EMBEDDED_CONSTRAINT (0),
        .USE_MEM_INIT        (1),
        .WAKEUP_TIME         ("disable_sleep"),
        .WRITE_DATA_WIDTH_A  (48),
        .WRITE_MODE_B        ("read_first")
    ) mem (
        .clka           (clk),
        .ena            (1'b1),
        .wea            (write),
        .addra          (write_address),
        .dina           (data_in),

        .clkb           (clk),
        .enb            (1'b1),
        .addrb          (read_address),
        .doutb          (data_out),

        .rstb           (rst),
        .regceb         (1'b1),

        .injectdbiterra (1'b0),
        .injectsbiterra (1'b0),
        .sleep          (1'b0),
        .dbiterrb       (),
        .sbiterrb       ()
    );
    
endmodule
