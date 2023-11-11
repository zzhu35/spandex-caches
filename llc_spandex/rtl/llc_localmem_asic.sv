`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_localmem_asic (
    input logic clk,
    input logic rst,
    input logic lmem_rd_en,
    input llc_set_t lmem_set_in,
    input llc_way_t lmem_way_in,
    input logic lmem_wr_en_evict_way,
    input logic lmem_wr_en_all_mem,
    input state_t lmem_wr_data_state,
    input line_t lmem_wr_data_line,
    input hprot_t lmem_wr_data_hprot,
    input llc_tag_t lmem_wr_data_tag,
    input llc_way_t lmem_wr_data_evict_way,
    input sharers_t lmem_wr_data_sharers,
    input owner_t lmem_wr_data_owner,
    input logic lmem_wr_data_dirty_bit,
    input logic [(`LLC_NUM_PORTS-1):0] lmem_wr_rst_flush,

    output logic lmem_rd_data_dirty_bit[`LLC_NUM_PORTS],
    output line_t lmem_rd_data_line[`LLC_NUM_PORTS],
    output llc_tag_t lmem_rd_data_tag[`LLC_NUM_PORTS],
    output sharers_t lmem_rd_data_sharers[`LLC_NUM_PORTS],
    output owner_t lmem_rd_data_owner[`LLC_NUM_PORTS],
    output hprot_t lmem_rd_data_hprot[`LLC_NUM_PORTS],
    output llc_state_t lmem_rd_data_state[`LLC_NUM_PORTS],
    output llc_way_t lmem_rd_data_evict_way
    );
    logic [27:0] lmem_rd_data_mixed_tmp[`LLC_NUM_PORTS][`LLC_ASIC_SRAMS_PER_WAY];
    sharers_t lmem_rd_data_sharers_tmp[`LLC_NUM_PORTS][`LLC_ASIC_SRAMS_PER_WAY];
    line_t lmem_rd_data_line_tmp[`LLC_NUM_PORTS][`LLC_ASIC_SRAMS_PER_WAY];

    //write enable decoder for ways
    logic wr_en_port[0:(`LLC_NUM_PORTS-1)];
    always_comb begin
        for (int i = 0; i < `LLC_NUM_PORTS; i++) begin
            wr_en_port[i] = 1'b0;
            if (lmem_wr_rst_flush[i]) begin
                wr_en_port[i] = 1'b1;
            end else if (lmem_way_in == i) begin
                wr_en_port[i] = 1'b1;
            end
        end
    end

    logic wr_en_mixed_bank[`LLC_ASIC_SRAMS_PER_WAY];
    logic wr_en_line_bank[`LLC_ASIC_SRAMS_PER_WAY];
    logic wr_en_sharers_bank[`LLC_ASIC_SRAMS_PER_WAY];

    logic [27:0] lmem_wr_data_mixed, wr_mixed_mask;

    generate
        if (`LLC_SET_BITS == 9) begin
            assign lmem_wr_data_mixed = {lmem_wr_data_hprot, lmem_wr_data_dirty_bit, lmem_wr_data_state, lmem_wr_data_owner, lmem_wr_data_tag};
        end else begin
            assign lmem_wr_data_mixed = {lmem_wr_data_hprot, lmem_wr_data_dirty_bit, lmem_wr_data_state, lmem_wr_data_owner, {(28 - 2 - `LLC_STATE_BITS - `MAX_N_L2_BITS -`LLC_TAG_BITS){1'b0}}, lmem_wr_data_tag};
        end
    endgenerate
    llc_way_t evict_way_arr[`LLC_SETS];

    logic lmem_wr_rst_flush_or;
    assign lmem_wr_rst_flush_or = |(lmem_wr_rst_flush);

    //determine mask for writing to shared SRAM
    always_comb begin
        wr_mixed_mask = 28'b0;

        if (lmem_wr_en_all_mem) begin
            wr_mixed_mask[`LLC_ASIC_MIXED_SRAM_HPROT_INDEX] = 1'b1;
            wr_mixed_mask[`LLC_ASIC_MIXED_SRAM_OWNER_INDEX_HI:`LLC_ASIC_MIXED_SRAM_OWNER_INDEX_LO] = {`MAX_N_L2_BITS{1'b1}};
            wr_mixed_mask[`LLC_ASIC_MIXED_SRAM_TAG_INDEX_HI:`LLC_ASIC_MIXED_SRAM_TAG_INDEX_LO] = {`LLC_TAG_BITS{1'b1}};
        end

        if (lmem_wr_en_all_mem | lmem_wr_rst_flush_or) begin
            wr_mixed_mask[`LLC_ASIC_MIXED_SRAM_DIRTY_BIT_INDEX] = 1'b1;
            wr_mixed_mask[`LLC_ASIC_MIXED_SRAM_STATE_INDEX_HI:`LLC_ASIC_MIXED_SRAM_STATE_INDEX_LO] = {`LLC_STATE_BITS{1'b1}};
        end

    end

    generate
        if (`LLC_ASIC_SRAMS_PER_WAY == 1) begin
            always_comb begin
                wr_en_mixed_bank[0] = lmem_wr_en_all_mem | lmem_wr_rst_flush_or;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `LLC_ASIC_SRAMS_PER_WAY; j++) begin
                    wr_en_mixed_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS)]) begin
                        wr_en_mixed_bank[j] = lmem_wr_en_all_mem | lmem_wr_rst_flush_or;
                    end
                end
            end
        end

        if (`LLC_ASIC_SRAMS_PER_WAY == 1) begin
            always_comb begin
                wr_en_line_bank[0] = lmem_wr_en_all_mem;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `LLC_ASIC_SRAMS_PER_WAY; j++) begin
                    wr_en_line_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS)]) begin
                        wr_en_line_bank[j] = lmem_wr_en_all_mem;
                    end
                end
            end
        end

        if (`LLC_ASIC_SRAMS_PER_WAY == 1) begin
            always_comb begin
                wr_en_sharers_bank[0] = lmem_wr_en_all_mem | lmem_wr_rst_flush_or;
            end
        end else begin
            always_comb begin
                for (int j = 0; j < `LLC_ASIC_SRAMS_PER_WAY; j++) begin
                    wr_en_sharers_bank[j] = 1'b0;
                    if (j == lmem_set_in[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS)]) begin
                        wr_en_sharers_bank[j] = lmem_wr_en_all_mem | lmem_wr_rst_flush_or;
                    end
                end
            end
        end
    endgenerate

    genvar i, j, k;
    generate
        for (i = 0; i < `LLC_NUM_PORTS; i++) begin
            //shared memory for tag, state, hprot
            for (j = 0; j < `LLC_ASIC_SRAMS_PER_WAY; j++) begin
                if (`ASIC_SRAM_ADDR_WIDTH > (`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS) + 1) begin
