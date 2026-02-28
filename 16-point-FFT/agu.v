module address_generator (
    input clk,
    input rst,
    
    input start_ready, //Start generating addresses
    output out_done, //Done calculating all values
    input bfu_valid, //butterfly unit done
    output reg bfu_out, //Accept bfu values
    output reg bfu_ready, //Start bfu calculation
    
    output reg [3:0] A, //Address A
    output reg [3:0] B, //Address B
    output reg read_select, //Select what RAM to read from
    output reg WE0, //Write to RAM 0
    output reg WE1, //Write to RAM 1
    output reg [2:0] twiddle_address //Address for twiddle ROM
);
    
    localparam OUTER_STATE_IDLE = 2'd0;
    localparam OUTER_STATE_STAGE = 2'd2;
    localparam OUTER_STATE_OUT = 2'd3;
    
    reg out_done_r;
    assign out_done = out_done_r;
    
    reg [1:0] outer_state;
    reg [2:0] stage_cnt;
    
    localparam INNER_STATE_ADDR = 3'd0;
    localparam INNER_STATE_BFU = 3'd1;
    localparam INNER_STATE_BFU_START = 3'd2;
    localparam INNER_STATE_WAIT = 3'd3;
    localparam INNER_STATE_WE = 3'd4;
    localparam INNER_STATE_CHECK = 3'd5;
    
    reg [2:0] inner_state;
    reg [3:0] address_count; //How many address pairs have been generated
    reg valid_address; //Generated address is valid
    
    reg mem_select; //Select which memory to write to
    
    reg [3:0] A_cnt; //Internal register of A address
    reg [3:0] stride; //stride of current stage
    reg [3:0] inverted_stride; //Inverted stride of current stage
    
    always @ (posedge clk or posedge rst) begin
        if(rst) begin
            A <= 4'b0;
            B <= 4'b0;
            A_cnt <= 4'b0;
            read_select <= 1'b0;
            WE0 <= 1'b0;
            WE1 <= 1'b0;
            twiddle_address <= 3'b0;
            outer_state <= OUTER_STATE_IDLE;
            inner_state <= INNER_STATE_ADDR;
            stage_cnt <= 3'b0;
            valid_address <= 1'b0;
            mem_select <= 1'b1;
            stride <= 4'b0001;
            inverted_stride <= 4'b1000;
            bfu_out <= 1'b0;
            bfu_ready <= 1'b0;
            address_count <= 4'b0;
            out_done_r <= 1'b0;
        end else begin 
            case(outer_state)
            
                OUTER_STATE_IDLE: begin //Only start generating addresses when ready
                    if(start_ready) outer_state <= OUTER_STATE_STAGE;
                end
            
                OUTER_STATE_STAGE: begin 
                    if(stage_cnt == 3'd4) begin //Stop generating addresses when all four stages are done
                        outer_state <= OUTER_STATE_OUT;
                    end else begin
                        
                        case(inner_state) 
                            
                            INNER_STATE_ADDR: begin //Generate a valid address
                                WE0 <= 1'b0;
                                WE1 <= 1'b0;
                                if(valid_address) begin
                                    inner_state <= INNER_STATE_BFU_START;
                                    address_count <= address_count + 1;
                                end else begin //Increment until a valid address is found
                                    A <= A_cnt;
                                    B <= A_cnt ^ stride; //Xor with stride to get B value
                                    if(A_cnt < (A_cnt ^ stride)) begin //Valid address if A<B
                                        valid_address <= 1'b1;
                                        A_cnt <= A_cnt + 1;
                                    end else begin
                                        valid_address <= 1'b0;
                                        A_cnt <= A_cnt + stride;
                                    end
                                end
                                
                            end
                            
                            INNER_STATE_BFU_START: begin
                                bfu_ready <= 1'b1;
                                inner_state <= INNER_STATE_BFU;
                            end
                            
                            INNER_STATE_BFU: begin
                                bfu_ready <= 1'b0;
                                if(bfu_valid) begin //Only write to memory once butterfly unit is ready
                                    inner_state <= INNER_STATE_WAIT;
                                end 
                            end
                            
                            INNER_STATE_WAIT: begin //Buffer writing to memory
                                inner_state <= INNER_STATE_WE;
                            end
                            
                            INNER_STATE_WE: begin //Buffer to write to memory, then handle changing stages.
                                
                                bfu_out <= 1'b1;
                                if(mem_select == 1'b1) begin
                                    WE1 <= 1'b1;
                                end else begin
                                    WE0 <= 1'b1;
                                end
                                
                                inner_state <= INNER_STATE_CHECK;
                            end
                            
                            INNER_STATE_CHECK: begin
                                valid_address <= 1'b0;
                                bfu_out <= 1'b0;
                                WE0 <= 1'b0;
                                WE1 <= 1'b0;
                                if(address_count == 4'd8) begin //The stage is completed when all eight address pairs have been generated
                                    twiddle_address <= 3'b0;
                                    mem_select <= ~mem_select;
                                    read_select <= ~read_select;
                                    stride <= stride << 1;
                                    inverted_stride <= inverted_stride >> 1;
                                    stage_cnt <= stage_cnt + 1;
                                    address_count <= 4'b0;
                                    A_cnt <= 4'b0;
                                end else begin
                                    twiddle_address <= twiddle_address + inverted_stride;
                                end
                                inner_state <= INNER_STATE_ADDR;
                            end
                            
                        endcase
                        
                    end
                end
                
                OUTER_STATE_OUT: begin
                    out_done_r <= 1'b1;
                end
                
                default: outer_state <= OUTER_STATE_IDLE;
                
            endcase
        end
    end
    
endmodule