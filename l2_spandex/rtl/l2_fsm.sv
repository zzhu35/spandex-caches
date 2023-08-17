// Copyright (c) 2011-2022 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_fsm(
    input logic clk,
    input logic rst,
    input logic do_flush_next,
    input logic do_rsp_next,
    input logic do_fwd_next,
    input logic do_ongoing_flush_next,
    input logic do_cpu_req_next,
    input logic is_flush_all,
    input logic l2_rd_rsp_ready_int,
    input logic l2_req_out_ready_int,
    input logic l2_rsp_out_ready_int,
    input logic l2_inval_ready_int,
    input logic l2_bresp_ready_int,
    input logic fwd_stall,
    input logic evict_stall,
    input logic ongoing_flush,
    input logic set_fwd_stall,
    input logic clr_fwd_stall,
    input logic reqs_hit,
    input logic reqs_hit_next,
    input logic set_conflict,
    input logic set_set_conflict_reqs,
    input logic ongoing_atomic,
    input logic clr_set_conflict_reqs,
    input logic tag_hit_next,
    input logic empty_way_found_next,
    input logic tag_hit,
    input logic incr_flush_set,
    input var logic [`REQS_BITS-1:0] reqs_i,
    input var logic [`REQS_BITS-1:0] reqs_i_next,
    input var logic [`L2_SET_BITS:0] flush_set,
    input var logic [`L2_WAY_BITS:0] flush_way,
    input l2_way_t way_hit,
    input l2_way_t empty_way,
    input l2_way_t evict_way_buf,
    input l2_way_t way_hit_next,
    input line_t line_out,
    input var reqs_buf_t reqs[`N_REQS],
    input var state_t states_buf[`L2_WAYS],
    input var hprot_t hprots_buf[`L2_WAYS],
    input var state_t rd_data_state[`L2_NUM_PORTS],
    input var hprot_t rd_data_hprot[`L2_NUM_PORTS],
    input var line_t lines_buf[`L2_WAYS],
    input var l2_tag_t tags_buf[`L2_WAYS],
    input word_mask_t word_mask_shared,
    input word_mask_t word_mask_owned,

    line_breakdown_l2_t.in line_br,
    line_breakdown_l2_t.in line_br_next,
    addr_breakdown_t.in addr_br,
    addr_breakdown_t.in addr_br_next,
    l2_rsp_in_t.in l2_rsp_in,
    l2_fwd_in_t.in l2_fwd_in,
    l2_cpu_req_t.in l2_cpu_req,

    output logic decode_en,
    output logic lookup_en,
    output logic rd_mem_en,
    output logic lookup_mode,
    output logic wr_rst,
    output logic wr_en_state,
    output logic fill_reqs,
    output logic wr_en_line,
    output logic wr_req_state,
    output logic wr_req_state_atomic,
    output logic wr_req_invack_cnt,
    output logic wr_req_line,
    output logic wr_en_put_reqs,
    output logic wr_req_tag,
    output logic wr_req_word_mask,
    output logic put_reqs_atomic,
    output logic wr_en_evict_way,
    output logic l2_rd_rsp_valid_int,
    output logic l2_req_out_valid_int,
    output logic l2_rsp_out_valid_int,
    output logic l2_inval_valid_int,
    output logic l2_bresp_valid_int,
    output logic incr_reqs_cnt,
    output logic set_ongoing_atomic,
    output logic incr_flush_way,
    output logic clr_evict_stall,
    output logic set_fwd_in_stalled,
    output logic clr_fwd_stall_ended,
    output logic set_set_conflict_fsm,
    output logic clr_set_conflict_fsm,
    output logic set_cpu_req_conflict,
    output logic clr_ongoing_atomic,
    output logic fill_reqs_flush,
    output logic set_evict_stall,
    output logic lr_to_xmw,
    output logic [2:0] reqs_op_code,
    output logic[`REQS_BITS-1:0]  reqs_atomic_i,
    output state_t wr_data_state,
    output unstable_state_t state_wr_data_req,
    output line_t wr_data_line,
    output line_t line_wr_data_req,
    output hprot_t wr_data_hprot,
    output hprot_t hprot_wr_data_req,
    output l2_tag_t wr_data_tag,
    output l2_tag_t tag_estall_wr_data_req,
    output l2_tag_t tag_wr_data_req,
    output invack_cnt_calc_t invack_cnt_wr_data_req,
    output hsize_t hsize_wr_data_req,
    output word_t word_wr_data_req,
    output cpu_msg_t cpu_msg_wr_data_req,
    output amo_t amo_wr_data_req,
    output word_mask_t word_mask_wr_data_req,
    output l2_set_t set_in,
    output l2_way_t way,
    output l2_way_t way_wr_data_req,
    output l2_way_t wr_data_evict_way,
    output bresp_t l2_bresp_o,
    output word_t word_in,
    output word_offset_t w_off_in,
    output byte_offset_t b_off_in,
    output hsize_t hsize_in,
    output line_t line_in,

    addr_breakdown_t.out addr_br_reqs,
    l2_rd_rsp_t.out l2_rd_rsp_o,
    l2_rsp_out_t.out l2_rsp_out_o,
    l2_req_out_t.out l2_req_out_o,
    l2_inval_t.out l2_inval_o