`ifdef GF12
                    GF12_SRAM_SP_512x28 mixed_sram(
                        .CLK(clk),
                        .A0({{(`ASIC_SRAM_ADDR_WIDTH - (`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]}),
                        .D0(lmem_wr_data_mixed),
                        .Q0(lmem_rd_data_mixed_tmp[i][j]),
                        .WE0(wr_en_port[i] & wr_en_mixed_bank[j]),
                        .CE0(lmem_rd_en),
                        .WEM0(wr_mixed_mask));
`else
                    sram_behav #(.DATA_WIDTH(28), .NUM_WORDS(512)) mixed_sram(
                        .clk_i(clk),
                        .req_i(lmem_rd_en),
                        .we_i(wr_en_port[i] & wr_en_mixed_bank[j]),
                        .addr_i({{(`ASIC_SRAM_ADDR_WIDTH - (`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]}),
                        .wdata_i(lmem_wr_data_mixed),
                        .be_i(wr_mixed_mask),
                        .rdata_o(lmem_rd_data_mixed_tmp[i][j]));
`endif
                end else begin
`ifdef GF12
                    GF12_SRAM_SP_512x28 mixed_sram(
                        .CLK(clk),
                        .A0(lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]),
                        .D0(lmem_wr_data_mixed),
                        .Q0(lmem_rd_data_mixed_tmp[i][j]),
                        .WE0(wr_en_port[i] & wr_en_mixed_bank[j]),
                        .CE0(lmem_rd_en),
                        .WEM0(wr_mixed_mask));
`else
                    sram_behav #(.DATA_WIDTH(28), .NUM_WORDS(512)) mixed_sram(
                        .clk_i(clk),
                        .req_i(lmem_rd_en),
                        .we_i(wr_en_port[i] & wr_en_mixed_bank[j]),
                        .addr_i(lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]),
                        .wdata_i(lmem_wr_data_mixed),
                        .be_i(wr_mixed_mask),
                        .rdata_o(lmem_rd_data_mixed_tmp[i][j]));
`endif
                end
                //sharers memory
                if (`ASIC_SRAM_ADDR_WIDTH > (`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS) + 1) begin
