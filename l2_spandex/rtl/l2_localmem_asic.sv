`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_localmem_asic (
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

    logic [23:0] lmem_rd_data_mixed_tmp[`L2_NUM_PORTS][`L2_ASIC_SRAMS_PER_WAY];
    line_t lmem_rd_data_line_tmp[`L2_NUM_PORTS][`L2_ASIC_SRAMS_PER_WAY];

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

    logic lmem_wr_en_mixed_bank[`L2_ASIC_SRAMS_PER_WAY];
    logic lmem_wr_en_line_bank[`L2_ASIC_SRAMS_PER_WAY];

    logic [23:0] lmem_wr_data_mixed, wr_mixed_mask;
    assign lmem_wr_data_mixed = {lmem_wr_data_hprot, lmem_wr_data_state[0], {(24 - 1 - `STABLE_STATE_BITS - `L2_TAG_BITS){1'b0}}, lmem_wr_data_tag};

    l2_way_t evict_way_arr [`L2_SETS];

    //determine mask for writing to shared SRAM
    always_comb begin
        wr_mixed_mask = 24'b0;

        if (lmem_wr_en_clear_mshr) begin
            wr_mixed_mask[`L2_ASIC_MIXED_SRAM_HPROT_INDEX] = 1'b1;
            wr_mixed_mask[`L2_ASIC_MIXED_SRAM_TAG_INDEX_HI:`L2_ASIC_MIXED_SRAM_TAG_INDEX_LO] = {`L2_TAG_BITS{1'b1}};
        end

        if (lmem_wr_en_clear_mshr | lmem_wr_en_state | lmem_wr_rst) begin
            wr_mixed_mask[`L2_ASIC_MIXED_SRAM_STATE_INDEX_HI:`L2_ASIC_MIXED_SRAM_STATE_INDEX_LO] = {`STABLE_STATE_BITS{1'b1}};
        end

    end

    generate
        if (`L2_ASIC_SRAMS_PER_WAY == 1) begin
            always_comb begin
                lmem_wr_en_mixed_bank[0] = lmem_wr_en_clear_mshr | lmem_wr_rst | lmem_wr_en_state;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `L2_ASIC_SRAMS_PER_WAY; j++) begin
                    lmem_wr_en_mixed_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS)]) begin
                        lmem_wr_en_mixed_bank[j] = lmem_wr_en_clear_mshr | lmem_wr_rst | lmem_wr_en_state;
                    end
                end
            end
        end

        if (`L2_ASIC_SRAMS_PER_WAY == 1) begin
            always_comb begin
                lmem_wr_en_line_bank[0] = lmem_wr_en_line | lmem_wr_en_clear_mshr;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `L2_ASIC_SRAMS_PER_WAY; j++) begin
                    lmem_wr_en_line_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS)]) begin
                        lmem_wr_en_line_bank[j] = lmem_wr_en_line | lmem_wr_en_clear_mshr;
                    end
                end
            end
        end
    endgenerate

    genvar i, j, k;
    generate
        for (i = 0; i < `L2_NUM_PORTS; i++) begin
            //shared memory for tag, state, hprot
            for (j = 0; j < `L2_ASIC_SRAMS_PER_WAY; j++) begin
                if (`ASIC_SRAM_ADDR_WIDTH > (`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS) + 1) begin
`ifdef GF12
                    GF12_SRAM_SP_512x24 mixed_sram(
                        .CLK(clk),
                        .A0({{(`ASIC_SRAM_ADDR_WIDTH - (`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                lmem_set_in[(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS - 1):0]}),
                        .D0(lmem_wr_data_mixed),
                        .Q0(lmem_rd_data_mixed_tmp[i][j]),
                        .WE0(lmem_wr_en_port[i] & lmem_wr_en_mixed_bank[j]),
                        .CE0(lmem_rd_en),
                        .WEM0(wr_mixed_mask));
`else
                    sram_behav #(.DATA_WIDTH(24), .NUM_WORDS(512)) mixed_sram(
                        .clk_i(clk),
                        .req_i(lmem_rd_en),
                        .we_i(lmem_wr_en_port[i] & lmem_wr_en_mixed_bank[j]),
                        .addr_i({{(`ASIC_SRAM_ADDR_WIDTH - (`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                lmem_set_in[(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS - 1):0]}),
                        .wdata_i(lmem_wr_data_mixed),
                        .be_i(wr_mixed_mask),
                        .rdata_o(lmem_rd_data_mixed_tmp[i][j]));
`endif
                end else begin
`ifdef GF12
                    GF12_SRAM_SP_512x24 mixed_sram(
                        .CLK(clk),
                        .A0(lmem_set_in[(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS - 1):0]),
                        .D0(lmem_wr_data_mixed),
                        .Q0(lmem_rd_data_mixed_tmp[i][j]),
                        .WE0(lmem_wr_en_port[i] & lmem_wr_en_mixed_bank[j]),
                        .CE0(lmem_rd_en),
                        .WEM0(wr_mixed_mask));
`else
                    sram_behav #(.DATA_WIDTH(24), .NUM_WORDS(512)) mixed_sram(
                        .clk_i(clk),
                        .req_i(lmem_rd_en),
                        .we_i(lmem_wr_en_port[i] & lmem_wr_en_mixed_bank[j]),
                        .addr_i(lmem_set_in[(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS - 1):0]),
                        .wdata_i(lmem_wr_data_mixed),
                        .be_i(wr_mixed_mask),
                        .rdata_o(lmem_rd_data_mixed_tmp[i][j]));
`endif
                end

                //line memory
                //128 bits - using 512x64 SRAM, need 2 SRAMs per line
                for (k = 0; k < `L2_ASIC_SRAMS_PER_LINE; k++) begin
                    if (`ASIC_SRAM_ADDR_WIDTH > (`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS) + 1) begin
`ifdef GF12
                        GF12_SRAM_SP_512x64 line_sram(
                            .CLK(clk),
                            .A0({{(`ASIC_SRAM_ADDR_WIDTH - (`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                    lmem_set_in[(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS - 1):0]}),
                            .D0(lmem_wr_data_line[(64*(k+1)-1):(64*k)]),
                            .Q0(lmem_rd_data_line_tmp[i][j][(64*(k+1)-1):(64*k)]),
                            .WE0(lmem_wr_en_port[i] & lmem_wr_en_line_bank[j]),
                            .CE0(lmem_rd_en),
                            .WEM0({64{1'b1}}));
`else
                        sram_behav #(.DATA_WIDTH(64), .NUM_WORDS(512)) line_sram(
                            .clk_i(clk),
                            .req_i(lmem_rd_en),
                            .we_i(lmem_wr_en_port[i] & lmem_wr_en_line_bank[j]),
                            .addr_i({{(`ASIC_SRAM_ADDR_WIDTH - (`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                    lmem_set_in[(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS - 1):0]}),
                            .wdata_i(lmem_wr_data_line[(64*(k+1)-1):(64*k)]),
                            .be_i({64{1'b1}}),
                            .rdata_o(lmem_rd_data_line_tmp[i][j][(64*(k+1)-1):(64*k)]));
`endif
                    end else begin
`ifdef GF12
                        GF12_SRAM_SP_512x64 line_sram(
                            .CLK(clk),
                            .A0(lmem_set_in[(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS - 1):0]),
                            .D0(lmem_wr_data_line[(64*(k+1)-1):(64*k)]),
                            .Q0(lmem_rd_data_line_tmp[i][j][(64*(k+1)-1):(64*k)]),
                            .WE0(lmem_wr_en_port[i] & lmem_wr_en_line_bank[j]),
                            .CE0(lmem_rd_en),
                            .WEM0({64{1'b1}}));
`else
                        sram_behav #(.DATA_WIDTH(64), .NUM_WORDS(512)) line_sram(
                            .clk_i(clk),
                            .req_i(lmem_rd_en),
                            .we_i(lmem_wr_en_port[i] & lmem_wr_en_line_bank[j]),
                            .addr_i(lmem_set_in[(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS - 1):0]),
                            .wdata_i(lmem_wr_data_line[(64*(k+1)-1):(64*k)]),
                            .be_i({64{1'b1}}),
                            .rdata_o(lmem_rd_data_line_tmp[i][j][(64*(k+1)-1):(64*k)]));
`endif
                    end
                end
            end
        end
    endgenerate

    generate
        if (`L2_ASIC_SRAMS_PER_WAY == 1) begin
            always_comb begin
                for (int k = 0; k < `WORDS_PER_LINE; k++) begin
                    for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                        lmem_rd_data_hprot[i] = lmem_rd_data_mixed_tmp[i][0][`L2_ASIC_MIXED_SRAM_HPROT_INDEX];
                        lmem_rd_data_state[i][k] = lmem_rd_data_mixed_tmp[i][0][`L2_ASIC_MIXED_SRAM_STATE_INDEX_HI:`L2_ASIC_MIXED_SRAM_STATE_INDEX_LO];
                        lmem_rd_data_tag[i] = lmem_rd_data_mixed_tmp[i][0][`L2_ASIC_MIXED_SRAM_TAG_INDEX_HI:`L2_ASIC_MIXED_SRAM_TAG_INDEX_LO];
                        lmem_rd_data_line[i] = lmem_rd_data_line_tmp[i][0];
                    end
                end
            end
        end else begin
            always_comb begin
                for (int k = 0; k < `WORDS_PER_LINE; k++) begin
                    for (int i = 0; i < `L2_NUM_PORTS; i++) begin
                        lmem_rd_data_hprot[i] = lmem_rd_data_mixed_tmp[i][0][`L2_ASIC_MIXED_SRAM_HPROT_INDEX];
                        lmem_rd_data_state[i][k] = lmem_rd_data_mixed_tmp[i][0][`L2_ASIC_MIXED_SRAM_STATE_INDEX_HI:`L2_ASIC_MIXED_SRAM_STATE_INDEX_LO];
                        lmem_rd_data_tag[i] = lmem_rd_data_mixed_tmp[i][0][`L2_ASIC_MIXED_SRAM_TAG_INDEX_HI:`L2_ASIC_MIXED_SRAM_TAG_INDEX_LO];
                        lmem_rd_data_line[i] = lmem_rd_data_line_tmp[i][0];
                        for (int j = 1; j < `L2_ASIC_SRAMS_PER_WAY; j++) begin
                            if (j == lmem_set_in[(`L2_SET_BITS-1):(`L2_SET_BITS - `L2_ASIC_SRAM_INDEX_BITS)]) begin
                                lmem_rd_data_hprot[i] = lmem_rd_data_mixed_tmp[i][j][`L2_ASIC_MIXED_SRAM_HPROT_INDEX];
                                lmem_rd_data_state[i][k] = lmem_rd_data_mixed_tmp[i][j][`L2_ASIC_MIXED_SRAM_STATE_INDEX_HI:`L2_ASIC_MIXED_SRAM_STATE_INDEX_LO];
                                lmem_rd_data_tag[i] = lmem_rd_data_mixed_tmp[i][j][`L2_ASIC_MIXED_SRAM_TAG_INDEX_HI:`L2_ASIC_MIXED_SRAM_TAG_INDEX_LO];
                                lmem_rd_data_line[i] = lmem_rd_data_line_tmp[i][j];
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (int i = 0; i < `L2_SETS; i++) begin
                evict_way_arr[i] <= {`L2_WAY_BITS{1'b0}};
            end
        end else begin
            if (lmem_wr_en_evict_way) begin
                evict_way_arr[lmem_set_in] <= lmem_wr_data_evict_way;
            end
            lmem_rd_data_evict_way <= evict_way_arr[lmem_set_in];
        end
    end

endmodule
