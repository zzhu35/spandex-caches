`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

// TODO: Removed flush, atomic, set_conflict, stall related signals.
module l2_fsm(
    `FPGA_DBG input logic clk,
    `FPGA_DBG input logic rst,
    // From input_decoder - what to service next.
    `FPGA_DBG input logic do_fence,
    `FPGA_DBG input logic do_fence_next,
    `FPGA_DBG input logic do_ongoing_fence,
    `FPGA_DBG input logic do_ongoing_fence_next,
    `FPGA_DBG input logic do_rsp,
    `FPGA_DBG input logic do_rsp_next,
    `FPGA_DBG input logic do_fwd,
    `FPGA_DBG input logic do_fwd_next,
    `FPGA_DBG input logic do_cpu_req,
    `FPGA_DBG input logic do_cpu_req_next,
    // Whether external interfaces are ready for new data.
    `FPGA_DBG input logic l2_rd_rsp_ready_int,
    `FPGA_DBG input logic l2_req_out_ready_int,
    `FPGA_DBG input logic l2_rsp_out_ready_int,
    `FPGA_DBG input logic l2_inval_ready_int,
    `FPGA_DBG input logic l2_bresp_ready_int,
    // MSHR
    `FPGA_DBG input logic mshr_hit,
    `FPGA_DBG input logic mshr_hit_next,
    `FPGA_DBG input logic [`MSHR_BITS-1:0] mshr_i,
    `FPGA_DBG input logic [`MSHR_BITS-1:0] mshr_i_next,
    `FPGA_DBG input mshr_buf_t mshr[`N_MSHR],
    `FPGA_DBG input logic set_set_conflict_mshr,
    `FPGA_DBG input logic clr_set_conflict_mshr,
    `FPGA_DBG input logic set_fwd_stall,
    `FPGA_DBG input logic clr_fwd_stall,
    // Outputs from looking up RAMs.
    `FPGA_DBG input logic tag_hit,
    `FPGA_DBG input logic tag_hit_next,
    `FPGA_DBG input logic empty_way_found,
    `FPGA_DBG input logic empty_way_found_next,
    `FPGA_DBG input l2_way_t way_hit,
    `FPGA_DBG input l2_way_t way_hit_next,
    `FPGA_DBG input l2_way_t empty_way,
    `FPGA_DBG input l2_way_t empty_way_next,
    `FPGA_DBG input word_mask_t word_mask_shared,
    `FPGA_DBG input word_mask_t word_mask_shared_next,
    `FPGA_DBG input word_mask_t word_mask_owned,
    `FPGA_DBG input word_mask_t word_mask_owned_next,
    `FPGA_DBG input word_mask_t word_mask_owned_evict,
    `FPGA_DBG input word_mask_t word_mask_owned_evict_next,
    // Inputs from write_word modules
    `FPGA_DBG input line_t write_word_line_out,
    `FPGA_DBG input line_t write_word_amo_line_out,
    // Bufs populated from the current set in RAMs.
    `FPGA_DBG input state_t states_buf[`L2_WAYS][`WORDS_PER_LINE],
    `FPGA_DBG input hprot_t hprots_buf[`L2_WAYS],
    input line_t lines_buf[`L2_WAYS],
    `FPGA_DBG input l2_tag_t tags_buf[`L2_WAYS],
    `FPGA_DBG input l2_way_t evict_way_buf,
    // State registers from regs/others
    `FPGA_DBG input logic evict_stall,
    `FPGA_DBG input logic set_conflict,
    `FPGA_DBG input logic fwd_stall,
    `FPGA_DBG input fence_t l2_fence,

    // Inputs from input_decoder -
    // line_br for responses/forwards and addr_br for input requests.
    line_breakdown_l2_t.in line_br,
    line_breakdown_l2_t.in line_br_next,
    addr_breakdown_t.in addr_br,
    addr_breakdown_t.in addr_br_next,
    // Bus from interfaces
    l2_rsp_in_t.in l2_rsp_in,
    l2_fwd_in_t.in l2_fwd_in,
    l2_cpu_req_t.in l2_cpu_req,

    // To input_decoder - get new input
    `FPGA_DBG output logic decode_en,
    // To lookup - check for hit/miss/conflict in new set.
    `FPGA_DBG output logic lookup_en,
    `FPGA_DBG output logic lookup_mode,
    // To bufs to read RAMs into bufs.
    `FPGA_DBG output logic rd_set_into_bufs,
    // To MSHR
    // TODO: Removed atomic from MSHR inputs.
    `FPGA_DBG output logic add_mshr_entry,
    `FPGA_DBG output logic update_mshr_state,
    `FPGA_DBG output logic update_mshr_line,
    `FPGA_DBG output logic update_mshr_tag,
    `FPGA_DBG output logic update_mshr_word_mask,
    `FPGA_DBG output logic [2:0] mshr_op_code,
    `FPGA_DBG output logic incr_mshr_cnt,
    `FPGA_DBG output cpu_msg_t update_mshr_value_cpu_msg,
    `FPGA_DBG output hprot_t update_mshr_value_hprot,
    `FPGA_DBG output hsize_t update_mshr_value_hsize,
    `FPGA_DBG output l2_tag_t update_mshr_value_tag,
    `FPGA_DBG output l2_way_t update_mshr_value_way,
    `FPGA_DBG output line_t update_mshr_value_line,
    `FPGA_DBG output unstable_state_t update_mshr_value_state,
    `FPGA_DBG output word_t update_mshr_value_word,
    `FPGA_DBG output amo_t update_mshr_value_amo,
    `FPGA_DBG output word_mask_t update_mshr_value_word_mask,
    `FPGA_DBG output word_mask_t update_mshr_value_word_mask_reg,
    // To external interfaces - new data available.
    `FPGA_DBG output logic l2_rd_rsp_valid_int,
    `FPGA_DBG output logic l2_req_out_valid_int,
    `FPGA_DBG output logic l2_rsp_out_valid_int,
    `FPGA_DBG output logic l2_inval_valid_int,
    `FPGA_DBG output logic l2_bresp_valid_int,
    // TODO: Removed set_conflict, stall, flush related signals.
    `FPGA_DBG output logic lmem_wr_rst,
    `FPGA_DBG output logic lmem_wr_en_state,
    `FPGA_DBG output logic lmem_wr_en_line,
    `FPGA_DBG output logic lmem_wr_en_clear_mshr,
    `FPGA_DBG output logic lmem_wr_en_evict_way,
    `FPGA_DBG output state_t lmem_wr_data_state[`WORDS_PER_LINE],
    `FPGA_DBG output line_t lmem_wr_data_line,
    `FPGA_DBG output hprot_t lmem_wr_data_hprot,
    `FPGA_DBG output l2_tag_t lmem_wr_data_tag,
    `FPGA_DBG output l2_way_t lmem_wr_data_evict_way,
    `FPGA_DBG output l2_set_t lmem_set_in,
    `FPGA_DBG output l2_way_t lmem_way_in,
    // outputs to write_word
    output word_t write_word_word_in,
    output word_offset_t write_word_w_off_in,
    output byte_offset_t write_word_b_off_in,
    output hsize_t write_word_hsize_in,
    output line_t write_word_line_in,
    // outputs to write_word_amo
    output word_t write_word_amo_word_in,
    output word_offset_t write_word_amo_w_off_in,
    output byte_offset_t write_word_amo_b_off_in,
    output hsize_t write_word_amo_hsize_in,
    output amo_t write_word_amo_amo_in,
    output line_t write_word_amo_line_in,
    // Outputs to regs to register states
    `FPGA_DBG output logic clr_evict_stall,
    `FPGA_DBG output logic set_evict_stall,
    `FPGA_DBG output logic set_set_conflict_fsm,
    `FPGA_DBG output logic clr_set_conflict_fsm,
    `FPGA_DBG output logic set_cpu_req_conflict,
    `FPGA_DBG output logic set_fwd_in_stalled,
    `FPGA_DBG output logic clr_fwd_stall_ended,
    `FPGA_DBG output logic set_ongoing_fence,
    `FPGA_DBG output logic clr_ongoing_fence,
    `FPGA_DBG output logic set_ongoing_drain,
    `FPGA_DBG output logic acc_flush_done,

    `FPGA_DBG output bresp_t l2_bresp_o,

    addr_breakdown_t.out addr_br_reqs,
    l2_rd_rsp_t.out l2_rd_rsp_o,
    l2_rsp_out_t.out l2_rsp_out_o,
    l2_req_out_t.out l2_req_out_o,
    l2_inval_t.out l2_inval_o
   );

    localparam RESET = 6'b000000;
    localparam DECODE = 6'b000001;

    localparam RSP_MSHR_LOOKUP = 6'b000010;
    localparam RSP_ODATA_HANDLER = 6'b000011;
    localparam RSP_S_HANDLER = 6'b000100;
    localparam RSP_WB_ACK_HANDLER = 6'b000101;

    localparam FWD_MSHR_LOOKUP = 6'b001000;
    localparam FWD_STALL = 6'b001001;
    localparam FWD_MSHR_HIT = 6'b001010;
    localparam FWD_TAG_LOOKUP = 6'b001011;
    localparam FWD_LOOKUP_HIT = 6'b001100;
    localparam FWD_INV_HANDLER = 6'b001101;
    localparam FWD_RVK_O_HANDLER = 6'b001110;
    localparam FWD_REQ_S_HANDLER = 6'b001111;
    localparam FWD_REQ_S_HANDLER_RVK = 6'b010000;
    localparam FWD_REQ_ODATA_HANDLER = 6'b010001;

    localparam NEW_FENCE_HANDLER = 6'b100000;
    localparam ONGOING_FENCE_HANDLER = 6'b100001;

    localparam CPU_REQ_MSHR_LOOKUP = 6'b100010;
    localparam CPU_REQ_SET_CONFLICT = 6'b100011;
    localparam CPU_REQ_TAG_LOOKUP = 6'b100100;
    localparam CPU_REQ_AMO_NO_REQ = 6'b100101;
    localparam CPU_REQ_AMO_REQ = 6'b100110;
    localparam CPU_REQ_READ_NO_REQ = 6'b100111;
    localparam CPU_REQ_READ_REQ = 6'b101000;
    localparam CPU_REQ_READ_ATOMIC_NO_REQ = 6'b101001;
    localparam CPU_REQ_READ_ATOMIC_REQ = 6'b101010;
    localparam CPU_REQ_WRITE_NO_REQ = 6'b101011;
    localparam CPU_REQ_WRITE_REQ = 6'b101100;
    localparam CPU_REQ_WRITE_ATOMIC_NO_REQ = 6'b101101;
    localparam CPU_REQ_WRITE_ATOMIC_REQ = 6'b101110;
    localparam CPU_REQ_EVICT = 6'b101111;

    `FPGA_DBG logic [5:0] state, next_state;
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

    // TODO: Removed atomic_line_addr and reqs_atomic_i registering.

    // TODO: Removed ready_bits till it is clear that we need them too.

    // Store the way to be evicted till evict_stall is removed.
    l2_way_t evict_way_reg;

    // Wrapper variable to store the way for the ongoing cpu request.
    `FPGA_DBG l2_way_t cpu_req_way;
    assign cpu_req_way = tag_hit ? way_hit : (empty_way_found ? empty_way : 'h0);

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
            // - do_fence_next: New fence request received
            // - do_rsp_next: Response to earlier req_out/fwd_out received
            // - do_fwd_next: Forward received from other L2/LLC
            // - do_ongoing_fence_next: Continue next half of ongoing fence
            // - do_cpu_req_next: New input request received
            DECODE : begin
                if (do_fence_next) begin
                    next_state = NEW_FENCE_HANDLER;
                end if (do_rsp_next) begin
                    next_state = RSP_MSHR_LOOKUP;
                end else if (do_fwd_next) begin
                    next_state = FWD_MSHR_LOOKUP;
                    // TODO: Removed do_ongoing_flush_next temporarily
                end else if (do_ongoing_fence_next) begin
                    next_state = ONGOING_FENCE_HANDLER;
                end else if (do_cpu_req_next) begin
                    next_state = CPU_REQ_MSHR_LOOKUP;
                end
            end
            // -------------------
            // Fence handler
            // -------------------
            // When we receive a new fence, we first check the type of fence:
            // l2_fence[0] = acquire; self-invalidation
            // l2_fence[1] = release; write-buffer and MSHR flush
            NEW_FENCE_HANDLER : begin
                next_state = DECODE;
            end
            ONGOING_FENCE_HANDLER : begin
                next_state = DECODE;
            end
            // -------------------
            // Response handler
            // -------------------
            // If new response received, lookup the coherence message
            // of the response.
            RSP_MSHR_LOOKUP : begin
                // TODO: Should we update the word_mask in reqs[reqs_i] here?
                // Maybe, we should update word_mask here, and only transition to
                // the handler that finally removes the MSHR entry and/or updates
                // data into the RAMs.
                // TODO: Don't we need to check if the response matches
                // an entry in the MSHR? FSM 2 does do a L2_REQS_LOOKUP, but it does
                // not test whether there was a hit or not. In the current design,
                // if there is no hit, we still end up clearing whatever reqs_i_next
                // was earlier.
                if (mshr_hit_next) begin
                    case(l2_rsp_in.coh_msg)
                        `RSP_Odata : begin
                            next_state = RSP_ODATA_HANDLER;
                        end
                        `RSP_S : begin
                            next_state = RSP_S_HANDLER;
                        end
                        `RSP_WB_ACK : begin
                            next_state = RSP_WB_ACK_HANDLER;
                        end
                        default : begin
                            next_state = DECODE;
                        end
                    endcase
                end else begin
                    next_state = DECODE;
                end
            end
            RSP_ODATA_HANDLER : begin
                // In the case of AMO, we need to wait for the read response to be sent
                // back, but in case of regular writes, there is no read response to wait for.
                if (mshr[mshr_i].state == `SPX_AMO) begin
                    if (~mshr[mshr_i].word_mask) begin
                        if (l2_rd_rsp_ready_int) begin
                            next_state = DECODE;
                        end
                    end else begin
                        next_state = DECODE;
                    end
                end else begin
                    next_state = DECODE;
                end
            end
            RSP_S_HANDLER : begin
                // Regular shared state request - from SPX_I to SPX_S.
                // If all words are received, FSM 2 will send the read response
                // to the core, and FSM 1 will wait for the response to be accepted.
                // If all words are not received, FSM 2 will update word_mask in the reqs entry
                // and FSM 1 will go back to decode.
                if (mshr[mshr_i].state == `SPX_IS) begin
                    if (~mshr[mshr_i].word_mask) begin
                        if (l2_rd_rsp_ready_int) begin
                            next_state = DECODE;
                        end
                    end else begin
                        next_state = DECODE;
                    end
                end else begin
                    next_state = DECODE;
                end
            end
            RSP_WB_ACK_HANDLER : begin
                next_state = DECODE;
            end
            // -------------------
            // Forward handler
            // -------------------
            // If new forward received, check if we're in fwd_stall or not
            // (L2_REQS_PEEK_FWD in FSM 2 will set fwd_stall). If not,
            // L2_REQS_PEEK_FWD in FSM 2 will set reqs_hit_next and reqs_i_next.
            // TODO: Need to check how to handle if no hit - what does
            // FWD_TAG_LOOKUP do here?
            // TODO: FWD_NO_HIT and FWD_NO_HIT_2 seem specific to their protocol -
            // need to adapt as necessary to Spandex forward handler.
            // TODO: For Spandex, we may need to service forwards during fwd_stall
            // as well, so the FWD_STALL state should not just go back to DECODE.
            FWD_MSHR_LOOKUP : begin
                // FSM 2 will lookup MSHR to see if there's already a stall - if yes,
                // go to FWD_STALL. Else, check if if the incoming entry is causing a
                // stall. Else, lookup the RAMs to see if the forward is a hit.
                // It is okay to check set_fwd_stall and clr_fwd_stall every time,
                // because the l2_fwd_in will be registered till the fwd_stall ends,
                // i.e., input_decoder will not accept a new forward till it ends. 
                if ((fwd_stall || set_fwd_stall) & !clr_fwd_stall) begin
                    next_state = FWD_STALL;
                end else if (mshr_hit_next) begin
                    next_state = FWD_MSHR_HIT;
                end else begin
                    next_state = FWD_TAG_LOOKUP;
                end
            end
            FWD_STALL : begin
                next_state = DECODE;
            end
            FWD_MSHR_HIT : begin
                case(l2_fwd_in.coh_msg)
                    `FWD_INV : begin
                        next_state = FWD_INV_HANDLER;
                    end
                    `FWD_RVK_O : begin
                        next_state = FWD_RVK_O_HANDLER;
                    end
                    `FWD_REQ_S : begin
                        next_state = FWD_REQ_S_HANDLER;
                    end
                    `FWD_REQ_Odata : begin
                        next_state = FWD_REQ_ODATA_HANDLER;
                    end
                    default : begin
                        next_state = DECODE;
                    end
                endcase
            end
            FWD_TAG_LOOKUP : begin
                case(l2_fwd_in.coh_msg)
                    `FWD_INV : begin
                        next_state = FWD_INV_HANDLER;
                    end
                    `FWD_RVK_O : begin
                        next_state = FWD_RVK_O_HANDLER;
                    end
                    `FWD_REQ_S : begin
                        next_state = FWD_REQ_S_HANDLER;
                    end
                    `FWD_REQ_Odata : begin
                        next_state = FWD_REQ_ODATA_HANDLER;
                    end
                    default : begin
                        next_state = DECODE;
                    end
                endcase
            end
            FWD_INV_HANDLER : begin
                // TODO: When inval is implemented, wait inval_ready
                if (l2_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            FWD_RVK_O_HANDLER : begin
                // TODO: When inval is implemented, wait inval_ready
                if (l2_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            FWD_REQ_S_HANDLER : begin
                // TODO: When inval is implemented, wait inval_ready
                if (l2_rsp_out_ready_int) begin
                    next_state = FWD_REQ_S_HANDLER_RVK;
                end
            end
            FWD_REQ_S_HANDLER_RVK : begin
                // TODO: When inval is implemented, wait inval_ready
                if (l2_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            FWD_REQ_ODATA_HANDLER : begin
                // TODO: When inval is implemented, wait inval_ready
                if (l2_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end            
            // Check if the flush_way (from l2_regs) has valid data,
            // and if it has data (instr don't need write-back). If yes,
            // go to next state ONGOING_FLUSH_PROCESS and wait
            // for write-back to complete.
            // TODO: update according to Spandex logic from SystemC.
            // TODO: Removed flush handling; add later
            // -------------------
            // Flush handler
            // -------------------
            // If new input request is received, check if there is an ongoing atomic
            // or set conflict. CPU_REQ_MSHR_LOOKUP in FSM 2 will also check reqs to
            // see if new set_conflict needs to be set.
            // If write atomic, this FSM will also wait for BRESP to be accepted.
            // If none of the above, check tag RAMs to know if hit or not.
            CPU_REQ_MSHR_LOOKUP : begin
                // TODO: All code related to ongoing atomic and set conflict removed. Add later.
                if ((set_conflict | set_set_conflict_mshr) & !clr_set_conflict_mshr) begin
                    next_state = CPU_REQ_SET_CONFLICT;
                end else begin
                    next_state = CPU_REQ_TAG_LOOKUP;
                end
            end
            CPU_REQ_SET_CONFLICT : begin
                next_state = DECODE;
            end
            CPU_REQ_TAG_LOOKUP : begin
                // TODO: All code related to atomic read/write removed. Add later.
                // TODO: Add eviction check for REQ_S where line is partially owned.
                // If tag is hit, check:
                // - if it is a non-FCS read (REQ_S) and all words in the line are at least shared.
                // - if it is a non-FCS write (REQ_O) and all words in the line are at least owned.
                // TODO: currently, REQ_O requires all words to be owned, but that should not be
                // necessary for word-granularity writes.
                // --- copied from CPU_REQ_EMPTY_WAY
                // TODO: READ_ATOMIC temporarily removed.
                // TODO: Fix line so that when the response is received,
                // the correct value that's currently in L2 memory and
                // the response that is received, and the new value to be
                // written (if applicable) are all considered.
                // TODO: set word_mask as necessary. We might need to add more
                // cases here and set word_mask and other signals (for req_out or reqs)
                // accordingly.
                if (tag_hit_next) begin
                    if (l2_cpu_req.amo) begin
                        if (word_mask_owned_next == `WORD_MASK_ALL) begin
                            next_state = CPU_REQ_AMO_NO_REQ;
                        end else begin
                            next_state = CPU_REQ_AMO_REQ;
                        end                        
                    end else begin
                        case(l2_cpu_req.cpu_msg)
                            `READ : begin
                                if (word_mask_shared_next == `WORD_MASK_ALL) begin
                                    next_state = CPU_REQ_READ_NO_REQ;
                                end else begin
                                    next_state = CPU_REQ_READ_REQ;
                                end
                            end
                            `READ_ATOMIC : begin
                                if (word_mask_owned_next == `WORD_MASK_ALL) begin
                                    next_state = CPU_REQ_READ_ATOMIC_NO_REQ;
                                end else begin
                                    next_state = CPU_REQ_READ_ATOMIC_REQ;
                                end
                            end
                            `WRITE : begin
                                if (word_mask_owned_next == `WORD_MASK_ALL) begin
                                    next_state = CPU_REQ_WRITE_NO_REQ;
                                end else begin
                                    next_state = CPU_REQ_WRITE_REQ;
                                end
                            end
                            `WRITE_ATOMIC : begin
                                if (word_mask_owned_next == `WORD_MASK_ALL) begin
                                    next_state = CPU_REQ_WRITE_ATOMIC_NO_REQ;
                                end else begin
                                    next_state = CPU_REQ_WRITE_ATOMIC_REQ;
                                end
                            end                        
                            default : begin
                                next_state = DECODE;
                            end
                        endcase
                    end
                end else if (empty_way_found_next) begin
                    if (l2_cpu_req.amo) begin
                        next_state = CPU_REQ_AMO_REQ;
                    end else begin
                        case(l2_cpu_req.cpu_msg)
                            `READ : begin
                                next_state = CPU_REQ_READ_REQ;
                            end
                            `READ_ATOMIC : begin
                                next_state = CPU_REQ_READ_ATOMIC_REQ;
                            end
                            `WRITE : begin
                                next_state = CPU_REQ_WRITE_REQ;
                            end
                            `WRITE_ATOMIC : begin
                                next_state = CPU_REQ_WRITE_ATOMIC_REQ;
                            end                        
                            default : begin
                                next_state = DECODE;
                            end
                        endcase
                    end
                end else begin
                    next_state = CPU_REQ_EVICT;
                end
            end
            CPU_REQ_AMO_NO_REQ : begin
                if (l2_rd_rsp_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_AMO_REQ : begin
                if (l2_req_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_READ_ATOMIC_NO_REQ : begin
                if (l2_rd_rsp_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_READ_ATOMIC_REQ : begin
                if (l2_req_out_ready_int) begin
                    next_state = DECODE;
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
            CPU_REQ_WRITE_ATOMIC_NO_REQ : begin
                if (l2_bresp_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_WRITE_ATOMIC_REQ : begin
                if (l2_bresp_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_WRITE_NO_REQ : begin
                next_state = DECODE;
            end
            CPU_REQ_WRITE_REQ : begin
                if (l2_req_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            CPU_REQ_EVICT : begin
                // TODO: Removed ready_bits check
                if (l2_inval_ready_int) begin
                    if (word_mask_owned_evict) begin
                        if (l2_req_out_ready_int) begin
                            next_state = CPU_REQ_MSHR_LOOKUP;
                        end
                    end else begin
                        next_state = CPU_REQ_MSHR_LOOKUP;
                    end
                end
            end
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
        lookup_en = 1'b0;
        lookup_mode = 1'b0;

        rd_set_into_bufs = 1'b0;

        set_evict_stall = 1'b0;
        clr_evict_stall = 1'b0;
        set_set_conflict_fsm = 1'b0;
        clr_set_conflict_fsm = 1'b0;
        set_cpu_req_conflict = 1'b0;
        set_fwd_in_stalled = 1'b0;
        clr_fwd_stall_ended = 1'b0;
        set_ongoing_fence = 1'b0;
        clr_ongoing_fence = 1'b0;
        set_ongoing_drain = 1'b0;
        acc_flush_done = 1'b0;

        add_mshr_entry = 1'b0;
        update_mshr_state = 1'b0;
        update_mshr_line = 1'b0;
        update_mshr_tag = 1'b0;
        update_mshr_word_mask = 1'b0;
        mshr_op_code = `L2_MSHR_IDLE;
        incr_mshr_cnt = 1'b0;
        update_mshr_value_cpu_msg = 'h0;
        update_mshr_value_hprot = 'h0;
        update_mshr_value_hsize = 'h0;
        update_mshr_value_tag = 'h0;
        update_mshr_value_way = 'h0;
        update_mshr_value_line = 'h0;
        update_mshr_value_state = 'h0;
        update_mshr_value_word = 'h0;
        update_mshr_value_amo = 'h0;
        update_mshr_value_word_mask = 'h0;
        update_mshr_value_word_mask_reg = 'h0;

        l2_req_out_valid_int = 1'b0;
        l2_req_out_o.coh_msg = 'h0;
        l2_req_out_o.hprot = 'h0;
        l2_req_out_o.addr = 'h0;
        l2_req_out_o.line = 'h0;
        l2_req_out_o.word_mask = 'h0;

        l2_rsp_out_valid_int = 1'b0;
        l2_rsp_out_o.coh_msg = 'h0;
        l2_rsp_out_o.req_id = 'h0;
        l2_rsp_out_o.to_req = 1'b0;
        l2_rsp_out_o.addr = 'h0;
        l2_rsp_out_o.line = 'h0;
        l2_rsp_out_o.word_mask = 'h0;

        l2_rd_rsp_o.line = 'h0;
        l2_rd_rsp_valid_int = 1'b0;
        l2_inval_o.addr = 'h0;
        l2_inval_o.hprot = 1'b0;
        l2_inval_valid_int = 1'b0;
        l2_bresp_valid_int = 1'b0;
        l2_bresp_o = `BRESP_OKAY;

        lmem_wr_rst = 1'b0;
        lmem_wr_en_state = 1'b0;
        lmem_wr_en_line = 1'b0;
        lmem_wr_en_evict_way = 1'b0;
        lmem_wr_en_clear_mshr = 1'b0;
        for (int i = 0; i < `WORDS_PER_LINE; i++) begin
            lmem_wr_data_state[i] = 'h0;
        end
        lmem_wr_data_line = 'h0;
        lmem_wr_data_hprot = 'h0;
        lmem_wr_data_tag = 'h0;
        lmem_wr_data_evict_way = 'h0;
        lmem_set_in = 'h0;
        lmem_way_in = 'h0;

        write_word_word_in = 'h0;
        write_word_w_off_in = 'h0;
        write_word_b_off_in = 'h0;
        write_word_hsize_in = 'h0;
        write_word_line_in = 'h0;

        write_word_amo_word_in = 'h0;
        write_word_amo_w_off_in = 'h0;
        write_word_amo_b_off_in = 'h0;
        write_word_amo_hsize_in = 'h0;
        write_word_amo_amo_in = 'h0;
        write_word_amo_line_in = 'h0;

        addr_br_reqs.line = 'h0;
        addr_br_reqs.line_addr = 'h0;
        addr_br_reqs.word = 'h0;
        addr_br_reqs.tag = 'h0;
        addr_br_reqs.set = 'h0;
        addr_br_reqs.w_off = 'h0;
        addr_br_reqs.b_off = 'h0;

        addr_tmp = 'h0;
        line_addr_tmp = 'h0;
        state_tmp = 'h0;
        coh_msg_tmp = 'h0;

        evict_way_reg = 'h0;

        case (state)
            RESET : begin
                lmem_wr_rst = 1'b1;
                for (int i = 0; i < `WORDS_PER_LINE; i++) begin
                    lmem_wr_data_state[i] = 'h0;
                end
                lmem_set_in = rst_set;
            end
            DECODE : begin
                // TODO: Removed do_ongoing_flush_next check
                if (do_fwd_next) begin
                    lmem_set_in = line_br_next.set;
                end else if (do_cpu_req_next) begin
                    lmem_set_in = addr_br_next.set;
                end
            end
            NEW_FENCE_HANDLER : begin
                // Start drain of ongoing requests.
                set_ongoing_fence = 1'b1;
                if (l2_fence[1]) begin
                    set_ongoing_drain = 1'b1;
                end
            end
            ONGOING_FENCE_HANDLER : begin
                // TODO: Once we add valid states, self-invalidate will come here.
                clr_ongoing_fence = 1'b1;
                acc_flush_done = 1'b1;
            end                 
            RSP_MSHR_LOOKUP : begin
                mshr_op_code = `L2_MSHR_LOOKUP;
            end
            // TODO: The current RSP_O implementation assumes word granularity REQ_O;
            // If we want to do line granularity REQ_O, we need to take care of read-modify-write
            // of the words that the CPU did not update.
            // The other option to implement line granularity with the current protocol, is to use REQ_Odata.
            RSP_ODATA_HANDLER : begin
                // Assign only valid words from response to the MSHR line.
                write_line_helper(mshr[mshr_i].line, l2_rsp_in.line, l2_rsp_in.word_mask, update_mshr_value_line);
                update_mshr_line = 1'b1;
                // Clear words in response from the pending MSHR word_mask.
                update_mshr_value_word_mask = mshr[mshr_i].word_mask & ~l2_rsp_in.word_mask;
                update_mshr_word_mask = 1'b1;

                // If all words requested have been received,
                // update the reqs entry state and increment the reqs_cnt.
                if (~update_mshr_value_word_mask) begin
                    // In case of AMO and LR, we send a read response back.
                    if (mshr[mshr_i].cpu_msg == `READ_ATOMIC) begin
                        send_rd_rsp(/* line */ update_mshr_value_line);
                    end else begin
                        // Write the original value to be written from the input request.
                        if (mshr[mshr_i].state == `SPX_AMO) begin
                            send_rd_rsp(/* line */ update_mshr_value_line);

                            // Only AMO update the line if read response is accepted, else
                            // the FSM will remain in this state and non-idempotent AMO operations
                            // (like AMO add) might be repetitively applied.
                            if (l2_rd_rsp_ready_int) begin
                                write_word_amo_helper (
                                    /* line_in */ update_mshr_value_line,
                                    /* word */ mshr[mshr_i].word,
                                    /* w_off */ mshr[mshr_i].w_off,
                                    /* b_off */ mshr[mshr_i].b_off,
                                    /* hsize */ mshr[mshr_i].hsize,
                                    /* amo */ mshr[mshr_i].amo,
                                    /* line_out */ update_mshr_value_line
                                );
                            end
                        end else begin
                            write_word_helper (
                                /* line_in */ update_mshr_value_line,
                                /* word */ mshr[mshr_i].word,
                                /* w_off */ mshr[mshr_i].w_off,
                                /* b_off */ mshr[mshr_i].b_off,
                                /* hsize */ mshr[mshr_i].hsize,
                                /* line_out */ update_mshr_value_line
                            );
                        end
                        update_mshr_line = 1'b1;
                    end

                    // Update the RAMs
                    clear_mshr_entry (
                        /* set */ line_br.set,
                        /* way */ mshr[mshr_i].way,
                        /* tag */ line_br.tag,
                        /* line */ update_mshr_value_line,
                        /* hprot */  mshr[mshr_i].hprot,
                        /* state */ `SPX_R,
                        /* word_mask_reg */ mshr[mshr_i].word_mask_reg
                    );

                    // Clear the MSHR entry only if response is accepted or if it is a write.
                    if ((mshr[mshr_i].cpu_msg != `READ_ATOMIC && mshr[mshr_i].state != `SPX_AMO) || l2_rd_rsp_ready_int) begin
                        update_mshr_state = 1'b1;
                        update_mshr_value_state = `SPX_I;
                        incr_mshr_cnt = 1'b1;
                    end
                end
            end
            RSP_S_HANDLER : begin
                // Assign only valid words from response to the MSHR line.
                write_line_helper(mshr[mshr_i].line, l2_rsp_in.line, l2_rsp_in.word_mask, update_mshr_value_line);
                update_mshr_line = 1'b1;
                // Clear words in response from the pending MSHR word_mask.
                update_mshr_value_word_mask = mshr[mshr_i].word_mask & ~l2_rsp_in.word_mask;
                update_mshr_word_mask = 1'b1;

                // If all words requested have been received, send the response,
                // update the reqs entry and increment the reqs_cnt
                if (~update_mshr_value_word_mask) begin
                    send_rd_rsp(/* line */ update_mshr_value_line);

                    // Update the RAMs and clear entry
                    if (mshr[mshr_i].state == `SPX_IS) begin
                        clear_mshr_entry (
                            /* set */ line_br.set,
                            /* way */ mshr[mshr_i].way,
                            /* tag */ line_br.tag,
                            /* line */ update_mshr_value_line,
                            /* hprot */  mshr[mshr_i].hprot,
                            /* state */ `SPX_S,
                            /* word_mask_reg */ mshr[mshr_i].word_mask_reg
                        );
                    end else if (mshr[mshr_i].state == `SPX_II) begin
                        clear_mshr_entry (
                            /* set */ line_br.set,
                            /* way */ mshr[mshr_i].way,
                            /* tag */ line_br.tag,
                            /* line */ update_mshr_value_line,
                            /* hprot */  mshr[mshr_i].hprot,
                            /* state */ `SPX_I,
                            /* word_mask_reg */ mshr[mshr_i].word_mask_reg
                        );
                    end

                    // Wait for read response to be accepted before incrementing the reqs_cnt and clearing state
                    if (l2_rd_rsp_ready_int) begin
                        update_mshr_state = 1'b1;
                        update_mshr_value_state = `SPX_I;
                        incr_mshr_cnt = 1'b1;
                    end
                end
            end
            RSP_WB_ACK_HANDLER : begin
                // Once response to write-back is received:
                if (evict_stall) begin
                    // clear the state
                    lmem_set_in = mshr[mshr_i].set;
                    lmem_way_in = mshr[mshr_i].way;
                    for (int i = 0; i < `WORDS_PER_LINE; i++) begin
                        lmem_wr_data_state[i] = `SPX_I;
                    end
                    lmem_wr_en_state = 1'b1;

                    // update the evict way
                    lmem_wr_en_evict_way = 1'b1;
                    lmem_wr_data_evict_way = mshr[mshr_i].way + 1;

                    // release evict_stall.
                    clr_evict_stall = 1'b1;
                end

                // clear MSHR entry
                update_mshr_state = 1'b1;
                update_mshr_value_state = `SPX_I;
                incr_mshr_cnt = 1'b1;
            end
            FWD_MSHR_LOOKUP : begin
                rd_set_into_bufs = 1'b1;
                lmem_set_in = line_br.set;
                mshr_op_code = `L2_MSHR_PEEK_FWD;
                clr_fwd_stall_ended = 1'b1;
            end
            FWD_TAG_LOOKUP : begin
                lookup_en = 1'b1;
                lookup_mode = `L2_LOOKUP_FWD;
            end
            FWD_STALL : begin
                // Assign the incoming fwd request to fwd_in_stalled
                set_fwd_in_stalled = 1'b1;
            end
            FWD_INV_HANDLER : begin
                if (mshr_hit) begin
                    // update MSHR entry
                    // The earlier ReqS is now invalid, and when the response
                    // comes back, we should not allocate in SPX_S.
                    if (mshr[mshr_i].state == `SPX_IS) begin
                        update_mshr_state = 1'b1;
                        update_mshr_value_state = `SPX_II;
                    end
                end else if (tag_hit) begin
                    // Invalidate state of words requested in forward
                    lmem_set_in = line_br.set;
                    lmem_way_in = way_hit;
                    for (int i = 0; i < `WORDS_PER_LINE; i++) begin
                        // Only update the state for valid words in forward.
                        if (l2_fwd_in.word_mask[i] && states_buf[way_hit][i] < `SPX_R) begin
                            lmem_wr_data_state[i] = `SPX_I;
                        end else begin
                            lmem_wr_data_state[i] = states_buf[way_hit][i];
                        end
                    end
                    lmem_wr_en_state = 1'b1;
                end

                // send inv response back - we send this irrespective of  MSHR/tag hit
                // else the system will deadlock, but ideally one of them should happen.
                if (l2_rsp_out_ready_int && l2_inval_ready_int) begin
                    send_rsp_out (
                        /* coh_msg */ `RSP_INV_ACK,
                        /* req_id */ 'h0,
                        /* to_req */ 1'b0,
                        /* line_addr */ l2_fwd_in.addr,
                        /* line */ 'h0,
                        /* word_mask */ l2_fwd_in.word_mask
                    );

                    send_inval(
                        /* addr */ l2_fwd_in.addr,
                        /* hprot */ `DATA
                    );
                end
            end
            FWD_RVK_O_HANDLER : begin
                // TODO: Should we invalidate the line or downgrade to shared state?
                // Invalidate state of words requested in forward
                // If a revoke arrived when there is SPX_XR in the MSHR, that means
                // the revoke was sent after the directory acknowledged the ReqOdata. This can only
                // happen if there is reordering in the NoC.
                if (tag_hit) begin
                    lmem_set_in = line_br.set;
                    lmem_way_in = way_hit;
                    for (int i = 0; i < `WORDS_PER_LINE; i++) begin
                        // Only update the state for valid words in forward.
                        if (l2_fwd_in.word_mask[i] && states_buf[way_hit][i] == `SPX_R) begin
                            lmem_wr_data_state[i] = `SPX_I;
                        end else begin
                            lmem_wr_data_state[i] = states_buf[way_hit][i];
                        end
                    end
                    lmem_wr_en_state = 1'b1;
                end

                // send revoke response back - we send this irrespective of MSHR/tag hit
                // else the system will deadlock, but ideally one of them should happen.
                // TODO: Should we check the valid words in the line and forward word_mask
                // to set the word_mask of the response?
                if (l2_rsp_out_ready_int && l2_inval_ready_int) begin
                    send_rsp_out (
                        /* coh_msg */ `RSP_RVK_O,
                        /* req_id */ l2_fwd_in.req_id,
                        /* to_req */ 1'b0,
                        /* line_addr */ l2_fwd_in.addr,
                        /* line */ lines_buf[way_hit],
                        /* word_mask */ l2_fwd_in.word_mask
                    );

                    send_inval(
                        /* addr */ l2_fwd_in.addr,
                        /* hprot */ `DATA
                    );
                end
            end
            FWD_REQ_S_HANDLER : begin
                // TODO: When inval is implemented, wait inval_ready
                if (tag_hit) begin
                    lmem_set_in = line_br.set;
                    lmem_way_in = way_hit;
                    for (int i = 0; i < `WORDS_PER_LINE; i++) begin
                        // Update all words to invalid. Shared state if possible, if line granularity.
                        // For word granularity, you could have partially owned words. As a result,
                        // you will need to move to partially shared state for the words you own.
                        // TODO: To optimize this, we could check if data is fully owned. If yes, move
                        // to shared state and send the entire line to the requestor.
                        lmem_wr_data_state[i] = `SPX_I;
                    end
                    lmem_wr_en_state = 1'b1;
                end

                // send responses back - we send this irrespective of MSHR/tag hit
                // else the system will deadlock, but ideally one of them should happen.
                // Send RSP_S to requestor and revoke response to LLC for the fwd word_mask
                // - assuming that LLC knows all the words the L2 owns, revoke in next state.
                if (l2_rsp_out_ready_int && l2_inval_ready_int) begin
                    send_rsp_out (
                        /* coh_msg */ `RSP_S,
                        /* req_id */ l2_fwd_in.req_id,
                        /* to_req */ 1'b1,
                        /* line_addr */ l2_fwd_in.addr,
                        /* line */ lines_buf[way_hit],
                        /* word_mask */ l2_fwd_in.word_mask
                    );

                    send_inval(
                        /* addr */ l2_fwd_in.addr,
                        /* hprot */ `DATA
                    );
                end
            end
            FWD_REQ_S_HANDLER_RVK : begin
                if (l2_rsp_out_ready_int) begin
                    send_rsp_out (
                        /* coh_msg */ `RSP_RVK_O,
                        /* req_id */ l2_fwd_in.req_id,
                        /* to_req */ 1'b0,
                        /* line_addr */ l2_fwd_in.addr,
                        /* line */ lines_buf[way_hit],
                        /* word_mask */ l2_fwd_in.word_mask
                    );
                end
            end
            FWD_REQ_ODATA_HANDLER : begin
                // TODO: When inval is implemented, wait inval_ready
                if (tag_hit) begin
                    lmem_set_in = line_br.set;
                    lmem_way_in = way_hit;
                    for (int i = 0; i < `WORDS_PER_LINE; i++) begin
                        // Update all words to invalid.
                        lmem_wr_data_state[i] = `SPX_I;
                    end
                    lmem_wr_en_state = 1'b1;
                end

                // send RSP_Odata back - we send this irrespective of MSHR/tag hit
                // else the system will deadlock, but ideally one of them should happen.
                if (l2_rsp_out_ready_int && l2_inval_ready_int) begin
                    send_rsp_out (
                        /* coh_msg */ `RSP_Odata,
                        /* req_id */ l2_fwd_in.req_id,
                        /* to_req */ 1'b1,
                        /* line_addr */ l2_fwd_in.addr,
                        /* line */ lines_buf[way_hit],
                        /* word_mask */ l2_fwd_in.word_mask
                    );

                    send_inval(
                        /* addr */ l2_fwd_in.addr,
                        /* hprot */ `DATA
                    );
                end
            end     
            CPU_REQ_MSHR_LOOKUP : begin
                mshr_op_code = `L2_MSHR_PEEK_REQ;
                rd_set_into_bufs = 1'b1;
                lmem_set_in = addr_br.set;
                // TODO: Removed code related to BRESP being sent back for atomic write.
            end
            CPU_REQ_SET_CONFLICT : begin
                set_cpu_req_conflict = 1'b1;
            end
            CPU_REQ_TAG_LOOKUP : begin
                // TODO: Removed code related to setting ongoing_atomic if atomic read.
                lookup_en = 1'b1;
                lookup_mode = `L2_LOOKUP;

                // In case the CPU request is a release, set the ongoing drain.
                // The request with the release semantic must also be flushed before
                // drain is complete.
                if (l2_cpu_req.rl) begin
                    set_ongoing_drain = 1'b1;
                end
            end
            CPU_REQ_AMO_NO_REQ : begin
                send_rd_rsp(/* line */ lines_buf[cpu_req_way]);

                // Only AMO update the line if read response is accepted, else
                // the FSM will remain in this state and non-idempotent AMO operations
                // (like AMO add) might be repetitively applied.
                if (l2_rd_rsp_ready_int) begin
                    write_word_amo_helper (
                        /* line_in */ lines_buf[cpu_req_way],
                        /* word */ l2_cpu_req.word,
                        /* w_off */ addr_br.w_off,
                        /* b_off */ addr_br.b_off,
                        /* hsize */ l2_cpu_req.hsize,
                        /* amo */ l2_cpu_req.amo,
                        /* line_out */ lmem_wr_data_line
                    );

                    lmem_set_in = addr_br.set;
                    lmem_way_in = cpu_req_way;
                    lmem_wr_en_line = 1'b1;
                end
            end
            CPU_REQ_AMO_REQ : begin
                // We add the MSHR entry (and decrement the MSHR count) only
                // if the req_out is accepted.
                if (l2_req_out_ready_int) begin
                    fill_mshr_entry (
                        /* cpu_msg */ l2_cpu_req.cpu_msg,
                        /* hprot */ l2_cpu_req.hprot,
                        /* hsize */ l2_cpu_req.hsize,
                        /* tag */ addr_br.tag,
                        /* way */ cpu_req_way,
                        /* state */ `SPX_AMO,
                        /* word */ l2_cpu_req.word,
                        /* line */ lines_buf[cpu_req_way],
                        /* amo */ l2_cpu_req.amo,
                        /* word_mask */ ~word_mask_owned_next
                    );

                    send_req_out (
                        /* coh_msg */ `REQ_Odata,
                        /* hprot */ l2_cpu_req.hprot,
                        /* line_addr */ addr_br.line_addr,
                        /* line */ 'h0,
                        /* word_mask */ ~word_mask_owned_next
                    );
                end
            end
            CPU_REQ_READ_ATOMIC_NO_REQ : begin
                send_rd_rsp(/* line */ lines_buf[cpu_req_way]);
            end
            CPU_REQ_READ_ATOMIC_REQ : begin
                // We add the MSHR entry (and decrement the MSHR count) only
                // if the req_out is accepted.
                if (l2_req_out_ready_int) begin
                    fill_mshr_entry (
                        /* cpu_msg */ l2_cpu_req.cpu_msg,
                        /* hprot */ l2_cpu_req.hprot,
                        /* hsize */ l2_cpu_req.hsize,
                        /* tag */ addr_br.tag,
                        /* way */ cpu_req_way,
                        /* state */ `SPX_XR,
                        /* word */ l2_cpu_req.word,
                        /* line */ lines_buf[cpu_req_way],
                        /* amo */ 'h0,
                        /* word_mask */ ~word_mask_owned_next
                    );

                    send_req_out (
                        /* coh_msg */ `REQ_Odata,
                        /* hprot */ l2_cpu_req.hprot,
                        /* line_addr */ addr_br.line_addr,
                        /* line */ 'h0,
                        /* word_mask */ ~word_mask_owned_next
                    );
                end
            end            
            CPU_REQ_READ_NO_REQ : begin
                send_rd_rsp(/* line */ lines_buf[cpu_req_way]);
            end
            CPU_REQ_READ_REQ : begin
                // We add the MSHR entry (and decrement the MSHR count) only
                // if the req_out is accepted.
                // Though we request for a word_mask of ~word_mask_shared_next,
                // in an ideal situation this should always be WORD_MASK_ALL.
                if (l2_req_out_ready_int) begin
                    fill_mshr_entry (
                        /* cpu_msg */ l2_cpu_req.cpu_msg,
                        /* hprot */ l2_cpu_req.hprot,
                        /* hsize */ l2_cpu_req.hsize,
                        /* tag */ addr_br.tag,
                        /* way */ cpu_req_way,
                        /* state */ `SPX_IS,
                        /* word */ l2_cpu_req.word,
                        /* line */ lines_buf[cpu_req_way],
                        /* amo */ 'h0,
                        /* word_mask */ ~word_mask_shared_next
                    );

                    send_req_out (
                        /* coh_msg */ `REQ_S,
                        /* hprot */ l2_cpu_req.hprot,
                        /* line_addr */ addr_br.line_addr,
                        /* line */ 'h0,
                        /* word_mask */ ~word_mask_shared_next
                    );
                end
            end
            CPU_REQ_WRITE_ATOMIC_NO_REQ : begin
                lmem_set_in = addr_br.set;
                lmem_way_in = cpu_req_way;
                write_word_helper (
                    /* line_in */ lines_buf[cpu_req_way],
                    /* word */ l2_cpu_req.word,
                    /* w_off */ addr_br.w_off,
                    /* b_off */ addr_br.b_off,
                    /* hsize */ l2_cpu_req.hsize,
                    /* line_out */ lmem_wr_data_line
                );
                lmem_wr_en_line = 1'b1;

                send_bresp(/* bresp */ `BRESP_EXOKAY);
            end
            CPU_REQ_WRITE_ATOMIC_REQ : begin
                // If the write atomic (SC) missed in the cache,
                // it means the LR was revoked before the SC is sent, or
                // LR was never sent at all.
                send_bresp(/* bresp */ `BRESP_OKAY);
            end
            CPU_REQ_WRITE_NO_REQ : begin
                lmem_set_in = addr_br.set;
                lmem_way_in = cpu_req_way;
                write_word_helper (
                    /* line_in */ lines_buf[cpu_req_way],
                    /* word */ l2_cpu_req.word,
                    /* w_off */ addr_br.w_off,
                    /* b_off */ addr_br.b_off,
                    /* hsize */ l2_cpu_req.hsize,
                    /* line_out */ lmem_wr_data_line
                );
                lmem_wr_en_line = 1'b1;
            end
            CPU_REQ_WRITE_REQ : begin
                // We add the MSHR entry (and decrement the MSHR count) only
                // if the req_out is accepted.
                if (l2_req_out_ready_int) begin
                    fill_mshr_entry (
                        /* cpu_msg */ l2_cpu_req.cpu_msg,
                        /* hprot */ l2_cpu_req.hprot,
                        /* hsize */ l2_cpu_req.hsize,
                        /* tag */ addr_br.tag,
                        /* way */ cpu_req_way,
                        /* state */ `SPX_XR,
                        /* word */ l2_cpu_req.word,
                        /* line */ lines_buf[cpu_req_way],
                        /* amo */ 'h0,
                        /* word_mask */ ~word_mask_owned_next
                    );

                    // TODO: REQ_O currently using WORD_MASK_ALL. Need to change to
                    // word granularity at some point.
                    send_req_out (
                        /* coh_msg */ `REQ_Odata,
                        /* hprot */ l2_cpu_req.hprot,
                        /* line_addr */ addr_br.line_addr,
                        /* line */ 'h0,
                        /* word_mask */ ~word_mask_owned_next
                    );
                end
            end
            CPU_REQ_EVICT: begin
                // Store the evict_way in a different register.
                evict_way_reg = evict_way_buf;

                // Only proceed if you know you can send back an inval to L1
                if (l2_inval_ready_int) begin
                    // Use word_mask_owned_evict from l2_lookup to know whether to evict or not.
                    if (word_mask_owned_evict) begin
                        // If owned, add MSHR entry and write-back the data if req_out is ready,
                        // and set evict_stall in l2_regs.
                        if (l2_req_out_ready_int) begin
                            fill_mshr_entry (
                                /* cpu_msg */ 1'b0,
                                /* hprot */ hprots_buf[evict_way_reg],
                                /* hsize */ 'h0,
                                /* tag */ tags_buf[evict_way_reg],
                                /* way */ evict_way_reg,
                                /* state */ `SPX_RI,
                                /* word */ 'h0,
                                /* line */ lines_buf[evict_way_reg],
                                /* amo */ 'h0,
                                /* word_mask */ word_mask_owned_evict
                            );

                            send_req_out (
                                /* coh_msg */ `REQ_WB,
                                /* hprot */ hprots_buf[evict_way_reg],
                                /* line_addr */ (tags_buf[evict_way_reg] << `L2_SET_BITS) | addr_br.set,
                                /* line */ lines_buf[evict_way_reg],
                                /* word_mask */ word_mask_owned_evict
                            );
                        end

                        set_evict_stall = 1'b1;
                    end else begin
                        // update the evict way
                        lmem_wr_en_evict_way = 1'b1;
                        lmem_wr_data_evict_way = evict_way_reg + 1;

                        lmem_set_in = addr_br.set;
                        lmem_way_in = evict_way_reg;
                        for (int i = 0; i < `WORDS_PER_LINE; i++) begin
                            lmem_wr_data_state[i] = `SPX_I;
                        end
                        lmem_wr_en_state = 1'b1;
                    end

                    send_inval(
                        /* addr */ (tags_buf[evict_way_reg] << `L2_SET_BITS) | addr_br.set,
                        /* hprot */ `DATA
                    );
                end
            end
            default : begin
                mshr_op_code = `L2_MSHR_IDLE;
            end
        endcase
    end

    function void send_inval;
        input line_addr_t addr;
        input hprot_t hprot;

        l2_inval_valid_int = 1'b1;
        l2_inval_o.addr = addr;
        l2_inval_o.hprot = hprot;
    endfunction

    function void send_rd_rsp;
        input line_t line;

        l2_rd_rsp_valid_int = 1'b1;
        l2_rd_rsp_o.line = line;
    endfunction

    function void send_bresp;
        input bresp_t bresp;

        l2_bresp_valid_int = 1'b1;
        l2_bresp_o = bresp;
    endfunction

    function void send_rsp_out;
        input coh_msg_t coh_msg;
        input cache_id_t req_id;
        input logic to_req;
        input line_addr_t line_addr;
        input line_t line;
        input word_mask_t word_mask;

        l2_rsp_out_o.coh_msg = coh_msg;
        l2_rsp_out_o.req_id = req_id;
        l2_rsp_out_o.to_req = to_req;
        l2_rsp_out_o.addr = line_addr;
        l2_rsp_out_o.line = line;
        l2_rsp_out_o.word_mask = word_mask;
        l2_rsp_out_valid_int = 1'b1;
    endfunction

    function void send_req_out;
        input coh_msg_t coh_msg;
        input hprot_t hprot;
        input line_addr_t line_addr;
        input line_t line;
        input word_mask_t word_mask;

        l2_req_out_o.coh_msg = coh_msg;
        l2_req_out_o.hprot = hprot;
        l2_req_out_o.addr = line_addr;
        l2_req_out_o.line = line;
        l2_req_out_o.word_mask = word_mask;
        l2_req_out_valid_int = 1'b1;
    endfunction

    function void clear_mshr_entry;
        input l2_set_t set;
        input l2_way_t way;
        input l2_tag_t tag;
        input line_t line;
        input hprot_t hprot;
        input state_t state;
        input word_mask_t word_mask;

        lmem_set_in = set;
        lmem_way_in = way;
        lmem_wr_data_tag = tag;
        lmem_wr_data_line = line;
        lmem_wr_data_hprot = hprot;
        // TODO: If we're doing state at word granularity, the state for a line
        // needs to be read-modify-written back.
        // Right now, we're overwritting the old state!
        for (int i = 0; i < `WORDS_PER_LINE; i++) begin
            if (word_mask[i]) begin
                lmem_wr_data_state[i] = state;
            end else begin
                lmem_wr_data_state[i] = states_buf[way][i];
            end
        end
        lmem_wr_en_clear_mshr = 1'b1;
    endfunction

    function void fill_mshr_entry;
        input cpu_msg_t cpu_msg;
        input hprot_t hprot;
        input hsize_t hsize;
        input l2_tag_t tag;
        input l2_way_t way;
        input unstable_state_t state;
        input word_t word;
        input line_t line;
        input amo_t amo;
        input word_mask_t word_mask;

        update_mshr_value_cpu_msg = cpu_msg;
        update_mshr_value_hprot = hprot;
        update_mshr_value_hsize = hsize;
        update_mshr_value_tag = tag;
        update_mshr_value_way = way;
        update_mshr_value_line = line;
        update_mshr_value_state = state;
        update_mshr_value_word = word;
        update_mshr_value_amo = amo;
        // word_mask_reg stores the original requested value of word_mask,
        // as word_mask can be altered as responses are serviced.
        update_mshr_value_word_mask = word_mask;
        update_mshr_value_word_mask_reg = word_mask;
        add_mshr_entry = 1'b1;
    endfunction

    function void write_word_helper;
        input line_t line_i;
        input word_t word;
        input word_offset_t w_off;
        input byte_offset_t b_off;
        input hsize_t hsize;
        output line_t line_out;

        write_word_line_in = line_i;
        write_word_word_in = word;
        write_word_w_off_in = w_off;
        write_word_b_off_in = b_off;
        write_word_hsize_in = hsize;
        line_out = write_word_line_out;
    endfunction

    function void write_word_amo_helper;
        input line_t line_i;
        input word_t word;
        input word_offset_t w_off;
        input byte_offset_t b_off;
        input hsize_t hsize;
        input amo_t amo;
        output line_t line_out;

        write_word_amo_line_in = line_i;
        write_word_amo_word_in = word;
        write_word_amo_w_off_in = w_off;
        write_word_amo_b_off_in = b_off;
        write_word_amo_hsize_in = hsize;
        write_word_amo_amo_in = amo;
        line_out = write_word_amo_line_out;
    endfunction

    function void write_line_helper;
        input line_t line_orig;
        input line_t line_in;
        input word_mask_t word_mask_i;
        output line_t line_out;

        for (int i = 0; i < `WORDS_PER_LINE; i++) begin
            if (word_mask_i[i]) begin
                line_out[i * `BITS_PER_WORD +: `BITS_PER_WORD] =
                    line_in[i * `BITS_PER_WORD +: `BITS_PER_WORD];
            end else begin
                line_out[i * `BITS_PER_WORD +: `BITS_PER_WORD] =
                    line_orig[i * `BITS_PER_WORD +: `BITS_PER_WORD];
            end
        end
    endfunction

endmodule

// module l2_fsm(
//     input logic clk,
//     input logic rst,
//     input logic do_flush_next,
//     input logic do_rsp_next,
//     input logic do_fwd_next,
//     input logic do_ongoing_flush_next,
//     input logic do_cpu_req_next,
//     input logic is_flush_all,
//     input logic l2_rd_rsp_ready_int,
//     input logic l2_req_out_ready_int,
//     input logic l2_rsp_out_ready_int,
//     input logic l2_inval_ready_int,
//     input logic l2_bresp_ready_int,
//     input logic fwd_stall,
//     input logic evict_stall,
//     input logic ongoing_flush,
//     input logic set_fwd_stall,
//     input logic clr_fwd_stall,
//     input logic reqs_hit,
//     input logic reqs_hit_next,
//     input logic set_conflict,
//     input logic set_set_conflict_reqs,
//     input logic ongoing_atomic,
//     input logic clr_set_conflict_reqs,
//     input logic tag_hit_next,
//     input logic empty_way_found_next,
//     input logic tag_hit,
//     input logic incr_flush_set,
//     input var logic [`REQS_BITS-1:0] reqs_i,
//     input var logic [`REQS_BITS-1:0] reqs_i_next,
//     input var logic [`L2_SET_BITS:0] flush_set,
//     input var logic [`L2_WAY_BITS:0] flush_way,
//     input l2_way_t way_hit,
//     input l2_way_t empty_way,
//     input l2_way_t evict_way_buf,
//     input l2_way_t way_hit_next,
//     input line_t line_out,
//     input var reqs_buf_t reqs[`N_REQS],
//     input var state_t states_buf[`L2_WAYS],
//     input var hprot_t hprots_buf[`L2_WAYS],
//     input var state_t rd_data_state[`L2_NUM_PORTS][`WORDS_PER_LINE],
//     input var hprot_t rd_data_hprot[`L2_NUM_PORTS],
//     input var line_t lines_buf[`L2_WAYS],
//     input var l2_tag_t tags_buf[`L2_WAYS],
//     input word_mask_t word_mask_shared,
//     input word_mask_t word_mask_owned,

//     line_breakdown_l2_t.in line_br,
//     line_breakdown_l2_t.in line_br_next,
//     addr_breakdown_t.in addr_br,
//     addr_breakdown_t.in addr_br_next,
//     l2_rsp_in_t.in l2_rsp_in,
//     l2_fwd_in_t.in l2_fwd_in,
//     l2_cpu_req_t.in l2_cpu_req,

//     output logic decode_en,
//     output logic lookup_en,
//     output logic rd_mem_en,
//     output logic lookup_mode,
//     output logic wr_rst,
//     output logic wr_en_state,
//     output logic fill_reqs,
//     output logic wr_en_line,
//     output logic wr_req_state,
//     output logic wr_req_state_atomic,
//     output logic wr_req_invack_cnt,
//     output logic wr_req_line,
//     output logic wr_en_clear_mshr,
//     output logic wr_req_tag,
//     output logic wr_req_word_mask,
//     output logic clear_mshr_atomic,
//     output logic wr_en_evict_way,
//     output logic l2_rd_rsp_valid_int,
//     output logic l2_req_out_valid_int,
//     output logic l2_rsp_out_valid_int,
//     output logic l2_inval_valid_int,
//     output logic l2_bresp_valid_int,
//     output logic incr_reqs_cnt,
//     output logic set_ongoing_atomic,
//     output logic incr_flush_way,
//     output logic clr_evict_stall,
//     output logic set_fwd_in_stalled,
//     output logic clr_fwd_stall_ended,
//     output logic set_set_conflict_fsm,
//     output logic clr_set_conflict_fsm,
//     output logic set_cpu_req_conflict,
//     output logic clr_ongoing_atomic,
//     output logic fill_reqs_flush,
//     output logic set_evict_stall,
//     output logic lr_to_xmw,
//     output logic [2:0] reqs_op_code,
//     output logic[`REQS_BITS-1:0]  reqs_atomic_i,
//     output state_t wr_data_state[`WORDS_PER_LINE],
//     output unstable_state_t state_wr_data_req,
//     output line_t wr_data_line,
//     output line_t line_wr_data_req,
//     output hprot_t wr_data_hprot,
//     output hprot_t hprot_wr_data_req,
//     output l2_tag_t wr_data_tag,
//     output l2_tag_t tag_estall_wr_data_req,
//     output l2_tag_t tag_wr_data_req,
//     output invack_cnt_calc_t invack_cnt_wr_data_req,
//     output hsize_t hsize_wr_data_req,
//     output word_t word_wr_data_req,
//     output cpu_msg_t cpu_msg_wr_data_req,
//     output amo_t amo_wr_data_req,
//     output word_mask_t word_mask_wr_data_req,
//     output l2_set_t set_in,
//     output l2_way_t way,
//     output l2_way_t way_wr_data_req,
//     output l2_way_t wr_data_evict_way,
//     output bresp_t l2_bresp_o,
//     output word_t word_in,
//     output word_offset_t w_off_in,
//     output byte_offset_t b_off_in,
//     output hsize_t hsize_in,
//     output line_t line_in,

//     addr_breakdown_t.out addr_br_reqs,
//     l2_rd_rsp_t.out l2_rd_rsp_o,
//     l2_rsp_out_t.out l2_rsp_out_o,
//     l2_req_out_t.out l2_req_out_o,
//     l2_inval_t.out l2_inval_o
//    );

//     localparam RESET = 5'b00000;
//     localparam DECODE = 5'b00001;

//     localparam RSP_MSHR_LOOKUP = 5'b00010;
//     localparam RSP_O_HANDLER = 5'b00011;
//     localparam RSP_S_HANDLER = 5'b00100;

//     localparam FWD_MSHR_LOOKUP = 5'b01000;
//     localparam FWD_TAG_LOOKUP = 5'b01001;
//     localparam FWD_STALL = 5'b01010;
//     localparam FWD_HIT = 5'b01011;
//     localparam FWD_HIT_2 = 5'b01100;
//     localparam FWD_NO_HIT = 5'b01101;
//     localparam FWD_NO_HIT_2 = 5'b01110;

//     localparam ONGOING_FLUSH_LOOKUP = 5'b01111;
//     localparam ONGOING_FLUSH_PROCESS = 5'b10000;

//     localparam CPU_REQ_MSHR_LOOKUP = 5'b10001;
//     localparam CPU_REQ_READ_NO_REQ = 5'b10010;
//     localparam CPU_REQ_READ_REQ = 5'b10011;
//     localparam CPU_REQ_WRITE_NO_REQ = 5'b10100;
//     localparam CPU_REQ_WRITE_REQ = 5'b10101;
//     localparam CPU_REQ_TAG_LOOKUP = 5'b10110;
//     localparam CPU_REQ_EMPTY_WAY = 5'b11010;
//     localparam CPU_REQ_EVICT = 5'b11011;

//     logic [4:0] state, next_state;
//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             state <= RESET;
//         end else begin
//             state <= next_state;
//         end
//     end

//     logic rst_en;
//     assign rst_en = (state == RESET);
//     assign decode_en = (state == DECODE);

//     l2_set_t rst_set;
//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             rst_set <= 0;
//         end else if (rst_en) begin
//             rst_set <= rst_set + 1;
//         end
//     end

//     logic update_atomic;
//     line_addr_t atomic_line_addr;
//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             atomic_line_addr <= 0;
//         end else if (update_atomic) begin
//             atomic_line_addr <= addr_br.line_addr;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             reqs_atomic_i <= 0;
//         end else if (update_atomic) begin
//             reqs_atomic_i <= reqs_i;
//         end
//     end

//     logic[1:0] ready_bits;
//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             ready_bits <= 0;
//         end else if (state == DECODE) begin
//             ready_bits <= 0;
//         end else if ((state == CPU_REQ_EVICT || state == FWD_NO_HIT || state == FWD_HIT) && l2_inval_ready_int) begin
//             ready_bits[0] <= 1'b1;
//         end else if ((state == CPU_REQ_EVICT && l2_req_out_ready_int) || ((state == FWD_NO_HIT || state == FWD_HIT) && l2_rsp_out_ready_int)) begin
//             ready_bits[1] <= 1'b1;
//         end
//     end

//     l2_way_t evict_way_tmp;

//     // FSM 1
//     // Decide which state to go to next;
//     // no outputs updated.
//     always_comb begin
//         next_state = state;
//         case (state)
//             RESET : begin
//                 if (rst_set == `L2_SETS - 1) begin
//                     next_state = DECODE;
//                 end
//             end
//             // Default state for the controller; driven
//             // by inputs from input_decoder module.
//             // - do_flush_next: New flush request received
//             // - do_rsp_next: Response to earlier req_out/fwd_out received
//             // - do_fwd_next: Forward received from other L2/LLC
//             // - do_ongoing_flush_next: Continue next set of ongoing flush
//             // - do_cpu_req_next: New input request received
//             // TODO: add fences
//             DECODE : begin
//                 if (do_flush_next) begin
//                     next_state = DECODE;
//                 end else if (do_rsp_next) begin
//                     next_state = RSP_MSHR_LOOKUP;
//                 end else if (do_fwd_next) begin
//                     next_state = FWD_MSHR_LOOKUP;
//                 end else if (do_ongoing_flush_next) begin
//                     next_state = ONGOING_FLUSH_LOOKUP;
//                 end else if (do_cpu_req_next) begin
//                     next_state = CPU_REQ_MSHR_LOOKUP;
//                 end
//             end
//             // If new response received, lookup the coherence message
//             // of the response.
//             RSP_MSHR_LOOKUP : begin
//                 // TODO: Should we update the word_mask in reqs[reqs_i] here?
//                 // Maybe, we should update word_mask here, and only transition to
//                 // the handler that finally removes the MSHR entry and/or updates
//                 // data into the RAMs.
//                 // TODO: Don't we need to check if the response matches
//                 // an entry in the MSHR? FSM 2 does do a L2_REQS_LOOKUP, but it does
//                 // not test whether there was a hit or not. In the current design,
//                 // if there is no hit, we still end up clearing whatever reqs_i_next
//                 // was earlier.
//                 if (reqs_hit_next) begin
//                     case(l2_rsp_in.coh_msg)
//                         `RSP_O : begin
//                             next_state = RSP_O_HANDLER;
//                         end
//                         `RSP_S : begin
//                             next_state = RSP_S_HANDLER;
//                         end
//                         default : begin
//                             next_state = DECODE;
//                         end
//                     endcase
//                 end
//             end
//             RSP_O_HANDLER : begin
//                 next_state = DECODE;
//             end
//             RSP_S_HANDLER : begin
//                 // Regular shared state request - from SPX_I to SPX_S.
//                 // If all words are received, FSM 2 will send the read response
//                 // to the core, and FSM 1 will wait for the response to be accepted.
//                 // If all words are not received, FSM 2 will update word_mask in the reqs entry
//                 // and FSM 1 will go back to decode.
//                 if (reqs[reqs_i].state == `SPX_IS) begin
//                     if (reqs[reqs_i].word_mask == `WORD_MASK_ALL) begin
//                         if (l2_rd_rsp_ready_int) begin
//                             next_state = DECODE;
//                         end
//                     end else begin
//                         next_state = DECODE;
//                     end
//                 end else begin
//                     // TODO: Add new state to handle SPX_II
//                     next_state = DECODE;
//                 end
//             end
//             // RSP_MSHR_LOOKUP : begin
//             //     case(l2_rsp_in.coh_msg)
//             //         `RSP_EDATA : begin
//             //             next_state = RSP_E_DATA_ISD;
//             //         end
//             //         `RSP_DATA : begin
//             //             case(reqs[reqs_i_next].state)
//             //                 `ISD : begin
//             //                     next_state = RSP_E_DATA_ISD;
//             //                 end
//             //                 `IMAD : begin
//             //                     next_state = RSP_DATA_XMAD;
//             //                 end
//             //                 `SMAD : begin
//             //                     next_state = RSP_DATA_XMAD;
//             //                 end
//             //                 `IMADW : begin
//             //                     next_state = RSP_DATA_XMADW;
//             //                 end
//             //                 `SMADW : begin
//             //                     next_state = RSP_DATA_XMADW;
//             //                 end
//             //                 default : begin
//             //                     next_state = DECODE;
//             //                 end
//             //             endcase
//             //         end
//             //         `RSP_INVACK : begin
//             //             next_state = RSP_INVACK;
//             //         end
//             //         `RSP_PUTACK : begin
//             //             next_state = RSP_PUTACK;
//             //         end
//             //         default : begin
//             //             next_state = DECODE;
//             //         end
//             //     endcase
//             // end
//             // RSP_E_DATA_ISD : begin
//             //     if (l2_rd_rsp_ready_int) begin
//             //         next_state = DECODE;
//             //     end
//             // end
//             // RSP_DATA_XMAD : begin
//             //     next_state = DECODE;
//             // end
//             // RSP_DATA_XMADW : begin
//             //     if (l2_rd_rsp_ready_int) begin
//             //         next_state = DECODE;
//             //     end
//             // end
//             // RSP_INVACK : begin
//             //     next_state = DECODE;
//             // end
//             // RSP_PUTACK : begin
//             //     if (l2_req_out_ready_int || !evict_stall) begin
//             //         next_state  = DECODE;
//             //     end
//             // end
//             // If new forward received, check if we're in fwd_stall or not
//             // (L2_REQS_PEEK_FWD in FSM 2 will set fwd_stall). If not,
//             // L2_REQS_PEEK_FWD in FSM 2 will set reqs_hit_next and reqs_i_next.
//             // TODO: Need to check how to handle if no hit - what does
//             // FWD_TAG_LOOKUP do here?
//             // TODO: FWD_NO_HIT and FWD_NO_HIT_2 seem specific to their protocol -
//             // need to adapt as necessary to Spandex forward handler.
//             // TODO: For Spandex, we may need to service forwards during fwd_stall
//             // as well, so the FWD_STALL state should not just go back to DECODE.
//             FWD_MSHR_LOOKUP : begin
//                 if ((fwd_stall || set_fwd_stall) & !clr_fwd_stall) begin
//                     next_state = FWD_STALL;
//                 end else if (reqs_hit_next) begin
//                     next_state = FWD_HIT;
//                 end else begin
//                     next_state = FWD_TAG_LOOKUP;
//                 end
//             end
//             FWD_TAG_LOOKUP : begin
//                 next_state = FWD_NO_HIT;
//             end
//             FWD_STALL : begin
//                 next_state = DECODE;
//             end
//             // TODO: Add a switch case here on reqs[reqs_i].state
//             // for all the forwards in our no fwd_stall handler.
//             // In FSM 2, we need to add the actual rsp_out updates.
//             // I think this FSM will proceed back to DECODE
//             // as soon as rsp_out_ready is high, for example.
//             FWD_HIT : begin
//                 if (reqs[reqs_i].state == `SMAD || reqs[reqs_i].state == `SMADW) begin
//                     if (l2_fwd_in.coh_msg == `FWD_INV) begin
//                         if (l2_rsp_out_ready_int && l2_inval_ready_int) begin
//                             next_state = DECODE;
//                         end else if (ready_bits[0] && l2_rsp_out_ready_int) begin
//                             next_state = DECODE;
//                         end else if (ready_bits[1] && l2_inval_ready_int) begin
//                             next_state = DECODE;
//                         end
//                     end else begin
//                         if (l2_inval_ready_int) begin
//                             next_state = DECODE;
//                         end
//                     end
//                 end else if (reqs[reqs_i].state == `MIA) begin
//                     if (l2_fwd_in.coh_msg == `FWD_GETS && l2_rsp_out_ready_int) begin
//                         next_state = FWD_HIT_2;
//                     end else if (l2_rsp_out_ready_int) begin
//                         next_state = DECODE;
//                     end
//                 end else if (reqs[reqs_i].state == `SIA) begin
//                     if (l2_fwd_in.coh_msg == `FWD_INV && l2_rsp_out_ready_int) begin
//                         next_state = DECODE;
//                     end else if (l2_fwd_in.coh_msg != `FWD_INV) begin
//                         next_state = DECODE;
//                     end
//                 end else begin
//                     next_state = DECODE;
//                 end
//             end
//             FWD_HIT_2 : begin
//                 if (l2_rsp_out_ready_int) begin
//                     next_state = DECODE;
//                 end
//             end
//             FWD_NO_HIT : begin
//                 if ((l2_inval_ready_int && l2_rsp_out_ready_int) ||
//                     (l2_inval_ready_int && ready_bits[1]) ||
//                     (ready_bits[0] && l2_rsp_out_ready_int) ||
//                     (l2_inval_ready_int && l2_fwd_in.coh_msg == `FWD_INV_LLC) ||
//                     (l2_rsp_out_ready_int && l2_fwd_in.coh_msg == `FWD_GETS)) begin
//                     if (l2_fwd_in.coh_msg == `FWD_GETS) begin
//                         next_state = FWD_NO_HIT_2;
//                     end else begin
//                         next_state = DECODE;
//                     end
//                 end
//             end
//             FWD_NO_HIT_2 : begin
//                 if (l2_rsp_out_ready_int) begin
//                     next_state = DECODE;
//                 end
//             end
//             // Check if the flush_way (from l2_regs) has valid data,
//             // and if it has data (instr don't need write-back). If yes,
//             // go to next state ONGOING_FLUSH_PROCESS and wait
//             // for write-back to complete.
//             // TODO: update according to Spandex logic from SystemC.
//             ONGOING_FLUSH_LOOKUP : begin
//                 if ((rd_data_state[flush_way] != `INVALID) && (is_flush_all || rd_data_hprot[flush_way])) begin
//                     next_state = ONGOING_FLUSH_PROCESS;
//                 end else begin
//                     next_state = DECODE;
//                 end
//             end
//             ONGOING_FLUSH_PROCESS : begin
//                 if (l2_req_out_ready_int) begin
//                     next_state = DECODE;
//                 end
//             end
//             // If new input request is received, check if there is an ongoing atomic
//             // or set conflict. CPU_REQ_MSHR_LOOKUP in FSM 2 will also check reqs to
//             // see if new set_conflict needs to be set.
//             // If write atomic, this FSM will also wait for BRESP to be accepted.
//             // If none of the above, check tag RAMs to know if hit or not.
//             CPU_REQ_MSHR_LOOKUP : begin
//                 // TODO: All code related to ongoing atomic and set conflict removed. Add later.
//                 next_state = CPU_REQ_TAG_LOOKUP;
//             end
//             CPU_REQ_TAG_LOOKUP : begin
//                 // TODO: All code related to atomic read/write removed. Add later.
//                 // TODO: Add eviction check for REQ_S where line is partially owned.
//                 // If tag is hit, check:
//                 // - if it is a non-FCS read (REQ_S) and all words in the line are at least shared.
//                 // - if it is a non-FCS write (REQ_O) and all words in the line are at least owned.
//                 // TODO: currently, REQ_O requires all words to be owned, but that should not be
//                 // necessary for word-granularity writes.
//                 if (tag_hit_next) begin
//                     if (l2_cpu_req.cpu_msg == `READ) begin
//                         if (word_mask_shared == `WORD_MASK_ALL) begin
//                             next_state = CPU_REQ_READ_NO_REQ;
//                         end else begin
//                             next_state = CPU_REQ_READ_REQ;
//                         end
//                     end else if (l2_cpu_req.cpu_msg == `WRITE) begin
//                         if (word_mask_owned == `WORD_MASK_ALL) begin
//                             next_state = CPU_REQ_WRITE_NO_REQ;
//                         end else begin
//                             next_state = CPU_REQ_WRITE_REQ;
//                         end
//                     end
//                 end else if (empty_way_found_next) begin
//                     next_state = CPU_REQ_EMPTY_WAY;
//                 end else begin
//                     next_state = CPU_REQ_EVICT;
//                 end
//             end
//             CPU_REQ_READ_NO_REQ : begin
//                 if (l2_rd_rsp_ready_int) begin
//                     next_state = DECODE;
//                 end
//             end
//             CPU_REQ_READ_REQ : begin
//                 if (l2_req_out_ready_int) begin
//                     next_state = DECODE;
//                 end
//             end
//             CPU_REQ_WRITE_NO_REQ : begin
//                 next_state = DECODE;
//             end
//             CPU_REQ_WRITE_REQ : begin
//                 if (l2_req_out_ready_int) begin
//                     next_state = DECODE;
//                 end
//             end
//             CPU_REQ_EMPTY_WAY : begin
//                 if (l2_req_out_ready_int) begin
//                     next_state = DECODE;
//                 end
//             end
//             CPU_REQ_EVICT : begin
//                 if (l2_inval_ready_int && l2_req_out_ready_int) begin
//                     next_state = DECODE;
//                 end else if (ready_bits[0] && l2_req_out_ready_int) begin
//                     next_state = DECODE;
//                 end else if (l2_inval_ready_int && ready_bits[1]) begin
//                     next_state = DECODE;
//                 end
//             end

//             // CPU_REQ_MSHR_LOOKUP : begin
//             //      if (ongoing_atomic) begin
//             //         if (atomic_line_addr != addr_br.line_addr) begin
//             //             next_state = CPU_REQ_ATOMIC_OVERRIDE;
//             //         end else begin
//             //             if (l2_cpu_req.cpu_msg == `READ || l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
//             //                 next_state = CPU_REQ_ATOMIC_CONTINUE_READ;
//             //             end else begin
//             //                 next_state = CPU_REQ_ATOMIC_CONTINUE_WRITE;
//             //             end
//             //         end
//             //     end else if ((set_conflict | set_set_conflict_reqs) & !clr_set_conflict_reqs) begin
//             //         next_state = CPU_REQ_SET_CONFLICT;
//             //     end else if (!ongoing_atomic && l2_cpu_req.cpu_msg == `WRITE_ATOMIC) begin
//             //         if (l2_bresp_ready_int) begin
//             //             next_state = DECODE;
//             //         end
//             //     end else begin
//             //         next_state = CPU_REQ_TAG_LOOKUP;
//             //     end
//             // end
//             // CPU_REQ_ATOMIC_OVERRIDE : begin
//             //     next_state = DECODE;
//             // end
//             // CPU_REQ_ATOMIC_CONTINUE_READ : begin
//             // if (l2_rd_rsp_ready_int || l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
//             //         next_state = DECODE;
//             //     end
//             // end
//             // CPU_REQ_ATOMIC_CONTINUE_WRITE : begin
//             //     if (l2_bresp_ready_int) begin
//             //         next_state = DECODE;
//             //     end
//             // end
//             // CPU_REQ_SET_CONFLICT : begin
//             //     next_state = DECODE;
//             // end
//             // CPU_REQ_TAG_LOOKUP : begin
//             //     if (tag_hit_next) begin
//             //         if (l2_cpu_req.cpu_msg == `READ || (l2_cpu_req.cpu_msg == `READ_ATOMIC
//             //                 && (states_buf[way_hit_next] == `EXCLUSIVE || states_buf[way_hit_next] == `MODIFIED)))  begin
//             //             next_state = CPU_REQ_READ_READ_ATOMIC_EM;
//             //         end else if ((l2_cpu_req.cpu_msg == `READ_ATOMIC && states_buf[way_hit_next] == `SHARED)
//             //                 || (l2_cpu_req.cpu_msg == `WRITE && states_buf[way_hit_next] == `SHARED)) begin
//             //             next_state = CPU_REQ_READ_ATOMIC_WRITE_S;
//             //         end else if (l2_cpu_req.cpu_msg == `WRITE && (states_buf[way_hit_next] == `EXCLUSIVE
//             //                 || states_buf[way_hit_next] == `MODIFIED)) begin
//             //             next_state = CPU_REQ_WRITE_EM;
//             //         end else begin
//             //             next_state = DECODE;
//             //         end
//             //     end else if (empty_way_found_next) begin
//             //         next_state = CPU_REQ_EMPTY_WAY;
//             //     end else begin
//             //         next_state = CPU_REQ_EVICT;
//             //     end
//             // end
//             // CPU_REQ_READ_READ_ATOMIC_EM : begin
//             //     if (l2_rd_rsp_ready_int) begin
//             //         next_state = DECODE;
//             //     end
//             // end
//             // CPU_REQ_READ_ATOMIC_WRITE_S : begin
//             //     if (l2_req_out_ready_int) begin
//             //         next_state = DECODE;
//             //     end
//             // end
//             // CPU_REQ_WRITE_EM : begin
//             //     next_state = DECODE;
//             // end
//             // CPU_REQ_EMPTY_WAY : begin
//             //     if (l2_req_out_ready_int) begin
//             //         next_state = DECODE;
//             //     end
//             // end
//             // CPU_REQ_EVICT : begin
//             //     if (l2_inval_ready_int && l2_req_out_ready_int) begin
//             //         next_state = DECODE;
//             //     end else if (ready_bits[0] && l2_req_out_ready_int) begin
//             //         next_state = DECODE;
//             //     end else if (l2_inval_ready_int && ready_bits[1]) begin
//             //         next_state = DECODE;
//             //     end
//             // end
//         endcase
//     end

//     addr_t addr_tmp;
//     line_addr_t line_addr_tmp;
//     unstable_state_t state_tmp;
//     coh_msg_t coh_msg_tmp;

//     // FSM 2
//     // Based on next state decided in FSM 1,
//     // update outputs for that next state.
//     always_comb begin
//         wr_rst = 1'b0;
//         wr_data_state = 0;
//         reqs_op_code = `L2_MSHR_IDLE;
//         lookup_en = 1'b0;
//         lookup_mode = 1'b0;
//         wr_req_state = 1'b0;
//         wr_req_state_atomic = 1'b0;
//         wr_req_line = 1'b0;
//         wr_req_invack_cnt = 0;
//         wr_req_tag = 1'b0;
//         wr_en_clear_mshr = 1'b0;
//         wr_en_state = 1'b0;
//         wr_en_line = 1'b0;
//         wr_en_evict_way = 1'b0;
//         set_in = 0;
//         way = 0;
//         way_wr_data_req = 0;
//         wr_data_tag = 0;
//         wr_data_hprot = 0;
//         wr_data_line = 0;
//         wr_data_state = 0;
//         wr_data_evict_way = 0;
//         incr_reqs_cnt = 1'b0;
//         set_ongoing_atomic = 1'b0;
//         rd_mem_en = 1'b0;
//         incr_flush_way = 1'b0;
//         addr_tmp = 0;
//         line_addr_tmp = 0;
//         state_tmp = 0;
//         coh_msg_tmp = 0;
//         fill_reqs = 1'b0;
//         fill_reqs_flush = 1'b0;

//         set_fwd_in_stalled = 1'b0;
//         clr_fwd_stall_ended = 1'b0;
//         set_set_conflict_fsm = 1'b0;
//         clr_set_conflict_fsm = 1'b0;
//         set_cpu_req_conflict = 1'b0;
//         clr_ongoing_atomic  = 1'b0;
//         update_atomic = 1'b0;
//         clr_evict_stall = 1'b0;
//         set_evict_stall = 1'b0;
//         clear_mshr_atomic = 1'b0;
//         lr_to_xmw = 1'b0;

//         l2_rd_rsp_o.line = 0;
//         l2_rd_rsp_valid_int = 1'b0;
//         l2_inval_o.addr = 0;
//         l2_inval_o.hprot = 1'b0;
//         l2_inval_valid_int = 1'b0;
//         l2_bresp_valid_int = 1'b0;
//         l2_bresp_o = `BRESP_OKAY;

//         addr_br_reqs.line = 0;
//         addr_br_reqs.line_addr = 0;
//         addr_br_reqs.word = 0;
//         addr_br_reqs.tag = 0;
//         addr_br_reqs.set = 0;
//         addr_br_reqs.w_off = 0;
//         addr_br_reqs.b_off = 0;

//         cpu_msg_wr_data_req = 0;
//         tag_estall_wr_data_req = 0;
//         invack_cnt_wr_data_req = 0;
//         hsize_wr_data_req = 0;
//         state_wr_data_req = 0;
//         hprot_wr_data_req = 0;
//         word_wr_data_req = 0;
//         line_wr_data_req = 0;
//         tag_wr_data_req = 0;
//         amo_wr_data_req = 0;

//         wr_req_word_mask = 0;
//         word_mask_wr_data_req = 0;

//         l2_req_out_valid_int = 1'b0;
//         l2_req_out_o.coh_msg = 0;
//         l2_req_out_o.hprot = 0;
//         l2_req_out_o.addr = 0;
//         l2_req_out_o.line = 0;
//         l2_req_out_o.word_mask = 0;

//         l2_rsp_out_valid_int = 1'b0;
//         l2_rsp_out_o.coh_msg = 0;
//         l2_rsp_out_o.req_id = 0;
//         l2_rsp_out_o.to_req = 1'b0;
//         l2_rsp_out_o.addr = 0;
//         l2_rsp_out_o.line = 0;
//         l2_rsp_out_o.word_mask = 0;

//         word_in = 0;
//         w_off_in = 0;
//         b_off_in = 0;
//         hsize_in = 0;
//         line_in = 0;

//         evict_way_tmp = 0;

//         case (state)
//             RESET : begin
//                 wr_rst = 1'b1;
//                 wr_data_state = 0;
//                 set_in = rst_set;
//             end
//             DECODE : begin
//                 if (do_ongoing_flush_next) begin
//                     if (incr_flush_set) begin
//                         set_in = flush_set + 1;
//                     end else begin
//                         set_in = flush_set;
//                     end
//                 end else if (do_fwd_next) begin
//                     set_in = line_br_next.set;
//                 end else if (do_cpu_req_next) begin
//                     set_in = addr_br_next.set;
//                 end
//             end
//             RSP_MSHR_LOOKUP : begin
//                 reqs_op_code = `L2_REQS_LOOKUP;
//             end
//             // TODO: The current RSP_O implementation assumes word granularity REQ_O;
//             // If we want to do line granularity REQ_O, we need to take care of read-modify-write
//             // of the words that the CPU did not update.
//             // The other option to implement line granularity with the current protocol, is to use REQ_Odata.
//             RSP_O_HANDLER : begin
//                 word_mask_wr_data_req = reqs[reqs_i].word_mask & ~l2_rsp_in.word_mask;
//                 wr_req_word_mask = 1'b1;

//                 // If all words requested have been received,
//                 // update the reqs entry state and increment the reqs_cnt
//                 if (~reqs[reqs_i].word_mask) begin
//                     wr_req_state = 1'b1;
//                     state_wr_data_req = `SPX_I;
//                     wr_en_clear_mshr = 1'b1;
//                     incr_reqs_cnt = 1'b1;

//                     // clear_mshr - Update the RAMs
//                     // TODO: Is it possible to abstract the clear_mshr process into a function?
//                     set_in = line_br.set;
//                     way = reqs[reqs_i].way;
//                     wr_data_tag = line_br.tag;
//                     wr_data_line = reqs[reqs_i].line;
//                     wr_data_hprot = reqs[reqs_i].hprot;
//                     wr_data_state = `SPX_R;
//                 end
//             end
//             RSP_S_HANDLER : begin
//                 // Update the reqs entry line and word mask only for valid words in the response.
//                 wr_req_line = 1'b1;
//                 line_wr_data_req = l2_rsp_in.line;
//                 word_mask_wr_data_req = reqs[reqs_i].word_mask | l2_rsp_in.word_mask;
//                 wr_req_word_mask = 1'b1;

//                 // If all words requested have been received,
//                 // update the reqs entry state and increment the reqs_cnt
//                 if (word_mask_wr_data_req == `WORD_MASK_ALL) begin
//                     send_rd_rsp(l2_rsp_in.line);
//                     wr_req_state = 1'b1;
//                     state_wr_data_req = `SPX_I;
//                     wr_en_clear_mshr = 1'b1;

//                     // clear_mshr - Update the RAMs
//                     clear_mshr(line_br.set, reqs[reqs_i].way, line_br.tag, reqs[reqs_i].line, reqs[reqs_i].hprot, `SPX_S);

//                     // Wiat for read response to be accepted before incrementing the reqs_cnt
//                     if (l2_rd_rsp_ready_int) begin
//                         incr_reqs_cnt = 1'b1;
//                     end
//                 end
//             end
//             // RSP_E_DATA_ISD : begin
//             //     l2_rd_rsp_valid_int = 1'b1;
//             //     l2_rd_rsp_o.line = l2_rsp_in.line;
//             //     wr_req_state = 1'b1;
//             //     state_wr_data_req = `INVALID;
//             //     wr_en_clear_mshr = 1'b1;
//             //     set_in = line_br.set;
//             //     way = reqs[reqs_i].way;
//             //     wr_data_tag = line_br.tag;
//             //     wr_data_line = l2_rsp_in.line;
//             //     wr_data_hprot = reqs[reqs_i].hprot;
//             //     wr_data_state = (l2_rsp_in.coh_msg == `RSP_EDATA) ? `EXCLUSIVE : `SHARED;

//             //     //only increment once if not ready
//             //      if (l2_rd_rsp_ready_int) begin
//             //         incr_reqs_cnt = 1'b1;
//             //     end
//             // end
//             // RSP_DATA_XMAD : begin
//             //     line_in = l2_rsp_in.line;
//             //     word_in = reqs[reqs_i].word;
//             //     w_off_in = reqs[reqs_i].w_off;
//             //     b_off_in = reqs[reqs_i].b_off;
//             //     hsize_in = reqs[reqs_i].hsize;

//             //     invack_cnt_wr_data_req = reqs[reqs_i].invack_cnt + l2_rsp_in.invack_cnt;
//             //     wr_req_invack_cnt = 1'b1;
//             //     if (invack_cnt_wr_data_req == `MAX_N_L2) begin
//             //         wr_en_clear_mshr = 1'b1;
//             //         set_in = line_br.set;
//             //         way = reqs[reqs_i].way;
//             //         wr_data_tag = line_br.tag;
//             //         wr_data_line = line_out;
//             //         wr_data_hprot = reqs[reqs_i].hprot;
//             //         wr_data_state = `MODIFIED;
//             //         wr_req_state = 1'b1;
//             //         state_wr_data_req = `INVALID;
//             //         incr_reqs_cnt = 1'b1;
//             //     end else begin
//             //         wr_req_state = 1'b1;
//             //         state_wr_data_req = reqs[reqs_i].state + 2;
//             //         wr_req_line = 1'b1;
//             //         line_wr_data_req = line_out;
//             //     end
//             // end
//             // RSP_DATA_XMADW : begin
//             //     l2_rd_rsp_valid_int = 1'b1;
//             //     l2_rd_rsp_o.line = l2_rsp_in.line;
//             //     wr_req_line = 1'b1;
//             //     line_wr_data_req = l2_rsp_in.line;

//             //     if (l2_rd_rsp_ready_int) begin
//             //         wr_req_invack_cnt = 1'b1;
//             //         invack_cnt_wr_data_req = reqs[reqs_i].invack_cnt + l2_rsp_in.invack_cnt;
//             //         wr_req_state = 1'b1;
//             //     end

//             //     if (invack_cnt_wr_data_req == `MAX_N_L2) begin
//             //         set_ongoing_atomic = 1'b1;
//             //         state_wr_data_req = `XMW;
//             //     end else begin
//             //         state_wr_data_req = reqs[reqs_i].state + 2;
//             //     end
//             // end
//             // RSP_INVACK : begin
//             //     invack_cnt_wr_data_req = reqs[reqs_i].invack_cnt - 1;
//             //     wr_req_invack_cnt = 1'b1;
//             //     if (invack_cnt_wr_data_req == `MAX_N_L2) begin
//             //         if (reqs[reqs_i].state == `IMA || reqs[reqs_i].state == `SMA) begin
//             //            wr_en_clear_mshr = 1'b1;
//             //            set_in = line_br.set;
//             //            way = reqs[reqs_i].way;
//             //            wr_data_tag = line_br.tag;
//             //            wr_data_line = reqs[reqs_i].line;
//             //            wr_data_hprot = reqs[reqs_i].hprot;
//             //            wr_data_state = `MODIFIED;
//             //            wr_req_state = 1'b1;
//             //            state_wr_data_req = `INVALID;
//             //            incr_reqs_cnt = 1'b1;
//             //         end else if (reqs[reqs_i].state == `IMAW || reqs[reqs_i].state == `SMAW) begin
//             //             set_ongoing_atomic = 1'b1;
//             //             wr_req_state = 1'b1;
//             //             state_wr_data_req = `XMW;
//             //         end
//             //     end
//             // end
//             // RSP_PUTACK : begin
//             //     if (evict_stall) begin
//             //         clr_evict_stall = 1'b1;
//             //         case (reqs[reqs_i].cpu_msg)
//             //             `READ : begin
//             //                 state_wr_data_req = `ISD;
//             //                 l2_req_out_o.coh_msg = `REQ_GETS;
//             //             end
//             //             `READ_ATOMIC : begin
//             //                 state_wr_data_req = `IMADW;
//             //                 l2_req_out_o.coh_msg = `REQ_GETM;
//             //             end
//             //             `WRITE : begin
//             //                 state_wr_data_req = `IMAD;
//             //                 l2_req_out_o.coh_msg = `REQ_GETM;
//             //             end
//             //         endcase
//             //         wr_req_state = 1'b1;
//             //         wr_req_tag = 1'b1;
//             //         tag_wr_data_req = reqs[reqs_i].tag_estall;

//             //         wr_en_evict_way = 1'b1;
//             //         wr_data_evict_way = reqs[reqs_i].way + 1;
//             //         set_in = reqs[reqs_i].set;

//             //         l2_req_out_o.hprot = reqs[reqs_i].hprot;
//             //         l2_req_out_o.addr = (reqs[reqs_i].tag_estall << `L2_SET_BITS) | line_br.set;
//             //         l2_req_out_valid_int = 1'b1;
//             //     end else begin
//             //         wr_req_state = 1'b1;
//             //         state_wr_data_req = `INVALID;
//             //         incr_reqs_cnt = 1'b1;
//             //     end
//             // end
//             FWD_MSHR_LOOKUP : begin
//                 rd_mem_en = 1'b1;
//                 set_in = line_br.set;
//                 reqs_op_code = `L2_REQS_PEEK_FWD;
//                 clr_fwd_stall_ended = 1'b1;
//             end
//             FWD_TAG_LOOKUP : begin
//                 lookup_en = 1'b1;
//                 lookup_mode = `L2_LOOKUP_FWD;
//             end
//             FWD_STALL : begin
//                 set_fwd_in_stalled = 1'b1;
//             end
//             FWD_HIT : begin
//                 if (reqs[reqs_i].state == `SMAD || reqs[reqs_i].state == `SMADW || reqs[reqs_i].state == `SIA) begin
//                     if (l2_fwd_in.coh_msg == `FWD_INV && !ready_bits[1]) begin
//                         l2_rsp_out_valid_int = 1'b1;
//                         l2_rsp_out_o.coh_msg = `RSP_INVACK;
//                         l2_rsp_out_o.req_id = l2_fwd_in.req_id;
//                         l2_rsp_out_o.to_req = 1'b1;
//                         l2_rsp_out_o.addr = l2_fwd_in.addr;
//                         l2_rsp_out_o.line = 0;
//                     end

//                     if (!ready_bits[0] && reqs[reqs_i].state != `SIA) begin
//                         l2_inval_o.addr = l2_fwd_in.addr;
//                         l2_inval_o.hprot = reqs[reqs_i].hprot;
//                         l2_inval_valid_int = 1'b1;
//                     end

//                     if (reqs[reqs_i] != `SIA) begin
//                         if (l2_fwd_in.coh_msg == `FWD_INV) begin
//                             if (l2_rsp_out_ready_int && l2_inval_ready_int) begin
//                                 wr_req_state = 1'b1;
//                             end else if (ready_bits[0] && l2_rsp_out_ready_int) begin
//                                 wr_req_state = 1'b1;
//                             end else if (ready_bits[1] && l2_inval_ready_int) begin
//                                 wr_req_state = 1'b1;
//                             end
//                         end else begin
//                             if (l2_inval_ready_int) begin
//                                 wr_req_state = 1'b1;
//                             end
//                         end
//                     end else if (l2_rsp_out_ready_int || l2_fwd_in.coh_msg != `FWD_INV) begin
//                         wr_req_state = 1'b1;
//                     end


//                     if (reqs[reqs_i].state == `SIA) begin
//                         state_wr_data_req  = `IIA;
//                     end else begin
//                         state_wr_data_req  = reqs[reqs_i].state - 4;
//                     end
//                 end else if (reqs[reqs_i].state == `MIA) begin
//                     l2_rsp_out_valid_int = 1'b1;
//                     l2_rsp_out_o.coh_msg = `RSP_DATA;
//                     l2_rsp_out_o.addr = l2_fwd_in.addr;
//                     l2_rsp_out_o.line = reqs[reqs_i].line;
//                     if (l2_fwd_in.coh_msg == `FWD_GETS || l2_fwd_in.coh_msg == `FWD_GETM) begin
//                         l2_rsp_out_o.req_id = l2_fwd_in.req_id;
//                         l2_rsp_out_o.to_req = 1'b1;
//                     end else begin
//                         l2_rsp_out_o.req_id = 0;
//                         l2_rsp_out_o.to_req = 1'b0;
//                     end

//                     if (l2_rsp_out_ready_int) begin
//                         wr_req_state = 1'b1;
//                     end

//                     if (l2_fwd_in.coh_msg == `FWD_GETS) begin
//                         state_wr_data_req = `SIA;
//                     end else begin
//                         state_wr_data_req = `IIA;
//                     end
//                 end
//             end
//             FWD_HIT_2 : begin
//                 l2_rsp_out_valid_int = 1'b1;
//                 l2_rsp_out_o.coh_msg = `RSP_DATA;
//                 l2_rsp_out_o.req_id = l2_fwd_in.req_id;
//                 l2_rsp_out_o.to_req = 1'b0;
//                 l2_rsp_out_o.addr = l2_fwd_in.addr;
//                 l2_rsp_out_o.line = reqs[reqs_i].line;
//             end
//             FWD_NO_HIT : begin
//                 if (!ongoing_flush && l2_fwd_in.coh_msg != `FWD_GETS) begin
//                     if (!ready_bits[0]) begin
//                         l2_inval_valid_int = 1'b1;
//                     end
//                     l2_inval_o.addr = l2_fwd_in.addr;
//                     l2_inval_o.hprot = hprots_buf[way_hit];
//                 end

//                 if (l2_fwd_in.coh_msg != `FWD_INV_LLC) begin
//                     if (!ready_bits[1]) begin
//                         l2_rsp_out_valid_int = 1'b1;
//                     end
//                     if (l2_fwd_in.coh_msg == `FWD_GETS || l2_fwd_in.coh_msg == `FWD_GETM) begin
//                         l2_rsp_out_o.coh_msg = `RSP_DATA;
//                         l2_rsp_out_o.req_id = l2_fwd_in.req_id;
//                         l2_rsp_out_o.to_req = 1'b1;
//                         l2_rsp_out_o.addr = l2_fwd_in.addr;
//                         l2_rsp_out_o.line = lines_buf[way_hit];
//                     end else if (l2_fwd_in.coh_msg == `FWD_INV) begin
//                         l2_rsp_out_o.coh_msg = `RSP_INVACK;
//                         l2_rsp_out_o.req_id = l2_fwd_in.req_id;
//                         l2_rsp_out_o.to_req = 1'b1;
//                         l2_rsp_out_o.addr = l2_fwd_in.addr;
//                         l2_rsp_out_o.line = 0;
//                     end else if (l2_fwd_in.coh_msg == `FWD_GETM_LLC) begin
//                         l2_rsp_out_o.req_id = 0;
//                         l2_rsp_out_o.to_req = 1'b0;
//                         l2_rsp_out_o.addr = l2_fwd_in.addr;
//                         if (states_buf[way_hit] == `EXCLUSIVE) begin
//                             l2_rsp_out_o.coh_msg = `RSP_INVACK;
//                             l2_rsp_out_o.line = 0;
//                         end else begin
//                             l2_rsp_out_o.coh_msg = `RSP_DATA;
//                             l2_rsp_out_o.line = lines_buf[way_hit];
//                         end
//                     end
//                 end

//                 if (l2_fwd_in.coh_msg != `FWD_GETS && tag_hit) begin
//                     wr_en_state = 1'b1;
//                     wr_data_state = `INVALID;
//                     way = way_hit;
//                     set_in = line_br.set;
//                 end
//             end
//             FWD_NO_HIT_2 : begin
//                 l2_rsp_out_valid_int = 1'b1;
//                 l2_rsp_out_o.coh_msg = `RSP_DATA;
//                 l2_rsp_out_o.req_id = l2_fwd_in.req_id;
//                 l2_rsp_out_o.to_req = 1'b0;
//                 l2_rsp_out_o.addr = l2_fwd_in.addr;
//                 l2_rsp_out_o.line = lines_buf[way_hit];
//                 wr_en_state = 1'b1;
//                 wr_data_state = `SHARED;
//                 set_in = line_br.set;
//                 way = way_hit;
//              end
//             ONGOING_FLUSH_LOOKUP : begin
//                 set_in = flush_set;
//                 rd_mem_en = 1'b1;
//                 if ((rd_data_state[flush_way] == `INVALID) || (~is_flush_all && ~rd_data_hprot[flush_way])) begin
//                     incr_flush_way = 1'b1;
//                 end
//                 reqs_op_code = `L2_REQS_PEEK_FLUSH;
//             end
//             ONGOING_FLUSH_PROCESS : begin
//                 addr_tmp = (tags_buf[flush_way] << `L2_TAG_RANGE_LO) | (flush_set << `SET_RANGE_LO);
//                 addr_br_reqs.line = addr_tmp;
//                 addr_br_reqs.line_addr = addr_tmp[`TAG_RANGE_HI:`SET_RANGE_LO];
//                 addr_br_reqs.word = addr_tmp;
//                 addr_br_reqs.tag = addr_tmp[`TAG_RANGE_HI:`L2_TAG_RANGE_LO];
//                 addr_br_reqs.set = addr_tmp[`L2_SET_RANGE_HI:`SET_RANGE_LO];
//                 addr_br_reqs.w_off = addr_tmp[`W_OFF_RANGE_HI:`W_OFF_RANGE_LO];
//                 addr_br_reqs.b_off = addr_tmp[`B_OFF_RANGE_HI:`B_OFF_RANGE_LO];
//                 addr_br_reqs.line[`OFF_RANGE_HI:`OFF_RANGE_LO] = 0;
//                 addr_br_reqs.word[`B_OFF_RANGE_HI:`B_OFF_RANGE_LO] = 0;

//                 line_addr_tmp = (tags_buf[flush_way] << `L2_SET_BITS) | (flush_set);
//                 set_in = flush_set;
//                 way = flush_way;
//                 wr_data_state = `INVALID;
//                 wr_en_state = 1'b1;
//                 case (states_buf[flush_way])
//                     `SHARED : begin
//                         coh_msg_tmp = `REQ_PUTS;
//                         state_tmp = `SIA;
//                     end
//                     `EXCLUSIVE : begin
//                         coh_msg_tmp = `REQ_PUTS;
//                         state_tmp = `MIA;
//                     end
//                     `MODIFIED : begin
//                         coh_msg_tmp = `REQ_PUTM;
//                         state_tmp = `MIA;
//                     end
//                     default : begin
//                         state_tmp = 0;
//                     end
//                 endcase
//                 cpu_msg_wr_data_req = 0;
//                 tag_estall_wr_data_req = 0;
//                 way_wr_data_req = flush_way;
//                 hsize_wr_data_req = 0;
//                 state_wr_data_req = state_tmp;
//                 hprot_wr_data_req = 0;
//                 word_wr_data_req = 0;
//                 line_wr_data_req = lines_buf[flush_way];
//                 amo_wr_data_req = 0;

//                 l2_req_out_valid_int = 1'b1;
//                 l2_req_out_o.coh_msg = coh_msg_tmp;
//                 l2_req_out_o.hprot = 0;
//                 l2_req_out_o.addr = line_addr_tmp;
//                 l2_req_out_o.line = lines_buf[flush_way];

//                 if (l2_req_out_ready_int) begin
//                     fill_reqs_flush = 1'b1;
//                     incr_flush_way = 1'b1;
//                 end
//             end
//             CPU_REQ_MSHR_LOOKUP : begin
//                 reqs_op_code = `L2_REQS_PEEK_REQ;
//                 rd_mem_en = 1'b1;
//                 set_in = addr_br.set;
//                 // TODO: Removed code related to BRESP being sent back for atomic write.
//             end
//             CPU_REQ_TAG_LOOKUP : begin
//                 // TODO: Removed code related to setting ongoing_atomic if atomic read.
//                 lookup_en = 1'b1;
//                 lookup_mode = `L2_LOOKUP;
//             end
//             CPU_REQ_READ_NO_REQ : begin
//                 l2_rd_rsp_valid_int = 1'b1;
//                 l2_rd_rsp_o.line = lines_buf[way_hit];
//             end
//             CPU_REQ_READ_REQ : begin
//                 state_wr_data_req = `SPX_IS;

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
//                 amo_wr_data_req = 0;

//                 l2_req_out_valid_int = 1'b1;
//                 l2_req_out_o.coh_msg = `REQ_S;
//                 l2_req_out_o.hprot = l2_cpu_req.hprot;
//                 l2_req_out_o.addr = addr_br.line_addr;
//                 l2_req_out_o.line = 0;
//                 l2_req_out_o.word_mask = `WORD_MASK_ALL;
//             end
//             CPU_REQ_WRITE_NO_REQ : begin
//                 set_in = addr_br.set;
//                 way = way_hit;

//                 line_in = lines_buf[way_hit];
//                 word_in = l2_cpu_req.word;
//                 w_off_in = addr_br.w_off;
//                 b_off_in = addr_br.b_off;
//                 hsize_in = l2_cpu_req.hsize;
//                 wr_data_line = line_out;
//                 wr_en_line = 1'b1;
//             end
//             CPU_REQ_WRITE_REQ : begin
//                 state_wr_data_req = `SPX_XR;

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
//                 amo_wr_data_req = 0;

//                 // TODO: REQ_O currently using WORD_MASK_ALL. Need to change to
//                 // word granularity at some point.
//                 l2_req_out_valid_int = 1'b1;
//                 l2_req_out_o.coh_msg = `REQ_O;
//                 l2_req_out_o.hprot = l2_cpu_req.hprot;
//                 l2_req_out_o.addr = addr_br.line_addr;
//                 l2_req_out_o.line = 0;
//                 l2_req_out_o.word_mask = `WORD_MASK_ALL;
//             end
//             CPU_REQ_EMPTY_WAY : begin
//                 l2_req_out_valid_int = 1'b1;
//                 l2_req_out_o.hprot = l2_cpu_req.hprot;
//                 l2_req_out_o.addr = addr_br.line_addr;
//                 l2_req_out_o.line = 0;
//                 // TODO: set word_mask as necessary. We might need to add more
//                 // cases here and set word_mask and other signals (for req_out or reqs)
//                 // accordingly.
//                 l2_req_out_o.word_mask = `WORD_MASK_ALL;
//                 // TODO: READ_ATOMIC temporarily removed.
//                 case (l2_cpu_req.cpu_msg)
//                     `READ : begin
//                         l2_req_out_o.coh_msg = `REQ_S;
//                         state_wr_data_req = `SPX_IS;
//                     end
//                     `WRITE : begin
//                         l2_req_out_o.coh_msg = `REQ_O;
//                         state_wr_data_req = `SPX_XR;
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
//                 // TODO: Fix this so that when the response is received,
//                 // the correct value that's currently in L2 memory and
//                 // the response that is received, and the new value to be
//                 // written (if applicable) are all considered.
//                 line_wr_data_req = 0;
//             end
// //             CPU_REQ_MSHR_LOOKUP : begin
// //                 reqs_op_code = `L2_REQS_PEEK_REQ;
// //                 rd_mem_en = 1'b1;
// //                 set_in = addr_br.set;
// //                 if (!((set_conflict | set_set_conflict_reqs) && !clr_set_conflict_reqs)) begin
// //                     if (l2_cpu_req.cpu_msg == `WRITE_ATOMIC && !ongoing_atomic) begin
// //                         l2_bresp_valid_int = 1'b1;
// //                         l2_bresp_o = `BRESP_OKAY;
// //                     end
// //                 end
// //             end
// //             CPU_REQ_ATOMIC_OVERRIDE : begin
// //                 set_set_conflict_fsm = 1'b1;
// //                 set_cpu_req_conflict = 1'b1;
// //                 state_wr_data_req = `INVALID;
// //                 wr_req_state_atomic = 1'b1;
// //                 incr_reqs_cnt = 1'b1;
// //                 clr_ongoing_atomic  = 1'b1;

// //                 set_in = reqs[reqs_atomic_i].set;
// //                 way = reqs[reqs_atomic_i].way;

// //                 clear_mshr_atomic = 1'b1;
// //                 wr_en_clear_mshr = 1'b1;
// //                 wr_data_tag = reqs[reqs_atomic_i].tag;
// //                 wr_data_line =  reqs[reqs_atomic_i].line;
// //                 wr_data_hprot = reqs[reqs_atomic_i].hprot;
// //                 wr_data_state = `MODIFIED;
// //             end
// //             CPU_REQ_ATOMIC_CONTINUE_READ :  begin
// //                 set_in = reqs[reqs_atomic_i].set;
// //                 way = reqs[reqs_atomic_i].way;

// //                 if (l2_cpu_req.cpu_msg == `READ) begin
// //                     clr_set_conflict_fsm = 1'b1;
// //                     l2_rd_rsp_valid_int = 1'b1;
// //                     l2_rd_rsp_o.line = reqs[reqs_atomic_i].line;
// //                 end else begin
// //                     set_set_conflict_fsm = 1'b1;
// //                     incr_reqs_cnt = 1'b1;
// //                     set_cpu_req_conflict = 1'b1;

// //                     clear_mshr_atomic = 1'b1;
// //                     wr_en_clear_mshr = 1'b1;
// //                     wr_data_tag = reqs[reqs_atomic_i].tag;
// //                     wr_data_line =  reqs[reqs_atomic_i].line;
// //                     wr_data_hprot = reqs[reqs_atomic_i].hprot;
// //                     wr_data_state = `MODIFIED;
// //                     clr_ongoing_atomic = 1'b1;

// //                     wr_req_state_atomic = 1'b1;
// //                     state_wr_data_req = `INVALID;
// //                 end
// //             end
// //             CPU_REQ_ATOMIC_CONTINUE_WRITE : begin
// //                 clr_set_conflict_fsm = 1'b1;
// //                 word_in = l2_cpu_req.word;
// //                 w_off_in = addr_br.w_off;
// //                 b_off_in = addr_br.b_off;
// //                 hsize_in = l2_cpu_req.hsize;
// //                 line_in = reqs[reqs_atomic_i].line;

// //                 wr_req_state_atomic = 1'b1;
// //                 state_wr_data_req = `INVALID;
// //                 incr_reqs_cnt = 1'b1;

// //                 set_in = reqs[reqs_atomic_i].set;
// //                 way = reqs[reqs_atomic_i].way;

// //                 clear_mshr_atomic = 1'b1;
// //                 wr_en_clear_mshr = 1'b1;
// //                 wr_data_tag = reqs[reqs_atomic_i].tag;
// //                 wr_data_line =  line_out;
// //                 wr_data_hprot = reqs[reqs_atomic_i].hprot;
// //                 wr_data_state = `MODIFIED;
// //                 clr_ongoing_atomic = 1'b1;

// //                 l2_bresp_valid_int = 1'b1;
// //                 if (l2_cpu_req.cpu_msg == `WRITE_ATOMIC) begin
// //                     l2_bresp_o = `BRESP_EXOKAY;
// //                 end
// //             end
// //             CPU_REQ_SET_CONFLICT : begin
// //                 set_cpu_req_conflict = 1'b1;
// //             end
// //             CPU_REQ_TAG_LOOKUP : begin
// //                 if (l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
// //                     update_atomic = 1'b1;
// //                 end
// //                 lookup_en = 1'b1;
// //                 lookup_mode = `L2_LOOKUP;
// //             end

// //             CPU_REQ_READ_READ_ATOMIC_EM : begin
// //                 if (l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
// //                     if (l2_rd_rsp_ready_int) begin
// //                         fill_reqs = 1'b1;
// //                     end
// //                     cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
// //                     tag_estall_wr_data_req = 0;
// //                     tag_wr_data_req = addr_br.tag;
// //                     way_wr_data_req = way_hit;
// //                     hsize_wr_data_req = l2_cpu_req.hsize;
// //                     state_wr_data_req = `XMW;
// //                     hprot_wr_data_req = l2_cpu_req.hprot;
// //                     word_wr_data_req = l2_cpu_req.word;
// //                     line_wr_data_req = lines_buf[way_hit];
// //                     amo_wr_data_req = l2_cpu_req.amo;
// //                     set_ongoing_atomic = 1'b1;
// //                 end

// //                 l2_rd_rsp_valid_int = 1'b1;
// //                 l2_rd_rsp_o.line = lines_buf[way_hit];
// // `ifdef STATS_ENABLE
// //                 if (l2_rd_rsp_ready_int) begin
// //                     l2_stats_valid_int = 1'b1;
// //                     l2_stats_o = 1'b1;
// //                 end
// // `endif
// //             end
// //             CPU_REQ_READ_ATOMIC_WRITE_S : begin
// //                 if (l2_cpu_req.cpu_msg == `READ_ATOMIC) begin
// //                     state_wr_data_req = `SMADW;
// //                 end else if (l2_cpu_req.cpu_msg == `WRITE) begin
// //                     state_wr_data_req = `SMAD;
// //                 end
// //                 if (l2_req_out_ready_int) begin
// //                     fill_reqs = 1'b1;
// //                 end

// //                 cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
// //                 tag_estall_wr_data_req = 0;
// //                 tag_wr_data_req = addr_br.tag;
// //                 way_wr_data_req = way_hit;
// //                 hsize_wr_data_req = l2_cpu_req.hsize;
// //                 hprot_wr_data_req = l2_cpu_req.hprot;
// //                 word_wr_data_req = l2_cpu_req.word;
// //                 line_wr_data_req = lines_buf[way_hit];
// //                 amo_wr_data_req = l2_cpu_req.amo;

// //                 l2_req_out_valid_int = 1'b1;
// //                 l2_req_out_o.coh_msg = `REQ_GETM;
// //                 l2_req_out_o.hprot = l2_cpu_req.hprot;
// //                 l2_req_out_o.addr = addr_br.line_addr;
// //                 l2_req_out_o.line = 0;
// // `ifdef STATS_ENABLE
// //                 if (l2_req_out_ready_int) begin
// //                     l2_stats_valid_int = 1'b1;
// //                     l2_stats_o = 1'b1;
// //                 end
// // `endif
// //             end
// //             CPU_REQ_WRITE_EM : begin
// //                 set_in = addr_br.set;
// //                 way = way_hit;

// //                 if (states_buf[way_hit] == `EXCLUSIVE) begin
// //                     wr_data_state = `MODIFIED;
// //                     wr_en_state = 1'b1;
// //                 end

// //                 line_in = lines_buf[way_hit];
// //                 word_in = l2_cpu_req.word;
// //                 w_off_in = addr_br.w_off;
// //                 b_off_in = addr_br.b_off;
// //                 hsize_in = l2_cpu_req.hsize;
// //                 wr_data_line = line_out;
// //                 wr_en_line = 1'b1;
// // `ifdef STATS_ENABLE
// //                 l2_stats_valid_int = 1'b1;
// //                 l2_stats_o = 1'b1;
// // `endif
// //             end
// //             CPU_REQ_EMPTY_WAY : begin
// //                 l2_req_out_valid_int = 1'b1;
// //                 l2_req_out_o.hprot = l2_cpu_req.hprot;
// //                 l2_req_out_o.addr = addr_br.line_addr;
// //                 l2_req_out_o.line = 0;
// //                 case (l2_cpu_req.cpu_msg)
// //                     `READ : begin
// //                         l2_req_out_o.coh_msg = `REQ_GETS;
// //                         state_wr_data_req = `ISD;
// //                     end
// //                     `READ_ATOMIC : begin
// //                         l2_req_out_o.coh_msg = `REQ_GETM;
// //                         state_wr_data_req = `IMADW;
// //                     end
// //                     `WRITE : begin
// //                         l2_req_out_o.coh_msg = `REQ_GETM;
// //                         state_wr_data_req = `IMAD;
// //                     end
// //                 endcase
// //                 if (l2_req_out_ready_int) begin
// //                     fill_reqs = 1'b1;
// //                 end
// //                 cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
// //                 tag_estall_wr_data_req = 0;
// //                 tag_wr_data_req = addr_br.tag;
// //                 way_wr_data_req = empty_way;
// //                 hsize_wr_data_req = l2_cpu_req.hsize;
// //                 hprot_wr_data_req = l2_cpu_req.hprot;
// //                 word_wr_data_req = l2_cpu_req.word;
// //                 amo_wr_data_req = l2_cpu_req.amo;
// //                 line_wr_data_req = 0;
// // `ifdef STATS_ENABLE
// //                 if (l2_req_out_ready_int) begin
// //                     l2_stats_valid_int = 1'b1;
// //                     l2_stats_o = 1'b0;
// //                 end
// // `endif
// //             end
// //             CPU_REQ_EVICT : begin
// //                 set_evict_stall = 1'b1;

// //                 evict_way_tmp = evict_way_buf;

// //                 if (!ready_bits[0]) begin
// //                     l2_inval_valid_int = 1'b1;
// //                 end
// //                 l2_inval_o.addr = (tags_buf[evict_way_tmp] << `L2_SET_BITS) | addr_br.set;
// //                 l2_inval_o.hprot = hprots_buf[evict_way_tmp];
// //                 if (!ready_bits[1]) begin
// //                     l2_req_out_valid_int = 1'b1;
// //                 end
// //                 case (states_buf[evict_way_tmp])
// //                     `SHARED : begin
// //                         l2_req_out_o.coh_msg = `REQ_PUTS;
// //                         state_wr_data_req = `SIA;
// //                     end
// //                     `EXCLUSIVE : begin
// //                         l2_req_out_o.coh_msg = `REQ_PUTS;
// //                         state_wr_data_req = `MIA;
// //                     end
// //                     `MODIFIED : begin
// //                         l2_req_out_o.coh_msg = `REQ_PUTM;
// //                         state_wr_data_req = `MIA;
// //                     end
// //                 endcase

// //                 l2_req_out_o.hprot = 0;
// //                 l2_req_out_o.addr = (tags_buf[evict_way_tmp] << `L2_SET_BITS) | addr_br.set;
// //                 l2_req_out_o.line = lines_buf[evict_way_tmp];

// //                 if (l2_inval_ready_int && l2_req_out_ready_int) begin
// //                     fill_reqs = 1'b1;
// // `ifdef STATS_ENABLE
// //                     l2_stats_valid_int = 1'b1;
// //                     l2_stats_o = 1'b0;
// // `endif
// //                 end else if (ready_bits[0] && l2_req_out_ready_int) begin
// //                     fill_reqs = 1'b1;
// // `ifdef STATS_ENABLE
// //                     l2_stats_valid_int = 1'b1;
// //                     l2_stats_o = 1'b0;
// // `endif
// //                 end else if (l2_inval_ready_int && ready_bits[1]) begin
// //                     fill_reqs = 1'b1;
// // `ifdef STATS_ENABLE
// //                     l2_stats_valid_int = 1'b1;
// //                     l2_stats_o = 1'b0;
// // `endif
// //                 end

// //                 cpu_msg_wr_data_req = l2_cpu_req.cpu_msg;
// //                 tag_estall_wr_data_req = addr_br.tag;
// //                 tag_wr_data_req = tags_buf[evict_way_tmp];
// //                 way_wr_data_req = evict_way_tmp;
// //                 hsize_wr_data_req = l2_cpu_req.hsize;
// //                 hprot_wr_data_req = l2_cpu_req.hprot;
// //                 word_wr_data_req = l2_cpu_req.word;
// //                 amo_wr_data_req = l2_cpu_req.amo;
// //                 line_wr_data_req = lines_buf[evict_way_tmp];
// //             end
// //             default : begin
// //                 reqs_op_code = `L2_REQS_IDLE;
// //             end
//         endcase
//     end

//     function void send_rd_rsp;
//         input line_t line;

//         l2_rd_rsp_valid_int = 1'b1;
//         l2_rd_rsp_o.line = line;
//     endfunction

//     function void clear_mshr;
//         input l2_set_t set;
//         input l2_way_t way;
//         input l2_tag_t tag;
//         input line_t line;
//         input hprot_t hprot;
//         input state_t state;

//         set_in = set;
//         way = way;
//         wr_data_tag = tag;
//         wr_data_line = line;
//         wr_data_hprot = hprot;
//         // TODO: If we're doing state at word granularity, the state for a line
//         // needs to be read-modify-written back.
//         wr_data_state = state;
//     endfunction

// endmodule
