`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_input_decoder (
    input logic clk,
    input logic rst,
    input logic decode_en,
    // Valid inputs from interfaces
    `FPGA_DBG input logic llc_rst_tb_valid_int,
    `FPGA_DBG input logic llc_rsp_in_valid_int,
    `FPGA_DBG input logic llc_req_in_valid_int,
    `FPGA_DBG input line_addr_t rsp_in_addr,
    `FPGA_DBG input line_addr_t req_in_addr,
    // To check if new request can be tracked
    `FPGA_DBG input logic [`REQS_BITS_P1-1:0] mshr_cnt,
    // State registers from regs/others
    input logic evict_stall,
    input logic set_conflict,
    input logic ongoing_flush,
    input logic [`LLC_SET_BITS:0] flush_set,
    input logic [`LLC_WAY_BITS:0] flush_way,
    `FPGA_DBG input logic new_bulk_req,
    `FPGA_DBG input addr_t llc_bulk_len_int,
    `FPGA_DBG input addr_t llc_conflict_len_int,
    `FPGA_DBG input addr_t bulk_done,
    `FPGA_DBG input addr_t bulk_nack_counter,
    `FPGA_DBG input logic ongoing_bulk_req,

    // Accept the new input now
    output logic do_get_req,
    output logic do_get_req_next,
    output logic do_get_rsp,
    output logic do_get_rsp_next,
    output logic do_flush,
    output logic do_flush_next,
    output logic do_bulk_req,
    output logic do_bulk_req_next,
    output logic set_ongoing_flush,
    output logic clr_ongoing_flush,
    output logic clr_flush_set,
    output logic clr_flush_way,
    output logic llc_rst_tb_done_valid_int,
    output logic llc_rst_tb_done_o,
    // Ready signals sent to interfaces
    output logic llc_rst_tb_ready_int,
    output logic llc_rsp_in_ready_int,
    output logic llc_req_in_ready_int,
    `FPGA_DBG output logic set_req_from_conflict,
    `FPGA_DBG output logic clr_ongoing_bulk_req,
    `FPGA_DBG output logic set_ongoing_bulk_req,
    `FPGA_DBG output logic clr_bulk_done,
    `FPGA_DBG output logic set_req_from_bulk,
    `FPGA_DBG output logic set_req_bulk,

    line_breakdown_llc_t.out line_br,
    line_breakdown_llc_t.out line_br_next
    );

    always_comb begin
        do_flush_next = 1'b0;
        do_get_req_next = 1'b0;
        do_get_rsp_next = 1'b0;
        do_bulk_req_next = 1'b0;
        llc_rst_tb_ready_int = 1'b0;
        llc_rsp_in_ready_int = 1'b0;
        llc_req_in_ready_int = 1'b0;
        set_req_from_conflict = 1'b0;
        set_ongoing_flush = 1'b0;
        llc_rst_tb_done_o = 1'b0;
        clr_flush_set = 1'b0;
        clr_flush_way = 1'b0;
        clr_ongoing_flush = 1'b0;
        llc_rst_tb_done_valid_int = 1'b0;
        llc_rst_tb_done_o = 1'b0;

        line_br_next.tag = 0;
        line_br_next.set = 0;

        clr_ongoing_bulk_req = 1'b0;
        set_ongoing_bulk_req = 1'b0;
        clr_bulk_done = 1'b0;
        set_req_from_bulk = 1'b0;
        set_req_bulk = 1'b0;

        if (decode_en) begin
            // If a response is ready and there is at least one MSHR entry (you should have at least one),
            // accept the response, and inform FSM 2 to mvoe to the response handler.
            // Else if a new request is ready or if there is an ongoing set conflict, check if there are
            // free entires in the MSHR and that we are not in an eviction stall, then accept one of them -
            // with priority to the set conflicted pending request (backed up in interfaces).
            if (llc_rst_tb_valid_int) begin
                llc_rst_tb_ready_int = 1'b1;
                set_ongoing_flush = 1'b1;
            end else if (ongoing_flush) begin
                if (flush_set < `LLC_SETS) begin
                    do_flush_next = 1'b1;

                    if (flush_way == `LLC_WAYS) begin
                        clr_flush_way = 1'b1;
                    end
                end else begin
                    clr_flush_set = 1'b1;
                    clr_flush_way = 1'b1;
                    clr_ongoing_flush = 1'b1;
                    llc_rst_tb_done_valid_int = 1'b1;
                    llc_rst_tb_done_o = 1'b1;
                end                       
            end else if (llc_rsp_in_valid_int && mshr_cnt != `N_MSHR) begin
                do_get_rsp_next =  1'b1;
                llc_rsp_in_ready_int = 1'b1;
            end else if (((llc_req_in_valid_int && !new_bulk_req) || (set_conflict && llc_conflict_len_int == 'h0)) && mshr_cnt != 0 && !evict_stall) begin
                do_get_req_next = 1'b1;
                if (set_conflict) begin
                    set_req_from_conflict = 1'b1;
                end else if (llc_req_in_valid_int) begin
                    llc_req_in_ready_int = 1'b1;
                end
            end else if (((llc_req_in_valid_int && new_bulk_req && !ongoing_bulk_req) || ongoing_bulk_req || (set_conflict && llc_conflict_len_int != 'h0)) && mshr_cnt != 0 && !evict_stall) begin
                // First check if bulk is done; if done, return without any do_*_req_next
                // If not set do_get_req_next with some additional signal that FSM can identify (not necessary?)
                // and set the req for next address from bulk in interfaces. This should set req_in_addr
                // which sets line_addr below.
                // In FSM, we will go to REQ_V_HANDLER, and respond the same way we do for non bulk requests,
                // however, we need to set invack to 1 based on the new signal we set. Then we return to
                // decode, check if there is a new req/ongoing bulk (need to add this) and if ongoing bulk,
                // we will set the req for the next address and proceed accordinly. In LLC FSM module have one
                // combinational block that keeps track of the bulk done. When bulk done reaches the remaining length,
                // then we will terminate the bulk and clear bulk done.
                // Owned lines: we will send NACKs when there are owned lines of the requestor. This will increment a 
                // NACK counter and also increment the bulk done. If the NACK counter, reaches a threshold, input
                // decoder will terminate the bulk transfer and clear bulk done.
                // L2 will have a similar counter and threshold for NACK and know when the bulk has been terminated.
                // Note that a successful RSP_V must reset the NACK counter.
                if ((bulk_done >= llc_bulk_len_int || bulk_nack_counter == `BULK_NACK_THRESHOLD) && (ongoing_bulk_req)) begin
                    clr_ongoing_bulk_req = 1'b1;
                    clr_bulk_done = 1'b1;
                end else if (ongoing_bulk_req) begin
                    // Bulk response pending
                    set_req_from_bulk = 1'b1;
                    do_bulk_req_next = 1'b1;
                end else if (llc_req_in_valid_int && !ongoing_bulk_req) begin
                    // New bulk transfer
                    do_bulk_req_next = 1'b1;
                    set_ongoing_bulk_req = 1'b1;
                    set_req_bulk = 1'b1;

                    if (set_conflict) begin
                        set_req_from_conflict = 1'b1;
                    end else if (llc_req_in_valid_int) begin
                        llc_req_in_ready_int = 1'b1;
                    end
                end
            end

            // Parse line addresses for rsp and req as line_br - this is used in the FSM 2.
            if (do_get_rsp_next) begin
                line_br_next.tag = rsp_in_addr[`ADDR_BITS - `OFFSET_BITS - 1 : `LLC_SET_BITS];
                line_br_next.set = rsp_in_addr[`LLC_SET_BITS - 1 : 0];
            end else if (do_get_req_next || do_bulk_req_next) begin
                line_br_next.tag = req_in_addr[`ADDR_BITS - `OFFSET_BITS - 1 : `LLC_SET_BITS];
                line_br_next.set = req_in_addr[`LLC_SET_BITS - 1 : 0];
            end else begin
                line_br_next.tag = 0;
                line_br_next.set = 0;
            end
        end
    end


    // Register all outputs (only breakdowns necessary) in always_comb
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            do_get_rsp <= 1'b0;
            do_get_req <= 1'b0;
            do_bulk_req <= 1'b0;
            do_flush <= 1'b0;
            line_br.tag <= 0;
            line_br.set <= 0;
        end else if (decode_en) begin
            do_get_rsp <= do_get_rsp_next;
            do_get_req <= do_get_req_next;
            do_bulk_req <= do_bulk_req_next;
            do_flush <= do_flush_next;
            line_br.tag <= line_br_next.tag;
            line_br.set <= line_br_next.set;
        end
    end
endmodule
