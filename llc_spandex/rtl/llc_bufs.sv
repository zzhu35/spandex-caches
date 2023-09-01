`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_bufs(
    input logic clk,
    input logic rst,
    // Command to read into bufs.
    input logic rd_set_into_bufs,
    // Way to store memory response once received.
    input llc_way_t mem_rsp_way,
    // Update lines buf when mem rsp returns.
    input logic llc_mem_rsp_ready_int,
    input logic llc_mem_rsp_valid_int,
    // Data from localmem
    input line_t lmem_rd_data_line[`LLC_WAYS],
    input llc_tag_t lmem_rd_data_tag[`LLC_WAYS],
    input sharers_t lmem_rd_data_sharers[`LLC_WAYS],
    input owner_t lmem_rd_data_owner[`LLC_WAYS],
    input hprot_t lmem_rd_data_hprot[`LLC_WAYS],
    input llc_way_t lmem_rd_data_evict_way,
    input llc_state_t lmem_rd_data_state[`LLC_WAYS],
    input logic lmem_rd_data_dirty_bit[`LLC_WAYS],

    llc_mem_rsp_t.in llc_mem_rsp_next,

    output llc_way_t evict_way_buf,
    output line_t lines_buf[`LLC_WAYS],
    output llc_tag_t tags_buf[`LLC_WAYS],
    output sharers_t sharers_buf[`LLC_WAYS],
    output owner_t owners_buf[`LLC_WAYS],
    output hprot_t hprots_buf[`LLC_WAYS],
    output llc_state_t states_buf[`LLC_WAYS],
    output logic dirty_bits_buf[`LLC_WAYS]
    );

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            evict_way_buf <= 0;
        end else if (rd_set_into_bufs) begin
            evict_way_buf <= lmem_rd_data_evict_way;
        end
    end

    genvar i;
    generate
        for (i = 0; i < `LLC_WAYS; i++) begin
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    lines_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    lines_buf[i] <= lmem_rd_data_line[i];
                end else if (llc_mem_rsp_ready_int && llc_mem_rsp_valid_int && (mem_rsp_way == i)) begin
                    lines_buf[i] <= llc_mem_rsp_next.line;
                end
            end

            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    tags_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    tags_buf[i] <= lmem_rd_data_tag[i];
                end
            end

            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    sharers_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    sharers_buf[i] <= lmem_rd_data_sharers[i];
                end
            end

            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    owners_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    owners_buf[i] <= lmem_rd_data_owner[i];
                end
            end

            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    hprots_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    hprots_buf[i] <= lmem_rd_data_hprot[i];
                end
            end

            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    dirty_bits_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    dirty_bits_buf[i] <= lmem_rd_data_dirty_bit[i];
                end
            end

            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    states_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    states_buf[i] <= lmem_rd_data_state[i];
                end
            end
        end
    endgenerate

endmodule