`ifdef GF12
                    GF12_SRAM_SP_512x16 sharers_sram(
                        .CLK(clk),
                        .A0({{(`ASIC_SRAM_ADDR_WIDTH - (`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]}),
                        .D0(lmem_wr_data_sharers),
                        .Q0(lmem_rd_data_sharers_tmp[i][j]),
                        .WE0(wr_en_port[i] & wr_en_sharers_bank[j]),
                        .CE0(lmem_rd_en),
                        .WEM0({16{1'b1}}));
`else
                    sram_behav #(.DATA_WIDTH(16), .NUM_WORDS(512)) sharers_sram(
                        .clk_i(clk),
                        .req_i(lmem_rd_en),
                        .we_i(wr_en_port[i] & wr_en_sharers_bank[j]),
                        .addr_i({{(`ASIC_SRAM_ADDR_WIDTH - (`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]}),
                        .wdata_i(lmem_wr_data_sharers),
                        .be_i({16{1'b1}}),
                        .rdata_o(lmem_rd_data_sharers_tmp[i][j]));
`endif
                end else begin
`ifdef GF12
                    GF12_SRAM_SP_512x16 sharers_sram(
                        .CLK(clk),
                        .A0(lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]),
                        .D0(lmem_wr_data_sharers),
                        .Q0(lmem_rd_data_sharers_tmp[i][j]),
                        .WE0(wr_en_port[i] & wr_en_sharers_bank[j]),
                        .CE0(lmem_rd_en),
                        .WEM0({16{1'b1}}));
`else
                     sram_behav #(.DATA_WIDTH(16), .NUM_WORDS(512)) sharers_sram(
                        .clk_i(clk),
                        .req_i(lmem_rd_en),
                        .we_i(wr_en_port[i] & wr_en_sharers_bank[j]),
                        .addr_i(lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]),
                        .wdata_i(lmem_wr_data_sharers),
                        .be_i({16{1'b1}}),
                        .rdata_o(lmem_rd_data_sharers_tmp[i][j]));
`endif
                end


                //line memory
                //128 bits - using 512x64 SRAM, need 2 SRAMs per line
                for (k = 0; k < `LLC_ASIC_SRAMS_PER_LINE; k++) begin
                    if (`ASIC_SRAM_ADDR_WIDTH > (`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS) + 1) begin
`ifdef GF12
                        GF12_SRAM_SP_512x64 line_sram(
                            .CLK(clk),
                            .A0({{(`ASIC_SRAM_ADDR_WIDTH - (`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                    lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]}),
                            .D0(lmem_wr_data_line[(64*(k+1)-1):(64*k)]),
                            .Q0(lmem_rd_data_line_tmp[i][j][(64*(k+1)-1):(64*k)]),
                            .WE0(wr_en_port[i] & wr_en_line_bank[j]),
                            .CE0(lmem_rd_en),
                            .WEM0({64{1'b1}}));
`else
                        sram_behav #(.DATA_WIDTH(64), .NUM_WORDS(512)) line_sram(
                            .clk_i(clk),
                            .req_i(lmem_rd_en),
                            .we_i(wr_en_port[i] & wr_en_line_bank[j]),
                            .addr_i({{(`ASIC_SRAM_ADDR_WIDTH - (`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS) - 1){1'b0}},
                                    lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]}),
                            .wdata_i(lmem_wr_data_line[(64*(k+1)-1):(64*k)]),
                            .be_i({64{1'b1}}),
                            .rdata_o(lmem_rd_data_line_tmp[i][j][(64*(k+1)-1):(64*k)]));
`endif
                    end else begin
`ifdef GF12
                        GF12_SRAM_SP_512x64 line_sram(
                            .CLK(clk),
                            .A0(lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]),
                            .D0(lmem_wr_data_line[(64*(k+1)-1):(64*k)]),
                            .Q0(lmem_rd_data_line_tmp[i][j][(64*(k+1)-1):(64*k)]),
                            .WE0(wr_en_port[i] & wr_en_line_bank[j]),
                            .CE0(lmem_rd_en),
                            .WEM0({64{1'b1}}));
`else
                        sram_behav #(.DATA_WIDTH(64), .NUM_WORDS(512)) line_sram(
                            .clk_i(clk),
                            .req_i(lmem_rd_en),
                            .we_i(wr_en_port[i] & wr_en_line_bank[j]),
                            .addr_i(lmem_set_in[(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS - 1):0]),
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
        if (`LLC_ASIC_SRAMS_PER_WAY == 1) begin
            always_comb begin
                for (int i = 0; i < `LLC_NUM_PORTS; i++) begin
                    lmem_rd_data_hprot[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_HPROT_INDEX];
                    lmem_rd_data_dirty_bit[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_DIRTY_BIT_INDEX];
                    lmem_rd_data_state[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_STATE_INDEX_HI:`LLC_ASIC_MIXED_SRAM_STATE_INDEX_LO];
                    lmem_rd_data_owner[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_OWNER_INDEX_HI:`LLC_ASIC_MIXED_SRAM_OWNER_INDEX_LO];
                    lmem_rd_data_tag[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_TAG_INDEX_HI:`LLC_ASIC_MIXED_SRAM_TAG_INDEX_LO];
                    lmem_rd_data_line[i] = lmem_rd_data_line_tmp[i][0];
                    lmem_rd_data_sharers[i] = lmem_rd_data_sharers_tmp[i][0];
                end
            end
        end else begin
            always_comb begin
                for (int i = 0; i < `LLC_NUM_PORTS; i++) begin
                    lmem_rd_data_hprot[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_HPROT_INDEX];
                    lmem_rd_data_dirty_bit[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_DIRTY_BIT_INDEX];
                    lmem_rd_data_state[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_STATE_INDEX_HI:`LLC_ASIC_MIXED_SRAM_STATE_INDEX_LO];
                    lmem_rd_data_owner[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_OWNER_INDEX_HI:`LLC_ASIC_MIXED_SRAM_OWNER_INDEX_LO];
                    lmem_rd_data_tag[i] = lmem_rd_data_mixed_tmp[i][0][`LLC_ASIC_MIXED_SRAM_TAG_INDEX_HI:`LLC_ASIC_MIXED_SRAM_TAG_INDEX_LO];
                    lmem_rd_data_line[i] = lmem_rd_data_line_tmp[i][0];
                    lmem_rd_data_sharers[i] = lmem_rd_data_sharers_tmp[i][0];
                    for (int j = 1; j < `LLC_ASIC_SRAMS_PER_WAY; j++) begin
                        if (j == lmem_set_in[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `LLC_ASIC_SRAM_INDEX_BITS)]) begin
                            lmem_rd_data_hprot[i] = lmem_rd_data_mixed_tmp[i][j][`LLC_ASIC_MIXED_SRAM_HPROT_INDEX];
                            lmem_rd_data_dirty_bit[i] = lmem_rd_data_mixed_tmp[i][j][`LLC_ASIC_MIXED_SRAM_DIRTY_BIT_INDEX];
                            lmem_rd_data_state[i] = lmem_rd_data_mixed_tmp[i][j][`LLC_ASIC_MIXED_SRAM_STATE_INDEX_HI:`LLC_ASIC_MIXED_SRAM_STATE_INDEX_LO];
                            lmem_rd_data_owner[i] = lmem_rd_data_mixed_tmp[i][j][`LLC_ASIC_MIXED_SRAM_OWNER_INDEX_HI:`LLC_ASIC_MIXED_SRAM_OWNER_INDEX_LO];
                            lmem_rd_data_tag[i] = lmem_rd_data_mixed_tmp[i][j][`LLC_ASIC_MIXED_SRAM_TAG_INDEX_HI:`LLC_ASIC_MIXED_SRAM_TAG_INDEX_LO];
                            lmem_rd_data_line[i] = lmem_rd_data_line_tmp[i][j];
                            lmem_rd_data_sharers[i] = lmem_rd_data_sharers_tmp[i][j];
                        end
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (int i = 0; i < `LLC_SETS; i++) begin
                evict_way_arr[i] <= {`LLC_WAY_BITS{1'b0}};
            end
        end else begin
            if (lmem_wr_en_evict_way) begin
                evict_way_arr[lmem_set_in] <= lmem_wr_data_evict_way;
            end
            lmem_rd_data_evict_way <= evict_way_arr[lmem_set_in];
        end
    end

endmodule
