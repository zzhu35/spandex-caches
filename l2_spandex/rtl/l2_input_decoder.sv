`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_input_decoder (
    input logic clk,
    input logic rst,
    input logic decode_en,
    // Valid inputs from interfaces
    input logic l2_fence_valid_int,
    input logic l2_rsp_in_valid_int,
    input logic l2_fwd_in_valid_int,
    input logic l2_cpu_req_valid_int,
    `FPGA_DBG input line_addr_t rsp_in_addr,
    `FPGA_DBG input line_addr_t fwd_in_addr,
    `FPGA_DBG input line_addr_t fwd_in_tmp_addr,
    `FPGA_DBG input addr_t cpu_req_addr,
    // To check if new request can be tracked
    input logic [`REQS_BITS_P1-1:0] mshr_cnt,
    // State registers from regs/others
    input logic evict_stall,
    input logic set_conflict,
    input logic fwd_stall,
    input logic fwd_stall_ended,
    `FPGA_DBG input logic ongoing_fence,
    `FPGA_DBG input logic ongoing_drain,
    `FPGA_DBG input logic drain_in_progress,

    // Assign cpu_req from conflict registers
    `FPGA_DBG output logic set_cpu_req_from_conflict,
    // Assign fwd_in from conflict registers
    `FPGA_DBG output logic set_fwd_in_from_stalled,
    // Accept the new input now
    output logic do_fence,
    output logic do_fence_next,
    output logic do_ongoing_fence,
    output logic do_ongoing_fence_next,
    output logic do_rsp,
    output logic do_rsp_next,
    output logic do_fwd,
    output logic do_fwd_next,
    output logic do_cpu_req,
    output logic do_cpu_req_next,
    // Ready signals sent to interfaces
    output logic l2_fence_ready_int,
    output logic l2_rsp_in_ready_int,
    output logic l2_fwd_in_ready_int,
    output logic l2_cpu_req_ready_int,
    // Clear ongoing drain if drain is complete
    `FPGA_DBG output logic clr_ongoing_drain,
    // Line and address breakdowns
    line_breakdown_l2_t.out line_br,
    addr_breakdown_t.out addr_br,
    line_breakdown_l2_t.out line_br_next,
    addr_breakdown_t.out addr_br_next
    );

    always_comb begin
        do_rsp_next = 1'b0;
        do_fwd_next = 1'b0;
        do_cpu_req_next = 1'b0;
        do_fence_next = 1'b0;
        do_ongoing_fence_next = 1'b0;

        l2_rsp_in_ready_int = 1'b0;
        l2_fwd_in_ready_int = 1'b0;
        l2_cpu_req_ready_int = 1'b0;
        l2_fence_ready_int = 1'b0;

        line_br_next.tag = 0;
        line_br_next.set = 0;

        addr_br_next.line = 0;
        addr_br_next.line_addr = 0;
        addr_br_next.word = 0;
        addr_br_next.tag = 0;
        addr_br_next.set = 0;
        addr_br_next.w_off = 0;
        addr_br_next.b_off = 0;
        addr_br_next.line[`OFF_RANGE_HI : `OFF_RANGE_LO ] = 0;
        addr_br_next.word[`B_OFF_RANGE_HI : `B_OFF_RANGE_LO ] = 0;

        set_cpu_req_from_conflict = 1'b0;
        set_fwd_in_from_stalled = 1'b0;

        // Priority:
        // - do_fence_next; unless there is an ongoing fence or drain already.
        // - do_rsp_next; unless the MSHR empty (what is the response for?),
        // - do_fwd_next; either a new forward or a pending forward whose stall just ended.
        // - do_ongoing_fence_next; to service the self-invalidation after drain is complete.
        // - do_cpu_req_next; unless there are no free MSHR entries, an evict stall, an ongoing
        // fence or drain. Either service a new request or the set conflicted request (priority to latter).
        if (decode_en) begin
            if (l2_fence_valid_int && !ongoing_fence && !drain_in_progress) begin
                l2_fence_ready_int = 1'b1;            
                do_fence_next = 1'b1;
            end else if (l2_rsp_in_valid_int && mshr_cnt != `N_MSHR && !(l2_fwd_in_valid_int && (!fwd_stall || fwd_stall_ended) && rsp_in_addr == fwd_in_tmp_addr)) begin
                do_rsp_next = 1'b1;
                l2_rsp_in_ready_int = 1'b1;
            end else if ((l2_fwd_in_valid_int && !fwd_stall) || fwd_stall_ended) begin
                do_fwd_next = 1'b1;
                if (!fwd_stall) begin
                    l2_fwd_in_ready_int = 1'b1;
                end else begin
                    set_fwd_in_from_stalled = 1'b1;
                end
            end else if (ongoing_fence && !drain_in_progress) begin
                do_ongoing_fence_next = 1'b1;
            end else if ((l2_cpu_req_valid_int || set_conflict) && mshr_cnt != 0 && !evict_stall && !ongoing_fence && !drain_in_progress) begin
                do_cpu_req_next = 1'b1;
                if (!set_conflict) begin
                    l2_cpu_req_ready_int = 1'b1;
                end else begin
                    set_cpu_req_from_conflict = 1'b1;
                end
            end
            // Parse line addresses for rsp and fwd as line_br
            if (do_rsp_next) begin
                line_br_next.tag = rsp_in_addr[`ADDR_BITS - `OFFSET_BITS - 1 : `L2_SET_BITS];
                line_br_next.set = rsp_in_addr[`L2_SET_BITS - 1 : 0];
            end else if (do_fwd_next) begin
                line_br_next.tag = fwd_in_addr[`ADDR_BITS - `OFFSET_BITS - 1 : `L2_SET_BITS];
                line_br_next.set = fwd_in_addr[`L2_SET_BITS - 1 : 0];
            end else begin
                line_br_next.tag = 0;
                line_br_next.set = 0;
            end

            // Parse cpu addresses as addr_br
            addr_br_next.line = cpu_req_addr;
            addr_br_next.line_addr = cpu_req_addr[`TAG_RANGE_HI :`SET_RANGE_LO];
            addr_br_next.word = cpu_req_addr;
            addr_br_next.tag = cpu_req_addr[ `TAG_RANGE_HI :`L2_TAG_RANGE_LO];
            addr_br_next.set = cpu_req_addr[`L2_SET_RANGE_HI : `SET_RANGE_LO];
            addr_br_next.w_off = cpu_req_addr[`W_OFF_RANGE_HI : `W_OFF_RANGE_LO];
            addr_br_next.b_off = cpu_req_addr[`B_OFF_RANGE_HI : `B_OFF_RANGE_LO];
            addr_br_next.line[`OFF_RANGE_HI : `OFF_RANGE_LO] = 0;
            addr_br_next.word[`B_OFF_RANGE_HI : `B_OFF_RANGE_LO] = 0;
        end
    end

    // Register all outputs (only breakdowns necessary) in always_comb
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            do_fence <= 0;
            do_ongoing_fence <= 0;
            do_rsp <= 0;
            do_fwd <= 0;
            do_cpu_req <= 0;
            line_br.tag <= 0;
            line_br.set <= 0;
            addr_br.line <= 0;
            addr_br.line_addr <= 0;
            addr_br.word <= 0;
            addr_br.tag <= 0;
            addr_br.set <= 0;
            addr_br.w_off <= 0;
            addr_br.b_off <= 0;
        end else if (decode_en) begin
            do_fence <= do_fence_next;
            do_ongoing_fence <= do_ongoing_fence_next;
            do_rsp <= do_rsp_next;
            do_fwd <= do_fwd_next;
            do_cpu_req <= do_cpu_req_next;
            line_br.tag <= line_br_next.tag;
            line_br.set <= line_br_next.set;
            addr_br.line <= addr_br_next.line;
            addr_br.line_addr <= addr_br_next.line_addr;
            addr_br.word <= addr_br_next.word;
            addr_br.tag <= addr_br_next.tag;
            addr_br.set <= addr_br_next.set;
            addr_br.w_off <= addr_br_next.w_off;
            addr_br.b_off <= addr_br_next.b_off;
        end
    end

    always_comb begin
        clr_ongoing_drain = 1'b0;

        if (!drain_in_progress && ongoing_drain) begin
            clr_ongoing_drain = 1'b1;
        end
    end
endmodule

// module l2_input_decoder (
//     input logic clk,
//     input logic rst,
//     input logic decode_en,
//     input logic l2_flush_valid_int,
//     input logic l2_rsp_in_valid_int,
//     input logic l2_fwd_in_valid_int,
//     input logic l2_cpu_req_valid_int,
//     input logic [`REQS_BITS_P1-1:0] reqs_cnt,
//     input logic fwd_stall,
//     input logic fwd_stall_ended,
//     input logic ongoing_flush,
//     input logic [`L2_SET_BITS:0] flush_set,
//     input logic [`L2_WAY_BITS:0] flush_way,
//     input logic set_conflict,
//     input logic evict_stall,
//     input logic ongoing_atomic,
//     input line_addr_t rsp_in_addr,
//     input line_addr_t fwd_in_addr,
//     input addr_t cpu_req_addr,

