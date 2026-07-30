module top_io_buffer # (
    parameter N = 256,
    parameter RANGE_PARAMETER = 16'd37500, //Bin spacing
    parameter FIRST_BIN = 3,
    parameter LAST_BIN = (N / 2) - 1,
    parameter FRAME_DELAY = 12500000
) (
    input clk,
    input rst,
    
    input start,
    
    input MISO,
    input IRQ,
    
    output SCLK,
    output MOSI,
    output SRST,
    output CS_N,

    input out_ready,
   
    output reg signed [17:0] alpha,
    output reg signed [17:0] beta,
    output reg [23:0] range_calc,
    output reg out_valid
);
    
    localparam ADDR_WIDTH = $clog2(N);
    
    wire signed [47:0] driver_output; //Windowed sample
    wire driver_valid;
    
    wire fft_rst;
    reg fft_rst_internal;
    wire buffer_ready;
    
    reg [ADDR_WIDTH:0] load_counter;
    
    assign buffer_ready = (state == STATE_LOAD) && (load_counter == 0);
    
    reg [1:0] bram_selector; 
    
    bgt_master #(
        .CONFIGURE_LENGTH(39),
        .CHIRP_SIZE(N * 3),
        .FRAME_DELAY(FRAME_DELAY)
    ) bgt_driver (
        .clk(clk),
        .start(start),
        .rst(rst),
        
        .MISO(MISO),
        .IRQ(IRQ),
        
        .fft_rst(fft_rst),
        .buffer_ready(buffer_ready),
        
        .SCLK(SCLK),
        .MOSI(MOSI),
        .SRST(SRST),
        .CS_N(CS_N),
        
        .adc_output(driver_output),
        .out_valid(driver_valid)
    );
    
    wire signed [47:0] bram_data_i;
    wire signed [47:0] bram_data0_o;
    wire signed [47:0] bram_data1_o;
    wire signed [47:0] bram_data2_o;
    wire signed [47:0] bram_data_o;
   
    wire write_mem;
    wire write_mem0;
    wire write_mem1;
    wire write_mem2;
    
    reg [ADDR_WIDTH - 1:0] read_address;
    reg [ADDR_WIDTH - 1:0] write_address;
    
    //Bit reverse the index of the FFT bin
    function automatic [ADDR_WIDTH-1:0] bit_reverse;
        input [ADDR_WIDTH-1:0] value;
        integer i;
    
        begin
            for (i = 0; i < ADDR_WIDTH; i = i + 1) begin
                bit_reverse[i] = value[ADDR_WIDTH - 1 - i];
            end
        end
    endfunction
    
    wire [ADDR_WIDTH - 1:0] bram_write_address;
    assign bram_write_address = (state == STATE_FFT) ? bit_reverse(write_address) : write_address;
    
    reg [ADDR_WIDTH:0] read_issue_counter;
    
    //Internal buffer BRAM modules
    buffer_module # (
        .SAMPLE_COUNT(N)
    ) bram0 (
        .clk(clk),
        .rst(rst),
        
        .write(write_mem0),
        .write_address(bram_write_address),
        .data_in(bram_data_i),
        
        .read_address(read_address),
        .data_out(bram_data0_o)
    );
    
    buffer_module # (
        .SAMPLE_COUNT(N)
    ) bram1 (
        .clk(clk),
        .rst(rst),
        
        .write(write_mem1),
        .write_address(bram_write_address),
        .data_in(bram_data_i),
        
        .read_address(read_address),
        .data_out(bram_data1_o)
    );
    
    buffer_module # (
        .SAMPLE_COUNT(N)
    ) bram2 (
        .clk(clk),
        .rst(rst),
        
        .write(write_mem2),
        .write_address(bram_write_address),
        .data_in(bram_data_i),
        
        .read_address(read_address),
        .data_out(bram_data2_o)
    );
    
    reg fft_in_valid;
    wire fft_out_valid;
    wire signed [23:0] fft_out_real;
    wire signed [23:0] fft_out_imag;
    
    sdf_fft_256 fft (
        .clk(clk),
        .rst(rst || fft_rst || fft_rst_internal),
        
        .in_valid(fft_in_valid),
        .data_real(bram_data_o[47:24]),
        .data_imag(bram_data_o[23:0]),
        
        .out_valid(fft_out_valid),
        .out_real(fft_out_real),
        .out_imag(fft_out_imag)
    );

    reg [2:0] state;
    localparam STATE_LOAD = 3'd0;
    localparam STATE_FFT = 3'd1;
    localparam STATE_FFT_RST = 3'd2;
    localparam STATE_MAX = 3'd3;
    localparam STATE_RANGE = 3'd4;
    localparam STATE_PHASE = 3'd5;
    localparam STATE_ANGLE = 3'd6;
    localparam STATE_OUTPUT = 3'd7;
    
    assign write_mem = ((state == STATE_LOAD) && driver_valid) || ((state == STATE_FFT) && fft_out_valid);
    assign write_mem0 = write_mem && (bram_selector == 0);
    assign write_mem1 = write_mem && (bram_selector == 1);
    assign write_mem2 = write_mem && (bram_selector == 2);
    
    assign bram_data_i = (state == STATE_LOAD) ? driver_output : {fft_out_real, fft_out_imag};
    assign bram_data_o =
        (bram_selector == 2'd0) ? bram_data0_o :
        (bram_selector == 2'd1) ? bram_data1_o :
                                  bram_data2_o;
    
    reg bram_valid_d;
    
    reg [1:0] max_state;
    localparam STATE_WAIT = 2'd0; 
    localparam STATE_MULT = 2'd1;
    localparam STATE_ADD = 2'd2;
    localparam STATE_FILT = 2'd3;
    
    reg signed [23:0] rx0_real, rx0_imag, 
        rx1_real, rx1_imag, rx2_real, rx2_imag;
    reg [47:0] rx0_real_s, rx0_imag_s,
        rx1_real_s, rx1_imag_s, rx2_real_s, rx2_imag_s;
    
    reg [49:0] bin_vector_comp; //Current vector
    reg [49:0] bin_vector; //Max bin vector
    reg [ADDR_WIDTH - 1:0] bin_index;
    
    reg signed [23:0] r1_real, r1_imag, r2_real, r2_imag;
    wire signed [47:0] ac, ad, bc, bd;
    reg signed [47:0] ac_r, ad_r, bc_r, bd_r;
    
    //Complex multiply
    assign ac = r1_real * r2_real;
    assign ad = r1_real * r2_imag;
    assign bc = r1_imag * r2_real;
    assign bd = r1_imag * r2_imag;
    
    reg signed [48:0] cordic_x, cordic_y;
    reg cordic_in_valid;
    
    wire signed [17:0] phase;
    
    reg signed [17:0] azimuth_phase;
    reg signed [17:0] elevation_phase;
    
    wire cordic_out_valid;
    
    //atan2 module for phase calculation
    atan2_cordic # (
        .ITERATIONS(16)
    ) atan2 (
        .clk(clk),
        .rst(rst),
        
        .x(cordic_x),
        .y(cordic_y),
        .in_valid(cordic_in_valid),
        
        .z_reg(phase),
        .out_valid(cordic_out_valid)
    );
    
    reg [2:0] phase_state;
    localparam STATE_AZ_PARAM = 3'd0;
    localparam STATE_AZ_MULT = 3'd1;
    localparam STATE_AZ_ADD = 3'd2;
    localparam STATE_AZ_CALC = 3'd3;
    localparam STATE_EL_MULT = 3'd4;
    localparam STATE_EL_ADD = 3'd5;
    localparam STATE_EL_CALC = 3'd6;
    
    //Measured phase offsets
    localparam signed [17:0] AZIMUTH_OFFSET   = -18'sd846; 
    localparam signed [17:0] ELEVATION_OFFSET =  18'sd44946;
    
    localparam signed [18:0] PI = 19'sd102944;
    localparam signed [18:0] NEG_PI = -19'sd102944;
    localparam signed [18:0] TWO_PI = 19'sd205888;
    
    reg [9:0] asin_address;
    reg signed [18:0] az_corrected;
    reg signed [18:0] el_corrected;
    reg sign;
    
    wire signed [17:0] angle;
    
    asin_rom # (
        .FILE("asin_lut.mem"),
        .DEPTH(805)
    ) asin_lut (
        .clk(clk),
        .address(asin_address),
        .rom_out(angle)
    );
    
    reg [2:0] angle_state;
    localparam STATE_CORRECT = 3'd0;
    localparam STATE_ABS = 3'd1;
    localparam STATE_AZ_ADDRESS = 3'd2;
    localparam STATE_AZ_WAIT = 3'd3;
    localparam STATE_ALPHA_CALC = 3'd4;
    localparam STATE_EL_ADDRESS = 3'd5;
    localparam STATE_EL_WAIT = 3'd6; 
    localparam STATE_BETA_CALC = 3'd7;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_LOAD;
            read_address <= 0;
            write_address <= 0;
            fft_in_valid <= 0;
            load_counter <= 0;
            read_issue_counter <= 0;
            bram_valid_d <= 0;
            out_valid <= 0;
            bram_selector <= 0;
            fft_rst_internal <= 0;
            max_state <= STATE_WAIT;
            bin_vector_comp <= 50'd0;
            bin_vector <= 50'd0;
            bin_index <= FIRST_BIN;
            rx0_real <= 24'd0; rx0_imag <= 24'd0;
            rx1_real <= 24'd0; rx1_imag <= 24'd0;
            rx2_real <= 24'd0; rx2_imag <= 24'd0;
            rx0_real_s <= 48'd0; rx0_imag_s <= 48'd0;
            rx1_real_s <= 48'd0; rx1_imag_s <= 48'd0;
            rx2_real_s <= 48'd0; rx2_imag_s <= 48'd0;
            range_calc <= 24'd0;
            cordic_in_valid <= 1'b0;
            azimuth_phase <= 18'sd0;
            elevation_phase <= 18'sd0;
            phase_state <= STATE_AZ_PARAM;
            r1_real <= 24'sd0; r1_imag <= 24'sd0;
            r2_real <= 24'sd0; r2_imag <= 24'sd0;
            ac_r <= 48'sd0; ad_r <= 48'sd0;
            bc_r <= 48'sd0; bd_r <= 48'sd0;
            cordic_x <= 49'sd0; cordic_y <= 49'sd0;
            angle_state <= STATE_CORRECT;
            asin_address <= 10'd0;
            az_corrected <= 19'sd0;
            el_corrected <= 19'sd0;
            sign <= 1'b0;
            alpha <= 18'sd0;
            beta  <= 18'sd0;
        end else begin
            case (state)
                
                //In this state, data sent from the BGT radar gets loaded into the buffers
                STATE_LOAD: begin
                    fft_in_valid <= 1'b0;
                    out_valid <= 1'b0;
    
                    if (driver_valid && load_counter < N) begin
                        if(bram_selector == 2'd2) begin
                            write_address <= write_address + 1;
                            load_counter <= load_counter + 1;
                            bram_selector <= 2'd0;
                        end else begin
                            bram_selector <= bram_selector + 1;
                        end
                    end
                    
                    //If the last value has been input, transition to STATE_FFT
                    if(load_counter == N) begin
                        state <= STATE_FFT;
                        write_address <= 0;
                        read_address <= 0;
                        read_issue_counter <= 0;
                        load_counter <= 0;
                        bram_valid_d <= 0;
                        bram_selector <= 0;
                    end
                   
                end
                
                //In this state, data is sent from the buffers into the FFT.
                //The output of the FFT gets written back into the buffers
                STATE_FFT: begin
                    if (read_issue_counter < N) begin
                        read_address <= read_issue_counter[ADDR_WIDTH - 1:0];
                        read_issue_counter <= read_issue_counter + 1;
                        bram_valid_d <= 1;
                    end else begin
                        bram_valid_d <= 0;
                    end
    
                    fft_in_valid <= bram_valid_d;
                    
                    if(fft_out_valid) begin
                        write_address <= write_address + 1;
                    end
                    
                    //If the last output has been written into the third buffer, switch to STATE_MAX
                    if(write_address == N - 1) begin
                        if(bram_selector == 2'd2) begin
                            state <= STATE_MAX;
                            max_state <= STATE_WAIT;
                            load_counter <= 0;
                            read_address <= 0;
                            read_issue_counter <= 1;
                            bram_valid_d <= 0;
                            bram_selector <= 0;
                            read_address <= FIRST_BIN;
                            bin_vector <= 50'd0;
                            bin_vector_comp <= 50'd0;
                            bin_index <= FIRST_BIN;
                            write_address <= 0;
                        //Reset the FFTs and switch to STATE_FFT_RST
                        end else begin 
                            state <= STATE_FFT_RST;
                            fft_rst_internal <= 1;
                            write_address <= 0;
                            read_issue_counter <= 0;
                            load_counter <= 0;
                            bram_valid_d <= 0;
                            bram_selector <= bram_selector + 1;
                        end
                    end
                end
                
                //In this state, the fft reset is given a one clock cycle buffer, then returns to STATE_FFT
                STATE_FFT_RST: begin
                    fft_rst_internal <= 0;
                    state <= STATE_FFT;
                end
                
                //In this state, the strongest peak is found by computing the size of the vector
                STATE_MAX: begin
                    case(max_state)
                        
                        STATE_WAIT: begin
                            max_state <= STATE_MULT;
                        end
                        
                        //Square each real and imaginary part
                        STATE_MULT: begin
                            rx0_real_s <= $signed(bram_data0_o[47:24]) * $signed(bram_data0_o[47:24]);
                            rx0_imag_s <= $signed(bram_data0_o[23:0]) * $signed(bram_data0_o[23:0]);
                            rx1_real_s <= $signed(bram_data1_o[47:24]) * $signed(bram_data1_o[47:24]);
                            rx1_imag_s <= $signed(bram_data1_o[23:0]) * $signed(bram_data1_o[23:0]);
                            rx2_real_s <= $signed(bram_data2_o[47:24]) * $signed(bram_data2_o[47:24]);
                            rx2_imag_s <= $signed(bram_data2_o[23:0]) * $signed(bram_data2_o[23:0]);
                            max_state <= STATE_ADD;
                        end
                        
                        //Sum each squared part to form a vector
                        STATE_ADD: begin
                            bin_vector_comp <=
                                  {2'b0, rx0_real_s}
                                + {2'b0, rx0_imag_s}
                                + {2'b0, rx1_real_s}
                                + {2'b0, rx1_imag_s}
                                + {2'b0, rx2_real_s}
                                + {2'b0, rx2_imag_s};
                            max_state <= STATE_FILT;
                        end
                        
                        //Go through each bin from FIRST_BIN to LAST_BIN
                        //If the current vector is greater than the stored, it updated the stored vector to the current one
                        STATE_FILT: begin
                            if(bin_vector_comp > bin_vector) begin
                                bin_vector <= bin_vector_comp;
                                rx0_real <= bram_data0_o[47:24];
                                rx0_imag <= bram_data0_o[23:0];
                                rx1_real <= bram_data1_o[47:24];
                                rx1_imag <= bram_data1_o[23:0];
                                rx2_real <= bram_data2_o[47:24];
                                rx2_imag <= bram_data2_o[23:0];
                                
                                bin_index <= read_address;
                            end
                            
                            if(read_address == LAST_BIN) begin
                                
                                //Azimuth parameters
                                r1_real <= rx0_real;
                                r1_imag <= rx0_imag;
                                r2_real <= rx2_real;
                                r2_imag <= rx2_imag;
                                
                                state <= STATE_RANGE;
                            end else begin
                                read_address <= read_address + 1;
                                max_state <= STATE_WAIT;
                            end
                            
                        end
                        
                    endcase
                end
                
                //In this state, the range is calculated by multiplying the index by the bit-reversed bin spacing
                STATE_RANGE: begin
                    range_calc <= bin_index * RANGE_PARAMETER;
                    state <= STATE_PHASE;
                end
                
                //In this state, the phase difference for azimuth and elevation is computed                
                STATE_PHASE: begin
                    case(phase_state)
                        
                        STATE_AZ_PARAM: begin
                            r1_real <= rx0_real;
                            r1_imag <= rx0_imag;
                            r2_real <= rx2_real;
                            r2_imag <= rx2_imag;
                            phase_state <= STATE_AZ_MULT;
                        end
                        
                        STATE_AZ_MULT: begin
                            ac_r <= ac;
                            ad_r <= ad;
                            bc_r <= bc;
                            bd_r <= bd;
                            phase_state <= STATE_AZ_ADD;
                        end
                        
                        //Compute the angle with atan2
                        STATE_AZ_ADD: begin
                            cordic_x <=
                                $signed({ac_r[47], ac_r})
                                + $signed({bd_r[47], bd_r});
                        
                            cordic_y <=
                                $signed({ad_r[47], ad_r})
                                - $signed({bc_r[47], bc_r});
                        
                            cordic_in_valid <= 1'b1;
                            phase_state <= STATE_AZ_CALC;
                        end
                        
                        STATE_AZ_CALC: begin
                            cordic_in_valid <= 1'b0;
                            r1_real <= rx1_real;
                            r1_imag <= rx1_imag;
                            if(cordic_out_valid) begin
                                azimuth_phase <= phase;
                                phase_state <= STATE_EL_MULT;
                            end
                        end
                        
                        STATE_EL_MULT: begin
                            ac_r <= ac;
                            ad_r <= ad;
                            bc_r <= bc;
                            bd_r <= bd;
                            phase_state <= STATE_EL_ADD;
                        end 
                        
                        STATE_EL_ADD: begin
                            cordic_x <=
                                $signed({ac_r[47], ac_r})
                                + $signed({bd_r[47], bd_r});
                        
                            cordic_y <=
                                $signed({ad_r[47], ad_r})
                                - $signed({bc_r[47], bc_r});
                        
                            cordic_in_valid <= 1'b1;
                            phase_state <= STATE_EL_CALC;
                        end
                        
                        STATE_EL_CALC: begin
                            cordic_in_valid <= 1'b0;
                            if(cordic_out_valid) begin
                                elevation_phase <= phase;
                                phase_state <= STATE_AZ_PARAM;
                                state <= STATE_ANGLE;
                            end
                        end
                        
                    endcase
                    
                end
                
                //In this state, the angle is computed based on the phase and the inverse sin
                STATE_ANGLE: begin
                    case(angle_state)
                        
                        //Account for the offset of the phases
                        STATE_CORRECT: begin
                            
                            az_corrected <= 
                                $signed({azimuth_phase[17], azimuth_phase})
                                - $signed({AZIMUTH_OFFSET[17], AZIMUTH_OFFSET});
                            
                            el_corrected <=
                                $signed({elevation_phase[17], elevation_phase})
                                - $signed({ELEVATION_OFFSET[17], ELEVATION_OFFSET});
                                
                            angle_state <= STATE_ABS;
                        end
                        
                        //Crimp the angle to fit within [-PI, PI)
                        STATE_ABS: begin
                            if(az_corrected >= PI) begin
                                az_corrected <= az_corrected - TWO_PI;
                            end else if (az_corrected < NEG_PI) begin
                                az_corrected <= az_corrected + TWO_PI;
                            end
                            
                            if(el_corrected >= PI) begin
                                el_corrected <= el_corrected - TWO_PI;
                            end else if (el_corrected < NEG_PI) begin
                                el_corrected <= el_corrected + TWO_PI;
                            end
                            
                            angle_state <= STATE_AZ_ADDRESS;
                        end
                        
                        //Scale the phase so that it can index the asin lookup table
                        STATE_AZ_ADDRESS: begin
                            //Store the sign
                            sign <= az_corrected[18];
                        
                            if (az_corrected[18])
                                asin_address <= (-az_corrected) >> 7;
                            else
                                asin_address <= az_corrected >> 7;
                        
                            angle_state <= STATE_AZ_WAIT;
                        end
                        
                        STATE_AZ_WAIT: begin
                            angle_state <= STATE_ALPHA_CALC;
                        end
                        
                        //Readd the sign and store alpha
                        STATE_ALPHA_CALC: begin
                            if(sign) begin
                                alpha <= -$signed(angle);
                            end else begin
                                alpha <= $signed(angle);
                            end
                            
                            angle_state <= STATE_EL_ADDRESS;
                        end
                        
                        //Scale the phase so that it can index the asin lookup table
                        STATE_EL_ADDRESS: begin
                            sign <= el_corrected[18];
                        
                            if (el_corrected[18])
                                asin_address <= (-el_corrected) >> 7;
                            else
                                asin_address <= el_corrected >> 7;
                        
                            angle_state <= STATE_EL_WAIT;
                        end
                        
                        STATE_EL_WAIT: begin
                            angle_state <= STATE_BETA_CALC;
                        end
                        
                        //Readd the sign and store beta
                        STATE_BETA_CALC: begin
                            if(sign) begin
                                beta <= -$signed(angle);
                            end else begin
                                beta <= $signed(angle);
                            end
                            
                            angle_state <= STATE_CORRECT;
                            state <= STATE_OUTPUT;
                            out_valid <= 1'b1;
                        end
                        
                    endcase
                end
                
                //In this state, the buffer waits until the PS is ready for input
                STATE_OUTPUT: begin
                    if(out_ready) begin
                        state <= STATE_LOAD;
                        out_valid <= 1'b0;
                    end
                end
                
            endcase
        end
    end

endmodule