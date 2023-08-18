`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"
module l2_localmem (
    input logic clk,
    input logic rst,
    input logic lmem_rd_en,
    input logic lmem_wr_en_line,
    input logic lmem_wr_en_state,
    input logic lmem_wr_en_evict_way,
    input logic lmem_wr_rst,
    input logic lmem_wr_en_clear_mshr,
    input l2_set_t lmem_set_in,
    input l2_way_t lmem_way_in,
    input line_t lmem_wr_data_line,
    input l2_tag_t lmem_wr_data_tag,
    input hprot_t lmem_wr_data_hprot,
    input l2_way_t lmem_wr_data_evict_way, 
    input state_t lmem_wr_data_state[`WORDS_PER_LINE],
  
    output line_t lmem_rd_data_line[`L2_NUM_PORTS],
    output l2_tag_t lmem_rd_data_tag[`L2_NUM_PORTS],
    output hprot_t lmem_rd_data_hprot[`L2_NUM_PORTS],
    output l2_way_t lmem_rd_data_evict_way,
    output state_t lmem_rd_data_state[`L2_NUM_PORTS][`WORDS_PER_LINE]
    );
   
    //for following 2 use BRAM data width to aviod warnings, only copy relevant bits to output data
    logic [23:0] lmem_rd_data_tag_tmp[`L2_NUM_PORTS][`L2_TAG_BRAMS_PER_WAY];
    logic [3:0] lmem_rd_data_evict_way_tmp[`L2_EVICT_WAY_BRAMS];
    state_t lmem_rd_data_state_tmp[`L2_NUM_PORTS][`L2_STATE_BRAMS_PER_WAY][`WORDS_PER_LINE];
    line_t lmem_rd_data_line_tmp[`L2_NUM_PORTS][`L2_LINE_BRAMS_PER_WAY];
    hprot_t lmem_rd_data_hprot_tmp[`L2_NUM_PORTS][`L2_HPROT_BRAMS_PER_WAY];
   
    //write enable decoder for ways
    logic lmem_wr_en_port[0:(`L2_NUM_PORTS-1)];
    always_comb begin
        for (int i = 0; i < `L2_NUM_PORTS; i++) begin
            lmem_wr_en_port[i] = 1'b0;
            if (lmem_wr_rst) begin
                lmem_wr_en_port[i] = 1'b1;
            end else if (lmem_way_in == i) begin
                lmem_wr_en_port[i] = 1'b1;
            end
        end
    end
    logic lmem_wr_en_hprot_bank[`L2_HPROT_BRAMS_PER_WAY];
    logic lmem_wr_en_state_bank[`L2_STATE_BRAMS_PER_WAY];
    logic lmem_wr_en_tag_bank[`L2_TAG_BRAMS_PER_WAY];
    logic lmem_wr_en_evict_way_bank[`L2_EVICT_WAY_BRAMS];
    logic lmem_wr_en_line_bank[`L2_LINE_BRAMS_PER_WAY];
    //extend to the appropriate BRAM width
    logic [23:0] lmem_wr_data_tag_extended;
    assign lmem_wr_data_tag_extended = {{(24-`L2_TAG_BITS){1'b0}}, lmem_wr_data_tag};
    logic [3:0] lmem_wr_data_evict_way_extended;
    assign lmem_wr_data_evict_way_extended = {{(4-`L2_WAY_BITS){1'b0}}, lmem_wr_data_evict_way};
    generate
        if (`L2_HPROT_BRAMS_PER_WAY == 1) begin
            always_comb begin
                lmem_wr_en_hprot_bank[0] = lmem_wr_en_clear_mshr;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `L2_HPROT_BRAMS_PER_WAY; j++) begin
                    lmem_wr_en_hprot_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_HPROT_BRAM_INDEX_BITS)]) begin
                        lmem_wr_en_hprot_bank[j] = lmem_wr_en_clear_mshr;
                    end
                end
            end
        end
       
        if (`L2_STATE_BRAMS_PER_WAY == 1) begin
            always_comb begin
                lmem_wr_en_state_bank[0] = lmem_wr_en_state  | lmem_wr_rst | lmem_wr_en_clear_mshr;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `L2_STATE_BRAMS_PER_WAY; j++) begin
                    lmem_wr_en_state_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_STATE_BRAM_INDEX_BITS)]) begin
                        lmem_wr_en_state_bank[j] = lmem_wr_en_state  | lmem_wr_rst | lmem_wr_en_clear_mshr;
                    end
                end
            end
        end
        if (`L2_TAG_BRAMS_PER_WAY == 1) begin
            always_comb begin
                lmem_wr_en_tag_bank[0] = lmem_wr_en_clear_mshr;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `L2_TAG_BRAMS_PER_WAY; j++) begin
                    lmem_wr_en_tag_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_TAG_BRAM_INDEX_BITS)]) begin
                        lmem_wr_en_tag_bank[j] = lmem_wr_en_clear_mshr;
                    end
                end
            end
        end
        if (`L2_EVICT_WAY_BRAMS == 1) begin
            always_comb begin
                lmem_wr_en_evict_way_bank[0] = lmem_wr_en_evict_way;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `L2_EVICT_WAY_BRAMS; j++) begin
                    lmem_wr_en_evict_way_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_EVICT_WAY_BRAM_INDEX_BITS)]) begin
                        lmem_wr_en_evict_way_bank[j] = lmem_wr_en_evict_way;
                    end
                end
            end
        end
        if (`L2_LINE_BRAMS_PER_WAY == 1) begin
            always_comb begin
                lmem_wr_en_line_bank[0] = lmem_wr_en_line | lmem_wr_en_clear_mshr;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `L2_LINE_BRAMS_PER_WAY; j++) begin
                    lmem_wr_en_line_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_LINE_BRAM_INDEX_BITS)]) begin
                        lmem_wr_en_line_bank[j] = lmem_wr_en_line | lmem_wr_en_clear_mshr;
                    end
                end
            end
        end
    endgenerate
    genvar i, j, k;
    generate
        for (i = 0; i < (`L2_NUM_PORTS / 2); i++) begin
            //hprot memory
            //need 1 bit for hprot - 16384x1 BRAM
            for (j = 0; j < `L2_HPROT_BRAMS_PER_WAY; j++) begin
                if (`BRAM_16384_ADDR_WIDTH > (`L2_SET_BITS - `L2_HPROT_BRAM_INDEX_BITS) + 1) begin
                    BRAM_16384x1 hprot_bram(
                        .CLK(clk),
                        .A0({{(`BRAM_16384_ADDR_WIDTH - (`L2_SET_BITS - `L2_HPROT_BRAM_INDEX_BITS) - 1){1'b0}},
                                1'b0, lmem_set_in[(`L2_SET_BITS - `L2_HPROT_BRAM_INDEX_BITS - 1):0]}),
                        .D0(lmem_wr_data_hprot),
                        .Q0(lmem_rd_data_hprot_tmp[2*i][j]),
                        .WE0(lmem_wr_en_port[2*i] & lmem_wr_en_hprot_bank[j]),
                        .CE0(lmem_rd_en),
                        .A1({{(`BRAM_16384_ADDR_WIDTH - (`L2_SET_BITS - `L2_HPROT_BRAM_INDEX_BITS) - 1){1'b0}},
                                1'b1, lmem_set_in[(`L2_SET_BITS - `L2_HPROT_BRAM_INDEX_BITS - 1):0]}),
                        .D1(lmem_wr_data_hprot),
                        .Q1(lmem_rd_data_hprot_tmp[2*i+1][j]),
                        .WE1(lmem_wr_en_port[2*i+1] & lmem_wr_en_hprot_bank[j]),
                        .CE1(lmem_rd_en),
                        .WEM0(),
                        .WEM1());
                   
                end else begin
                    BRAM_16384x1 hprot_bram(
                        .CLK(clk),
                        .A0({1'b0, lmem_set_in[(`L2_SET_BITS - `L2_HPROT_BRAM_INDEX_BITS - 1):0]}),
                        .D0(lmem_wr_data_hprot),
                        .Q0(lmem_rd_data_hprot_tmp[2*i][j]),
                        .WE0(lmem_wr_en_port[2*i] & lmem_wr_en_hprot_bank[j]),
                        .CE0(lmem_rd_en),
                        .A1({1'b1, lmem_set_in[(`L2_SET_BITS - `L2_HPROT_BRAM_INDEX_BITS - 1):0]}),
                        .D1(lmem_wr_data_hprot),
                        .Q1(lmem_rd_data_hprot_tmp[2*i+1][j]),
                        .WE1(lmem_wr_en_port[2*i+1] & lmem_wr_en_hprot_bank[j]),
                        .CE1(lmem_rd_en),
                        .WEM0(),
                        .WEM1());
                end
            end
            //state memory
            //need 3 bits for state - 4096x4 BRAM
            for (k = 0; k < `WORDS_PER_LINE; k++) begin
                for (j = 0; j < `L2_STATE_BRAMS_PER_WAY; j++) begin
                     if (`BRAM_8192_ADDR_WIDTH > (`L2_SET_BITS - `L2_STATE_BRAM_INDEX_BITS) + 1) begin
                        BRAM_8192x2 state_bram(
                            .CLK(clk),
                            .A0({{(`BRAM_8192_ADDR_WIDTH - (`L2_SET_BITS - `L2_STATE_BRAM_INDEX_BITS) - 1){1'b0}},
                                    1'b0, lmem_set_in[(`L2_SET_BITS - `L2_STATE_BRAM_INDEX_BITS - 1):0]}),
                            .D0(lmem_wr_data_state[k]),
                            .Q0(lmem_rd_data_state_tmp[2*i][j][k]),
                            .WE0(lmem_wr_en_port[2*i] & lmem_wr_en_state_bank[j]),
                            .CE0(lmem_rd_en),
                            .A1({{(`BRAM_8192_ADDR_WIDTH - (`L2_SET_BITS - `L2_STATE_BRAM_INDEX_BITS) - 1){1'b0}},
                                    1'b1, lmem_set_in[(`L2_SET_BITS - `L2_STATE_BRAM_INDEX_BITS - 1):0]}),
                            .D1(lmem_wr_data_state[k]),
                            .Q1(lmem_rd_data_state_tmp[2*i+1][j][k]),
                            .WE1(lmem_wr_en_port[2*i+1] & lmem_wr_en_state_bank[j]),
                            .CE1(lmem_rd_en),
                            .WEM0(),
                            .WEM1());
                    end else begin
                        BRAM_8192x2 state_bram(
                            .CLK(clk),
                            .A0({1'b0, lmem_set_in[(`L2_SET_BITS - `L2_STATE_BRAM_INDEX_BITS - 1):0]}),
                            .D0(lmem_wr_data_state[k]),
                            .Q0(lmem_rd_data_state_tmp[2*i][j][k]),
                            .WE0(lmem_wr_en_port[2*i] & lmem_wr_en_state_bank[j]),
                            .CE0(lmem_rd_en),
                            .A1({1'b1, lmem_set_in[(`L2_SET_BITS - `L2_STATE_BRAM_INDEX_BITS - 1):0]}),
                            .D1(lmem_wr_data_state[k]),
                            .Q1(lmem_rd_data_state_tmp[2*i+1][j][k]),
                            .WE1(lmem_wr_en_port[2*i+1] & lmem_wr_en_state_bank[j]),
                            .CE1(lmem_rd_en),
                            .WEM0(),
                            .WEM1());
                    end
                end
            end
            //tag memory
            //need ~15-20 bits for tag - 2048x8 BRAM
            for (j = 0; j < `L2_TAG_BRAMS_PER_WAY; j++) begin
                for (k = 0; k < `L2_BRAMS_PER_TAG; k++) begin
                    if (`BRAM_2048_ADDR_WIDTH > (`L2_SET_BITS - `L2_TAG_BRAM_INDEX_BITS) + 1) begin
                        BRAM_2048x8 tag_bram(
                            .CLK(clk),
                            .A0({{(`BRAM_2048_ADDR_WIDTH - (`L2_SET_BITS - `L2_TAG_BRAM_INDEX_BITS) - 1){1'b0}},
                                    1'b0, lmem_set_in[(`L2_SET_BITS - `L2_TAG_BRAM_INDEX_BITS - 1):0]}),
                            .D0(lmem_wr_data_tag_extended[(8*(k+1)-1):(8*k)]),
                            .Q0(lmem_rd_data_tag_tmp[2*i][j][(8*(k+1)-1):(8*k)]),
                            .WE0(lmem_wr_en_port[2*i] & lmem_wr_en_tag_bank[j]),
                            .CE0(lmem_rd_en),
                            .A1({{(`BRAM_2048_ADDR_WIDTH - (`L2_SET_BITS - `L2_TAG_BRAM_INDEX_BITS) - 1){1'b0}} ,
                                    1'b1, lmem_set_in[(`L2_SET_BITS - `L2_TAG_BRAM_INDEX_BITS - 1):0]}),
                            .D1(lmem_wr_data_tag_extended[(8*(k+1)-1):(8*k)]),
                            .Q1(lmem_rd_data_tag_tmp[2*i+1][j][(8*(k+1)-1):(8*k)]),
                            .WE1(lmem_wr_en_port[2*i+1] & lmem_wr_en_tag_bank[j]),
                            .CE1(lmem_rd_en),
                            .WEM0(),
                            .WEM1());
                    end else begin
                        BRAM_2048x8 tag_bram(
                            .CLK(clk),
                            .A0({1'b0, lmem_set_in[(`L2_SET_BITS - `L2_TAG_BRAM_INDEX_BITS - 1):0]}),
                            .D0(lmem_wr_data_tag_extended[(8*(k+1)-1):(8*k)]),
                            .Q0(lmem_rd_data_tag_tmp[2*i][j][(8*(k+1)-1):(8*k)]),
                            .WE0(lmem_wr_en_port[2*i] & lmem_wr_en_tag_bank[j]),
                            .CE0(lmem_rd_en),
                            .A1({1'b1, lmem_set_in[(`L2_SET_BITS - `L2_TAG_BRAM_INDEX_BITS - 1):0]}),
                            .D1(lmem_wr_data_tag_extended[(8*(k+1)-1):(8*k)]),
                            .Q1(lmem_rd_data_tag_tmp[2*i+1][j][(8*(k+1)-1):(8*k)]),
                            .WE1(lmem_wr_en_port[2*i+1] & lmem_wr_en_tag_bank[j]),
                            .CE1(lmem_rd_en),
                            .WEM0(),
                            .WEM1());
                    end
                end
            end
            //line memory
            //128 bits - using 1024x16 BRAM, need 4 BRAMs per line
            for (j = 0; j < `L2_LINE_BRAMS_PER_WAY; j++) begin
                for (k = 0; k < `L2_BRAMS_PER_LINE; k++) begin
                    if (`BRAM_1024_ADDR_WIDTH > (`L2_SET_BITS - `L2_LINE_BRAM_INDEX_BITS) + 1) begin
                        BRAM_1024x16 line_bram(
                            .CLK(clk),
                            .A0({{(`BRAM_1024_ADDR_WIDTH - (`L2_SET_BITS - `L2_LINE_BRAM_INDEX_BITS) - 1){1'b0}},
                                    1'b0, lmem_set_in[(`L2_SET_BITS - `L2_LINE_BRAM_INDEX_BITS - 1):0]}),
                            .D0(lmem_wr_data_line[(16*(k+1)-1):(16*k)]),
                            .Q0(lmem_rd_data_line_tmp[2*i][j][(16*(k+1)-1):(16*k)]),
                            .WE0(lmem_wr_en_port[2*i] & lmem_wr_en_line_bank[j]),
                            .CE0(lmem_rd_en),
                            .A1({{(`BRAM_1024_ADDR_WIDTH - (`L2_SET_BITS - `L2_LINE_BRAM_INDEX_BITS) - 1){1'b0}} ,
                                    1'b1, lmem_set_in[(`L2_SET_BITS - `L2_LINE_BRAM_INDEX_BITS - 1):0]}),
                            .D1(lmem_wr_data_line[(16*(k+1)-1):(16*k)]),
                            .Q1(lmem_rd_data_line_tmp[2*i+1][j][(16*(k+1)-1):(16*k)]),
                            .WE1(lmem_wr_en_port[2*i+1] & lmem_wr_en_line_bank[j]),
                            .CE1(lmem_rd_en),
                            .WEM0(),
                            .WEM1());
                    end else begin
                        BRAM_1024x16 line_bram(
                            .CLK(clk),
                            .A0({1'b0, lmem_set_in[(`L2_SET_BITS - `L2_LINE_BRAM_INDEX_BITS - 1):0]}),
                            .D0(lmem_wr_data_line[(16*(k+1)-1):(16*k)]),
                            .Q0(lmem_rd_data_line_tmp[2*i][j][(16*(k+1)-1):(16*k)]),
                            .WE0(lmem_wr_en_port[2*i] & lmem_wr_en_line_bank[j]),
                            .CE0(lmem_rd_en),
                            .A1({1'b1, lmem_set_in[(`L2_SET_BITS - `L2_LINE_BRAM_INDEX_BITS - 1):0]}),
                            .D1(lmem_wr_data_line[(16*(k+1)-1):(16*k)]),
                            .Q1(lmem_rd_data_line_tmp[2*i+1][j][(16*(k+1)-1):(16*k)]),
                            .WE1(lmem_wr_en_port[2*i+1] & lmem_wr_en_line_bank[j]),
                            .CE1(lmem_rd_en),
                            .WEM0(),
                            .WEM1());
                    end
                end
            end
        end
        //evict ways memory
        //need 2-5 bits for eviction  - 4096x4 BRAM
        for (j = 0; j < `L2_EVICT_WAY_BRAMS; j++) begin
            if (`BRAM_4096_ADDR_WIDTH > (`L2_SET_BITS - `L2_EVICT_WAY_BRAM_INDEX_BITS)) begin
                BRAM_4096x4 evict_way_bram(
                    .CLK(clk),
                    .A0({{(`BRAM_4096_ADDR_WIDTH - (`L2_SET_BITS - `L2_EVICT_WAY_BRAM_INDEX_BITS)){1'b0}},
                            lmem_set_in[(`L2_SET_BITS - `L2_EVICT_WAY_BRAM_INDEX_BITS - 1):0]}),
                    .D0(lmem_wr_data_evict_way_extended),
                    .Q0(lmem_rd_data_evict_way_tmp[j]),
                    .WE0(lmem_wr_en_evict_way_bank[j]),
                    .CE0(lmem_rd_en),
                    .A1(12'b0),
                    .D1(4'b0),
                    .Q1(),
                    .WE1(1'b0),
                    .CE1(1'b0),
                    .WEM0(),
                    .WEM1());
            end else begin
                BRAM_4096x4 evict_way_bram(
                    .CLK(clk),
                    .A0({lmem_set_in[(`L2_SET_BITS - `L2_EVICT_WAY_BRAM_INDEX_BITS - 1):0]}),
                    .D0(lmem_wr_data_evict_way_extended),
                    .Q0(lmem_rd_data_evict_way_tmp[j]),
                    .WE0(lmem_wr_en_evict_way_bank[j]),
                    .CE0(lmem_rd_en),
                    .A1(12'b0),
                    .D1(4'b0),
                    .Q1(),
                    .WE1(1'b0),
                    .CE1(1'b0),
                    .WEM0(),
                    .WEM1());
            end
        end
    endgenerate
    generate
       
        if (`L2_HPROT_BRAMS_PER_WAY == 1) begin
            always_comb begin
                for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                    lmem_rd_data_hprot[i] = lmem_rd_data_hprot_tmp[i][0];
                end
            end
        end else begin
            always_comb begin
                for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                    lmem_rd_data_hprot[i] = lmem_rd_data_hprot_tmp[i][0];
                    for (int j = 1; j < `L2_HPROT_BRAMS_PER_WAY; j++) begin
                        if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_HPROT_BRAM_INDEX_BITS)]) begin
                            lmem_rd_data_hprot[i] = lmem_rd_data_hprot_tmp[i][j];
                        end
                    end
                end
            end
        end
              
        if (`L2_STATE_BRAMS_PER_WAY == 1) begin
            always_comb begin
                for (int k = 0; k < `WORDS_PER_LINE; k++) begin
                    for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                        lmem_rd_data_state[i][k] = lmem_rd_data_state_tmp[i][0][k];
                    end
                end
            end
        end else begin
            always_comb begin
                for (int k = 0; k < `WORDS_PER_LINE; k++) begin
                    for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                        lmem_rd_data_state[i][k] = lmem_rd_data_state_tmp[i][0][k];
                        for (int j = 1; j < `L2_STATE_BRAMS_PER_WAY; j++) begin
                            if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_STATE_BRAM_INDEX_BITS)]) begin
                                lmem_rd_data_state[i][k] = lmem_rd_data_state_tmp[i][j][k];
                            end
                        end
                    end
                end
            end
        end
       
        if (`L2_TAG_BRAMS_PER_WAY == 1) begin
            always_comb begin
                for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                    lmem_rd_data_tag[i] = lmem_rd_data_tag_tmp[i][0];
                end
            end
        end else begin
            always_comb begin
                for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                    lmem_rd_data_tag[i] = lmem_rd_data_tag_tmp[i][0];
                    for (int j = 1; j < `L2_TAG_BRAMS_PER_WAY; j++) begin
                        if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_TAG_BRAM_INDEX_BITS)]) begin
                            lmem_rd_data_tag[i] = lmem_rd_data_tag_tmp[i][j];
                        end
                    end
                end
            end
        end
       
        if (`L2_LINE_BRAMS_PER_WAY == 1) begin
            always_comb begin
                for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                    lmem_rd_data_line[i] = lmem_rd_data_line_tmp[i][0];
                end
            end
        end else begin
            always_comb begin
                for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                    lmem_rd_data_line[i] = lmem_rd_data_line_tmp[i][0];
                    for (int j = 1; j < `L2_LINE_BRAMS_PER_WAY; j++) begin
                        if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_LINE_BRAM_INDEX_BITS)]) begin
                            lmem_rd_data_line[i] = lmem_rd_data_line_tmp[i][j];
                        end
                    end
                end
            end
        end
       
        if (`L2_EVICT_WAY_BRAMS == 1) begin
            always_comb begin
                lmem_rd_data_evict_way = lmem_rd_data_evict_way_tmp[0];
            end
        end else begin
            always_comb begin
                lmem_rd_data_evict_way = lmem_rd_data_evict_way_tmp[0];
                for (int j = 1; j < `L2_EVICT_WAY_BRAMS; j++) begin
                    if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_EVICT_WAY_BRAM_INDEX_BITS)]) begin
                        lmem_rd_data_evict_way = lmem_rd_data_evict_way_tmp[j];
                    end
                end
            end
        end
    endgenerate
endmodule