//     output logic do_flush,
//     output logic do_rsp,
//     output logic do_fwd,
//     output logic do_ongoing_flush,
//     output logic do_cpu_req,
//     output logic l2_flush_ready_int,
//     output logic l2_rsp_in_ready_int,
//     output logic l2_fwd_in_ready_int,
//     output logic l2_cpu_req_ready_int,
//     output logic set_ongoing_flush,
//     output logic clr_ongoing_flush,
//     output logic set_cpu_req_from_conflict,
//     output logic set_fwd_in_from_stalled,
//     output logic incr_flush_set,
//     output logic clr_flush_set,
//     output logic clr_flush_way,
//     output logic flush_done,
//     output logic idle,
//     output logic do_flush_next,
//     output logic do_rsp_next,
//     output logic do_fwd_next,
//     output logic do_ongoing_flush_next,
//     output logic do_cpu_req_next,

//     line_breakdown_l2_t.out line_br,
//     addr_breakdown_t.out addr_br,
//     line_breakdown_l2_t.out line_br_next,
//     addr_breakdown_t.out addr_br_next
//     );

//     always_comb begin
//         do_flush_next = 1'b0;
//         do_rsp_next = 1'b0;
//         do_fwd_next = 1'b0;
//         do_ongoing_flush_next = 1'b0;
//         do_cpu_req_next = 1'b0;
//         l2_flush_ready_int = 1'b0;
//         l2_rsp_in_ready_int = 1'b0;
//         l2_fwd_in_ready_int = 1'b0;
//         l2_cpu_req_ready_int = 1'b0;
//         set_ongoing_flush = 1'b0;
//         set_fwd_in_from_stalled = 1'b0;
//         incr_flush_set = 1'b0;
//         clr_flush_way = 1'b0;
//         clr_flush_set = 1'b0;
//         clr_ongoing_flush = 1'b0;
//         flush_done = 1'b0;
//         set_cpu_req_from_conflict = 1'b0;
//         idle = 1'b0;
//         line_br_next.tag = 0;
//         line_br_next.set = 0;