`ifdef STATS_ENABLE
    , input logic l2_stats_ready_int
    , output logic l2_stats_o
    , output logic l2_stats_valid_int
`endif
   );

    localparam RESET = 5'b00000;
    localparam DECODE = 5'b00001;

    localparam RSP_LOOKUP = 5'b00010;
    localparam RSP_O_HANDLER = 5'b00011;
    localparam RSP_S_HANDLER = 5'b00100;

    localparam FWD_REQS_LOOKUP = 5'b01000;
    localparam FWD_TAG_LOOKUP = 5'b01001;
    localparam FWD_STALL = 5'b01010;
    localparam FWD_HIT = 5'b01011;
    localparam FWD_HIT_2 = 5'b01100;
    localparam FWD_NO_HIT = 5'b01101;
    localparam FWD_NO_HIT_2 = 5'b01110;

    localparam ONGOING_FLUSH_LOOKUP = 5'b01111;
    localparam ONGOING_FLUSH_PROCESS = 5'b10000;
    
    localparam CPU_REQ_REQS_LOOKUP = 5'b10001;
    localparam CPU_REQ_READ_NO_REQ = 5'b10010;
    localparam CPU_REQ_READ_REQ = 5'b10011;
    localparam CPU_REQ_WRITE_NOREQ = 5'b10100;
    localparam CPU_REQ_WRITE_REQ = 5'b10101;
    localparam CPU_REQ_TAG_LOOKUP = 5'b10110;
    localparam CPU_REQ_EMPTY_WAY = 5'b11010;
    localparam CPU_REQ_EVICT = 5'b11011;

    logic [4:0] state, next_state;
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= RESET;
        end else begin
            state <= next_state;
        end
    end

    logic rst_en;
    assign rst_en = (state == RESET);
    assign decode_en = (state == DECODE);

    l2_set_t rst_set;
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            rst_set <= 0;
        end else if (rst_en) begin
            rst_set <= rst_set + 1;
        end
    end

    logic update_atomic;
    line_addr_t atomic_line_addr;
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            atomic_line_addr <= 0;
        end else if (update_atomic) begin
            atomic_line_addr <= addr_br.line_addr;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            reqs_atomic_i <= 0;
        end else if (update_atomic) begin
            reqs_atomic_i <= reqs_i;
        end
    end

    logic[1:0] ready_bits;
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            ready_bits <= 0;
        end else if (state == DECODE) begin
            ready_bits <= 0;
        end else if ((state == CPU_REQ_EVICT || state == FWD_NO_HIT || state == FWD_HIT) && l2_inval_ready_int) begin
            ready_bits[0] <= 1'b1;
        end else if ((state == CPU_REQ_EVICT && l2_req_out_ready_int) || ((state == FWD_NO_HIT || state == FWD_HIT) && l2_rsp_out_ready_int)) begin
            ready_bits[1] <= 1'b1;
        end
    end

    l2_way_t evict_way_tmp;

    // FSM 1
    // Decide which state to go to next;
    // no outputs updated.
    always_comb begin
        next_state = state;
        case (state)
            RESET : begin
                if (rst_set == `L2_SETS - 1) begin
                    next_state = DECODE;
                end
            end
            // Default state for the controller; driven
            // by inputs from input_decoder module.
            // - do_flush_next: New flush request received
            // - do_rsp_next: Response to earlier req_out/fwd_out received
            // - do_fwd_next: Forward received from other L2/LLC
            // - do_ongoing_flush_next: Continue next set of ongoing flush
            // - do_cpu_req_next: New input request received
            // TODO: add fences
            DECODE : begin
                if (do_flush_next) begin
                    next_state = DECODE;
                end else if (do_rsp_next) begin
                    next_state = RSP_LOOKUP;
                end else if (do_fwd_next) begin
                    next_state = FWD_REQS_LOOKUP;
                end else if (do_ongoing_flush_next) begin
                    next_state = ONGOING_FLUSH_LOOKUP;
                end else if (do_cpu_req_next) begin
                    next_state = CPU_REQ_REQS_LOOKUP;
                end
            end
            // If new response received, lookup the coherence message
            // of the response.
            RSP_LOOKUP : begin
                // TODO: Should we update the word_mask in reqs[reqs_i] here?
                // Maybe, we should update word_mask here, and only transition to
                // the handler that finally removes the MSHR entry and/or updates
                // data into the RAMs.
                // TODO: Don't we need to check if the response matches
                // an entry in the MSHR? FSM 2 does do a L2_REQS_LOOKUP, but it does
                // not test whether there was a hit or not. In the current design,
                // if there is no hit, we still end up clearing whatever reqs_i_next
                // was earlier.
                if (reqs_hit_next) begin
                    case(l2_rsp_in.coh_msg)
                        `RSP_O : begin
                            next_state = RSP_O_HANDLER;
                        end
                        `RSP_S : begin
                            next_state = RSP_S_HANDLER;
                        end
                        default : begin
                            next_state = DECODE;
                        end
                    endcase
                end
            end
            RSP_O_HANDLER : begin
                next_state = DECODE;
            end
            RSP_S_HANDLER : begin
                // Regular shared state request - from SPX_I to SPX_S.
                // If all words are received, FSM 2 will send the read response
                // to the core, and FSM 1 will wait for the response to be accepted.
                // If all words are not received, FSM 2 will update word_mask in the reqs entry
                // and FSM 1 will go back to decode.
                if (reqs[reqs_i].state == `SPX_IS) begin
                    if (reqs[reqs_i].word_mask == `WORD_MASK_ALL) begin
                        if (l2_rd_rsp_ready_int) begin
                            next_state = DECODE;
                        end
                    end else begin
                        next_state = DECODE;
                    end
                end else begin
                    // TODO: Add new state to handle SPX_II
                    next_state = DECODE;
                end
            end
            // RSP_LOOKUP : begin
            //     case(l2_rsp_in.coh_msg)
            //         `RSP_EDATA : begin
            //             next_state = RSP_E_DATA_ISD;
            //         end
            //         `RSP_DATA : begin
            //             case(reqs[reqs_i_next].state)
            //                 `ISD : begin
            //                     next_state = RSP_E_DATA_ISD;
            //                 end
            //                 `IMAD : begin
            //                     next_state = RSP_DATA_XMAD;
            //                 end
            //                 `SMAD : begin
            //                     next_state = RSP_DATA_XMAD;
            //                 end
            //                 `IMADW : begin
            //                     next_state = RSP_DATA_XMADW;
            //                 end
            //                 `SMADW : begin
            //                     next_state = RSP_DATA_XMADW;
            //                 end
            //                 default : begin
            //                     next_state = DECODE;
            //                 end
            //             endcase
            //         end
            //         `RSP_INVACK : begin
            //             next_state = RSP_INVACK;
            //         end
            //         `RSP_PUTACK : begin
            //             next_state = RSP_PUTACK;
            //         end
            //         default : begin
            //             next_state = DECODE;
            //         end
            //     endcase
            // end
            // RSP_E_DATA_ISD : begin
            //     if (l2_rd_rsp_ready_int) begin
            //         next_state = DECODE;
            //     end
            // end
            // RSP_DATA_XMAD : begin
            //     next_state = DECODE;
            // end
            // RSP_DATA_XMADW : begin
            //     if (l2_rd_rsp_ready_int) begin
            //         next_state = DECODE;
            //     end
            // end
            // RSP_INVACK : begin
            //     next_state = DECODE;
            // end
            // RSP_PUTACK : begin
            //     if (l2_req_out_ready_int || !evict_stall) begin
            //         next_state  = DECODE;
            //     end
            // end
            // If new forward received, check if we're in fwd_stall or not
            // (L2_REQS_PEEK_FWD in FSM 2 will set fwd_stall). If not,
            // L2_REQS_PEEK_FWD in FSM 2 will set reqs_hit_next and reqs_i_next.
            // TODO: Need to check how to handle if no hit - what does
            // FWD_TAG_LOOKUP do here?
            // TODO: FWD_NO_HIT and FWD_NO_HIT_2 seem specific to their protocol -
            // need to adapt as necessary to Spandex forward handler.
            // TODO: For Spandex, we may need to service forwards during fwd_stall
            // as well, so the FWD_STALL state should not just go back to DECODE.
            FWD_REQS_LOOKUP : begin
                if ((fwd_stall || set_fwd_stall) & !clr_fwd_stall) begin
                    next_state = FWD_STALL;
                end else if (reqs_hit_next) begin
                    next_state = FWD_HIT;
                end else begin
                    next_state = FWD_TAG_LOOKUP;
                end
            end
            FWD_TAG_LOOKUP : begin
                next_state = FWD_NO_HIT;
            end
            FWD_STALL : begin
                next_state = DECODE;
            end
            // TODO: Add a switch case here on reqs[reqs_i].state
            // for all the forwards in our no fwd_stall handler.
            // In FSM 2, we need to add the actual rsp_out updates.
            // I think this FSM will proceed back to DECODE
            // as soon as rsp_out_ready is high, for example.
            FWD_HIT : begin
                if (reqs[reqs_i].state == `SMAD || reqs[reqs_i].state == `SMADW) begin
                    if (l2_fwd_in.coh_msg == `FWD_INV) begin
                        if (l2_rsp_out_ready_int && l2_inval_ready_int) begin
                            next_state = DECODE;
                        end else if (ready_bits[0] && l2_rsp_out_ready_int) begin
                            next_state = DECODE;
                        end else if (ready_bits[1] && l2_inval_ready_int) begin
                            next_state = DECODE;
                        end
                    end else begin
                        if (l2_inval_ready_int) begin
                            next_state = DECODE;
                        end
                    end
                end else if (reqs[reqs_i].state == `MIA) begin
                    if (l2_fwd_in.coh_msg == `FWD_GETS && l2_rsp_out_ready_int) begin
                        next_state = FWD_HIT_2;
                    end else if (l2_rsp_out_ready_int) begin
                        next_state = DECODE;
                    end
                end else if (reqs[reqs_i].state == `SIA) begin
                    if (l2_fwd_in.coh_msg == `FWD_INV && l2_rsp_out_ready_int) begin
                        next_state = DECODE;
                    end else if (l2_fwd_in.coh_msg != `FWD_INV) begin
                        next_state = DECODE;
                    end
                end else begin
                    next_state = DECODE;
                end
            end
            FWD_HIT_2 : begin
                if (l2_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            FWD_NO_HIT : begin
                if ((l2_inval_ready_int && l2_rsp_out_ready_int) ||
                    (l2_inval_ready_int && ready_bits[1]) ||
                    (ready_bits[0] && l2_rsp_out_ready_int) ||
                    (l2_inval_ready_int && l2_fwd_in.coh_msg == `FWD_INV_LLC) ||
                    (l2_rsp_out_ready_int && l2_fwd_in.coh_msg == `FWD_GETS)) begin
                    if (l2_fwd_in.coh_msg == `FWD_GETS) begin
                        next_state = FWD_NO_HIT_2;
                    end else begin
                        next_state = DECODE;
                    end
                end
            end
            FWD_NO_HIT_2 : begin
                if (l2_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            // Check if the flush_way (from l2_regs) has valid data,
            // and if it has data (instr don't need write-back). If yes,
            // go to next state ONGOING_FLUSH_PROCESS and wait
            // for write-back to complete.
            // TODO: update according to Spandex logic from SystemC.
            ONGOING_FLUSH_LOOKUP : begin
                if ((rd_data_state[flush_way] != `INVALID) && (is_flush_all || rd_data_hprot[flush_way])) begin
                    next_state = ONGOING_FLUSH_PROCESS;
                end else begin
                    next_state = DECODE;
                end
            end
            ONGOING_FLUSH_PROCESS : begin
                if (l2_req_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            // If new input request is received, check if there is an ongoing atomic
            // or set conflict. CPU_REQ_REQS_LOOKUP in FSM 2 will also check reqs to
            // see if new set_conflict needs to be set.
            // If write atomic, this FSM will also wait for BRESP to be accepted.
            // If none of the above, check tag RAMs to know if hit or not.
            CPU_REQ_REQS_LOOKUP : begin
                // TODO: All code related to ongoing atomic and set conflict removed. Add later.
                next_state = CPU_REQ_TAG_LOOKUP;
            end
            CPU_REQ_TAG_LOOKUP : begin
                // TODO: All code related to atomic read/write removed. Add later. 
                // TODO: Add eviction check for REQ_S where line is partially owned.
                // If tag is hit, check:
                // - if it is a non-FCS read (REQ_S) and all words in the line are at least shared.
                // - if it is a non-FCS write (REQ_O) and all words in the line are at least owned.
                // TODO: currently, REQ_O requires all words to be owned, but that should not be
                // necessary for word-granularity writes.
                if (tag_hit_next) begin
                    if (l2_cpu_req.cpu_msg == `READ) begin 
                        if (word_mask_shared == `WORD_MASK_ALL) begin
                            next_state = CPU_REQ_READ_NO_REQ;
                        end else begin
                            next_state = CPU_REQ_READ_REQ;
                        end
                    end else if (l2_cpu_req.cpu_msg == `WRITE) begin
                        if (word_mask_owned == `WORD_MASK_ALL) begin
                            next_state = CPU_REQ_WRITE_NOREQ;
                        end else begin
                            next_state = CPU_REQ_WRITE_REQ;
                        end
                    end
                end else if (empty_way_found_next) begin
                    next_state = CPU_REQ_EMPTY_WAY;
                end else begin
                    next_state = CPU_REQ_EVICT;
                end
            end
            CPU_REQ_READ_NO_REQ : begin
                if (l2_rd_rsp_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_READ_REQ : begin
                if (l2_req_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_WRITE_NOREQ : begin
                next_state = DECODE;
            end
            CPU_REQ_WRITE_REQ : begin
                if (l2_req_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_EMPTY_WAY : begin
                if (l2_req_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_EVICT : begin
                if (l2_inval_ready_int && l2_req_out_ready_int) begin
                    next_state = DECODE;
                end else if (ready_bits[0] && l2_req_out_ready_int) begin
                    next_state = DECODE;
                end else if (l2_inval_ready_int && ready_bits[1]) begin
                    next_state = DECODE;
                end
            end

            // CPU_REQ_REQS_LOOKUP : begin
            //      if (ongoing_atomic) begin
            //         if (atomic_line_addr != addr_br.line_addr) begin
            //             next_state = CPU_REQ_ATOMIC_OVERRIDE;
            //         end else begin
            //             if (l2_cpu_req.cpu_msg == `READ || l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
            //                 next_state = CPU_REQ_ATOMIC_CONTINUE_READ;
            //             end else begin
            //                 next_state = CPU_REQ_ATOMIC_CONTINUE_WRITE;
            //             end
            //         end
            //     end else if ((set_conflict | set_set_conflict_reqs) & !clr_set_conflict_reqs) begin
            //         next_state = CPU_REQ_SET_CONFLICT;
            //     end else if (!ongoing_atomic && l2_cpu_req.cpu_msg == `WRITE_ATOMIC) begin
            //         if (l2_bresp_ready_int) begin
            //             next_state = DECODE;
            //         end
            //     end else begin
            //         next_state = CPU_REQ_TAG_LOOKUP;
            //     end
            // end
            // CPU_REQ_ATOMIC_OVERRIDE : begin
            //     next_state = DECODE;
            // end
            // CPU_REQ_ATOMIC_CONTINUE_READ : begin
            // if (l2_rd_rsp_ready_int || l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
            //         next_state = DECODE;
            //     end
            // end
            // CPU_REQ_ATOMIC_CONTINUE_WRITE : begin
            //     if (l2_bresp_ready_int) begin
            //         next_state = DECODE;
            //     end
            // end
            // CPU_REQ_SET_CONFLICT : begin
            //     next_state = DECODE;
            // end
            // CPU_REQ_TAG_LOOKUP : begin
            //     if (tag_hit_next) begin
            //         if (l2_cpu_req.cpu_msg == `READ || (l2_cpu_req.cpu_msg == `READ_ATOMIC
            //                 && (states_buf[way_hit_next] == `EXCLUSIVE || states_buf[way_hit_next] == `MODIFIED)))  begin
            //             next_state = CPU_REQ_READ_READ_ATOMIC_EM;
            //         end else if ((l2_cpu_req.cpu_msg == `READ_ATOMIC && states_buf[way_hit_next] == `SHARED)
            //                 || (l2_cpu_req.cpu_msg == `WRITE && states_buf[way_hit_next] == `SHARED)) begin
            //             next_state = CPU_REQ_READ_ATOMIC_WRITE_S;
            //         end else if (l2_cpu_req.cpu_msg == `WRITE && (states_buf[way_hit_next] == `EXCLUSIVE
            //                 || states_buf[way_hit_next] == `MODIFIED)) begin
            //             next_state = CPU_REQ_WRITE_EM;
            //         end else begin
            //             next_state = DECODE;
            //         end
            //     end else if (empty_way_found_next) begin
            //         next_state = CPU_REQ_EMPTY_WAY;
            //     end else begin
            //         next_state = CPU_REQ_EVICT;
            //     end
            // end
            // CPU_REQ_READ_READ_ATOMIC_EM : begin
            //     if (l2_rd_rsp_ready_int) begin
            //         next_state = DECODE;
            //     end
            // end
            // CPU_REQ_READ_ATOMIC_WRITE_S : begin
            //     if (l2_req_out_ready_int) begin
            //         next_state = DECODE;
            //     end
            // end
            // CPU_REQ_WRITE_EM : begin
            //     next_state = DECODE;
            // end
            // CPU_REQ_EMPTY_WAY : begin
            //     if (l2_req_out_ready_int) begin
            //         next_state = DECODE;
            //     end
            // end
            // CPU_REQ_EVICT : begin
            //     if (l2_inval_ready_int && l2_req_out_ready_int) begin
            //         next_state = DECODE;
            //     end else if (ready_bits[0] && l2_req_out_ready_int) begin
            //         next_state = DECODE;
            //     end else if (l2_inval_ready_int && ready_bits[1]) begin
            //         next_state = DECODE;
            //     end
            // end
        endcase
    end

    addr_t addr_tmp;
    line_addr_t line_addr_tmp;
    unstable_state_t state_tmp;
    coh_msg_t coh_msg_tmp;

    // FSM 2
    // Based on next state decided in FSM 1,
    // update outputs for that next state.
    always_comb begin
        wr_rst = 1'b0;
        wr_data_state = 0;
        reqs_op_code = `L2_REQS_IDLE;
        lookup_en = 1'b0;
        lookup_mode = 1'b0;
        wr_req_state = 1'b0;
        wr_req_state_atomic = 1'b0;
        wr_req_line = 1'b0;
        wr_req_invack_cnt = 0;
        wr_req_tag = 1'b0;
        wr_en_put_reqs = 1'b0;
        wr_en_state = 1'b0;
        wr_en_line = 1'b0;
        wr_en_evict_way = 1'b0;
        set_in = 0;
        way = 0;
        way_wr_data_req = 0;
        wr_data_tag = 0;
        wr_data_hprot = 0;
        wr_data_line = 0;
        wr_data_state = 0;
        wr_data_evict_way = 0;
        incr_reqs_cnt = 1'b0;
        set_ongoing_atomic = 1'b0;
        rd_mem_en = 1'b0;
        incr_flush_way = 1'b0;
        addr_tmp = 0;
        line_addr_tmp = 0;
        state_tmp = 0;
        coh_msg_tmp = 0;
        fill_reqs = 1'b0;
        fill_reqs_flush = 1'b0;

        set_fwd_in_stalled = 1'b0;
        clr_fwd_stall_ended = 1'b0;
        set_set_conflict_fsm = 1'b0;
        clr_set_conflict_fsm = 1'b0;
        set_cpu_req_conflict = 1'b0;
        clr_ongoing_atomic  = 1'b0;
        update_atomic = 1'b0;
        clr_evict_stall = 1'b0;
        set_evict_stall = 1'b0;
        put_reqs_atomic = 1'b0;
        lr_to_xmw = 1'b0;

        l2_rd_rsp_o.line = 0;
        l2_rd_rsp_valid_int = 1'b0;
        l2_inval_o.addr = 0;
        l2_inval_o.hprot = 1'b0;
        l2_inval_valid_int = 1'b0;
        l2_bresp_valid_int = 1'b0;
        l2_bresp_o = `BRESP_OKAY;

        addr_br_reqs.line = 0;
        addr_br_reqs.line_addr = 0;
        addr_br_reqs.word = 0;
        addr_br_reqs.tag = 0;
        addr_br_reqs.set = 0;
        addr_br_reqs.w_off = 0;
        addr_br_reqs.b_off = 0;

        cpu_msg_wr_data_req = 0;
        tag_estall_wr_data_req = 0;
        invack_cnt_wr_data_req = 0;
        hsize_wr_data_req = 0;
        state_wr_data_req = 0;
        hprot_wr_data_req = 0;
        word_wr_data_req = 0;
        line_wr_data_req = 0;
        tag_wr_data_req = 0;
        amo_wr_data_req = 0;

        wr_req_word_mask = 0;
        word_mask_wr_data_req = 0;

        l2_req_out_valid_int = 1'b0;
        l2_req_out_o.coh_msg = 0;
        l2_req_out_o.hprot = 0;
        l2_req_out_o.addr = 0;
        l2_req_out_o.line = 0;
        l2_req_out_o.word_mask = 0;

        l2_rsp_out_valid_int = 1'b0;
        l2_rsp_out_o.coh_msg = 0;
        l2_rsp_out_o.req_id = 0;
        l2_rsp_out_o.to_req = 1'b0;
        l2_rsp_out_o.addr = 0;
        l2_rsp_out_o.line = 0;
        l2_rsp_out_o.word_mask = 0;

        word_in = 0;
        w_off_in = 0;
        b_off_in = 0;
        hsize_in = 0;
        line_in = 0;

        evict_way_tmp = 0;

`ifdef STATS_ENABLE
        l2_stats_o = 1'b0;
        l2_stats_valid_int = 1'b0;
`endif

        case (state)
            RESET : begin
                wr_rst = 1'b1;
                wr_data_state = `INVALID;
                set_in = rst_set;
            end
            DECODE : begin
                if (do_ongoing_flush_next) begin
                    if (incr_flush_set) begin
                        set_in = flush_set + 1;
                    end else begin
                        set_in = flush_set;
                    end
                end else if (do_fwd_next) begin
                    set_in = line_br_next.set;
                end else if (do_cpu_req_next) begin
                    set_in = addr_br_next.set;
                end
            end
            RSP_LOOKUP : begin
                reqs_op_code = `L2_REQS_LOOKUP;
            end
            // TODO: The current RSP_O implementation assumes word granularity REQ_O;
            // If we want to do line granularity REQ_O, we need to take care of read-modify-write
            // of the words that the CPU did not update.
            // The other option to implement line granularity with the current protocol, is to use REQ_Odata.
            RSP_O_HANDLER : begin
                word_mask_wr_data_req = reqs[reqs_i].word_mask & ~l2_rsp_in.word_mask;
                wr_req_word_mask = 1'b1;

                // If all words requested have been received, 
                // update the reqs entry state and increment the reqs_cnt
                if (~reqs[reqs_i].word_mask) begin
                    wr_req_state = 1'b1;
                    state_wr_data_req = `SPX_I;
                    wr_en_put_reqs = 1'b1;
                    incr_reqs_cnt = 1'b1;

                    // put_reqs - Update the RAMs
                    // TODO: Is it possible to abstract the put_reqs process into a function?
                    set_in = line_br.set;
                    way = reqs[reqs_i].way;
                    wr_data_tag = line_br.tag;
                    wr_data_line = reqs[reqs_i].line;
                    wr_data_hprot = reqs[reqs_i].hprot;
                    wr_data_state = `SPX_R;
                end
            end
            RSP_S_HANDLER : begin
                // Update the reqs entry line and word mask only for valid words in the response.
                wr_req_line = 1'b1;
                line_wr_data_req = l2_rsp_in.line;
                word_mask_wr_data_req = reqs[reqs_i].word_mask | l2_rsp_in.word_mask;
                wr_req_word_mask = 1'b1;

                // If all words requested have been received, 
                // update the reqs entry state and increment the reqs_cnt
                if (word_mask_wr_data_req == `WORD_MASK_ALL) begin
                    send_rd_rsp(l2_rsp_in.line);
                    wr_req_state = 1'b1;
                    state_wr_data_req = `SPX_I;
                    wr_en_put_reqs = 1'b1;

                    // put_reqs - Update the RAMs
                    put_reqs(line_br.set, reqs[reqs_i].way, line_br.tag, reqs[reqs_i].line, reqs[reqs_i].hprot, `SPX_S);

                    // Wiat for read response to be accepted before incrementing the reqs_cnt
                    if (l2_rd_rsp_ready_int) begin
                        incr_reqs_cnt = 1'b1;
                    end
                end
            end
            // RSP_E_DATA_ISD : begin
            //     l2_rd_rsp_valid_int = 1'b1;
            //     l2_rd_rsp_o.line = l2_rsp_in.line;
            //     wr_req_state = 1'b1;
            //     state_wr_data_req = `INVALID;
            //     wr_en_put_reqs = 1'b1;
            //     set_in = line_br.set;
            //     way = reqs[reqs_i].way;
            //     wr_data_tag = line_br.tag;
            //     wr_data_line = l2_rsp_in.line;
            //     wr_data_hprot = reqs[reqs_i].hprot;
            //     wr_data_state = (l2_rsp_in.coh_msg == `RSP_EDATA) ? `EXCLUSIVE : `SHARED;

            //     //only increment once if not ready
            //      if (l2_rd_rsp_ready_int) begin
            //         incr_reqs_cnt = 1'b1;
            //     end
            // end
            // RSP_DATA_XMAD : begin
            //     line_in = l2_rsp_in.line;
            //     word_in = reqs[reqs_i].word;
            //     w_off_in = reqs[reqs_i].w_off;
            //     b_off_in = reqs[reqs_i].b_off;
            //     hsize_in = reqs[reqs_i].hsize;

            //     invack_cnt_wr_data_req = reqs[reqs_i].invack_cnt + l2_rsp_in.invack_cnt;
            //     wr_req_invack_cnt = 1'b1;
            //     if (invack_cnt_wr_data_req == `MAX_N_L2) begin
            //         wr_en_put_reqs = 1'b1;
            //         set_in = line_br.set;
            //         way = reqs[reqs_i].way;
            //         wr_data_tag = line_br.tag;
            //         wr_data_line = line_out;
            //         wr_data_hprot = reqs[reqs_i].hprot;
            //         wr_data_state = `MODIFIED;
            //         wr_req_state = 1'b1;
            //         state_wr_data_req = `INVALID;
            //         incr_reqs_cnt = 1'b1;
            //     end else begin
            //         wr_req_state = 1'b1;
            //         state_wr_data_req = reqs[reqs_i].state + 2;
            //         wr_req_line = 1'b1;
            //         line_wr_data_req = line_out;
            //     end
            // end
            // RSP_DATA_XMADW : begin
            //     l2_rd_rsp_valid_int = 1'b1;
            //     l2_rd_rsp_o.line = l2_rsp_in.line;
            //     wr_req_line = 1'b1;
            //     line_wr_data_req = l2_rsp_in.line;

            //     if (l2_rd_rsp_ready_int) begin
            //         wr_req_invack_cnt = 1'b1;
            //         invack_cnt_wr_data_req = reqs[reqs_i].invack_cnt + l2_rsp_in.invack_cnt;
            //         wr_req_state = 1'b1;
            //     end

            //     if (invack_cnt_wr_data_req == `MAX_N_L2) begin
            //         set_ongoing_atomic = 1'b1;
            //         state_wr_data_req = `XMW;
            //     end else begin
            //         state_wr_data_req = reqs[reqs_i].state + 2;
            //     end
            // end
            // RSP_INVACK : begin
            //     invack_cnt_wr_data_req = reqs[reqs_i].invack_cnt - 1;
            //     wr_req_invack_cnt = 1'b1;
            //     if (invack_cnt_wr_data_req == `MAX_N_L2) begin
            //         if (reqs[reqs_i].state == `IMA || reqs[reqs_i].state == `SMA) begin
            //            wr_en_put_reqs = 1'b1;
            //            set_in = line_br.set;
            //            way = reqs[reqs_i].way;
            //            wr_data_tag = line_br.tag;
            //            wr_data_line = reqs[reqs_i].line;
            //            wr_data_hprot = reqs[reqs_i].hprot;
            //            wr_data_state = `MODIFIED;
            //            wr_req_state = 1'b1;
            //            state_wr_data_req = `INVALID;
            //            incr_reqs_cnt = 1'b1;
            //         end else if (reqs[reqs_i].state == `IMAW || reqs[reqs_i].state == `SMAW) begin
            //             set_ongoing_atomic = 1'b1;
            //             wr_req_state = 1'b1;
            //             state_wr_data_req = `XMW;
            //         end
            //     end
            // end
            // RSP_PUTACK : begin
            //     if (evict_stall) begin
            //         clr_evict_stall = 1'b1;
            //         case (reqs[reqs_i].cpu_msg)
            //             `READ : begin
            //                 state_wr_data_req = `ISD;
            //                 l2_req_out_o.coh_msg = `REQ_GETS;
            //             end
            //             `READ_ATOMIC : begin
            //                 state_wr_data_req = `IMADW;
            //                 l2_req_out_o.coh_msg = `REQ_GETM;
            //             end
            //             `WRITE : begin
            //                 state_wr_data_req = `IMAD;
            //                 l2_req_out_o.coh_msg = `REQ_GETM;
            //             end
            //         endcase
            //         wr_req_state = 1'b1;
            //         wr_req_tag = 1'b1;
            //         tag_wr_data_req = reqs[reqs_i].tag_estall;

            //         wr_en_evict_way = 1'b1;
            //         wr_data_evict_way = reqs[reqs_i].way + 1;
            //         set_in = reqs[reqs_i].set;

            //         l2_req_out_o.hprot = reqs[reqs_i].hprot;
            //         l2_req_out_o.addr = (reqs[reqs_i].tag_estall << `L2_SET_BITS) | line_br.set;
            //         l2_req_out_valid_int = 1'b1;
            //     end else begin
            //         wr_req_state = 1'b1;
            //         state_wr_data_req = `INVALID;
            //         incr_reqs_cnt = 1'b1;
            //     end
            // end
            FWD_REQS_LOOKUP : begin
                rd_mem_en = 1'b1;
                set_in = line_br.set;
                reqs_op_code = `L2_REQS_PEEK_FWD;
                clr_fwd_stall_ended = 1'b1;
            end
            FWD_TAG_LOOKUP : begin
                lookup_en = 1'b1;
                lookup_mode = `L2_LOOKUP_FWD;
            end
            FWD_STALL : begin
                set_fwd_in_stalled = 1'b1;
            end
            FWD_HIT : begin
                if (reqs[reqs_i].state == `SMAD || reqs[reqs_i].state == `SMADW || reqs[reqs_i].state == `SIA) begin
                    if (l2_fwd_in.coh_msg == `FWD_INV && !ready_bits[1]) begin
                        l2_rsp_out_valid_int = 1'b1;
                        l2_rsp_out_o.coh_msg = `RSP_INVACK;
                        l2_rsp_out_o.req_id = l2_fwd_in.req_id;
                        l2_rsp_out_o.to_req = 1'b1;
                        l2_rsp_out_o.addr = l2_fwd_in.addr;
                        l2_rsp_out_o.line = 0;
                    end

                    if (!ready_bits[0] && reqs[reqs_i].state != `SIA) begin
                        l2_inval_o.addr = l2_fwd_in.addr;
                        l2_inval_o.hprot = reqs[reqs_i].hprot;
                        l2_inval_valid_int = 1'b1;
                    end

                    if (reqs[reqs_i] != `SIA) begin
                        if (l2_fwd_in.coh_msg == `FWD_INV) begin
                            if (l2_rsp_out_ready_int && l2_inval_ready_int) begin
                                wr_req_state = 1'b1;
                            end else if (ready_bits[0] && l2_rsp_out_ready_int) begin
                                wr_req_state = 1'b1;
                            end else if (ready_bits[1] && l2_inval_ready_int) begin
                                wr_req_state = 1'b1;
                            end
                        end else begin
                            if (l2_inval_ready_int) begin
                                wr_req_state = 1'b1;
                            end
                        end
                    end else if (l2_rsp_out_ready_int || l2_fwd_in.coh_msg != `FWD_INV) begin
                        wr_req_state = 1'b1;
                    end


                    if (reqs[reqs_i].state == `SIA) begin
                        state_wr_data_req  = `IIA;
                    end else begin
                        state_wr_data_req  = reqs[reqs_i].state - 4;
                    end
                end else if (reqs[reqs_i].state == `MIA) begin
                    l2_rsp_out_valid_int = 1'b1;
                    l2_rsp_out_o.coh_msg = `RSP_DATA;
                    l2_rsp_out_o.addr = l2_fwd_in.addr;
                    l2_rsp_out_o.line = reqs[reqs_i].line;
                    if (l2_fwd_in.coh_msg == `FWD_GETS || l2_fwd_in.coh_msg == `FWD_GETM) begin
                        l2_rsp_out_o.req_id = l2_fwd_in.req_id;
                        l2_rsp_out_o.to_req = 1'b1;
                    end else begin
                        l2_rsp_out_o.req_id = 0;
                        l2_rsp_out_o.to_req = 1'b0;
                    end

                    if (l2_rsp_out_ready_int) begin
                        wr_req_state = 1'b1;
                    end

                    if (l2_fwd_in.coh_msg == `FWD_GETS) begin
                        state_wr_data_req = `SIA;
                    end else begin
                        state_wr_data_req = `IIA;
                    end
                end
            end
            FWD_HIT_2 : begin
                l2_rsp_out_valid_int = 1'b1;
                l2_rsp_out_o.coh_msg = `RSP_DATA;
                l2_rsp_out_o.req_id = l2_fwd_in.req_id;
                l2_rsp_out_o.to_req = 1'b0;
                l2_rsp_out_o.addr = l2_fwd_in.addr;
                l2_rsp_out_o.line = reqs[reqs_i].line;
            end
            FWD_NO_HIT : begin
                if (!ongoing_flush && l2_fwd_in.coh_msg != `FWD_GETS) begin
                    if (!ready_bits[0]) begin
                        l2_inval_valid_int = 1'b1;
                    end
                    l2_inval_o.addr = l2_fwd_in.addr;
                    l2_inval_o.hprot = hprots_buf[way_hit];
                end

                if (l2_fwd_in.coh_msg != `FWD_INV_LLC) begin
                    if (!ready_bits[1]) begin
                        l2_rsp_out_valid_int = 1'b1;
                    end
                    if (l2_fwd_in.coh_msg == `FWD_GETS || l2_fwd_in.coh_msg == `FWD_GETM) begin
                        l2_rsp_out_o.coh_msg = `RSP_DATA;
                        l2_rsp_out_o.req_id = l2_fwd_in.req_id;
                        l2_rsp_out_o.to_req = 1'b1;
                        l2_rsp_out_o.addr = l2_fwd_in.addr;
                        l2_rsp_out_o.line = lines_buf[way_hit];
                    end else if (l2_fwd_in.coh_msg == `FWD_INV) begin
                        l2_rsp_out_o.coh_msg = `RSP_INVACK;
                        l2_rsp_out_o.req_id = l2_fwd_in.req_id;
                        l2_rsp_out_o.to_req = 1'b1;
                        l2_rsp_out_o.addr = l2_fwd_in.addr;
                        l2_rsp_out_o.line = 0;
                    end else if (l2_fwd_in.coh_msg == `FWD_GETM_LLC) begin
                        l2_rsp_out_o.req_id = 0;
                        l2_rsp_out_o.to_req = 1'b0;
                        l2_rsp_out_o.addr = l2_fwd_in.addr;
                        if (states_buf[way_hit] == `EXCLUSIVE) begin
                            l2_rsp_out_o.coh_msg = `RSP_INVACK;
                            l2_rsp_out_o.line = 0;
                        end else begin
                            l2_rsp_out_o.coh_msg = `RSP_DATA;
                            l2_rsp_out_o.line = lines_buf[way_hit];
                        end
                    end
                end

                if (l2_fwd_in.coh_msg != `FWD_GETS && tag_hit) begin
                    wr_en_state = 1'b1;
                    wr_data_state = `INVALID;
                    way = way_hit;
                    set_in = line_br.set;
                end
            end
            FWD_NO_HIT_2 : begin
                l2_rsp_out_valid_int = 1'b1;
                l2_rsp_out_o.coh_msg = `RSP_DATA;
                l2_rsp_out_o.req_id = l2_fwd_in.req_id;
                l2_rsp_out_o.to_req = 1'b0;
                l2_rsp_out_o.addr = l2_fwd_in.addr;
                l2_rsp_out_o.line = lines_buf[way_hit];
                wr_en_state = 1'b1;
                wr_data_state = `SHARED;
                set_in = line_br.set;
                way = way_hit;
             end
            ONGOING_FLUSH_LOOKUP : begin
                set_in = flush_set;
                rd_mem_en = 1'b1;
                if ((rd_data_state[flush_way] == `INVALID) || (~is_flush_all && ~rd_data_hprot[flush_way])) begin
                    incr_flush_way = 1'b1;
                end
                reqs_op_code = `L2_REQS_PEEK_FLUSH;
            end
            ONGOING_FLUSH_PROCESS : begin
                addr_tmp = (tags_buf[flush_way] << `L2_TAG_RANGE_LO) | (flush_set << `SET_RANGE_LO);
                addr_br_reqs.line = addr_tmp;
                addr_br_reqs.line_addr = addr_tmp[`TAG_RANGE_HI:`SET_RANGE_LO];
                addr_br_reqs.word = addr_tmp;
                addr_br_reqs.tag = addr_tmp[`TAG_RANGE_HI:`L2_TAG_RANGE_LO];
                addr_br_reqs.set = addr_tmp[`L2_SET_RANGE_HI:`SET_RANGE_LO];
                addr_br_reqs.w_off = addr_tmp[`W_OFF_RANGE_HI:`W_OFF_RANGE_LO];
                addr_br_reqs.b_off = addr_tmp[`B_OFF_RANGE_HI:`B_OFF_RANGE_LO];
                addr_br_reqs.line[`OFF_RANGE_HI:`OFF_RANGE_LO] = 0;
                addr_br_reqs.word[`B_OFF_RANGE_HI:`B_OFF_RANGE_LO] = 0;

                line_addr_tmp = (tags_buf[flush_way] << `L2_SET_BITS) | (flush_set);
                set_in = flush_set;
                way = flush_way;
                wr_data_state = `INVALID;
                wr_en_state = 1'b1;
                case (states_buf[flush_way])
                    `SHARED : begin
                        coh_msg_tmp = `REQ_PUTS;
                        state_tmp = `SIA;
                    end
                    `EXCLUSIVE : begin
                        coh_msg_tmp = `REQ_PUTS;
                        state_tmp = `MIA;
                    end
                    `MODIFIED : begin
                        coh_msg_tmp = `REQ_PUTM;
                        state_tmp = `MIA;
                    end
                    default : begin
                        state_tmp = 0;
                    end
                endcase
                cpu_msg_wr_data_req = 0;
                tag_estall_wr_data_req = 0;
                way_wr_data_req = flush_way;
                hsize_wr_data_req = 0;
                state_wr_data_req = state_tmp;
                hprot_wr_data_req = 0;
                word_wr_data_req = 0;
                line_wr_data_req = lines_buf[flush_way];
                amo_wr_data_req = 0;

                l2_req_out_valid_int = 1'b1;
                l2_req_out_o.coh_msg = coh_msg_tmp;
                l2_req_out_o.hprot = 0;
                l2_req_out_o.addr = line_addr_tmp;
                l2_req_out_o.line = lines_buf[flush_way];

                if (l2_req_out_ready_int) begin
                    fill_reqs_flush = 1'b1;
                    incr_flush_way = 1'b1;
                end
            end
            CPU_REQ_REQS_LOOKUP : begin
                reqs_op_code = `L2_REQS_PEEK_REQ;
                rd_mem_en = 1'b1;
                set_in = addr_br.set;
                // TODO: Removed code related to BRESP being sent back for atomic write.
            end
            CPU_REQ_TAG_LOOKUP : begin
                // TODO: Removed code related to setting ongoing_atomic if atomic read.
                lookup_en = 1'b1;
                lookup_mode = `L2_LOOKUP;
            end
            CPU_REQ_READ_NO_REQ : begin
                l2_rd_rsp_valid_int = 1'b1;
                l2_rd_rsp_o.line = lines_buf[way_hit];
            end
            CPU_REQ_READ_REQ : begin
                state_wr_data_req = `SPX_IS;

                if (l2_req_out_ready_int) begin
                    fill_reqs = 1'b1;
                end

                cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
                tag_estall_wr_data_req = 0;
                tag_wr_data_req = addr_br.tag;
                way_wr_data_req = way_hit;
                hsize_wr_data_req = l2_cpu_req.hsize;
                hprot_wr_data_req = l2_cpu_req.hprot;
                word_wr_data_req = l2_cpu_req.word;
                line_wr_data_req = lines_buf[way_hit];
                amo_wr_data_req = 0;

                l2_req_out_valid_int = 1'b1;
                l2_req_out_o.coh_msg = `REQ_S;
                l2_req_out_o.hprot = l2_cpu_req.hprot;
                l2_req_out_o.addr = addr_br.line_addr;
                l2_req_out_o.line = 0;
                l2_req_out_o.word_mask = `WORD_MASK_ALL;
            end
            CPU_REQ_WRITE_NOREQ : begin
                set_in = addr_br.set;
                way = way_hit;

                line_in = lines_buf[way_hit];
                word_in = l2_cpu_req.word;
                w_off_in = addr_br.w_off;
                b_off_in = addr_br.b_off;
                hsize_in = l2_cpu_req.hsize;
                wr_data_line = line_out;
                wr_en_line = 1'b1;
            end
            CPU_REQ_WRITE_REQ : begin
                state_wr_data_req = `SPX_XR;

                if (l2_req_out_ready_int) begin
                    fill_reqs = 1'b1;
                end

                cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
                tag_estall_wr_data_req = 0;
                tag_wr_data_req = addr_br.tag;
                way_wr_data_req = way_hit;
                hsize_wr_data_req = l2_cpu_req.hsize;
                hprot_wr_data_req = l2_cpu_req.hprot;
                word_wr_data_req = l2_cpu_req.word;
                line_wr_data_req = lines_buf[way_hit];
                amo_wr_data_req = 0;

                // TODO: REQ_O currently using WORD_MASK_ALL. Need to change to
                // word granularity at some point.
                l2_req_out_valid_int = 1'b1;
                l2_req_out_o.coh_msg = `REQ_O;
                l2_req_out_o.hprot = l2_cpu_req.hprot;
                l2_req_out_o.addr = addr_br.line_addr;
                l2_req_out_o.line = 0;
                l2_req_out_o.word_mask = `WORD_MASK_ALL;
            end
            CPU_REQ_EMPTY_WAY : begin
                l2_req_out_valid_int = 1'b1;
                l2_req_out_o.hprot = l2_cpu_req.hprot;
                l2_req_out_o.addr = addr_br.line_addr;
                l2_req_out_o.line = 0;
                // TODO: set word_mask as necessary. We might need to add more
                // cases here and set word_mask and other signals (for req_out or reqs)
                // accordingly.
                l2_req_out_o.word_mask = `WORD_MASK_ALL;
                // TODO: READ_ATOMIC temporarily removed.
                case (l2_cpu_req.cpu_msg)
                    `READ : begin
                        l2_req_out_o.coh_msg = `REQ_S;
                        state_wr_data_req = `SPX_IS;
                    end
                    `WRITE : begin
                        l2_req_out_o.coh_msg = `REQ_O;
                        state_wr_data_req = `SPX_XR;
                    end
                endcase
                if (l2_req_out_ready_int) begin
                    fill_reqs = 1'b1;
                end
                cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
                tag_estall_wr_data_req = 0;
                tag_wr_data_req = addr_br.tag;
                way_wr_data_req = empty_way;
                hsize_wr_data_req = l2_cpu_req.hsize;
                hprot_wr_data_req = l2_cpu_req.hprot;
                word_wr_data_req = l2_cpu_req.word;
                amo_wr_data_req = l2_cpu_req.amo;
                // TODO: Fix this so that when the response is received,
                // the correct value that's currently in L2 memory and
                // the response that is received, and the new value to be
                // written (if applicable) are all considered.
                line_wr_data_req = 0;
            end
//             CPU_REQ_REQS_LOOKUP : begin
//                 reqs_op_code = `L2_REQS_PEEK_REQ;
//                 rd_mem_en = 1'b1;
//                 set_in = addr_br.set;
//                 if (!((set_conflict | set_set_conflict_reqs) && !clr_set_conflict_reqs)) begin
//                     if (l2_cpu_req.cpu_msg == `WRITE_ATOMIC && !ongoing_atomic) begin
//                         l2_bresp_valid_int = 1'b1;
//                         l2_bresp_o = `BRESP_OKAY;
//                     end
//                 end
//             end
//             CPU_REQ_ATOMIC_OVERRIDE : begin
//                 set_set_conflict_fsm = 1'b1;
//                 set_cpu_req_conflict = 1'b1;
//                 state_wr_data_req = `INVALID;
//                 wr_req_state_atomic = 1'b1;
//                 incr_reqs_cnt = 1'b1;
//                 clr_ongoing_atomic  = 1'b1;

//                 set_in = reqs[reqs_atomic_i].set;
//                 way = reqs[reqs_atomic_i].way;

//                 put_reqs_atomic = 1'b1;
//                 wr_en_put_reqs = 1'b1;
//                 wr_data_tag = reqs[reqs_atomic_i].tag;
//                 wr_data_line =  reqs[reqs_atomic_i].line;
//                 wr_data_hprot = reqs[reqs_atomic_i].hprot;
//                 wr_data_state = `MODIFIED;
//             end
//             CPU_REQ_ATOMIC_CONTINUE_READ :  begin
//                 set_in = reqs[reqs_atomic_i].set;
//                 way = reqs[reqs_atomic_i].way;

//                 if (l2_cpu_req.cpu_msg == `READ) begin
//                     clr_set_conflict_fsm = 1'b1;
//                     l2_rd_rsp_valid_int = 1'b1;
//                     l2_rd_rsp_o.line = reqs[reqs_atomic_i].line;
//                 end else begin
//                     set_set_conflict_fsm = 1'b1;
//                     incr_reqs_cnt = 1'b1;
//                     set_cpu_req_conflict = 1'b1;

//                     put_reqs_atomic = 1'b1;
//                     wr_en_put_reqs = 1'b1;
//                     wr_data_tag = reqs[reqs_atomic_i].tag;
//                     wr_data_line =  reqs[reqs_atomic_i].line;
//                     wr_data_hprot = reqs[reqs_atomic_i].hprot;
//                     wr_data_state = `MODIFIED;
//                     clr_ongoing_atomic = 1'b1;

//                     wr_req_state_atomic = 1'b1;
//                     state_wr_data_req = `INVALID;
//                 end
//             end
//             CPU_REQ_ATOMIC_CONTINUE_WRITE : begin
//                 clr_set_conflict_fsm = 1'b1;
//                 word_in = l2_cpu_req.word;
//                 w_off_in = addr_br.w_off;
//                 b_off_in = addr_br.b_off;
//                 hsize_in = l2_cpu_req.hsize;
//                 line_in = reqs[reqs_atomic_i].line;

//                 wr_req_state_atomic = 1'b1;
//                 state_wr_data_req = `INVALID;
//                 incr_reqs_cnt = 1'b1;

//                 set_in = reqs[reqs_atomic_i].set;
//                 way = reqs[reqs_atomic_i].way;

//                 put_reqs_atomic = 1'b1;
//                 wr_en_put_reqs = 1'b1;
//                 wr_data_tag = reqs[reqs_atomic_i].tag;
//                 wr_data_line =  line_out;
//                 wr_data_hprot = reqs[reqs_atomic_i].hprot;
//                 wr_data_state = `MODIFIED;
//                 clr_ongoing_atomic = 1'b1;

//                 l2_bresp_valid_int = 1'b1;
//                 if (l2_cpu_req.cpu_msg == `WRITE_ATOMIC) begin
//                     l2_bresp_o = `BRESP_EXOKAY;
//                 end
//             end
//             CPU_REQ_SET_CONFLICT : begin
//                 set_cpu_req_conflict = 1'b1;
//             end
//             CPU_REQ_TAG_LOOKUP : begin
//                 if (l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
//                     update_atomic = 1'b1;
//                 end
//                 lookup_en = 1'b1;
//                 lookup_mode = `L2_LOOKUP;
//             end
            
//             CPU_REQ_READ_READ_ATOMIC_EM : begin
//                 if (l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
//                     if (l2_rd_rsp_ready_int) begin
//                         fill_reqs = 1'b1;
//                     end
//                     cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
//                     tag_estall_wr_data_req = 0;
//                     tag_wr_data_req = addr_br.tag;
//                     way_wr_data_req = way_hit;
//                     hsize_wr_data_req = l2_cpu_req.hsize;
//                     state_wr_data_req = `XMW;
//                     hprot_wr_data_req = l2_cpu_req.hprot;
//                     word_wr_data_req = l2_cpu_req.word;
//                     line_wr_data_req = lines_buf[way_hit];
//                     amo_wr_data_req = l2_cpu_req.amo;
//                     set_ongoing_atomic = 1'b1;
//                 end

//                 l2_rd_rsp_valid_int = 1'b1;
//                 l2_rd_rsp_o.line = lines_buf[way_hit];
// `ifdef STATS_ENABLE
//                 if (l2_rd_rsp_ready_int) begin
//                     l2_stats_valid_int = 1'b1;
//                     l2_stats_o = 1'b1;
//                 end
// `endif
//             end
//             CPU_REQ_READ_ATOMIC_WRITE_S : begin
//                 if (l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
//                     state_wr_data_req = `SMADW;
//                 end else if (l2_cpu_req.cpu_msg == `WRITE) begin
//                     state_wr_data_req = `SMAD;
//                 end
//                 if (l2_req_out_ready_int) begin
//                     fill_reqs = 1'b1;
//                 end

//                 cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
//                 tag_estall_wr_data_req = 0;
//                 tag_wr_data_req = addr_br.tag;
//                 way_wr_data_req = way_hit;
//                 hsize_wr_data_req = l2_cpu_req.hsize;
//                 hprot_wr_data_req = l2_cpu_req.hprot;
//                 word_wr_data_req = l2_cpu_req.word;
//                 line_wr_data_req = lines_buf[way_hit];
//                 amo_wr_data_req = l2_cpu_req.amo;

//                 l2_req_out_valid_int = 1'b1;
//                 l2_req_out_o.coh_msg = `REQ_GETM;
//                 l2_req_out_o.hprot = l2_cpu_req.hprot;
//                 l2_req_out_o.addr = addr_br.line_addr;
//                 l2_req_out_o.line = 0;
// `ifdef STATS_ENABLE
//                 if (l2_req_out_ready_int) begin
//                     l2_stats_valid_int = 1'b1;
//                     l2_stats_o = 1'b1;
//                 end
// `endif
//             end
//             CPU_REQ_WRITE_EM : begin
//                 set_in = addr_br.set;
//                 way = way_hit;

//                 if (states_buf[way_hit] == `EXCLUSIVE) begin
//                     wr_data_state = `MODIFIED;
//                     wr_en_state = 1'b1;
//                 end

//                 line_in = lines_buf[way_hit];
//                 word_in = l2_cpu_req.word;
//                 w_off_in = addr_br.w_off;
//                 b_off_in = addr_br.b_off;
//                 hsize_in = l2_cpu_req.hsize;
//                 wr_data_line = line_out;
//                 wr_en_line = 1'b1;
// `ifdef STATS_ENABLE
//                 l2_stats_valid_int = 1'b1;
//                 l2_stats_o = 1'b1;
// `endif
//             end
//             CPU_REQ_EMPTY_WAY : begin
//                 l2_req_out_valid_int = 1'b1;
//                 l2_req_out_o.hprot = l2_cpu_req.hprot;
//                 l2_req_out_o.addr = addr_br.line_addr;
//                 l2_req_out_o.line = 0;
//                 case (l2_cpu_req.cpu_msg)
//                     `READ : begin
//                         l2_req_out_o.coh_msg = `REQ_GETS;
//                         state_wr_data_req = `ISD;
//                     end
//                     `READ_ATOMIC : begin
//                         l2_req_out_o.coh_msg = `REQ_GETM;
//                         state_wr_data_req = `IMADW;
//                     end
//                     `WRITE : begin
//                         l2_req_out_o.coh_msg = `REQ_GETM;
//                         state_wr_data_req = `IMAD;
//                     end
//                 endcase
//                 if (l2_req_out_ready_int) begin
//                     fill_reqs = 1'b1;
//                 end
//                 cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
//                 tag_estall_wr_data_req = 0;
//                 tag_wr_data_req = addr_br.tag;
//                 way_wr_data_req = empty_way;
//                 hsize_wr_data_req = l2_cpu_req.hsize;
//                 hprot_wr_data_req = l2_cpu_req.hprot;
//                 word_wr_data_req = l2_cpu_req.word;
//                 amo_wr_data_req = l2_cpu_req.amo;
//                 line_wr_data_req = 0;
// `ifdef STATS_ENABLE
//                 if (l2_req_out_ready_int) begin
//                     l2_stats_valid_int = 1'b1;
//                     l2_stats_o = 1'b0;
//                 end
// `endif
//             end
//             CPU_REQ_EVICT : begin
//                 set_evict_stall = 1'b1;

//                 evict_way_tmp = evict_way_buf;

//                 if (!ready_bits[0]) begin
//                     l2_inval_valid_int = 1'b1;
//                 end
//                 l2_inval_o.addr = (tags_buf[evict_way_tmp] << `L2_SET_BITS) | addr_br.set;
//                 l2_inval_o.hprot = hprots_buf[evict_way_tmp];
//                 if (!ready_bits[1]) begin
//                     l2_req_out_valid_int = 1'b1;
//                 end
//                 case (states_buf[evict_way_tmp])
//                     `SHARED : begin
//                         l2_req_out_o.coh_msg = `REQ_PUTS;
//                         state_wr_data_req = `SIA;
//                     end
//                     `EXCLUSIVE : begin
//                         l2_req_out_o.coh_msg = `REQ_PUTS;
//                         state_wr_data_req = `MIA;
//                     end
//                     `MODIFIED : begin
//                         l2_req_out_o.coh_msg = `REQ_PUTM;
//                         state_wr_data_req = `MIA;
//                     end
//                 endcase

//                 l2_req_out_o.hprot = 0;
//                 l2_req_out_o.addr = (tags_buf[evict_way_tmp] << `L2_SET_BITS) | addr_br.set;
//                 l2_req_out_o.line = lines_buf[evict_way_tmp];

//                 if (l2_inval_ready_int && l2_req_out_ready_int) begin
//                     fill_reqs = 1'b1;
// `ifdef STATS_ENABLE
//                     l2_stats_valid_int = 1'b1;
//                     l2_stats_o = 1'b0;
// `endif
//                 end else if (ready_bits[0] && l2_req_out_ready_int) begin
//                     fill_reqs = 1'b1;
// `ifdef STATS_ENABLE
//                     l2_stats_valid_int = 1'b1;
//                     l2_stats_o = 1'b0;
// `endif
//                 end else if (l2_inval_ready_int && ready_bits[1]) begin
//                     fill_reqs = 1'b1;
// `ifdef STATS_ENABLE
//                     l2_stats_valid_int = 1'b1;
//                     l2_stats_o = 1'b0;
// `endif
//                 end

//                 cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
//                 tag_estall_wr_data_req = addr_br.tag;
//                 tag_wr_data_req = tags_buf[evict_way_tmp];
//                 way_wr_data_req = evict_way_tmp;
//                 hsize_wr_data_req = l2_cpu_req.hsize;
//                 hprot_wr_data_req = l2_cpu_req.hprot;
//                 word_wr_data_req = l2_cpu_req.word;
//                 amo_wr_data_req = l2_cpu_req.amo;
//                 line_wr_data_req = lines_buf[evict_way_tmp];
//             end
//             default : begin
//                 reqs_op_code = `L2_REQS_IDLE;
//             end
        endcase
    end

    function void send_rd_rsp;
        input line_t line;

        l2_rd_rsp_valid_int = 1'b1;
        l2_rd_rsp_o.line = line;
    endfunction

    function void put_reqs;
        input l2_set_t set;
        input l2_way_t way;
        input l2_tag_t tag;
        input line_t line;
        input hprot_t hprot;
        input state_t state;

        set_in = set;
        way = way;
        wr_data_tag = tag;
        wr_data_line = line;
        wr_data_hprot = hprot;
        // TODO: If we're doing state at word granularity, the state for a line
        // needs to be read-modify-written back.
        wr_data_state = state;
    endfunction

endmodule
