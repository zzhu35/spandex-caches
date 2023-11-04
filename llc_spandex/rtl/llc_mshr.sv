`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_mshr(
    input logic clk,
    input logic rst,
    input logic add_mshr_entry,
    // Update parts of an MSHR entry.
    input logic update_mshr_tag,
    input logic update_mshr_way,
    input logic update_mshr_state,
    input logic update_mshr_invack_cnt,
    input logic update_mshr_line,
    input logic update_mshr_word_mask,
    // Function of the MSHR to perform
    input logic [2:0] mshr_op_code,
    input logic incr_mshr_cnt,
    // Values to update an MSHR entry.
    input mix_msg_t update_mshr_value_msg,
    input cache_id_t update_mshr_value_req_id,
    input llc_tag_t update_mshr_value_tag,
    input llc_way_t update_mshr_value_way,
    input unstable_state_t update_mshr_value_state,
    input hprot_t update_mshr_value_hprot,
    input invack_cnt_calc_t update_mshr_value_invack_cnt,
    input line_t update_mshr_value_line,
    input word_mask_t update_mshr_value_word_mask,
    input word_mask_t update_mshr_value_word_mask_reg,

    line_breakdown_llc_t.in line_br,
    // Triggers to set/clr global registers
    output logic set_set_conflict_mshr,
    output logic clr_set_conflict_mshr,
    // Signals indicating whether there was a hit and the index for hit.
    output logic mshr_hit_next,
    output logic mshr_hit,
    output logic [`MSHR_BITS-1:0] mshr_i_next,
    output logic [`MSHR_BITS-1:0] mshr_i,
    // All MSHR entries
    output mshr_llc_buf_t mshr[`N_MSHR]
    );

    // Generate logic for all MSHR entries
    genvar i;
    generate
        for (i = 0; i < `N_MSHR; i++) begin
            // Update all parts of MSHR entry when adding
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].msg <= 0;
                    mshr[i].req_id <= 0;
                    mshr[i].set <= 0;
                    mshr[i].way <= 0;
                    mshr[i].hprot <= 0;
                    mshr[i].word_mask_reg <= 0;
                end else if (add_mshr_entry) begin
                    if (mshr_i == i) begin
                        mshr[i].msg <= update_mshr_value_msg;
                        mshr[i].req_id <= update_mshr_value_req_id;
                        mshr[i].set <= line_br.set;
                        mshr[i].way <= update_mshr_value_way;
                        mshr[i].hprot <= update_mshr_value_hprot;
                        mshr[i].word_mask_reg <= update_mshr_value_word_mask_reg;
                    end
                end
            end

            // Update only state of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].state <= 0;
                end else if (update_mshr_state || add_mshr_entry) begin
                    if (mshr_i == i) begin
                        mshr[i].state <= update_mshr_value_state;
                    end
                end
            end

            // Update only line of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].line <= 0;
                end else if (update_mshr_line || add_mshr_entry) begin
                    if (mshr_i == i) begin
                        mshr[i].line <= update_mshr_value_line;
                    end
                end
            end

            // Update only tag of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].tag <= 0;
                end else if (update_mshr_tag || add_mshr_entry) begin
                    if (mshr_i == i) begin
                        mshr[i].tag <= update_mshr_value_tag;
                    end
                end
            end

            // Update only word_mask of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].word_mask <= 0;
                end else if (update_mshr_word_mask || add_mshr_entry) begin
                    if (mshr_i == i) begin
                        mshr[i].word_mask <= update_mshr_value_word_mask;
                    end
                end
            end

            // Update only invack_cnt of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].invack_cnt <= 0;
                end else if (update_mshr_invack_cnt || add_mshr_entry) begin
                    if (mshr_i == i) begin
                        mshr[i].invack_cnt <= update_mshr_value_invack_cnt;
                    end
                end
            end
        end
    endgenerate

    always_comb begin
        mshr_i_next = 0;
        mshr_hit_next = 1'b0;
        clr_set_conflict_mshr = 1'b0;
        set_set_conflict_mshr = 1'b0;

        // Different MSHR-specific actions from L2 FSM
        case(mshr_op_code)
            // Check if there is a matching MSHR entry for the incoming response.
            `LLC_MSHR_LOOKUP : begin
                for (int i = 0; i < `N_MSHR; i++) begin
                    if (mshr[i].tag == line_br.tag && mshr[i].set == line_br.set && mshr[i].state != `LLC_I) begin
                        mshr_hit_next = 1'b1;
                        mshr_i_next = i;
                    end
                end
            end
            // Check if there is a conflicting entry to incoming request. If yes, stall.
            `LLC_MSHR_PEEK_REQ : begin
                clr_set_conflict_mshr = 1'b1;

                for (int i = 0; i < `N_MSHR; i++) begin
                    if (mshr[i].state == `LLC_I) begin
                        mshr_i_next = i;
                    end

                    // If the incoming request matches with an entry in the MSHR,
                    // assert set_conflict (which is sampled in l2_core).
                    if (mshr[i].set == line_br.set && mshr[i].state != `LLC_I) begin
                        set_set_conflict_mshr = 1'b1;
                        clr_set_conflict_mshr = 1'b0;
                    end
                end
            end
            default : begin
                mshr_hit_next = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            mshr_i <= 0;
            mshr_hit <= 0;
        end else if (mshr_op_code != `LLC_MSHR_IDLE) begin
            mshr_i <= mshr_i_next;
            mshr_hit <= mshr_hit_next;
        end
    end

endmodule

// // Copyright (c) 2011-2022 Columbia University, System Level Design Group
// // SPDC-License-Identifier: Apache-2.0

// `timescale 1ps / 1ps
// `include "spandex_consts.svh"
// `include "spandex_types.svh"

// // l2_reqs.sv
// // Author: Joseph Zuckerman
// // request buffer for l2

// module l2_reqs(
//     input logic clk,
//     input logic rst,
//     input logic fill_reqs,
//     input logic fill_reqs_flush,
//     input logic wr_req_state,
//     input logic wr_req_state_atomic,
//     input logic wr_req_line,
//     input logic wr_req_invack_cnt,
//     input logic wr_req_tag,
//     input logic wr_req_word_mask,
//     input logic [2:0] reqs_op_code,
//     input logic [`REQS_BITS-1:0] reqs_atomic_i,
//     input cpu_msg_t cpu_msg_wr_data_req,
//     input hprot_t hprot_wr_data_req,
//     input hsize_t hsize_wr_data_req,
//     input invack_cnt_calc_t invack_cnt_wr_data_req,
//     input l2_tag_t tag_estall_wr_data_req,
//     input l2_tag_t tag_wr_data_req,
//     input l2_way_t way_wr_data_req,
//     input line_t line_wr_data_req,
//     input mix_msg_t fwd_in_coh_msg,
//     input unstable_state_t state_wr_data_req,
//     input word_t word_wr_data_req,
//     input amo_t  amo_wr_data_req,
//     input word_mask_t word_mask_wr_data_req,

//     addr_breakdown_t.in addr_br,
//     addr_breakdown_t.in addr_br_reqs,
//     line_breakdown_l2_t.in line_br,

//     output logic set_set_conflict_reqs,
//     output logic clr_set_conflict_reqs,
//     output logic reqs_hit,
//     output logic reqs_hit_next,
//     output logic set_fwd_stall,
//     output logic clr_fwd_stall,
//     output logic set_fwd_stall_i,
//     output logic [`REQS_BITS-1:0] reqs_i_next,
//     output logic [`REQS_BITS-1:0] fwd_stall_i_wr_data,
//     output logic [`REQS_BITS-1:0] reqs_i,
//     output reqs_buf_t reqs[`N_REQS]
//     );

//     genvar i;
//     generate
//         for (i = 0; i < `N_REQS; i++) begin
//             always_ff @(posedge clk or negedge rst) begin
//                 if (!rst) begin
//                     reqs[i].cpu_msg <= 0;
//                     reqs[i].tag_estall <= 0;
//                     reqs[i].set <= 0;
//                     reqs[i].way <= 0;
//                     reqs[i].hsize <= 0;
//                     reqs[i].w_off <= 0;
//                     reqs[i].b_off <= 0;
//                     reqs[i].hprot <= 0;
//                     reqs[i].word <= 0;
//                     reqs[i].amo <= 0;
//                 end else if (fill_reqs) begin
//                     if (reqs_i == i) begin
//                         reqs[i].cpu_msg <= cpu_msg_wr_data_req;
//                         reqs[i].tag_estall <= tag_estall_wr_data_req;
//                         reqs[i].set <= addr_br.set;
//                         reqs[i].way <= way_wr_data_req;
//                         reqs[i].hsize <= hsize_wr_data_req;
//                         reqs[i].w_off <= addr_br.w_off;
//                         reqs[i].b_off <= addr_br.b_off;
//                         reqs[i].hprot <= hprot_wr_data_req;
//                         reqs[i].word <= word_wr_data_req;
//                         reqs[i].amo <= amo_wr_data_req;
//                     end
//                 end else if (fill_reqs_flush) begin
//                     if (reqs_i == i) begin
//                         reqs[i].cpu_msg <= cpu_msg_wr_data_req;
//                         reqs[i].tag_estall <= tag_estall_wr_data_req;
//                         reqs[i].set <= addr_br_reqs.set;
//                         reqs[i].way <= way_wr_data_req;
//                         reqs[i].hsize <= hsize_wr_data_req;
//                         reqs[i].w_off <= addr_br_reqs.w_off;
//                         reqs[i].b_off <= addr_br_reqs.b_off;
//                         reqs[i].hprot <= hprot_wr_data_req;
//                         reqs[i].word <= word_wr_data_req;
//                         reqs[i].amo <= amo_wr_data_req;
//                     end
//                 end
//             end

//             //state
//             always_ff @(posedge clk or negedge rst) begin
//                 if (!rst) begin
//                     reqs[i].state <= 0;
//                 end else if (wr_req_state_atomic) begin
//                     if (reqs_atomic_i == i) begin
//                         reqs[i].state <= state_wr_data_req;
//                     end
//                 end else if (wr_req_state || fill_reqs || fill_reqs_flush) begin
//                     if (reqs_i == i) begin
//                         reqs[i].state <= state_wr_data_req;
//                     end
//                 end
//             end

//             //line
//             always_ff @(posedge clk or negedge rst) begin
//                 if (!rst) begin
//                     reqs[i].line <= 0;
//                 end else if (wr_req_line || fill_reqs || fill_reqs_flush) begin
//                     if (reqs_i == i) begin
//                         reqs[i].line <= line_wr_data_req;
//                     end
//                 end
//             end

//             //invack_cnt
//             always_ff @(posedge clk or negedge rst) begin
//                 if (!rst) begin
//                     reqs[i].invack_cnt <= 0;
//                 end else if (fill_reqs || fill_reqs_flush) begin
//                     if (reqs_i == i) begin
//                         reqs[i].invack_cnt <= `MAX_N_L2;
//                     end
//                 end else if (wr_req_invack_cnt) begin
//                     if (reqs_i == i) begin
//                         reqs[i].invack_cnt <= invack_cnt_wr_data_req;
//                     end
//                 end
//             end

//             //tag
//             always_ff @(posedge clk or negedge rst) begin
//                 if (!rst) begin
//                     reqs[i].tag <= 0;
//                 end else if (fill_reqs) begin
//                     if (reqs_i == i) begin
//                         reqs[i].tag <= tag_wr_data_req;
//                     end
//                 end else if (fill_reqs_flush) begin
//                     if (reqs_i == i) begin
//                         reqs[i].tag <= addr_br_reqs.tag;
//                     end
//                 end else if (wr_req_tag) begin
//                     if (reqs_i == i) begin
//                         reqs[i].tag <= tag_wr_data_req;
//                     end
//                 end
//             end

//             // word_mask
//             always_ff @(posedge clk or negedge rst) begin
//                 if (!rst) begin
//                     reqs[i].word_mask <= 0;
//                 end else if (wr_req_word_mask) begin
//                     if (reqs_i == i) begin
//                         reqs[i].word_mask <= word_mask_wr_data_req;
//                     end
//                 end
//             end
//         end
//     endgenerate

//     always_comb begin
//         clr_set_conflict_reqs = 1'b0;
//         set_set_conflict_reqs = 1'b0;
//         clr_fwd_stall = 1'b0;
//         set_fwd_stall = 1'b0;
//         reqs_i_next = 0;
//         reqs_hit_next = 1'b0;
//         fwd_stall_i_wr_data = 0;
//         set_fwd_stall_i = 1'b0;
//         case(reqs_op_code)
//             `L2_REQS_LOOKUP : begin
//                 for (int i = 0; i < `N_REQS; i++) begin
//                     if (reqs[i].tag == line_br.tag && reqs[i].set == line_br.set && reqs[i].state != `INVALID) begin
//                         reqs_hit_next = 1'b1;
//                         reqs_i_next = i;
//                     end
//                 end
//             end
//             `L2_REQS_PEEK_REQ : begin
//                 clr_set_conflict_reqs = 1'b1;
//                 for (int i = 0; i < `N_REQS; i++) begin
//                     if (reqs[i].state == `INVALID) begin
//                         reqs_i_next = i;
//                     end

//                     if (reqs[i].set == addr_br.set && reqs[i].state != `INVALID) begin
//                         set_set_conflict_reqs = 1'b1;
//                         clr_set_conflict_reqs = 1'b0;
//                     end
//                 end
//             end
//             `L2_REQS_PEEK_FLUSH : begin
//                 for (int i = 0; i <`N_REQS; i++) begin
//                     if (reqs[i].state == `INVALID) begin
//                         reqs_i_next = i;
//                     end
//                 end
//             end
//             `L2_REQS_PEEK_FWD : begin
//                 clr_fwd_stall = 1'b1;
//                 for (int i = 0; i < `N_REQS; i++) begin
//                     if (reqs[i].state != `INVALID && reqs[i].tag == line_br.tag && reqs[i].set == line_br.set) begin
//                         reqs_hit_next = 1'b1;
//                         reqs_i_next = i;

//                         set_fwd_stall = 1'b1;
//                         clr_fwd_stall = 1'b0;
//                         if (fwd_in_coh_msg == `FWD_INV || fwd_in_coh_msg == `FWD_INV_LLC) begin
//                             if (reqs[i].state != `ISD) begin
//                                 set_fwd_stall = 1'b0;
//                                 clr_fwd_stall = 1'b1;
//                             end
//                         end else begin
//                             if (reqs[i].state == `MIA) begin
//                                 set_fwd_stall = 1'b0;
//                                 clr_fwd_stall = 1'b1;
//                             end
//                         end
//                     end
//                 end
//                 set_fwd_stall_i = 1'b1;
//                 fwd_stall_i_wr_data = reqs_i_next;
//             end
//             default : begin
//                 reqs_hit_next = 1'b0;
//             end
//         endcase
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             reqs_i <= 0;
//             reqs_hit <= 1'b0;
//         end else if (reqs_op_code != `L2_REQS_IDLE) begin
//             reqs_i <= reqs_i_next;
//             reqs_hit <= reqs_hit_next;
//         end
//     end

// endmodule