//         addr_br_next.line = 0;
//         addr_br_next.line_addr = 0;
//         addr_br_next.word = 0;
//         addr_br_next.tag = 0;
//         addr_br_next.set = 0;
//         addr_br_next.w_off = 0;
//         addr_br_next.b_off = 0;
//         addr_br_next.line[`OFF_RANGE_HI : `OFF_RANGE_LO ] = 0;
//         addr_br_next.word[`B_OFF_RANGE_HI : `B_OFF_RANGE_LO ] = 0;
//         if (decode_en) begin
//             if (l2_flush_valid_int && reqs_cnt == `N_REQS) begin
//                 do_flush_next = 1'b1;
//                 set_ongoing_flush = 1'b1;
//                 l2_flush_ready_int = 1'b1;
//             end else if (l2_rsp_in_valid_int && reqs_cnt != `N_REQS) begin
//                 do_rsp_next = 1'b1;
//                 l2_rsp_in_ready_int = 1'b1;
//             end else if ((l2_fwd_in_valid_int && !fwd_stall) || fwd_stall_ended) begin
//                 do_fwd_next = 1'b1;
//                 if (!fwd_stall) begin
//                     l2_fwd_in_ready_int = 1'b1;
//                 end else begin
//                     set_fwd_in_from_stalled = 1'b1;
//                 end
//             end else if (ongoing_flush) begin
//                 if (flush_set < `L2_SETS) begin
//                     if (!l2_fwd_in_valid_int && reqs_cnt != 0) begin
//                         do_ongoing_flush_next = 1'b1;
//                     end

