`timescale 1 ns / 1 ps

module fmcw_output_slave_slave_lite_v1_0_S00_AXI #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)
(
    output reg buf_out_ready,
    output reg start,

    input wire [11:0] buf_out_data,
    input wire        buf_out_valid,

    // Global Clock Signal
    input wire S_AXI_ACLK,

    // Global Reset Signal. Active LOW.
    input wire S_AXI_ARESETN,

    // Write address channel
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire S_AXI_AWVALID,
    output wire S_AXI_AWREADY,

    // Write data channel
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire S_AXI_WVALID,
    output wire S_AXI_WREADY,

    // Write response channel
    output wire [1 : 0] S_AXI_BRESP,
    output wire S_AXI_BVALID,
    input wire S_AXI_BREADY,

    // Read address channel
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire S_AXI_ARVALID,
    output wire S_AXI_ARREADY,

    // Read data channel
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire S_AXI_RVALID,
    input wire S_AXI_RREADY
);

    // AXI4-Lite internal signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1 : 0] axi_bresp;
    reg axi_bvalid;

    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    reg axi_arready;
    reg [1 : 0] axi_rresp;
    reg axi_rvalid;

    // Four 32-bit registers:
    // address bits [3:2] select register 0-3
    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH / 32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 1;

    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0; // 0x00: Control
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1; // 0x04: Status
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2; // 0x08: Raw ADC sample
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg3; // 0x0C: Reserved

    wire slv_reg_wren;
    wire slv_reg_rden;

    assign slv_reg_wren = S_AXI_WVALID && axi_wready &&
                          S_AXI_AWVALID && axi_awready;

    assign slv_reg_rden = S_AXI_ARVALID && axi_arready;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // State machine variables
    reg [1:0] state_write;
    reg [1:0] state_read;

    localparam Idle  = 2'b00;
    localparam Raddr = 2'b10;
    localparam Rdata = 2'b11;
    localparam Waddr = 2'b10;
    localparam Wdata = 2'b11;

    // ------------------------------------------------------------
    // AXI write state machine
    // ------------------------------------------------------------
    always @(posedge S_AXI_ACLK)
    begin
        if (S_AXI_ARESETN == 1'b0)
        begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            axi_bresp   <= 2'b00;
            axi_awaddr  <= 0;
            state_write <= Idle;
        end
        else
        begin
            case (state_write)

                Idle:
                begin
                    axi_awready <= 1'b1;
                    axi_wready  <= 1'b1;
                    state_write <= Waddr;
                end

                Waddr:
                begin
                    if (S_AXI_AWVALID && S_AXI_AWREADY)
                    begin
                        axi_awaddr <= S_AXI_AWADDR;

                        if (S_AXI_WVALID)
                        begin
                            axi_awready <= 1'b1;
                            state_write <= Waddr;
                            axi_bvalid  <= 1'b1;
                        end
                        else
                        begin
                            axi_awready <= 1'b0;
                            state_write <= Wdata;

                            if (S_AXI_BREADY && axi_bvalid)
                                axi_bvalid <= 1'b0;
                        end
                    end
                    else
                    begin
                        if (S_AXI_BREADY && axi_bvalid)
                            axi_bvalid <= 1'b0;
                    end
                end

                Wdata:
                begin
                    if (S_AXI_WVALID)
                    begin
                        state_write <= Waddr;
                        axi_bvalid  <= 1'b1;
                        axi_awready <= 1'b1;
                    end
                    else
                    begin
                        if (S_AXI_BREADY && axi_bvalid)
                            axi_bvalid <= 1'b0;
                    end
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // Register address decode
    // ------------------------------------------------------------
    wire [C_S_AXI_ADDR_WIDTH-1:0] write_addr_for_decode;

    assign write_addr_for_decode =
        (S_AXI_AWVALID && axi_awready) ? S_AXI_AWADDR : axi_awaddr;

    wire [1:0] write_reg_addr;
    wire [1:0] read_reg_addr;

    assign write_reg_addr =
        write_addr_for_decode[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB];

    assign read_reg_addr =
        S_AXI_ARADDR[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB];

    // ------------------------------------------------------------
    // User logic registers
    // ------------------------------------------------------------
    always @(posedge S_AXI_ACLK)
    begin
        if (S_AXI_ARESETN == 1'b0)
        begin
            slv_reg0 <= 32'd0;
            slv_reg1 <= 32'd0;
            slv_reg2 <= 32'd0;
            slv_reg3 <= 32'd0;

            buf_out_ready <= 1'b0;
            start <= 1'b0;
        end
        else
        begin
            // Default: buf_out_ready is a one-clock pulse
            buf_out_ready <= 1'b0;
            start <= 1'b0;

            // 0x04 status register
            // bit 1 = raw sample available
            slv_reg1 <= {30'd0, buf_out_valid, 1'b0};

            // Hold current raw ADC sample in 0x08
            if (buf_out_valid)
            begin
                slv_reg2 <= {20'd0, buf_out_data};
            end

            // Writes from PS
            if (slv_reg_wren)
            begin
                case (write_reg_addr)

                    // 0x00: control
                    2'h0:
                    begin
                        slv_reg0 <= S_AXI_WDATA;
                        start <= S_AXI_WDATA[0];
                    end

                    default:
                    begin
                        // Ignore writes to status/data/reserved registers
                    end

                endcase
            end

            // Reads from PS
            //
            // Reading 0x08 means the PS has consumed the
            // current raw ADC sample.
            if (slv_reg_rden)
            begin
                case (read_reg_addr)

                    // 0x08: raw ADC sample
                    2'h2:
                    begin
                        buf_out_ready <= buf_out_valid;
                    end

                    default:
                    begin
                    end

                endcase
            end
        end
    end

    // ------------------------------------------------------------
    // AXI read state machine
    // ------------------------------------------------------------
    always @(posedge S_AXI_ACLK)
    begin
        if (S_AXI_ARESETN == 1'b0)
        begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rresp   <= 2'b00;
            axi_araddr  <= 0;
            state_read  <= Idle;
        end
        else
        begin
            case (state_read)

                Idle:
                begin
                    state_read  <= Raddr;
                    axi_arready <= 1'b1;
                end

                Raddr:
                begin
                    if (S_AXI_ARVALID && S_AXI_ARREADY)
                    begin
                        state_read  <= Rdata;
                        axi_araddr  <= S_AXI_ARADDR;
                        axi_rvalid  <= 1'b1;
                        axi_arready <= 1'b0;
                    end
                end

                Rdata:
                begin
                    if (S_AXI_RVALID && S_AXI_RREADY)
                    begin
                        axi_rvalid  <= 1'b0;
                        axi_arready <= 1'b1;
                        state_read  <= Raddr;
                    end
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // Read mux
    // ------------------------------------------------------------
    assign S_AXI_RDATA =
        (axi_araddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB] == 2'h0) ? slv_reg0 :
        (axi_araddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB] == 2'h1) ? slv_reg1 :
        (axi_araddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB] == 2'h2) ? slv_reg2 :
        (axi_araddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB] == 2'h3) ? slv_reg3 :
        32'd0;

endmodule