module delay_line #(
    parameter length = 4
) (
    input  wire clk,
    input  wire rst,

    input  wire write,
    input  wire signed [15:0] data,

    output wire signed [15:0] out
);

    localparam ADDR_WIDTH = (length <= 1) ? 1 : $clog2(length);

    reg [ADDR_WIDTH-1:0] pointer;

    wire [15:0] dout_b;

    xpm_memory_sdpram #(
        .ADDR_WIDTH_A        (ADDR_WIDTH),
        .ADDR_WIDTH_B        (ADDR_WIDTH),
        .AUTO_SLEEP_TIME     (0),
        .BYTE_WRITE_WIDTH_A  (16),
        .CASCADE_HEIGHT      (0),
        .CLOCKING_MODE       ("common_clock"),
        .ECC_MODE            ("no_ecc"),
        .MEMORY_INIT_FILE    ("none"),
        .MEMORY_INIT_PARAM   ("0"),
        .MEMORY_OPTIMIZATION ("true"),
        .MEMORY_PRIMITIVE    ("block"),
        .MEMORY_SIZE         (length * 16),
        .MESSAGE_CONTROL     (0),
        .READ_DATA_WIDTH_B   (16),
        .READ_LATENCY_B      (1),
        .READ_RESET_VALUE_B  ("0"),
        .RST_MODE_A          ("SYNC"),
        .RST_MODE_B          ("SYNC"),
        .SIM_ASSERT_CHK      (0),
        .USE_EMBEDDED_CONSTRAINT (0),
        .USE_MEM_INIT        (1),
        .WAKEUP_TIME         ("disable_sleep"),
        .WRITE_DATA_WIDTH_A  (16),
        .WRITE_MODE_B        ("read_first")
    ) mem_i (
        .clka           (clk),
        .ena            (1'b1),
        .wea            (write),
        .addra          (pointer),
        .dina           (data),

        .clkb           (clk),
        .enb            (1'b1),
        .addrb          (pointer),
        .doutb          (dout_b),

        .rstb           (rst),
        .regceb         (1'b1),

        .injectdbiterra (1'b0),
        .injectsbiterra (1'b0),
        .sleep          (1'b0),
        .dbiterrb       (),
        .sbiterrb       ()
    );

    assign out = dout_b;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pointer   <= 0;
        end else begin
            pointer <= pointer + 1'b1;
        end
    end

endmodule