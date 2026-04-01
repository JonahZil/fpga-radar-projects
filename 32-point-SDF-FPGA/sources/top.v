module top(
    input clk
);

    wire vio_rst;
    wire vio_start;
    
    // FFT outputs
    wire signed [15:0] real_data;
    wire signed [15:0] imag_data;
    wire out_valid;
    
    // one cycle start pulse from VIO level
    reg vio_start_d = 1'b0;
    wire start_pulse;

    always @(posedge clk) begin
        vio_start_d <= vio_start;
    end
    
    assign start_pulse = vio_start & ~vio_start_d;
    
    sdf_pipeline UUT (
        .clk(clk),
        .rst(vio_rst),
        .start_calc(start_pulse),
        .real_bin(real_data),
        .imag_bin(imag_data),
        .pipeline_valid(out_valid)
    );

    // VIO
    vio_0 u_vio (
        .clk(clk),
        .probe_out0(vio_rst),
        .probe_out1(vio_start)
    );

    // ILA
    ila_0 u_ila (
        .clk(clk),
        .probe0(start_pulse),
        .probe1(out_valid),
        .probe2(real_data),
        .probe3(imag_data)
    );

endmodule