//                     if (flush_way == `L2_WAYS) begin
//                         incr_flush_set = 1'b1;
//                         clr_flush_way = 1'b1;
//                     end
//                 end else begin
//                     clr_flush_set = 1'b1;
//                     clr_flush_way = 1'b1;
//                     clr_ongoing_flush = 1'b1;
//                     flush_done = 1'b1;
//                 end
//             end else if ((l2_cpu_req_valid_int || set_conflict) && !evict_stall
//                             && (reqs_cnt != 0 || ongoing_atomic) ) begin
//                 do_cpu_req_next = 1'b1;
//                 if (!set_conflict) begin
//                     l2_cpu_req_ready_int = 1'b1;
//                 end else begin
//                     set_cpu_req_from_conflict = 1'b1;
//                 end
//             end else begin
//                 idle = 1'b1;
//             end

//             if (do_rsp_next) begin
//                 line_br_next.tag = rsp_in_addr[`ADDR_BITS - `OFFSET_BITS - 1 : `L2_SET_BITS];
//                 line_br_next.set = rsp_in_addr[`L2_SET_BITS - 1 : 0];
//             end else if (do_fwd_next) begin
//                 line_br_next.tag = fwd_in_addr[`ADDR_BITS - `OFFSET_BITS - 1 : `L2_SET_BITS];
//                 line_br_next.set = fwd_in_addr[`L2_SET_BITS - 1 : 0];
//             end else begin
//                 line_br_next.tag = 0;
//                 line_br_next.set = 0;
//             end

//             addr_br_next.line = cpu_req_addr;
//             addr_br_next.line_addr = cpu_req_addr[`TAG_RANGE_HI :`SET_RANGE_LO ];
//             addr_br_next.word = cpu_req_addr;
//             addr_br_next.tag = cpu_req_addr[ `TAG_RANGE_HI :`L2_TAG_RANGE_LO ];
//             addr_br_next.set = cpu_req_addr[`L2_SET_RANGE_HI : `SET_RANGE_LO ];
//             addr_br_next.w_off = cpu_req_addr[`W_OFF_RANGE_HI : `W_OFF_RANGE_LO ];
//             addr_br_next.b_off = cpu_req_addr[`B_OFF_RANGE_HI : `B_OFF_RANGE_LO ];
//             addr_br_next.line[`OFF_RANGE_HI : `OFF_RANGE_LO ] = 0;
//             addr_br_next.word[`B_OFF_RANGE_HI : `B_OFF_RANGE_LO ] = 0;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             do_flush <= 1'b0;
//             do_rsp <= 1'b0;
//             do_fwd <= 1'b0;
//             do_ongoing_flush <= 1'b0;
//             do_cpu_req <= 1'b0;
//             line_br.tag <= 0;
//             line_br.set <= 0;
//             addr_br.line <= 0;
//             addr_br.line_addr <= 0;
//             addr_br.word <= 0;
//             addr_br.tag <= 0;
//             addr_br.set <= 0;
//             addr_br.w_off <= 0;
//             addr_br.b_off <= 0;
//         end else if (decode_en) begin
//             do_flush <= do_flush_next;
//             do_rsp <= do_rsp_next;
//             do_fwd <= do_fwd_next;
//             do_ongoing_flush <= do_ongoing_flush_next;
//             do_cpu_req <= do_cpu_req_next;
//             line_br.tag <= line_br_next.tag;
//             line_br.set <= line_br_next.set;
//             addr_br.line <= addr_br_next.line;
//             addr_br.line_addr <= addr_br_next.line_addr;
//             addr_br.word <= addr_br_next.word;
//             addr_br.tag <= addr_br_next.tag;
//             addr_br.set <= addr_br_next.set;
//             addr_br.w_off <= addr_br_next.w_off;
//             addr_br.b_off <= addr_br_next.b_off;
//         end
//     end

// endmodule
