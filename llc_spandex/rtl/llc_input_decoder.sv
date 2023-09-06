`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_input_decoder (
    input logic clk,
    input logic rst,
    input logic decode_en,
    // Valid inputs from interfaces
    input logic llc_rsp_in_valid_int,
    input logic llc_req_in_valid_int,
    `FPGA_DBG input line_addr_t rsp_in_addr,
    `FPGA_DBG input line_addr_t req_in_addr,
    // To check if new request can be tracked
    `FPGA_DBG input logic [`REQS_BITS_P1-1:0] mshr_cnt,
    // State registers from regs/others
    input logic evict_stall,
    input logic set_conflict,

    // Accept the new input now
    output logic do_get_req,
    output logic do_get_req_next,
    output logic do_get_rsp,
    output logic do_get_rsp_next,
    // Ready signals sent to interfaces
    output logic llc_rsp_in_ready_int,
    output logic llc_req_in_ready_int,
    `FPGA_DBG output logic set_req_from_conflict,

    line_breakdown_llc_t.out line_br,
    line_breakdown_llc_t.out line_br_next
    );

    always_comb begin
        do_get_req_next = 1'b0;
        do_get_rsp_next = 1'b0;
        llc_rsp_in_ready_int = 1'b0;
        llc_req_in_ready_int = 1'b0;
        set_req_from_conflict = 1'b0;

        line_br_next.tag = 0;
        line_br_next.set = 0;

        if (decode_en) begin
            // If a response is ready and there is at least one MSHR entry (you should have at least one),
            // accept the response, and inform FSM 2 to mvoe to the response handler.
            // Else if a new request is ready or if there is an ongoing set conflict, check if there are
            // free entires in the MSHR and that we are not in an eviction stall, then accept one of them -
            // with priority to the set conflicted pending request (backed up in interfaces).
            if (llc_rsp_in_valid_int && mshr_cnt != `N_MSHR) begin
                do_get_rsp_next =  1'b1;
                llc_rsp_in_ready_int = 1'b1;
            end else if ((llc_req_in_valid_int || set_conflict) && mshr_cnt != 0 && !evict_stall) begin
                do_get_req_next = 1'b1;
                if (set_conflict) begin
                    set_req_from_conflict = 1'b1;
                end else if (llc_req_in_valid_int) begin
                    llc_req_in_ready_int = 1'b1;
                end
            end

            // Parse line addresses for rsp and req as line_br - this is used in the FSM 2.
            if (do_get_rsp_next) begin
                line_br_next.tag = rsp_in_addr[`ADDR_BITS - `OFFSET_BITS - 1 : `LLC_SET_BITS];
                line_br_next.set = rsp_in_addr[`LLC_SET_BITS - 1 : 0];
            end else if (do_get_req_next) begin
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
            line_br.tag <= 0;
            line_br.set <= 0;
        end else if (decode_en) begin
            do_get_rsp <= do_get_rsp_next;
            do_get_req <= do_get_req_next;
            line_br.tag <= line_br_next.tag;
            line_br.set <= line_br_next.set;
        end
    end
endmodule

// module llc_input_decoder(
//     input logic clk,
//     input logic rst,
//     input logic llc_rst_tb_valid_int,
//     input logic llc_rsp_in_valid_int,
//     input logic llc_req_in_valid_int,
//     input logic llc_dma_req_in_valid_int,
//     input logic recall_pending,
//     input logic recall_valid,
//     input logic dma_read_pending,
//     input logic dma_write_pending,
//     input logic req_pending,
//     input logic flush_stall,
//     input logic rst_stall,
//     input logic req_stall,
//     input logic req_in_stalled_valid,
//     input logic decode_en,
//     input logic rd_set_en,
//     input logic is_dma_read_to_resume,
//     input logic is_dma_write_to_resume,
//     input line_addr_t rsp_in_addr,
//     input line_addr_t req_in_addr,
//     input line_addr_t dma_req_in_addr,
//     input line_addr_t req_in_recall_addr,
//     input llc_set_t rst_flush_stalled_set,
//     input llc_set_t req_in_stalled_set,
//     input llc_tag_t req_in_stalled_tag,
//     input addr_t dma_addr,

//     output logic update_req_in_from_stalled,
//     output logic clr_req_in_stalled_valid,
//     output logic look,
//     output logic is_rst_to_resume,
//     output logic is_flush_to_resume,
//     output logic set_is_dma_read_to_resume_decoder,
//     output logic set_is_dma_write_to_resume_decoder,
//     output logic clr_is_dma_read_to_resume,
//     output logic clr_is_dma_write_to_resume,
//     output logic is_rst_to_get,
//     output logic is_rsp_to_get,
//     output logic is_req_to_get,
//     output logic is_dma_req_to_get,
//     output logic is_req_to_resume,
//     output logic is_rst_to_get_next,
//     output logic is_rsp_to_get_next,
//     output logic do_get_req,
//     output logic do_get_dma_req,
//     output logic clr_rst_stall,
//     output logic clr_flush_stall,
//     output logic clr_req_stall_decoder,
//     output logic update_dma_addr_from_req,
//     output logic idle,
//     output logic idle_next,
//     output llc_set_t set,
//     output llc_set_t set_next,

//     line_breakdown_llc_t.out line_br
//     );

//     logic can_get_rst_tb, can_get_rsp_in, can_get_req_in, can_get_dma_req_in;
//     assign can_get_rst_tb = llc_rst_tb_valid_int;
//     assign can_get_rsp_in = llc_rsp_in_valid_int;
//     assign can_get_req_in = llc_req_in_valid_int;
//     assign can_get_dma_req_in = llc_dma_req_in_valid_int;

//     logic is_rst_to_resume_next, is_flush_to_resume_next, is_req_to_resume_next;
//     logic is_req_to_get_next, is_dma_req_to_get_next;

//     line_addr_t addr_for_set;
//     line_breakdown_llc_t line_br_next();

//     always_comb begin
//         is_rst_to_resume_next =  1'b0;
//         is_flush_to_resume_next = 1'b0;
//         is_req_to_resume_next = 1'b0;
//         is_rst_to_get_next = 1'b0;
//         is_rsp_to_get_next = 1'b0;
//         is_req_to_get_next = 1'b0;
//         is_dma_req_to_get_next =  1'b0;
//         set_is_dma_read_to_resume_decoder = 1'b0;
//         set_is_dma_write_to_resume_decoder = 1'b0;
//         clr_is_dma_read_to_resume = 1'b0;
//         clr_is_dma_write_to_resume = 1'b0;
//         update_req_in_from_stalled = 1'b0;
//         clr_req_in_stalled_valid = 1'b0;
//         do_get_req = 1'b0;
//         do_get_dma_req = 1'b0;
//         idle_next = 1'b0;
//         if (decode_en) begin
//             clr_is_dma_read_to_resume = 1'b1;
//             clr_is_dma_write_to_resume = 1'b1;
//             if (recall_pending) begin
//                 if(!recall_valid) begin
//                     if(can_get_rsp_in) begin
//                         is_rsp_to_get_next = 1'b1;
//                     end
//                 end else begin
//                     if (req_pending) begin
//                         is_req_to_resume_next = 1'b1;
//                     end else if (dma_read_pending) begin
//                         clr_is_dma_read_to_resume = 1'b0;
//                         set_is_dma_read_to_resume_decoder = 1'b1;
//                     end else if (dma_write_pending) begin
//                         clr_is_dma_write_to_resume = 1'b0;
//                         set_is_dma_write_to_resume_decoder = 1'b1;
//                     end
//                 end
//             end else if (rst_stall) begin
//                 is_rst_to_resume_next = 1'b1;
//             end else if (flush_stall) begin
//                 is_flush_to_resume_next = 1'b1;
//             end else if (can_get_rst_tb && !dma_read_pending && !dma_write_pending) begin
//                 is_rst_to_get_next = 1'b1;
//             end else if (can_get_rsp_in) begin
//                 is_rsp_to_get_next =  1'b1;
//             end else if ((can_get_req_in &&  !req_stall)  ||  (!req_stall  && req_in_stalled_valid)) begin
//                 if (req_in_stalled_valid) begin
//                     clr_req_in_stalled_valid = 1'b1;
//                     update_req_in_from_stalled = 1'b1;
//                 end else begin
//                     do_get_req = 1'b1;
//                 end
//                 is_req_to_get_next = 1'b1;
//             end else if (dma_read_pending) begin
//                 set_is_dma_read_to_resume_decoder = 1'b1;
//                 clr_is_dma_read_to_resume = 1'b0;
//             end else if (dma_write_pending) begin
//                 if (can_get_dma_req_in) begin
//                     set_is_dma_write_to_resume_decoder = 1'b1;
//                     clr_is_dma_write_to_resume = 1'b0;
//                     do_get_dma_req = 1'b1;
//                 end
//             end else if (can_get_dma_req_in && !req_stall) begin
//                 is_dma_req_to_get_next = 1'b1;
//                 do_get_dma_req = 1'b1;
//             end else begin
//                 idle_next = 1'b1;
//             end
//         end
//     end

//     //flop outputs
//     always_ff@(posedge clk or negedge rst) begin
//         if (!rst) begin
//             idle <= 1'b0;
//             is_rst_to_resume <= 1'b0;
//             is_flush_to_resume <= 1'b0;
//             is_req_to_resume <= 1'b0;
//             is_rst_to_get <= 1'b0;
//             is_req_to_get <= 1'b0;
//             is_rsp_to_get <= 1'b0;
//             is_dma_req_to_get <= 1'b0;
//         end else if (decode_en) begin
//             idle <= idle_next;
//             is_rst_to_resume <= is_rst_to_resume_next;
//             is_flush_to_resume <= is_flush_to_resume_next;
//             is_req_to_resume <= is_req_to_resume_next;
//             is_rst_to_get <= is_rst_to_get_next;
//             is_req_to_get <= is_req_to_get_next;
//             is_rsp_to_get <= is_rsp_to_get_next;
//             is_dma_req_to_get <= is_dma_req_to_get_next;
//         end
//     end

//     always_comb begin
//         update_dma_addr_from_req = 1'b0;
//         clr_rst_stall = 1'b0;
//         clr_flush_stall = 1'b0;
//         clr_req_stall_decoder = 1'b0;
//         line_br_next.set = 0;
//         line_br_next.tag = 0;
//         addr_for_set = {`LINE_ADDR_BITS{1'b0}};
//         if (rd_set_en) begin
//             if (is_rsp_to_get) begin
//                 addr_for_set = rsp_in_addr;
//             end else if (is_req_to_get) begin
//                 addr_for_set = req_in_addr;
//             end else if (is_dma_req_to_get  || is_dma_read_to_resume || is_dma_write_to_resume) begin
//                 addr_for_set = is_dma_req_to_get ? dma_req_in_addr : dma_addr;
//                 if (is_dma_req_to_get) begin
//                     update_dma_addr_from_req = 1'b1;
//                 end
//             end else if (is_req_to_resume) begin
//                 addr_for_set = req_in_recall_addr;
//             end

//             line_br_next.tag = addr_for_set[(`ADDR_BITS - `OFFSET_BITS -1): `LLC_SET_BITS];
//             line_br_next.set = addr_for_set[(`LLC_SET_BITS - 1):0];

//             if (is_flush_to_resume || is_rst_to_resume) begin
//                 if (rst_flush_stalled_set == {`LLC_SET_BITS{1'b1}}) begin
//                     clr_rst_stall  =  1'b1;
//                     clr_flush_stall = 1'b1;
//                 end
//             end else if (is_rsp_to_get) begin
//                 if ((req_stall == 1'b1)
//                     && (line_br_next.tag  == req_in_stalled_tag)
//                     && (line_br_next.set == req_in_stalled_set)) begin
//                     clr_req_stall_decoder = 1'b1;
//                 end
//             end
//         end
//     end

//     //flop outputs
//     always_ff@(posedge clk or negedge rst) begin
//         if (!rst) begin
//             line_br.tag <= 0;
//             line_br.set <= 0;
//         end else if (rd_set_en) begin
//             line_br.tag <= line_br_next.tag;
//             line_br.set <= line_br_next.set;
//         end
//     end

//     assign look =  is_flush_to_resume | is_rsp_to_get |
//                    is_req_to_get | is_dma_req_to_get |
//                    (is_dma_read_to_resume & ~recall_pending) |
//                    (is_dma_write_to_resume & ~recall_pending);

//     assign set_next = (is_flush_to_resume | is_rst_to_resume) ? rst_flush_stalled_set : line_br_next.set;
//     assign set = (is_flush_to_resume | is_rst_to_resume) ? rst_flush_stalled_set : line_br.set;

// endmodule
