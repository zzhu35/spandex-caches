`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_fsm (
    `FPGA_DBG input logic clk,
    `FPGA_DBG input logic rst,
    // From input decoder
    `FPGA_DBG input logic do_flush,
    `FPGA_DBG input logic do_flush_next,
    `FPGA_DBG input logic do_get_rsp,
    `FPGA_DBG input logic do_get_rsp_next,
    `FPGA_DBG input logic do_get_req,
    `FPGA_DBG input logic do_get_req_next,
    `FPGA_DBG input logic do_bulk_req,
    `FPGA_DBG input logic do_bulk_req_next,
    // From interfaces
    `FPGA_DBG input logic llc_mem_req_ready_int,
    `FPGA_DBG input logic llc_fwd_out_ready_int,
    `FPGA_DBG input logic llc_rsp_out_ready_int,
    `FPGA_DBG input logic llc_mem_rsp_valid_int,
    // From MSHR
    `FPGA_DBG input logic mshr_hit,
    `FPGA_DBG input logic mshr_hit_next,
    `FPGA_DBG input logic [`MSHR_BITS-1:0] mshr_i,
    `FPGA_DBG input logic [`MSHR_BITS-1:0] mshr_i_next,
    `FPGA_DBG input logic mshr_coalesce_hit_next,
    `FPGA_DBG input logic mshr_coalesce_hit,
    `FPGA_DBG input logic [`MSHR_BITS-1:0] mshr_coalesce_i_next,
    `FPGA_DBG input logic [`MSHR_BITS-1:0] mshr_coalesce_i,
    `FPGA_DBG input mshr_llc_buf_t mshr[`N_MSHR],
    `FPGA_DBG input logic set_set_conflict_mshr,
    `FPGA_DBG input logic clr_set_conflict_mshr,
    // From lookup
    `FPGA_DBG input logic tag_hit,
    `FPGA_DBG input logic tag_hit_next,
    `FPGA_DBG input logic empty_way_found,
    `FPGA_DBG input logic empty_way_found_next,
    `FPGA_DBG input llc_way_t way_hit,
    `FPGA_DBG input llc_way_t way_hit_next,
    `FPGA_DBG input llc_way_t empty_way,
    `FPGA_DBG input llc_way_t empty_way_next,
    `FPGA_DBG input word_mask_t word_mask_owned,
    `FPGA_DBG input word_mask_t word_mask_owned_next,
    `FPGA_DBG input word_mask_t word_mask_owned_evict,
    `FPGA_DBG input word_mask_t word_mask_owned_evict_next,
    `FPGA_DBG input cache_id_t owners_cache_id[`WORDS_PER_LINE],
    `FPGA_DBG input cache_id_t owners_evict_cache_id[`WORDS_PER_LINE],
    // Bufs populated from the current set in RAMs.
    `FPGA_DBG input var logic dirty_bits_buf[`LLC_WAYS],
    input var line_t lines_buf[`LLC_WAYS],
    `FPGA_DBG input var llc_tag_t tags_buf[`LLC_WAYS],
    `FPGA_DBG input var sharers_t sharers_buf[`LLC_WAYS],
    `FPGA_DBG input var owner_t owners_buf[`LLC_WAYS],
    `FPGA_DBG input var hprot_t hprots_buf[`LLC_WAYS],
    `FPGA_DBG input var llc_state_t states_buf[`LLC_WAYS],
    `FPGA_DBG input llc_way_t evict_way_buf,
    // State registers from regs/others
    `FPGA_DBG input logic evict_stall,
    `FPGA_DBG input logic set_conflict,
    `FPGA_DBG input logic ongoing_flush,
    `FPGA_DBG input logic [`LLC_SET_BITS:0] flush_set,
    `FPGA_DBG input logic [`LLC_WAY_BITS:0] flush_way,

    // Interface buses
    llc_req_in_t.in llc_req_in,
    llc_dma_req_in_t.in llc_dma_req_in,
    llc_rsp_in_t.in llc_rsp_in,
    llc_mem_rsp_t.in llc_mem_rsp,
    llc_mem_rsp_t.in llc_mem_rsp_next,
    line_breakdown_llc_t.in line_br,
    line_breakdown_llc_t.in line_br_next,

    // To input_decoder - get new input
    `FPGA_DBG output logic decode_en,
    // To lookup - check for hit/miss/conflict in new set.
    `FPGA_DBG output logic lookup_en,
    `FPGA_DBG output logic lookup_mode,
    // To external interfaces - new data available.
    `FPGA_DBG output logic llc_mem_req_valid_int,
    `FPGA_DBG output logic llc_fwd_out_valid_int,
    `FPGA_DBG output logic llc_rsp_out_valid_int,
    `FPGA_DBG output logic llc_mem_rsp_ready_int,
    `FPGA_DBG output logic llc_dma_rsp_out_valid_int,
    // To bufs to read RAMs into bufs.
    `FPGA_DBG output logic rd_set_into_bufs,
    // Way to store memory response once received.
    `FPGA_DBG output llc_way_t mem_rsp_way,
    // To MSHR
    `FPGA_DBG output logic add_mshr_entry,
    `FPGA_DBG output logic update_mshr_tag,
    `FPGA_DBG output logic update_mshr_way,
    `FPGA_DBG output logic update_mshr_state,
    `FPGA_DBG output logic update_mshr_invack_cnt,
    `FPGA_DBG output logic update_mshr_line,
    `FPGA_DBG output logic update_mshr_word_mask,
    `FPGA_DBG output logic update_mshr_hprot,
    `FPGA_DBG output logic update_mshr_coal_line,
    `FPGA_DBG output logic update_mshr_coal_state,
    `FPGA_DBG output logic update_mshr_coal_hprot,
    `FPGA_DBG output logic update_mshr_coal_invack_cnt,
    `FPGA_DBG output logic update_mshr_coal_word_mask,
    `FPGA_DBG output logic [2:0] mshr_op_code,
    `FPGA_DBG output logic incr_mshr_cnt,
    `FPGA_DBG output mix_msg_t update_mshr_value_msg,
    `FPGA_DBG output cache_id_t update_mshr_value_req_id,
    `FPGA_DBG output llc_tag_t update_mshr_value_tag,
    `FPGA_DBG output llc_way_t update_mshr_value_way,
    `FPGA_DBG output unstable_state_t update_mshr_value_state,
    `FPGA_DBG output hprot_t update_mshr_value_hprot,
    `FPGA_DBG output invack_cnt_calc_t update_mshr_value_invack_cnt,
    `FPGA_DBG output line_t update_mshr_value_line,
    `FPGA_DBG output word_mask_t update_mshr_value_word_mask,
    `FPGA_DBG output word_mask_t update_mshr_value_word_mask_reg,
    // To localmem - update triggers
    `FPGA_DBG output llc_set_t lmem_set_in,
    `FPGA_DBG output llc_way_t lmem_way_in,
    `FPGA_DBG output logic lmem_wr_en_state,
    `FPGA_DBG output logic lmem_wr_en_line,
    `FPGA_DBG output logic lmem_wr_en_evict_way,
    `FPGA_DBG output logic lmem_wr_en_sharers,
    `FPGA_DBG output logic lmem_wr_en_owner,
    `FPGA_DBG output logic lmem_wr_en_dirty_bit,
    `FPGA_DBG output logic lmem_wr_en_all_mem,
    // To localmem - update values
    `FPGA_DBG output state_t lmem_wr_data_state,
    `FPGA_DBG output line_t lmem_wr_data_line,
    `FPGA_DBG output hprot_t lmem_wr_data_hprot,
    `FPGA_DBG output llc_tag_t lmem_wr_data_tag,
    `FPGA_DBG output llc_way_t lmem_wr_data_evict_way,
    `FPGA_DBG output sharers_t lmem_wr_data_sharers,
    `FPGA_DBG output owner_t lmem_wr_data_owner,
    `FPGA_DBG output logic lmem_wr_data_dirty_bit,
    // Outputs to regs to register states
    `FPGA_DBG output logic clr_evict_stall,
    `FPGA_DBG output logic set_evict_stall,
    `FPGA_DBG output logic set_set_conflict_fsm,
    `FPGA_DBG output logic clr_set_conflict_fsm,
    `FPGA_DBG output logic set_req_conflict,
    `FPGA_DBG output logic incr_flush_way,
    `FPGA_DBG output logic incr_flush_set,
    `FPGA_DBG output logic incr_bulk_nack_counter,
    `FPGA_DBG output logic clr_bulk_nack_counter,
    `FPGA_DBG output logic incr_bulk_done,
    `FPGA_DBG output logic set_req_bulk_addr,
    `FPGA_DBG output line_addr_t set_req_bulk_addr_data,

    llc_mem_req_t.out llc_mem_req_o,
    llc_fwd_out_t.out llc_fwd_out_o,
    llc_rsp_out_t.out llc_rsp_out_o,
    llc_dma_rsp_out_t.out llc_dma_rsp_out_o
    );

    // LLC FSM state name enums
    typedef enum logic[5:0] {
        RESET,
        DECODE,

        RSP_MSHR_LOOKUP,
        RSP_INV_HANDLER,
        RSP_INV_HANDLER_MEM_REQ,
        RSP_RVK_O_HANDLER,

        ONGOING_FLUSH_LOOKUP,
        ONGOING_FLUSH_PROCESS,
        ONGOING_FLUSH_EVICT,

        REQ_MSHR_LOOKUP,
        REQ_SET_CONFLICT,
        REQ_TAG_LOOKUP,
        REQ_ODATA_HANDLER_HIT,
        REQ_ODATA_HANDLER_HIT_RSP,
        REQ_ODATA_HANDLER_MISS,
        REQ_ODATA_HANDLER_MISS_MEM_RSP,
        REQ_ODATA_HANDLER_MISS_RSP,
        REQ_S_HANDLER_HIT,
        REQ_S_HANDLER_HIT_RSP,
        REQ_S_HANDLER_MISS,
        REQ_S_HANDLER_MISS_MEM_RSP,
        REQ_S_HANDLER_MISS_RSP,
        REQ_WB_HANDLER_HIT,
        REQ_WB_HANDLER_MISS,
        REQ_WTFWD_HANDLER_HIT,
        REQ_WTFWD_HANDLER_HIT_RSP,
        REQ_WTFWD_HANDLER_MISS,
        REQ_WTFWD_HANDLER_MISS_MEM_RSP,
        REQ_WTFWD_HANDLER_MISS_RSP,
        REQ_V_HANDLER_HIT,
        REQ_V_HANDLER_HIT_RSP,
        REQ_V_HANDLER_MISS,
        REQ_V_HANDLER_MISS_MEM_RSP,
        REQ_V_HANDLER_MISS_RSP,
        REQ_EVICT,
        REQ_EVICT_FWD_RVK,
        REQ_EVICT_FWD_INV,

        SEND_FWD_WITH_OWNER_MASK
    } llc_state_t;

    `FPGA_DBG llc_state_t state, next_state;
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

    llc_set_t rst_set;
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            rst_set <= 0;
        end else if (rst_en) begin
            rst_set <= rst_set + 1;
        end
    end

    // Wrapper variable to store the way for the ongoing cpu request.
    `FPGA_DBG llc_way_t req_in_way;
    assign req_in_way = tag_hit ? way_hit : (empty_way_found ? empty_way : 'h0);

    // Way to store memory response once received.
    `FPGA_DBG llc_way_t mem_rsp_way_next;
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            mem_rsp_way <= 'h0;
        end else begin
            mem_rsp_way <= mem_rsp_way_next;
        end
    end

    // Helper signals for how which words are owned.
    `FPGA_DBG word_mask_t word_owner_mask, word_no_owner_mask;
    assign word_owner_mask = llc_req_in.word_mask & word_mask_owned;
    assign word_no_owner_mask = llc_req_in.word_mask & ~word_mask_owned;

    // Helper signals and registers to track FWD_INV destinations.
    `FPGA_DBG invack_cnt_calc_t fwd_l2_cnt, fwd_invack_cnt;
    `FPGA_DBG logic incr_l2_cnt, clr_l2_cnt;
    `FPGA_DBG logic incr_invack_cnt, clr_invack_cnt, skip_invack_cnt;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            fwd_invack_cnt <= 0;
        end else if (clr_invack_cnt) begin
            fwd_invack_cnt <= 'h0;
        end else if (incr_invack_cnt) begin
            fwd_invack_cnt <= fwd_invack_cnt + 1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            fwd_l2_cnt <= 0;
        end else if (clr_l2_cnt) begin
            fwd_l2_cnt <= 'h0;
        end else if (incr_l2_cnt) begin
            fwd_l2_cnt <= fwd_l2_cnt + 1;
        end
    end

    // Temporary line to hold the line value for coalesced MSHR line.
    `FPGA_DBG line_t wtfwd_temp_line;

    always_comb begin
        next_state = state;
        case (state)
            RESET : begin
                // Reset the state in all sets.
                if (rst_set == `LLC_SETS - 1) begin
                    next_state = DECODE;
                end
            end
            DECODE : begin
                // In FSM 2, we decode the possible inputs, and if any of *_next
                // cycles are asserted, we sample that in the same cycle here, and move to
                // the appropriate state for responses (to old forwards) or new requests.
                if (do_flush_next) begin
                    next_state = ONGOING_FLUSH_LOOKUP;
                end else if (do_get_rsp_next) begin
                    next_state = RSP_MSHR_LOOKUP;
                end else if (do_get_req_next || do_bulk_req_next) begin
                    next_state = REQ_MSHR_LOOKUP;
                end
            end
            RSP_MSHR_LOOKUP : begin
                // On a response, we test to check if the MSHR has the entry in FSM 2. If hit is
                // asserted, we transition to the appropriate response handler based on the type of response.
                if (mshr_hit_next) begin
                    case(llc_rsp_in.coh_msg)
                        `RSP_INV_ACK : begin
                            next_state = RSP_INV_HANDLER;
                        end
                        `RSP_RVK_O : begin
                            next_state = RSP_RVK_O_HANDLER;
                        end
                        default : begin
                            next_state = DECODE;
                        end
                    endcase
                end else begin
                    next_state = DECODE;
                end
            end
            RSP_INV_HANDLER : begin
                // On RSP_INV, we check the transient state:
                // If LLC_SWB, our line is dirty in the LLC but shared.
                // Therefore, we need to write-back the dirty line to memory after all invalidations are received (RSP_INV_HANDLER_MEM_REQ).
                // IF LLC_SI, we don't need to write back the line and just overwrite the state RAM as invalid.
                case(mshr[mshr_i].state)
                    `LLC_SO : begin
                        if (!update_mshr_value_invack_cnt) begin
                            if (llc_rsp_out_ready_int) begin
                                next_state = DECODE;
                            end
                        end else begin
                            next_state = DECODE;
                        end
                    end
                    `LLC_SWB : begin
                        if (!update_mshr_value_invack_cnt) begin
                            next_state = RSP_INV_HANDLER_MEM_REQ;
                        end else begin
                            next_state = DECODE;
                        end
                    end
                    `LLC_SI : begin
                        next_state = DECODE;
                    end
                    default : begin
                        next_state = DECODE;
                    end
                endcase
            end
            RSP_INV_HANDLER_MEM_REQ : begin
                if (llc_mem_req_ready_int) begin
                    next_state = DECODE;
                end
            end
            RSP_RVK_O_HANDLER : begin
                // On RSP_RVK_O, we check the transient state:
                // If LLC_OWB, we always assume that the dirty is data (since the L2 could have modified the data).
                // Therefore, we always write-back once the (only) revoke response is received.
                case(mshr[mshr_i].state)
                    `LLC_OWB : begin
                        if (llc_mem_req_ready_int) begin
                            next_state = DECODE;
                        end
                    end
                    `LLC_OS : begin
                        next_state = DECODE;
                    end
                    `LLC_OV : begin
                        if (llc_rsp_out_ready_int) begin
                            next_state = DECODE;
                        end
                    end
                    default : begin
                        next_state = DECODE;
                    end
                endcase
            end
            // Read flush_set from the RAMs into bufs in ONGOING_FLUSH_LOOKUP.
            // In ONGOING_FLUSH_PROCESS, we will check whether the flush_way is
            // dirty or not. Note: If an L2 flush was performed before this, the
            // L2 should have written back all owned line and silent invalidated
            // all other lines. Therefore, all we need to check is if the line
            // is dirty - if yes, we must write it back. If not dirty, we
            // set the state as invalid directly, else, we move to ONGOING_FLUSH_EVICT
            // to write back the line to memory.
            ONGOING_FLUSH_LOOKUP : begin
                next_state = ONGOING_FLUSH_PROCESS;
            end
            ONGOING_FLUSH_PROCESS : begin
                if (dirty_bits_buf[flush_way] && states_buf[flush_way] != `LLC_I) begin
                    next_state = ONGOING_FLUSH_EVICT;
                end else begin
                    next_state = DECODE;
                end
            end
            ONGOING_FLUSH_EVICT : begin
                if (llc_mem_req_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_MSHR_LOOKUP : begin
                // On a new request, we check if a set conflict is ongoing, or the MSHR lookup just found a
                // set conflict. If yes, we go into set conflict and copy the new request to a set of registers
                // till the set conflicts are resolved. If not, we check the tag buffers to know hit/miss.
                if ((set_conflict | set_set_conflict_mshr) & !clr_set_conflict_mshr) begin
                    next_state = REQ_SET_CONFLICT;
                end else begin
                    next_state = REQ_TAG_LOOKUP;
                end
            end
            REQ_SET_CONFLICT : begin
                next_state = DECODE;
            end
            REQ_TAG_LOOKUP : begin
                // In FSM 2, the tag lookup asserts tag_hit_next or empty_way_found_next, and we sample them in the
                // same cycle. If it is a miss, we check if empty way was found, else we move to eviction.
                // TODO: REQV - add 2 new states here for cases where there is a tag hit or miss. In the case of miss,
                // we do the same thing as REQ_S, without adding a sharer or going to `LLC_S state. In case of a hit
                // with no owner, the LLC can respond with the words it owns. In case there is an owner, the LLC will
                // forward REQ_V to that owner. However, we do not make any changes to owners or state.
                if (tag_hit_next) begin
                    case(llc_req_in.coh_msg)
                        `REQ_Odata : begin
                            next_state = REQ_ODATA_HANDLER_HIT;
                        end
                        `REQ_S : begin
                            next_state = REQ_S_HANDLER_HIT;
                        end
                        `REQ_WB : begin
                            next_state = REQ_WB_HANDLER_HIT;
                        end
                        `REQ_V : begin
                            next_state = REQ_V_HANDLER_HIT;
                        end
                        `REQ_WTfwd : begin
                            next_state = REQ_WTFWD_HANDLER_HIT;
                        end
                        default : begin
                            next_state = DECODE;
                        end
                    endcase
                end else if (empty_way_found_next) begin
                    case(llc_req_in.coh_msg)
                        `REQ_Odata : begin
                            next_state = REQ_ODATA_HANDLER_MISS;
                        end
                        `REQ_S : begin
                            next_state = REQ_S_HANDLER_MISS;
                        end
                        `REQ_WB : begin
                            next_state = REQ_WB_HANDLER_MISS;
                        end
                        `REQ_V : begin
                            next_state = REQ_V_HANDLER_MISS;
                        end
                        `REQ_WTfwd : begin
                            next_state = REQ_WTFWD_HANDLER_MISS;
                        end
                        default : begin
                            next_state = DECODE;
                        end
                    endcase
                end else begin
                    next_state = REQ_EVICT;
                end
            end
            REQ_ODATA_HANDLER_HIT : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
                        if (word_owner_mask) begin
                            if (llc_fwd_out_ready_int) begin
                                next_state = REQ_ODATA_HANDLER_HIT_RSP;
                            end
                        end else begin
                            next_state = REQ_ODATA_HANDLER_HIT_RSP;
                        end
                    end
                    `LLC_S : begin
                        // In FSM 2, we're invalidating each sharer one by one. Here, we
                        // wait for going through all elements in the sharer's list (fwd_l2_cnt),
                        // and then checking if the last element was successfully processed -
                        // either skipped or a forward is sent.
                        if ((fwd_l2_cnt == `MAX_N_L2 - 1) && (llc_fwd_out_ready_int || skip_invack_cnt)) begin
                            next_state = REQ_ODATA_HANDLER_HIT_RSP;
                        end
                    end
                endcase
            end
            REQ_ODATA_HANDLER_HIT_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_ODATA_HANDLER_MISS : begin
                // On miss, we send a memory request for the data,
                // and move to a second state to wait for the response.
                if (llc_mem_req_ready_int) begin
                    next_state = REQ_ODATA_HANDLER_MISS_MEM_RSP;
                end
            end
            REQ_ODATA_HANDLER_MISS_MEM_RSP : begin
                if (llc_mem_rsp_valid_int) begin
                    next_state = REQ_ODATA_HANDLER_MISS_RSP;
                end
            end
            REQ_ODATA_HANDLER_MISS_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_S_HANDLER_HIT : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
                        if (word_owner_mask) begin
                            if (llc_fwd_out_ready_int) begin
                                next_state = REQ_S_HANDLER_HIT_RSP;
                            end
                        end else begin
                            next_state = REQ_S_HANDLER_HIT_RSP;
                        end
                    end
                    `LLC_S : begin
                        if (llc_rsp_out_ready_int) begin
                            next_state = DECODE;
                        end
                    end
                endcase
            end
            REQ_S_HANDLER_HIT_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_S_HANDLER_MISS : begin
                // On miss, we send a memory request for the data,
                // and move to a second state to wait for the response.
                if (llc_mem_req_ready_int) begin
                    next_state = REQ_S_HANDLER_MISS_MEM_RSP;
                end
            end
            REQ_S_HANDLER_MISS_MEM_RSP : begin
                if (llc_mem_rsp_valid_int) begin
                    next_state = REQ_S_HANDLER_MISS_RSP;
                end
            end
            REQ_S_HANDLER_MISS_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_WB_HANDLER_HIT : begin
                // If the data being written back is not owned by the requestor,
                // we treat this as a miss, and just send a dummy response,
                // without updating the data.
                // TODO: We're assuming all words have the same owner with owners_cache_id[0];
                // need to fix once we move to supporting word granularity.
                if (word_owner_mask && owners_cache_id[0] == llc_req_in.req_id) begin
                    if (llc_rsp_out_ready_int) begin
                        next_state = DECODE;
                    end
                end else begin
                    next_state = REQ_WB_HANDLER_MISS;
                end
            end
            REQ_WB_HANDLER_MISS : begin
                // If either the line being written back by the requestor is missing in the LLC,
                // or owned by a different cache, wait for `LLC_WB_DELAY and send a response.
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_V_HANDLER_HIT : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
                        if (word_owner_mask) begin
                            if (llc_fwd_out_ready_int) begin
                                next_state = REQ_V_HANDLER_HIT_RSP;
                            end
                        end else begin
                            next_state = REQ_V_HANDLER_HIT_RSP;
                        end
                    end
                    `LLC_S : begin
                        if (llc_rsp_out_ready_int) begin
                            next_state = DECODE;
                        end
                    end
                endcase
            end
            REQ_V_HANDLER_HIT_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_V_HANDLER_MISS : begin
                // On miss, we send a memory request for the data,
                // and move to a second state to wait for the response.
                if (llc_mem_req_ready_int) begin
                    next_state = REQ_V_HANDLER_MISS_MEM_RSP;
                end
            end
            REQ_V_HANDLER_MISS_MEM_RSP : begin
                if (llc_mem_rsp_valid_int) begin
                    next_state = REQ_V_HANDLER_MISS_RSP;
                end
            end
            REQ_V_HANDLER_MISS_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end            
            REQ_WTFWD_HANDLER_HIT : begin
                if (llc_req_in.word_mask == 'h0 && llc_req_in.line != 'h0) begin
                    next_state = DECODE;
                end else if (llc_req_in.word_mask == 'h0 && llc_req_in.line == 'h0) begin
                    if (llc_fwd_out_ready_int) begin
                        next_state = REQ_WTFWD_HANDLER_HIT_RSP;
                    end
                end else begin                
                    case (states_buf[req_in_way])
                        `LLC_V : begin
                            if (word_owner_mask) begin
                                if (llc_fwd_out_ready_int) begin
                                    if (mshr_coalesce_hit && mshr[mshr_coalesce_i].hprot == `INSTR) begin
                                        // HEAD packet
                                        next_state = REQ_WTFWD_HANDLER_HIT;
                                    end else if (mshr_coalesce_hit && mshr[mshr_coalesce_i].hprot == `DATA && mshr[mshr_coalesce_i].invack_cnt != owners_cache_id[0]) begin
                                        // TAIL packet
                                        next_state = REQ_WTFWD_HANDLER_HIT;
                                    end else begin
                                        // DATA packets and non-bulk packets
                                        next_state = REQ_WTFWD_HANDLER_HIT_RSP;
                                    end
                                end 
                            end else begin
                                next_state = REQ_WTFWD_HANDLER_HIT_RSP;
                            end
                        end
                        `LLC_S : begin
                            // In FSM 2, we're invalidating each sharer one by one. Here, we
                            // wait for going through all elements in the sharer's list (fwd_l2_cnt),
                            // and then checking if the last element was successfully processed -
                            // either skipped or a forward is sent.
                            if ((fwd_l2_cnt == `MAX_N_L2 - 1) && (llc_fwd_out_ready_int || skip_invack_cnt)) begin
                                next_state = REQ_WTFWD_HANDLER_HIT_RSP;
                            end
                        end
                    endcase
                end
            end
            REQ_WTFWD_HANDLER_HIT_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_WTFWD_HANDLER_MISS : begin
                if (llc_req_in.word_mask == 'h0 && llc_req_in.line != 'h0) begin
                    next_state = DECODE;
                end else if (llc_req_in.word_mask == 'h0 && llc_req_in.line == 'h0) begin
                    if (llc_fwd_out_ready_int) begin
                        next_state = REQ_WTFWD_HANDLER_MISS_RSP;
                    end
                end else begin                
                    // On miss, we can either directly update the line in the RAM
                    // if all words are present in the request; if not,
                    // we send a memory request for the data,
                    // and move to a second state to wait for the response.
                    if (llc_req_in.word_mask == `WORD_MASK_ALL) begin
                        if (llc_rsp_out_ready_int) begin
                            next_state = DECODE;
                        end
                    end else begin
                        if (llc_mem_req_ready_int) begin
                            next_state = REQ_WTFWD_HANDLER_MISS_MEM_RSP;
                        end
                    end
                end
            end
            REQ_WTFWD_HANDLER_MISS_MEM_RSP : begin
                if (llc_mem_rsp_valid_int) begin
                    next_state = REQ_WTFWD_HANDLER_MISS_RSP;
                end
            end
            REQ_WTFWD_HANDLER_MISS_RSP : begin
                if (llc_req_in.word_mask == 'h0 && llc_req_in.line == 'h0) begin
                    if (llc_rsp_out_ready_int) begin
                        next_state = DECODE;
                    end
                end else begin                
                    if (mshr_coalesce_hit) begin
                        next_state = DECODE;
                    end else begin
                        if (llc_rsp_out_ready_int) begin
                            next_state = DECODE;
                        end
                    end
                end
            end
            REQ_EVICT : begin
                // If we choose to evict, we can have a few cases:
                // If the line to be evicted is valid with an owner, we need to revoke the line,
                // and write-back the dirty line to memory.
                // Else, if no owner, we can choose to write-back if dirty or just invalidate.
                // If the line to be evicted is shared, we need to invalidate all sharers, and
                // then if dirty, choose to write-back to memory, else just invalidate.
                // In all cases, we transition to REQ_MSHR_LOOKUP, to check if there was a revoke/invaldiate
                // and put in set conflict. If not, we can immediate process the new pending request.
                case(states_buf[evict_way_buf])
                    `LLC_V : begin
                        if (!owners_buf[evict_way_buf]) begin
                            if (dirty_bits_buf[evict_way_buf]) begin
                                if (llc_mem_req_ready_int) begin
                                    next_state = REQ_MSHR_LOOKUP;
                                end
                            end else begin
                                next_state = REQ_MSHR_LOOKUP;
                            end
                        end else begin
                            if (llc_fwd_out_ready_int) begin
                                next_state = REQ_MSHR_LOOKUP;
                            end
                        end
                    end
                    `LLC_S : begin
                        // In FSM 2, we're invalidating each sharer one by one. Here, we
                        // wait for going through all elements in the sharer's list (fwd_l2_cnt),
                        // and then checking if the last element was successfully processed -
                        // either skipped or a forward is sent.
                        if ((fwd_l2_cnt == `MAX_N_L2 - 1) && (llc_fwd_out_ready_int || skip_invack_cnt)) begin
                            next_state = REQ_MSHR_LOOKUP;
                        end
                    end
                    default : begin
                        next_state = DECODE;
                    end
                endcase
            end
            default : begin
                next_state = DECODE;
            end
        endcase
    end

    always_comb begin
        //interfaces
        llc_mem_req_o.hwrite = 'h0;
        llc_mem_req_o.hsize = 'h0;
        llc_mem_req_o.hprot = 'h0;
        llc_mem_req_o.addr = 'h0;
        llc_mem_req_o.line = 'h0;
        llc_mem_req_valid_int = 1'b0;

        llc_rsp_out_o.coh_msg = 'h0;
        llc_rsp_out_o.addr = 'h0;
        llc_rsp_out_o.line = 'h0;
        llc_rsp_out_o.req_id = 'h0;
        llc_rsp_out_o.dest_id = 'h0;
        llc_rsp_out_o.invack_cnt = 'h0;
        llc_rsp_out_o.word_offset = 'h0;
        llc_rsp_out_o.word_mask = 'h0;
        llc_rsp_out_valid_int = 1'b0;

        llc_fwd_out_o.coh_msg = 'h0;
        llc_fwd_out_o.addr = 'h0;
        llc_fwd_out_o.req_id = 'h0;
        llc_fwd_out_o.dest_id = 'h0;
        llc_fwd_out_o.line = 'h0;
        llc_fwd_out_o.word_mask = 'h0;
        llc_fwd_out_valid_int = 1'b0;

        llc_dma_rsp_out_o.coh_msg = 'h0;
        llc_dma_rsp_out_o.addr = 'h0;
        llc_dma_rsp_out_o.line = 'h0;
        llc_dma_rsp_out_o.req_id = 'h0;
        llc_dma_rsp_out_o.dest_id = 'h0;
        llc_dma_rsp_out_o.invack_cnt = 'h0;
        llc_dma_rsp_out_o.word_offset = 'h0;
        llc_dma_rsp_out_valid_int = 1'b0;

        llc_mem_rsp_ready_int = 1'b0;

        lookup_en = 1'b0;
        lookup_mode = 'h0;
        llc_mem_req_valid_int = 1'b0;
        llc_fwd_out_valid_int = 1'b0;
        llc_rsp_out_valid_int = 1'b0;
        llc_mem_rsp_ready_int = 1'b0;
        llc_dma_rsp_out_valid_int = 1'b0;
        rd_set_into_bufs = 1'b0;
        add_mshr_entry = 1'b0;
        update_mshr_tag = 1'b0;
        update_mshr_way = 1'b0;
        update_mshr_state = 1'b0;
        update_mshr_invack_cnt = 1'b0;
        update_mshr_line = 1'b0;
        update_mshr_word_mask = 1'b0;
        update_mshr_hprot = 1'b0;
        update_mshr_coal_line = 1'b0;
        update_mshr_coal_state = 1'b0;
        update_mshr_coal_hprot = 1'b0;
        update_mshr_coal_invack_cnt = 1'b0;
        update_mshr_coal_word_mask = 1'b0;
        mshr_op_code = `LLC_MSHR_IDLE;
        incr_mshr_cnt = 1'b0;
        update_mshr_value_msg = 'h0;
        update_mshr_value_req_id = 'h0;
        update_mshr_value_tag = 'h0;
        update_mshr_value_way = 'h0;
        update_mshr_value_state = 'h0;
        update_mshr_value_hprot = 'h0;
        update_mshr_value_invack_cnt = 'h0;
        update_mshr_value_line = 'h0;
        update_mshr_value_word_mask = 'h0;
        update_mshr_value_word_mask_reg = 'h0;
        lmem_wr_en_state = 1'b0;
        lmem_wr_en_line = 1'b0;
        lmem_wr_en_evict_way = 1'b0;
        lmem_wr_en_sharers = 1'b0;
        lmem_wr_en_owner = 1'b0;
        lmem_wr_en_dirty_bit = 1'b0;
        lmem_wr_en_all_mem = 1'b0;
        lmem_wr_data_state = 'h0;
        lmem_wr_data_line = 'h0;
        lmem_wr_data_hprot = 'h0;
        lmem_wr_data_tag = 'h0;
        lmem_wr_data_evict_way = 'h0;
        lmem_wr_data_sharers = 'h0;
        lmem_wr_data_owner = 'h0;
        lmem_wr_data_dirty_bit = 1'b0;
        lmem_set_in = 'h0;
        lmem_way_in = 'h0;
        clr_evict_stall = 1'b0;
        set_evict_stall = 1'b0;
        set_set_conflict_fsm = 1'b0;
        clr_set_conflict_fsm = 1'b0;
        set_req_conflict = 1'b0;
        mem_rsp_way_next = 'h0;

        incr_invack_cnt = 1'b0;
        clr_invack_cnt = 1'b0;
        skip_invack_cnt = 1'b0;
        incr_l2_cnt = 1'b0;
        clr_l2_cnt = 1'b0;
        incr_flush_way = 1'b0;
        incr_flush_set = 1'b0;

        incr_bulk_nack_counter = 1'b0;
        clr_bulk_nack_counter = 1'b0;
        incr_bulk_done = 1'b0;
        set_req_bulk_addr_data = 'h0;
        set_req_bulk_addr = 1'b0;
        wtfwd_temp_line = 'h0;

        case (state)
            RESET : begin
                lmem_wr_en_state = 1'b1;
                lmem_wr_data_state = 'h0;
                lmem_set_in = rst_set;
            end
            DECODE : begin
                // The lmem_set_in here is because read_mem is enabled always for the localmem.
                // Therfore, this ensures the correct set is read into the bufs.
                if (do_flush_next) begin
                    lmem_set_in = flush_set;
                end else if (do_get_rsp_next) begin
                    lmem_set_in = line_br_next.set;
                end else if (do_get_req_next || do_bulk_req_next) begin
                    lmem_set_in = line_br_next.set;
                end
            end
            RSP_MSHR_LOOKUP : begin
                // Check the MSHR for the entry corresponding to the response.
                mshr_op_code = `LLC_MSHR_LOOKUP;
                rd_set_into_bufs = 1'b1;
            end
            RSP_INV_HANDLER : begin
                // Reduce number of invalidations to wait for by one.
                // We do not update the MSHR entry immediately to ensure idempotence since
                // llc_rsp_out_ready_int might not be high.
                update_mshr_value_invack_cnt = mshr[mshr_i].invack_cnt - 1;

                // Remove the sender from the sharers list.
                lmem_set_in = line_br.set;
                lmem_way_in = mshr[mshr_i].way;
                lmem_wr_data_sharers = sharers_buf[mshr[mshr_i].way] & ~(1 << llc_rsp_in.req_id);
                lmem_wr_en_sharers = 1'b1;

                // Once all invalidations are received, we clear the MSHR entry and invalidate the state RAM.
                if (!update_mshr_value_invack_cnt) begin
                    case (mshr[mshr_i].state)
                        `LLC_SO : begin
                            if (llc_rsp_out_ready_int) begin
                                send_rsp_out (
                                    /* coh_msg */ `RSP_Odata,
                                    /* line_addr */ llc_rsp_in.addr,
                                    /* line */ mshr[mshr_i].line,
                                    /* req_id */ mshr[mshr_i].req_id,
                                    /* dest_id */ mshr[mshr_i].req_id,
                                    /* invack_cnt */ 'h0,
                                    /* word_offset */ 'h0,
                                    /* word_mask */ mshr[mshr_i].word_mask
                                );

                                // Clear the MSHR entry
                                update_mshr_state = 1'b1;
                                update_mshr_value_state = `LLC_I;
                                incr_mshr_cnt = 1'b1;
                            end
                        end
                        `LLC_SWB : begin
                            // Update the states RAM to invalid.
                            lmem_set_in = line_br.set;
                            lmem_way_in = mshr[mshr_i].way;
                            lmem_wr_data_state = `LLC_I;
                            lmem_wr_en_state = 1'b1;

                            // Clear the MSHR entry
                            update_mshr_state = 1'b1;
                            update_mshr_value_state = `LLC_I;
                            incr_mshr_cnt = 1'b1;

                            // LLC_SWB is triggered on eviction therefore, we clear the evict_stall.
                            // In FSM 1, we transition to DECODE state, where input_decoder checks if set_conflict is asserted
                            // and there is no evict stall. This triggers the interface to update the input request with
                            // original pending request that caused the eviction.
                            lmem_wr_data_evict_way = mshr[mshr_i].way + 1;
                            lmem_wr_en_evict_way = 1'b1;
                            clr_evict_stall = 1'b1;
                        end
                        `LLC_SI : begin
                            // Update the states RAM
                            lmem_set_in = line_br.set;
                            lmem_way_in = mshr[mshr_i].way;
                            lmem_wr_data_state = `LLC_I;
                            lmem_wr_en_state = 1'b1;

                            // Clear the MSHR entry
                            update_mshr_state = 1'b1;
                            update_mshr_value_state = `LLC_I;
                            incr_mshr_cnt = 1'b1;

                            // LLC_SI is triggered on eviction therefore, we clear the evict_stall.
                            // In FSM 1, we transition to DECODE state, where input_decoder checks if set_conflict is asserted
                            // and there is no evict stall. This triggers the interface to update the input request with
                            // original pending request that caused the eviction.
                            lmem_wr_data_evict_way = mshr[mshr_i].way + 1;
                            lmem_wr_en_evict_way = 1'b1;
                            clr_evict_stall = 1'b1;
                        end
                        `LLC_SV : begin
                            // If responses were received for a bulk write to a shared line, then
                            // we do not need to immediately send the response - we only need to clear
                            // the MSHR entry that was tracking invalidation.
                            if (llc_rsp_out_ready_int) begin
                                if (!mshr_coalesce_hit) begin
                                    send_rsp_out (
                                        /* coh_msg */ `RSP_O,
                                        /* line_addr */ llc_rsp_in.addr,
                                        /* line */ 'h0,
                                        /* req_id */ mshr[mshr_i].req_id,
                                        /* dest_id */ mshr[mshr_i].req_id,
                                        /* invack_cnt */ 'h0,
                                        /* word_offset */ 'h0,
                                        /* word_mask */ mshr[mshr_i].word_mask
                                    );
                                end

                                // Clear the MSHR entry
                                update_mshr_state = 1'b1;
                                update_mshr_value_state = `LLC_I;
                                incr_mshr_cnt = 1'b1;
                            end
                        end
                    endcase
                end else begin
                    // Update MSHR immediately only in cases where we're yet to receive more responses.
                    update_mshr_invack_cnt = 1'b1;
                end
            end
            RSP_INV_HANDLER_MEM_REQ : begin
                // Once all the invalidates have been received, write back line in MSHR to memory.
                // We take an additional cycle here because RSP_INV_HANDLER has several non-idempotent
                // operations like invack decrement and incr_mshr_count update. Although the
                // later could be done by testing llc_mem_req_ready_int, we do this for simplicity.
                if (llc_mem_req_ready_int) begin
                    send_mem_req (
                        /* coh_msg */ `LLC_WRITE,
                        /* line_addr */ llc_rsp_in.addr,
                        /* hprot */ mshr[mshr_i].hprot,
                        /* line */ mshr[mshr_i].line
                    );
                end
            end
            RSP_RVK_O_HANDLER : begin
                if (mshr[mshr_i].invack_cnt == 'h1) begin
                    // This is a response for a bulk response from an owner of the line currently
                    // serviced. LLC does not change the ownership state of the line, only responds back
                    // to the owner, clears the MSHR entry and increments bulk transfer tracking registers.
                    case (mshr[mshr_i].state)
                        `LLC_OV : begin
                            if (llc_rsp_out_ready_int) begin
                                // We assume that the owners are not at word granularity and respond back to the
                                // requestor with all the words in the response. Similarly, update_mshr_value_line 
                                // is not technically necessary in this case since it will be equal to llc_rsp_in.line.
                                send_rsp_out (
                                    /* coh_msg */ `RSP_V,
                                    /* line_addr */ llc_rsp_in.addr,
                                    /* line */ llc_rsp_in.line,
                                    /* req_id */ mshr[mshr_i].req_id,
                                    /* dest_id */ mshr[mshr_i].req_id,
                                    /* invack_cnt */ 'h1,
                                    /* word_offset */ 'h0,
                                    /* word_mask */ llc_rsp_in.word_mask
                                );

                                clr_bulk_nack_counter = 1'b1;
                                incr_bulk_done = 1'b1;
                                set_req_bulk_addr_data = llc_req_in.addr + 1;
                                set_req_bulk_addr = 1'b1;

                                // A valid state revoke for bulk transfers will result in a set conflict
                                // since the bulk element will be reattempted immediately after the forward is sent.
                                // Therefore, we clear the set conflict here.
                                clr_set_conflict_fsm = 1'b1;

                                // Clear the MSHR entry
                                update_mshr_state = 1'b1;
                                update_mshr_value_state = `LLC_I;
                                incr_mshr_cnt = 1'b1;
                            end
                        end
                    endcase
                end else begin
                    // Directly update the RAMs because only one response is expected - lines and owner.
                    lmem_set_in = line_br.set;
                    lmem_way_in = mshr[mshr_i].way;
                    // Update the words in the response in the line, based on word_mask (overwriting the owner ID).
                    write_line_helper (
                        /* line_orig */ mshr[mshr_i].line,
                        /* line_in */ llc_rsp_in.line,
                        /* word_mask_i */ llc_rsp_in.word_mask,
                        /* line_out */ lmem_wr_data_line
                    );
                    // Clear the words that were owned earlier..
                    lmem_wr_data_owner = owners_buf[mshr[mshr_i].way] & ~llc_rsp_in.word_mask;
                    lmem_wr_data_dirty_bit = 1'b1;
                    lmem_wr_en_line = 1'b1;
                    lmem_wr_en_owner = 1'b1;
                    lmem_wr_en_dirty_bit = 1'b1;

                    // We do not change the sharers list because L2 invalidates on revoke rather than go to shared.
                    // State table shows to move to valid state, which is okay even on eviction from LLC. However,
                    // this necessitates a self-invalidation. Therefore, we choose to invalidate instead for now.
                    case (mshr[mshr_i].state)
                        `LLC_OWB : begin
                            // Send the mem req and clear the MSHR entry only when mem req is accepted.
                            if (llc_mem_req_ready_int) begin
                                send_mem_req (
                                    /* coh_msg */ `LLC_WRITE,
                                    /* line_addr */ llc_rsp_in.addr,
                                    /* hprot */ mshr[mshr_i].hprot,
                                    /* line */ lmem_wr_data_line
                                );

                                // Clear the MSHR entry
                                update_mshr_state = 1'b1;
                                update_mshr_value_state = `LLC_I;
                                incr_mshr_cnt = 1'b1;
                            end

                            // Update the states RAM
                            lmem_set_in = line_br.set;
                            lmem_way_in = mshr[mshr_i].way;
                            lmem_wr_data_state = `LLC_I;
                            lmem_wr_en_state = 1'b1;

                            // LLC_OWB is triggered on eviction therefore, we clear the evict_stall.
                            // In FSM 1, we transition to DECODE state, where input_decoder checks if set_conflict is asserted
                            // and there is no evict stall. This triggers the interface to update the input request with
                            // original pending request that caused the eviction.
                            // It is okay to update evict_way multiple times here since
                            // mshr[mshr_i].way (which is same as evict_way_buf) is never updated till entry is freed.
                            lmem_wr_data_evict_way = mshr[mshr_i].way + 1;
                            lmem_wr_en_evict_way = 1'b1;
                            clr_evict_stall = 1'b1;
                        end
                        `LLC_OS : begin
                            // Clear the MSHR entry
                            update_mshr_state = 1'b1;
                            update_mshr_value_state = `LLC_I;
                            incr_mshr_cnt = 1'b1;

                            // Update the states RAM
                            lmem_set_in = line_br.set;
                            lmem_way_in = mshr[mshr_i].way;
                            lmem_wr_data_state = `LLC_S;
                            lmem_wr_en_state = 1'b1;
                        end
                    endcase
                end
            end
            ONGOING_FLUSH_LOOKUP : begin
                rd_set_into_bufs = 1'b1;
                lmem_set_in = flush_set;
            end
            ONGOING_FLUSH_PROCESS : begin
                // If the line in flush_way is not dirty, we can safely invalidate it,
                // similar to how we do in evictions.
                if (!dirty_bits_buf[flush_way] || states_buf[flush_way] == `LLC_I) begin
                    lmem_set_in = flush_set;
                    lmem_way_in = flush_way;
                    lmem_wr_data_state = `LLC_I;
                    lmem_wr_en_state = 1'b1;

                    // Increment the flush way and increment flush set
                    // if we are at the last way.
                    incr_flush_way = 1'b1;
                    if (flush_way + incr_flush_way == `LLC_WAYS) begin
                        incr_flush_set = 1'b1;
                    end
                end
            end
            ONGOING_FLUSH_EVICT : begin
                // If dirty and mem_req interface is ready, we will write-back the line.
                if (llc_mem_req_ready_int) begin
                    send_mem_req (
                        /* coh_msg */ `LLC_WRITE,
                        /* line_addr */ (tags_buf[flush_way] << `LLC_SET_BITS) | flush_set,
                        /* hprot */ hprots_buf[flush_way],
                        /* line */ lines_buf[flush_way]
                    );

                    // Update the states and evict_way RAM
                    lmem_set_in = flush_set;
                    lmem_way_in = flush_way;
                    lmem_wr_data_state = `LLC_I;
                    lmem_wr_en_state = 1'b1;

                    // Increment the flush way and increment flush set
                    // if we are at the last way.
                    incr_flush_way = 1'b1;
                    if (flush_way + incr_flush_way == `LLC_WAYS) begin
                        incr_flush_set = 1'b1;
                    end
                end
            end
            REQ_MSHR_LOOKUP : begin
                // Check for conflicts in MSHR. Also, read set from RAMs to buffers for the tag lookup in next cycle.
                mshr_op_code = `LLC_MSHR_PEEK_REQ;
                rd_set_into_bufs = 1'b1;
                lmem_set_in = line_br.set;
            end
            REQ_SET_CONFLICT : begin
                set_req_conflict = 1'b1;
            end
            REQ_TAG_LOOKUP : begin
                lookup_en = 1'b1;
                lookup_mode = `LLC_LOOKUP;
            end
            REQ_ODATA_HANDLER_HIT : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
                        // For words that are owned elsewhere, we need to send a FWD_REQ_Odata
                        // to the owner. For the remaining words, we can send the response ourselves.
                        // TODO: We assume line granularity here. Need coalescing for word granularity.
                        if (word_owner_mask) begin
                            // Send forward to owner, if we have any unowned words.
                            if (llc_fwd_out_ready_int) begin
                                send_fwd_out (
                                    /* coh_msg */ `FWD_REQ_Odata,
                                    /* addr */ llc_req_in.addr,
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ owners_cache_id[0],
                                    /* word_mask */ word_owner_mask,
                                    /* line */ 'h0
                                );
                            end
                        end
                    end
                    `LLC_S : begin
                        // If this line is shared elsewhere, we need to send a FWD_INV to all sharers.
                        // We do this by checking each element of the sharer's list on by one.
                        // If a sharer is found, a forward is sent, and fwd_invack_cnt is incremented.
                        // We remove the requestor from the sharers list (if present) without FWD_INV.
                        // Enhancement: this is going to take MAX_N_L2 cycles - possible to optimize?
                        if ((sharers_buf[req_in_way] & (1 << fwd_l2_cnt)) && fwd_l2_cnt != llc_req_in.req_id) begin
                            // Send forward to owner, if we have any unowned words.
                            if (llc_fwd_out_ready_int) begin
                                send_fwd_out (
                                    /* coh_msg */ `FWD_INV,
                                    /* addr */ llc_req_in.addr,
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ fwd_l2_cnt,
                                    /* word_mask */ `WORD_MASK_ALL,
                                    /* line */ 'h0
                                );

                                incr_invack_cnt = 1'b1;
                                incr_l2_cnt = 1'b1;
                            end
                        end else begin
                            skip_invack_cnt = 1'b1;
                            incr_l2_cnt = 1'b1;
                        end
                    end
                endcase
            end
            REQ_ODATA_HANDLER_HIT_RSP : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
                        if (word_no_owner_mask) begin
                            // Send response to requestor, if we have any unowned words.
                            if (llc_rsp_out_ready_int) begin
                                send_rsp_out (
                                    /* coh_msg */ `RSP_Odata,
                                    /* line_addr */ llc_req_in.addr,
                                    /* line */ lines_buf[req_in_way],
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ llc_req_in.req_id,
                                    /* invack_cnt */ 'h0,
                                    /* word_offset */ 'h0,
                                    /* word_mask */ word_no_owner_mask
                                );
                            end
                        end

                        // Update owner mask in owner RAM and owner ID in lines RAM
                        // for all the words requested (owned elsewhere and otherwise).
                        lmem_set_in = line_br.set;
                        lmem_way_in = req_in_way;
                        write_owner_helper (
                            /* line_orig */ lines_buf[req_in_way],
                            /* req_id */ llc_req_in.req_id,
                            /* word_mask_i */ llc_req_in.word_mask,
                            /* line_out */ lmem_wr_data_line
                        );
                        lmem_wr_data_owner = owners_buf[req_in_way] | llc_req_in.word_mask;
                        lmem_wr_en_line = 1'b1;
                        lmem_wr_en_owner = 1'b1;
                    end
                    `LLC_S : begin
                        // If we sent any invalidations, we have to add an MSHR entry
                        // before responding to the original requestor. If not, we
                        // can directly respond now.
                        if (fwd_invack_cnt) begin
                            fill_mshr_entry (
                                /* msg */ `FWD_INV,
                                /* req_id */ llc_req_in.req_id,
                                /* tag */ tags_buf[req_in_way],
                                /* way */ req_in_way,
                                /* state */ `LLC_SO,
                                /* hprot */ hprots_buf[req_in_way],
                                /* invack_cnt */ fwd_invack_cnt,
                                /* line */ lines_buf[req_in_way],
                                /* word_mask */ llc_req_in.word_mask
                            );
                        end else begin
                            if (llc_rsp_out_ready_int) begin
                                send_rsp_out (
                                    /* coh_msg */ `RSP_Odata,
                                    /* line_addr */ llc_req_in.addr,
                                    /* line */ lines_buf[req_in_way],
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ llc_req_in.req_id,
                                    /* invack_cnt */ 'h0,
                                    /* word_offset */ 'h0,
                                    /* word_mask */ llc_req_in.word_mask
                                );
                            end
                        end

                        // We remove the requestor from the sharers list (if present) without FWD_INV.
                        lmem_set_in = line_br.set;
                        lmem_way_in = req_in_way;
                        lmem_wr_data_sharers = sharers_buf[req_in_way] & ~(1 << llc_req_in.req_id);
                        lmem_wr_en_sharers = 1'b1;

                        // Update owner mask in owner RAM, owner ID in lines RAM and state to valid.
                        lmem_set_in = line_br.set;
                        lmem_way_in = req_in_way;
                        write_owner_helper (
                            /* line_orig */ lines_buf[req_in_way],
                            /* req_id */ llc_req_in.req_id,
                            /* word_mask_i */ llc_req_in.word_mask,
                            /* line_out */ lmem_wr_data_line
                        );
                        lmem_wr_data_owner = llc_req_in.word_mask;
                        lmem_wr_data_state = `LLC_V;
                        lmem_wr_en_line = 1'b1;
                        lmem_wr_en_owner = 1'b1;
                        lmem_wr_en_state = 1'b1;

                        // Clear the forward inv registers.
                        clr_invack_cnt = 1'b1;
                        clr_l2_cnt = 1'b1;
                    end
                endcase
            end
            REQ_ODATA_HANDLER_MISS : begin
                if (llc_mem_req_ready_int) begin
                    // On miss, get data from memory.
                    send_mem_req (
                        /* coh_msg */ `LLC_READ,
                        /* line_addr */ llc_req_in.addr,
                        /* hprot */ llc_req_in.hprot,
                        /* line */ 'h0
                    );

                    // Indicate ready for data from memory, and update way to be allocated.
                    llc_mem_rsp_ready_int = 1'b1;
                    mem_rsp_way_next = req_in_way;
                end
            end
            REQ_ODATA_HANDLER_MISS_MEM_RSP : begin
                llc_mem_rsp_ready_int = 1'b1;

                if (llc_mem_rsp_valid_int) begin
                    // Update all RAMs - owners_buf and lines_buf with word owned and owner ID, respectively.
                    lmem_set_in = line_br.set;
                    lmem_way_in = req_in_way;
                    write_owner_helper (
                        /* line_orig */ llc_mem_rsp_next.line,
                        /* req_id */ llc_req_in.req_id,
                        /* word_mask_i */ llc_req_in.word_mask,
                        /* line_out */ lmem_wr_data_line
                    );
                    lmem_wr_data_owner = llc_req_in.word_mask;
                    lmem_wr_data_sharers = 'h0;
                    lmem_wr_data_hprot = llc_req_in.hprot;
                    lmem_wr_data_tag = line_br.tag;
                    lmem_wr_data_state = `LLC_V;
                    lmem_wr_data_dirty_bit = 1'b0;
                    lmem_wr_en_all_mem = 1'b1;
                end
            end
            REQ_ODATA_HANDLER_MISS_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    // Send response to requestor.
                    send_rsp_out (
                        /* coh_msg */ `RSP_Odata,
                        /* line_addr */ llc_req_in.addr,
                        /* line */ llc_mem_rsp.line,
                        /* req_id */ llc_req_in.req_id,
                        /* dest_id */ llc_req_in.req_id,
                        /* invack_cnt */ 'h0,
                        /* word_offset */ 'h0,
                        /* word_mask */ llc_req_in.word_mask
                    );
                end
            end
            REQ_S_HANDLER_HIT : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
                        // For words that are owned elsewhere, we need to send a FWD_REQ_S
                        // to the owner. For the remaining words, we can send the response ourselves.
                        // TODO: We assume line granularity here. Need coalescing for word granularity.
                        if (word_owner_mask) begin
                            // Send forward to owner, if we have any unowned words.
                            if (llc_fwd_out_ready_int) begin
                                send_fwd_out (
                                    /* coh_msg */ `FWD_REQ_S,
                                    /* addr */ llc_req_in.addr,
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ owners_cache_id[0],
                                    /* word_mask */ word_owner_mask,
                                    /* line */ 'h0
                                );

                                fill_mshr_entry (
                                    /* msg */ `FWD_REQ_S,
                                    /* req_id */ llc_req_in.req_id,
                                    /* tag */ tags_buf[req_in_way],
                                    /* way */ req_in_way,
                                    /* state */ `LLC_OS,
                                    /* hprot */ hprots_buf[req_in_way],
                                    /* invack_cnt */ 'h0,
                                    /* line */ lines_buf[req_in_way],
                                    /* word_mask */ word_owner_mask
                                );
                            end
                        end
                    end
                    `LLC_S : begin
                        // Send response to requestor.
                        if (llc_rsp_out_ready_int) begin
                            send_rsp_out (
                                /* coh_msg */ `RSP_S,
                                /* line_addr */ llc_req_in.addr,
                                /* line */ lines_buf[req_in_way],
                                /* req_id */ llc_req_in.req_id,
                                /* dest_id */ llc_req_in.req_id,
                                /* invack_cnt */ 'h0,
                                /* word_offset */ 'h0,
                                /* word_mask */ llc_req_in.word_mask
                            );
                        end

                        // Update sharer RAM - add requestor
                        lmem_set_in = line_br.set;
                        lmem_way_in = req_in_way;
                        lmem_wr_data_sharers = sharers_buf[req_in_way] | (1 << llc_req_in.req_id);
                        lmem_wr_en_sharers = 1'b1;
                    end
                endcase
            end
            REQ_S_HANDLER_HIT_RSP : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
                        if (word_no_owner_mask) begin
                            // Send response to requestor, if we have any unowned words.
                            if (llc_rsp_out_ready_int) begin
                                send_rsp_out (
                                    /* coh_msg */ `RSP_S,
                                    /* line_addr */ llc_req_in.addr,
                                    /* line */ lines_buf[req_in_way],
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ llc_req_in.req_id,
                                    /* invack_cnt */ 'h0,
                                    /* word_offset */ 'h0,
                                    /* word_mask */ word_no_owner_mask
                                );
                            end
                        end

                        // Update sharer, states RAM
                        lmem_set_in = line_br.set;
                        lmem_way_in = req_in_way;
                        // We can overwrite sharers buf here, since there are no
                        // old sharers to worry about if line is LLC_V.
                        lmem_wr_data_sharers = 1 << llc_req_in.req_id;
                        lmem_wr_data_state = `LLC_S;
                        lmem_wr_en_sharers = 1'b1;
                        lmem_wr_en_state = 1'b1;
                    end
                endcase
            end
            REQ_S_HANDLER_MISS : begin
                if (llc_mem_req_ready_int) begin
                    // On miss, get data from memory.
                    send_mem_req (
                        /* coh_msg */ `LLC_READ,
                        /* line_addr */ llc_req_in.addr,
                        /* hprot */ llc_req_in.hprot,
                        /* line */ 'h0
                    );

                    // Indicate ready for data from memory, and update way to be allocated.
                    llc_mem_rsp_ready_int = 1'b1;
                    mem_rsp_way_next = req_in_way;
                end
            end
            REQ_S_HANDLER_MISS_MEM_RSP : begin
                llc_mem_rsp_ready_int = 1'b1;

                if (llc_mem_rsp_valid_int) begin
                    // Update all RAMs.
                    lmem_set_in = line_br.set;
                    lmem_way_in = req_in_way;
                    lmem_wr_data_line = llc_mem_rsp_next.line;
                    lmem_wr_data_sharers = 1 << llc_req_in.req_id;
                    lmem_wr_data_owner = 'h0;
                    lmem_wr_data_hprot = llc_req_in.hprot;
                    lmem_wr_data_tag = line_br.tag;
                    lmem_wr_data_state = `LLC_S;
                    lmem_wr_data_dirty_bit = 1'b0;
                    lmem_wr_en_all_mem = 1'b1;
                end
            end
            REQ_S_HANDLER_MISS_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    // Send response to requestor.
                    send_rsp_out (
                        /* coh_msg */ `RSP_S,
                        /* line_addr */ llc_req_in.addr,
                        /* line */ llc_mem_rsp.line,
                        /* req_id */ llc_req_in.req_id,
                        /* dest_id */ llc_req_in.req_id,
                        /* invack_cnt */ 'h0,
                        /* word_offset */ 'h0,
                        /* word_mask */ llc_req_in.word_mask
                    );
                end
            end
            REQ_WB_HANDLER_HIT : begin
                // We update the WB data only if the cache sending the write-back
                // is the owner, else ignore with just response.
                // TODO: We're assuming all words have the same owner with owners_cache_id[0];
                // need to fix once we move to supporting word granularity.
                if (word_owner_mask && owners_cache_id[0] == llc_req_in.req_id) begin
                    // Send response for the write-back
                    if (llc_rsp_out_ready_int) begin
                        send_rsp_out (
                            /* coh_msg */ `RSP_WB_ACK,
                            /* line_addr */ llc_req_in.addr,
                            /* line */ 'h0,
                            /* req_id */ llc_req_in.req_id,
                            /* dest_id */ llc_req_in.req_id,
                            /* invack_cnt */ 'h0,
                            /* word_offset */ 'h0,
                            /* word_mask */ llc_req_in.word_mask
                        );
                    end

                    // Update data in lines, remove owner and mark line as dirty.
                    lmem_set_in = line_br.set;
                    lmem_way_in = req_in_way;
                    write_line_helper (
                        /* line_orig */ lines_buf[req_in_way],
                        /* line_in */ llc_req_in.line,
                        /* word_mask_i */ llc_req_in.word_mask,
                        /* line_out */ lmem_wr_data_line
                    );
                    lmem_wr_data_owner = owners_buf[req_in_way] & ~llc_req_in.word_mask;
                    lmem_wr_data_dirty_bit = 1'b1;
                    lmem_wr_en_line = 1'b1;
                    lmem_wr_en_owner = 1'b1;
                    lmem_wr_en_dirty_bit = 1'b1;
                end
            end
            REQ_WB_HANDLER_MISS : begin
                // This is a dummy state to just send the response to the L2 to avoid a
                // deadlock. This might have happened because the L2 issued a WB
                // of the same line as the LLC trying to evict at the same time. Hence,
                // the L2 WB got stalled till the LLC evict is complete. However,
                // once the LLC evict completes, the L2's original WB will miss.
                if (llc_rsp_out_ready_int) begin
                    send_rsp_out (
                        /* coh_msg */ `RSP_WB_ACK,
                        /* line_addr */ llc_req_in.addr,
                        /* line */ 'h0,
                        /* req_id */ llc_req_in.req_id,
                        /* dest_id */ llc_req_in.req_id,
                        /* invack_cnt */ 'h0,
                        /* word_offset */ 'h0,
                        /* word_mask */ llc_req_in.word_mask
                    );
                end
            end
            REQ_V_HANDLER_HIT : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
                        // For words that are owned elsewhere, we need to send a FWD_REQ_V
                        // to the owner. For the remaining words, we can send the response ourselves.
                        // TODO: We assume line granularity here. Need coalescing for word granularity.
                        if (word_owner_mask) begin
                            if (owners_cache_id[0] == llc_req_in.req_id && do_bulk_req) begin
                                // If the REQ_V bulk miss request is already owned by the requestor,
                                // then we send a NACK to the current request and increment the NACK counter.
                                if (llc_rsp_out_ready_int) begin
                                    send_rsp_out (
                                        /* coh_msg */ `RSP_NACK,
                                        /* line_addr */ llc_req_in.addr,
                                        /* line */ 'h0,
                                        /* req_id */ llc_req_in.req_id,
                                        /* dest_id */ llc_req_in.req_id,
                                        /* invack_cnt */ 'h1,
                                        /* word_offset */ 'h0,
                                        /* word_mask */ llc_req_in.word_mask
                                    );

                                    incr_bulk_nack_counter = 1'b1;
                                    incr_bulk_done = 1'b1;
                                    set_req_bulk_addr_data = llc_req_in.addr + 1;
                                    set_req_bulk_addr = 1'b1;
                                end
                            end else begin
                                // Send forward to owner, if we have any unowned words.
                                // TMP FIX: If there is a bulk transfer element that is owned elsewhere,
                                // we will request for that data with FWD_REQ_V but set the req_id as the
                                // owner itself. Using this, the owner will know to respond back to the LLC
                                // with the up to date copy (using RSP_RVK_O), however, without ceding ownership.
                                // The LLC when it receives this response, will check the MSHR entry to find that
                                // this is a bulk response, release evict stall without changing the ownership state
                                // of the line and respond back to the requestor with received data as a RSP_V.
                                // If the line is partially owned, we will coalesce the returned works with the
                                // existing words in the LLC and respond with the full line as RSP_V.
                                if (do_bulk_req) begin
                                    // If the REQ_V bulk miss request is already owned by the requestor,
                                    // then we send a NACK to the current request and increment the NACK counter.
                                    send_fwd_out (
                                        /* coh_msg */ `FWD_RVK_V,
                                        /* addr */ llc_req_in.addr,
                                        /* req_id */ owners_cache_id[0],
                                        /* dest_id */ owners_cache_id[0],
                                        /* word_mask */ word_owner_mask,
                                        /* line */ 'h0
                                    );

                                    fill_mshr_entry (
                                        /* msg */ `FWD_RVK_V,
                                        /* req_id */ llc_req_in.req_id,
                                        /* tag */ tags_buf[req_in_way],
                                        /* way */ req_in_way,
                                        /* state */ `LLC_OV,
                                        /* hprot */ hprots_buf[req_in_way],
                                        /* invack_cnt */ 'h1,
                                        /* line */ lines_buf[req_in_way],
                                        /* word_mask */ word_owner_mask
                                    );        
                                end else begin
                                    if (llc_fwd_out_ready_int) begin
                                        send_fwd_out (
                                            /* coh_msg */ `FWD_REQ_V,
                                            /* addr */ llc_req_in.addr,
                                            /* req_id */ llc_req_in.req_id,
                                            /* dest_id */ owners_cache_id[0],
                                            /* word_mask */ word_owner_mask,
                                            /* line */ 'h0
                                        );
                                    end
                                end
                            end
                        end
                    end
                    `LLC_S : begin
                        // Send response to requestor.
                        if (llc_rsp_out_ready_int) begin
                            send_rsp_out (
                                /* coh_msg */ `RSP_V,
                                /* line_addr */ llc_req_in.addr,
                                /* line */ lines_buf[req_in_way],
                                /* req_id */ llc_req_in.req_id,
                                /* dest_id */ llc_req_in.req_id,
                                /* invack_cnt */ do_bulk_req ? 'h1 : 'h0,
                                /* word_offset */ 'h0,
                                /* word_mask */ llc_req_in.word_mask
                            );

                            if (do_bulk_req) begin
                                clr_bulk_nack_counter = 1'b1;
                                incr_bulk_done = 1'b1;
                                set_req_bulk_addr_data = llc_req_in.addr + 1;
                                set_req_bulk_addr = 1'b1;
                            end
                        end
                    end
                endcase
            end
            REQ_V_HANDLER_HIT_RSP : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
                        if (word_no_owner_mask) begin
                            // Send response to requestor, if we have any unowned words.
                            if (llc_rsp_out_ready_int) begin
                                send_rsp_out (
                                    /* coh_msg */ `RSP_V,
                                    /* line_addr */ llc_req_in.addr,
                                    /* line */ lines_buf[req_in_way],
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ llc_req_in.req_id,
                                    /* invack_cnt */ do_bulk_req ? 'h1 : 'h0,
                                    /* word_offset */ 'h0,
                                    /* word_mask */ word_no_owner_mask
                                );

                                if (do_bulk_req) begin
                                    clr_bulk_nack_counter = 1'b1;
                                    incr_bulk_done = 1'b1;
                                    set_req_bulk_addr_data = llc_req_in.addr + 1;
                                    set_req_bulk_addr = 1'b1;
                                end
                            end
                        end
                    end
                endcase
            end
            REQ_V_HANDLER_MISS : begin
                if (llc_mem_req_ready_int) begin
                    // On miss, get data from memory.
                    send_mem_req (
                        /* coh_msg */ `LLC_READ,
                        /* line_addr */ llc_req_in.addr,
                        /* hprot */ llc_req_in.hprot,
                        /* line */ 'h0
                    );

                    // Indicate ready for data from memory, and update way to be allocated.
                    llc_mem_rsp_ready_int = 1'b1;
                    mem_rsp_way_next = req_in_way;
                end
            end
            REQ_V_HANDLER_MISS_MEM_RSP : begin
                llc_mem_rsp_ready_int = 1'b1;

                if (llc_mem_rsp_valid_int) begin
                    // Update all RAMs.
                    lmem_set_in = line_br.set;
                    lmem_way_in = req_in_way;
                    lmem_wr_data_line = llc_mem_rsp_next.line;
                    lmem_wr_data_sharers = 'h0;
                    lmem_wr_data_owner = 'h0;
                    lmem_wr_data_hprot = llc_req_in.hprot;
                    lmem_wr_data_tag = line_br.tag;
                    lmem_wr_data_state = `LLC_V;
                    lmem_wr_data_dirty_bit = 1'b0;
                    lmem_wr_en_all_mem = 1'b1;
                end
            end
            REQ_V_HANDLER_MISS_RSP : begin
                if (llc_rsp_out_ready_int) begin
                    // Send response to requestor.
                    send_rsp_out (
                        /* coh_msg */ `RSP_V,
                        /* line_addr */ llc_req_in.addr,
                        /* line */ llc_mem_rsp.line,
                        /* req_id */ llc_req_in.req_id,
                        /* dest_id */ llc_req_in.req_id,
                        /* invack_cnt */ do_bulk_req ? 'h1 : 'h0,
                        /* word_offset */ 'h0,
                        /* word_mask */ llc_req_in.word_mask
                    );
                    
                    if (do_bulk_req) begin
                        clr_bulk_nack_counter = 1'b1;
                        incr_bulk_done = 1'b1;
                        set_req_bulk_addr_data = llc_req_in.addr + 1;
                        set_req_bulk_addr = 1'b1;
                    end
                end
            end            
            REQ_WTFWD_HANDLER_HIT : begin
                if (llc_req_in.word_mask == 'h0 && llc_req_in.line != 'h0) begin
                    // HEAD packet - we create a new MSHR entry to start tracking this
                    // bulk write and return to DECODE state to wait for the date packets.
                    fill_mshr_entry (
                        /* msg */ `FWD_WTfwd_BULK,
                        /* req_id */ llc_req_in.req_id,
                        /* tag */ line_br.tag,
                        /* way */ 'h0,
                        /* state */ `LLC_O,
                        /* hprot */ `INSTR,
                        /* invack_cnt */ 'h0,
                        /* line */ llc_req_in.line,
                        /* word_mask */ 'h0 
                    ); 
                end else if (llc_req_in.word_mask == 'h0 && llc_req_in.line == 'h0) begin
                    // TAIL packet - we first forward a FWD_WTfwd_BULK tail packet to any pending owner
                    // in the MSHR entry (identified from the hprot and invack_cnt fields of the mshr entry).
                    // We then transition to the RSP state, where the LLC itself can respond to any lines
                    // that it had the up to date copy for.
                    if (mshr_coalesce_hit && mshr[mshr_coalesce_i].hprot == `DATA) begin
                        if (llc_fwd_out_ready_int) begin
                            send_fwd_out (
                                /* coh_msg */ `FWD_WTfwd_BULK,
                                /* addr */ (mshr[mshr_coalesce_i].tag << `LLC_SET_BITS) | mshr[mshr_coalesce_i].set,
                                /* req_id */ llc_req_in.req_id,
                                /* dest_id */ mshr[mshr_coalesce_i].invack_cnt,
                                /* word_mask */ 'h0,
                                /* line */ 'h0
                            );
                        end
                    end
                end else begin
                    case (states_buf[req_in_way])
                        `LLC_V : begin
                            // For words that are owned elsewhere, we need to send a FWD_WTfwd
                            // to the owner. For the remaining words, we can send the response ourselves.
                            // TODO: We assume there's only one owner for all the words.
                            if (word_owner_mask) begin
                                // Send forward to owner, if we have any unowned words.
                                if (llc_fwd_out_ready_int) begin
                                    if (mshr_coalesce_hit && mshr[mshr_coalesce_i].hprot == `INSTR) begin
                                        // If there is no owner already tracked in this bulk transfer, we will send
                                        // the HEAD packet to the owner, and update the hprot and invack_cnt fields.
                                        // We always use the original start address of the bulk transfer and original
                                        // length for control messages so that destination caches can have a uniform
                                        // implementation within_bulk_check in their MSHR modules.
                                        get_ref_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line);

                                        send_fwd_out (
                                            /* coh_msg */ `FWD_WTfwd_BULK,
                                            /* addr */ (mshr[mshr_coalesce_i].tag << `LLC_SET_BITS) | mshr[mshr_coalesce_i].set,
                                            /* req_id */ llc_req_in.req_id,
                                            /* dest_id */ owners_cache_id[0],
                                            /* word_mask */ 'h0,
                                            /* line */ wtfwd_temp_line
                                        );

                                        update_mshr_coal_hprot = 1'b1;
                                        update_mshr_value_hprot = `DATA;
                                        update_mshr_coal_invack_cnt = 1'b1;
                                        update_mshr_value_invack_cnt = owners_cache_id[0];
                                    end else if (mshr_coalesce_hit && mshr[mshr_coalesce_i].hprot == `DATA && mshr[mshr_coalesce_i].invack_cnt != owners_cache_id[0]) begin
                                        // If there is an owner already tracked in this bulk transfer, but
                                        // it is not the owner of this line, then we need to first send the TAIL
                                        // packet to that owner, and return to this state again, send the HEAD packet
                                        // to the new owner and update the hprot and invack_cnt fields.
                                        send_fwd_out (
                                            /* coh_msg */ `FWD_WTfwd_BULK,
                                            /* addr */ (mshr[mshr_coalesce_i].tag << `LLC_SET_BITS) | mshr[mshr_coalesce_i].set,
                                            /* req_id */ llc_req_in.req_id,
                                            /* dest_id */ mshr[mshr_coalesce_i].invack_cnt,
                                            /* word_mask */ 'h0,
                                            /* line */ 'h0 
                                        );

                                        update_mshr_coal_hprot = 1'b1;
                                        update_mshr_value_hprot = `INSTR;
                                    end else if (mshr_coalesce_hit && mshr[mshr_coalesce_i].hprot == `DATA && mshr[mshr_coalesce_i].invack_cnt == owners_cache_id[0]) begin
                                        // If there is an owner already tracked in this bulk transfer, and
                                        // it is the same as the owner of this line, we can forward the data 
                                        // direct to that cache.
                                        send_fwd_out (
                                            /* coh_msg */ `FWD_WTfwd_BULK,
                                            /* addr */ llc_req_in.addr,
                                            /* req_id */ llc_req_in.req_id,
                                            /* dest_id */ owners_cache_id[0],
                                            /* word_mask */ word_owner_mask,
                                            /* line */ llc_req_in.line
                                        );

                                        if (llc_req_in.word_mask == 'h2) begin
                                            update_mshr_value_word_mask = 'h1;
                                            update_mshr_coal_word_mask = 1'b1;
                                        end
                                    end else begin
                                        // Original non-bulk WTfwd case.
                                        send_fwd_out (
                                            /* coh_msg */ `FWD_WTfwd,
                                            /* addr */ llc_req_in.addr,
                                            /* req_id */ llc_req_in.req_id,
                                            /* dest_id */ owners_cache_id[0],
                                            /* word_mask */ word_owner_mask,
                                            /* line */ llc_req_in.line
                                        );
                                    end
                                end
                            end
                        end
                        `LLC_S : begin
                            // If this line is shared elsewhere, we need to send a FWD_INV to all sharers.
                            // We do this by checking each element of the sharer's list on by one.
                            // If a sharer is found, a forward is sent, and fwd_invack_cnt is incremented.
                            // We remove the requestor from the sharers list (if present) without FWD_INV.
                            // Enhancement: this is going to take MAX_N_L2 cycles - possible to optimize?
                            // Note that for bulk writes, we keep this logic the same because we still
                            // want the sharers to be invalidated. In the next state, we will add an MSHR 
                            // entry to track the responses. Once the responses are received in the response
                            // handler, we will update the coalesced MSHR line entry as well.
                            if ((sharers_buf[req_in_way] & (1 << fwd_l2_cnt)) && fwd_l2_cnt != llc_req_in.req_id) begin
                                // Send forward to owner, if we have any unowned words.
                                if (llc_fwd_out_ready_int) begin
                                    send_fwd_out (
                                        /* coh_msg */ `FWD_INV,
                                        /* addr */ llc_req_in.addr,
                                        /* req_id */ llc_req_in.req_id,
                                        /* dest_id */ fwd_l2_cnt,
                                        /* word_mask */ `WORD_MASK_ALL,
                                        /* line */ 'h0
                                    );

                                    incr_invack_cnt = 1'b1;
                                    incr_l2_cnt = 1'b1;
                                end
                            end else begin
                                skip_invack_cnt = 1'b1;
                                incr_l2_cnt = 1'b1;
                            end
                        end
                    endcase
                end
            end
            REQ_WTFWD_HANDLER_HIT_RSP : begin
                if (llc_req_in.word_mask == 'h0 && llc_req_in.line == 'h0) begin
                    // TAIL packet - we have previously forwarded the tail packet to the current owner
                    // tracked in the MSHR entry. In this state, the LLC will respond to any words that
                    // it had responded to during the course of the bulk transfer.
                    get_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line);

                    if (mshr_coalesce_hit) begin
                        if (wtfwd_temp_line != 0) begin
                            if (llc_rsp_out_ready_int) begin
                                send_rsp_out (
                                    /* coh_msg */ `RSP_O,
                                    /* line_addr */ (mshr[mshr_coalesce_i].tag << `LLC_SET_BITS) | mshr[mshr_coalesce_i].set,
                                    /* line */ wtfwd_temp_line,
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ llc_req_in.req_id,
                                    /* invack_cnt */ 'h0,
                                    /* word_offset */ 'h0,
                                    /* word_mask */ 'h0
                                );
                            end
                        end

                        if (llc_rsp_out_ready_int) begin
                            // Clear the MSHR entry
                            update_mshr_coal_state = 1'b1;
                            update_mshr_value_state = `LLC_I;
                            incr_mshr_cnt = 1'b1;
                        end
                    end
                end else begin
                    case (states_buf[req_in_way])
                        `LLC_V : begin
                            if (word_no_owner_mask) begin
                                // For the words that are not owned, we directly update
                                // the line in the LLC, and send response to requestor.
                                // Unlike in REQ_Odata and REQ_S before this, we will
                                // update the line and dirty bit only if there are
                                // unowned words in the LLC.
                                if (mshr_coalesce_hit) begin
                                    // Here, we will update the second word of the line of the MSHR
                                    // entry that is coalescing the response by the number of words
                                    // that are in the word_no_owner_mask.
                                    get_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line);
                                    wtfwd_temp_line = wtfwd_temp_line + (word_no_owner_mask == `WORD_MASK_ALL ? 2 : 1);
                                    set_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line, update_mshr_value_line);
                                    update_mshr_coal_line = 1'b1;

                                    if (llc_req_in.word_mask == 'h2) begin
                                        update_mshr_value_word_mask = 'h1;
                                        update_mshr_coal_word_mask = 1'b1;
                                    end
                                end else begin
                                    if (llc_rsp_out_ready_int) begin
                                        send_rsp_out (
                                            /* coh_msg */ `RSP_O,
                                            /* line_addr */ llc_req_in.addr,
                                            /* line */ 'h0,
                                            /* req_id */ llc_req_in.req_id,
                                            /* dest_id */ llc_req_in.req_id,
                                            /* invack_cnt */ 'h0,
                                            /* word_offset */ 'h0,
                                            /* word_mask */ word_no_owner_mask
                                        );
                                    end
                                end

                                lmem_set_in = line_br.set;
                                lmem_way_in = req_in_way;
                                write_line_helper (
                                    /* line_orig */ lines_buf[req_in_way],
                                    /* line_in */ llc_req_in.line,
                                    /* word_mask_i */ word_no_owner_mask,
                                    /* line_out */ lmem_wr_data_line
                                );
                                lmem_wr_data_dirty_bit = 1'b1;
                                lmem_wr_en_line = 1'b1;
                                lmem_wr_en_dirty_bit = 1'b1;
                            end
                        end
                        `LLC_S : begin
                            // If we sent any invalidations, we have to add an MSHR entry
                            // before responding to the original requestor.
                            if (mshr_coalesce_hit) begin
                                // Here, we will update the second word of the line of the MSHR
                                // entry that is coalescing the response by the number of words
                                // that are in the word_no_owner_mask.
                                if (fwd_invack_cnt) begin
                                    fill_mshr_entry (
                                        /* msg */ `FWD_INV,
                                        /* req_id */ llc_req_in.req_id,
                                        /* tag */ tags_buf[req_in_way],
                                        /* way */ req_in_way,
                                        /* state */ `LLC_SV,
                                        /* hprot */ hprots_buf[req_in_way],
                                        /* invack_cnt */ fwd_invack_cnt,
                                        /* line */ lines_buf[req_in_way],
                                        /* word_mask */ llc_req_in.word_mask
                                    );
                                end

                                get_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line);
                                wtfwd_temp_line = wtfwd_temp_line + (llc_req_in.word_mask == `WORD_MASK_ALL ? 2 : 1);
                                set_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line, update_mshr_value_line);

                                // Since we are updating two MSHR entries together, we have a special signal to
                                // update the coalesced MSHR entry with the new line value as well. In this specific case,
                                // the line that is added to the FWD_INV MSHR entry is not important, therefore, it is okay
                                // to overwrite with the current length value.
                                update_mshr_coal_line = 1'b1;

                                if (llc_req_in.word_mask == 'h2) begin
                                    update_mshr_value_word_mask = 'h1;
                                    update_mshr_coal_word_mask = 1'b1;
                                end
                            end else begin
                                if (fwd_invack_cnt) begin
                                    fill_mshr_entry (
                                        /* msg */ `FWD_INV,
                                        /* req_id */ llc_req_in.req_id,
                                        /* tag */ tags_buf[req_in_way],
                                        /* way */ req_in_way,
                                        /* state */ `LLC_SV,
                                        /* hprot */ hprots_buf[req_in_way],
                                        /* invack_cnt */ fwd_invack_cnt,
                                        /* line */ lines_buf[req_in_way],
                                        /* word_mask */ llc_req_in.word_mask
                                    );
                                end else begin
                                    if (llc_rsp_out_ready_int) begin
                                        send_rsp_out (
                                            /* coh_msg */ `RSP_O,
                                            /* line_addr */ llc_req_in.addr,
                                            /* line */ 'h0,
                                            /* req_id */ llc_req_in.req_id,
                                            /* dest_id */ llc_req_in.req_id,
                                            /* invack_cnt */ 'h0,
                                            /* word_offset */ 'h0,
                                            /* word_mask */ llc_req_in.word_mask
                                        );
                                    end
                                end
                            end

                            // We can now update the LLC with the words in the request.
                            // We can do this since there is a data-race-free assumption
                            // with REQ_WTfwd. This is simpler than storing the line to
                            // the MSHR entry and updating after all the invalidation
                            // responses are received. However, we must remember to keep only
                            // the words in the request in valid state.
                            lmem_set_in = line_br.set;
                            lmem_way_in = req_in_way;
                            write_line_helper (
                                /* line_orig */ lines_buf[req_in_way],
                                /* line_in */ llc_req_in.line,
                                /* word_mask_i */ word_no_owner_mask,
                                /* line_out */ lmem_wr_data_line
                            );
                            lmem_wr_data_dirty_bit = 1'b1;
                            lmem_wr_en_line = 1'b1;
                            lmem_wr_en_dirty_bit = 1'b1;

                            // We remove the requestor from the sharers list (if present) without FWD_INV.
                            lmem_wr_data_sharers = sharers_buf[req_in_way] & ~(1 << llc_req_in.req_id);
                            lmem_wr_en_sharers = 1'b1;

                            // Zero-out owner mask in owners RAM and set state to valid.
                            lmem_wr_data_owner = 'h0;
                            lmem_wr_data_state = `LLC_V;
                            lmem_wr_en_owner = 1'b1;
                            lmem_wr_en_state = 1'b1;

                            // Clear the forward inv registers.
                            clr_invack_cnt = 1'b1;
                            clr_l2_cnt = 1'b1;
                        end
                    endcase
                end
            end
            REQ_WTFWD_HANDLER_MISS : begin
                // Check if HEAD, TAIL - do the same as above. You do not need to load from memory
                // because you are not updating RAMs for these packets.
                // If neither, go in to the below code, and use the same logic. If WORD_MASK_ALL,
                // update RAMs, check if mshr_coalesce_hit. If yes, update MSHR coalesce entry but
                // do not send back response. Else, only send response.
                // If not WORD_MASK_ALL, read from memory the same way, write to RAMs the same way,
                // but in last state, check if mshr_coalesce_hit. If yes, update MSHR coalesce entry
                // but do not send back response. Else, only send response.
                if (llc_req_in.word_mask == 'h0 && llc_req_in.line != 'h0) begin
                    // HEAD packet - we create a new MSHR entry to start tracking this
                    // bulk write and return to DECODE state to wait for the date packets.
                    fill_mshr_entry (
                        /* msg */ `FWD_WTfwd_BULK,
                        /* req_id */ llc_req_in.req_id,
                        /* tag */ line_br.tag,
                        /* way */ 'h0,
                        /* state */ `LLC_O,
                        /* hprot */ `INSTR,
                        /* invack_cnt */ 'h0,
                        /* line */ llc_req_in.line,
                        /* word_mask */ 'h0 
                    ); 
                end else if (llc_req_in.word_mask == 'h0 && llc_req_in.line == 'h0) begin
                    // TAIL packet - we first forward a FWD_WTfwd_BULK tail packet to any pending owner
                    // in the MSHR entry (identified from the hprot and invack_cnt fields of the mshr entry).
                    // We then transition to the RSP state, where the LLC itself can respond to any lines
                    // that it had the up to date copy for.
                    if (mshr_coalesce_hit && mshr[mshr_coalesce_i].hprot == `DATA) begin
                        if (llc_fwd_out_ready_int) begin
                            send_fwd_out (
                                /* coh_msg */ `FWD_WTfwd_BULK,
                                /* addr */ (mshr[mshr_coalesce_i].tag << `LLC_SET_BITS) | mshr[mshr_coalesce_i].set,
                                /* req_id */ llc_req_in.req_id,
                                /* dest_id */ mshr[mshr_coalesce_i].invack_cnt,
                                /* word_mask */ 'h0,
                                /* line */ 'h0
                            );
                        end
                    end
                end else begin                
                    if (llc_req_in.word_mask == `WORD_MASK_ALL) begin
                        if (llc_rsp_out_ready_int) begin
                            // Update all RAMs - lines_buf with with words in the request,
                            // owners_buf and sharers buf zeroed, but dirty bit ste.
                            lmem_set_in = line_br.set;
                            lmem_way_in = req_in_way;
                            lmem_wr_data_line = llc_req_in.line;
                            lmem_wr_data_dirty_bit = 1'b1;
                            lmem_wr_data_owner = 'h0;
                            lmem_wr_data_sharers = 'h0;
                            lmem_wr_data_hprot = llc_req_in.hprot;
                            lmem_wr_data_tag = line_br.tag;
                            lmem_wr_data_state = `LLC_V;
                            lmem_wr_en_all_mem = 1'b1;

                            if (mshr_coalesce_hit) begin
                                // Here, we will update the second word of the line of the MSHR
                                // entry that is coalescing the response by the number of words
                                // that are in the word_no_owner_mask.
                                get_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line);
                                wtfwd_temp_line = wtfwd_temp_line + 2;
                                set_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line, update_mshr_value_line);
                                update_mshr_coal_line = 1'b1;
                            end else begin
                                send_rsp_out (
                                    /* coh_msg */ `RSP_O,
                                    /* line_addr */ llc_req_in.addr,
                                    /* line */ 'h0,
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ llc_req_in.req_id,
                                    /* invack_cnt */ 'h0,
                                    /* word_offset */ 'h0,
                                    /* word_mask */ llc_req_in.word_mask
                                );
                            end
                        end
                    end else begin
                        if (llc_mem_req_ready_int) begin
                            // On miss, get data from memory.
                            send_mem_req (
                                /* coh_msg */ `LLC_READ,
                                /* line_addr */ llc_req_in.addr,
                                /* hprot */ llc_req_in.hprot,
                                /* line */ 'h0
                            );

                            // Indicate ready for data from memory, and update way to be allocated.
                            llc_mem_rsp_ready_int = 1'b1;
                            mem_rsp_way_next = req_in_way;
                        end
                    end
                end
            end
            REQ_WTFWD_HANDLER_MISS_MEM_RSP : begin
                llc_mem_rsp_ready_int = 1'b1;

                if (llc_mem_rsp_valid_int) begin
                    // Update all RAMs - lines_buf with with words in the request,
                    // owners_buf and sharers buf zeroed, but dirty bit ste.
                    lmem_set_in = line_br.set;
                    lmem_way_in = req_in_way;
                    write_line_helper (
                        /* line_orig */ llc_mem_rsp_next.line,
                        /* line_in */ llc_req_in.line,
                        /* word_mask_i */ llc_req_in.word_mask,
                        /* line_out */ lmem_wr_data_line
                    );
                    lmem_wr_data_dirty_bit = 1'b1;
                    lmem_wr_data_owner = 'h0;
                    lmem_wr_data_sharers = 'h0;
                    lmem_wr_data_hprot = llc_req_in.hprot;
                    lmem_wr_data_tag = line_br.tag;
                    lmem_wr_data_state = `LLC_V;
                    lmem_wr_en_all_mem = 1'b1;
                end
            end
            REQ_WTFWD_HANDLER_MISS_RSP : begin
                if (llc_req_in.word_mask == 'h0 && llc_req_in.line == 'h0) begin
                    // TAIL packet - we have previously forwarded the tail packet to the current owner
                    // tracked in the MSHR entry. In this state, the LLC will respond to any words that
                    // it had responded to during the course of the bulk transfer.
                    get_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line);

                    if (mshr_coalesce_hit) begin
                        if (wtfwd_temp_line != 0) begin
                            if (llc_rsp_out_ready_int) begin
                                send_rsp_out (
                                    /* coh_msg */ `RSP_O,
                                    /* line_addr */ (mshr[mshr_coalesce_i].tag << `LLC_SET_BITS) | mshr[mshr_coalesce_i].set,
                                    /* line */ wtfwd_temp_line,
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ llc_req_in.req_id,
                                    /* invack_cnt */ 'h0,
                                    /* word_offset */ 'h0,
                                    /* word_mask */ 'h0
                                );
                            end
                        end

                        if (llc_rsp_out_ready_int) begin
                            // Clear the MSHR entry
                            update_mshr_coal_state = 1'b1;
                            update_mshr_value_state = `LLC_I;
                            incr_mshr_cnt = 1'b1;
                        end
                    end
                end else begin                
                    if (mshr_coalesce_hit) begin
                        // Here, we will update the second word of the line of the MSHR
                        // entry that is coalescing the response by the number of words
                        // that are in the word_no_owner_mask.
                        get_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line);
                        wtfwd_temp_line = wtfwd_temp_line + (llc_req_in.word_mask == `WORD_MASK_ALL ? 2 : 1);
                        set_cur_len(mshr[mshr_coalesce_i].line, wtfwd_temp_line, update_mshr_value_line);
                        update_mshr_coal_line = 1'b1;

                        if (llc_req_in.word_mask == 'h2) begin
                            update_mshr_value_word_mask = 'h1;
                            update_mshr_coal_word_mask = 1'b1;
                        end
                    end else begin
                        if (llc_rsp_out_ready_int) begin
                            send_rsp_out (
                                /* coh_msg */ `RSP_O,
                                /* line_addr */ llc_req_in.addr,
                                /* line */ 'h0,
                                /* req_id */ llc_req_in.req_id,
                                /* dest_id */ llc_req_in.req_id,
                                /* invack_cnt */ 'h0,
                                /* word_offset */ 'h0,
                                /* word_mask */ llc_req_in.word_mask
                            );
                        end
                    end
                end
            end
            REQ_EVICT : begin
                case (states_buf[evict_way_buf])
                    `LLC_V : begin
                        // Check if there are an owners for words in this line - single owner at the moment.
                        if (!owners_buf[evict_way_buf]) begin
                            // If not, check if the line is dirty.
                            if (dirty_bits_buf[evict_way_buf]) begin
                                send_mem_req (
                                    /* coh_msg */ `LLC_WRITE,
                                    /* line_addr */ (tags_buf[evict_way_buf] << `LLC_SET_BITS) | line_br.set,
                                    /* hprot */ hprots_buf[evict_way_buf],
                                    /* line */ lines_buf[evict_way_buf]
                                );
                            end

                            // Update the states and evict_way RAM
                            lmem_set_in = line_br.set;
                            lmem_way_in = evict_way_buf;
                            lmem_wr_data_evict_way = evict_way_buf + 1;
                            lmem_wr_data_state = `LLC_I;
                            lmem_wr_en_evict_way = 1'b1;
                            lmem_wr_en_state = 1'b1;
                        end else begin
                            // For words that are owned elsewhere, we need to first revoke them.
                            // TODO: We assume line granularity here. Need coalescing for word granularity.
                            if (llc_fwd_out_ready_int) begin
                                send_fwd_out (
                                    /* coh_msg */ `FWD_RVK_O,
                                    /* addr */ (tags_buf[evict_way_buf] << `LLC_SET_BITS) | line_br.set,
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ owners_evict_cache_id[0],
                                    /* word_mask */ word_mask_owned_evict,
                                    /* line */ 'h0
                                );

                                fill_mshr_entry (
                                    /* msg */ `FWD_RVK_O,
                                    /* req_id */ llc_req_in.req_id,
                                    /* tag */ tags_buf[evict_way_buf],
                                    /* way */ evict_way_buf,
                                    /* state */ `LLC_OWB,
                                    /* hprot */ hprots_buf[evict_way_buf],
                                    /* invack_cnt */ 'h0,
                                    /* line */ lines_buf[evict_way_buf],
                                    /* word_mask */ word_mask_owned_evict
                                );
                            end

                            // Set evict stall, so that when the incoming request is checked again, set conflict is asserted.
                            set_evict_stall = 1'b1;
                        end
                    end
                    `LLC_S : begin
                        // If this line is shared elsewhere, we need to send a FWD_INV to all sharers.
                        // We do this by checking each element of the sharer's list on by one.
                        // If a sharer is found, a forward is sent, and fwd_invack_cnt is incremented.
                        // TODO: this is going to take MAX_N_L2 cycles - possible to optimize?
                        if ((sharers_buf[evict_way_buf] & (1 << fwd_l2_cnt))) begin
                            // Send forward to owner, if we have any unowned words.
                            if (llc_fwd_out_ready_int) begin
                                send_fwd_out (
                                    /* coh_msg */ `FWD_INV,
                                    /* addr */ (tags_buf[evict_way_buf] << `LLC_SET_BITS) | line_br.set,
                                    /* req_id */ llc_req_in.req_id,
                                    /* dest_id */ fwd_l2_cnt,
                                    /* word_mask */ `WORD_MASK_ALL,
                                    /* line */ 'h0
                                );

                                incr_invack_cnt = 1'b1;
                                incr_l2_cnt = 1'b1;
                            end
                        end else begin
                            skip_invack_cnt = 1'b1;
                            incr_l2_cnt = 1'b1;
                        end

                        // Once the last element in the sharer's list is processed,
                        // we can add an entry into the MSHR and enter into evict_stall.
                        if (fwd_l2_cnt == `MAX_N_L2-1) begin
                            if (dirty_bits_buf[evict_way_buf]) begin
                                fill_mshr_entry (
                                    /* msg */ `FWD_INV,
                                    /* req_id */ llc_req_in.req_id,
                                    /* tag */ tags_buf[evict_way_buf],
                                    /* way */ evict_way_buf,
                                    /* state */ `LLC_SWB,
                                    /* hprot */ hprots_buf[evict_way_buf],
                                    /* invack_cnt */ fwd_invack_cnt + incr_invack_cnt,
                                    /* line */ lines_buf[evict_way_buf],
                                    /* word_mask */ `WORD_MASK_ALL
                                );
                            end else begin
                                fill_mshr_entry (
                                    /* msg */ `FWD_INV,
                                    /* req_id */ llc_req_in.req_id,
                                    /* tag */ tags_buf[evict_way_buf],
                                    /* way */ evict_way_buf,
                                    /* state */ `LLC_SI,
                                    /* hprot */ hprots_buf[evict_way_buf],
                                    /* invack_cnt */ fwd_invack_cnt + incr_invack_cnt,
                                    /* line */ 'h0,
                                    /* word_mask */ `WORD_MASK_ALL
                                );
                            end

                            // Set evict stall, so that when the incoming request is checked again, set conflict is asserted.
                            set_evict_stall = 1'b1;

                            // Clear the forward inv registers.
                            clr_invack_cnt = 1'b1;
                            clr_l2_cnt = 1'b1;
                        end
                    end
                endcase
            end
            default : begin
                mshr_op_code = `LLC_MSHR_IDLE;
            end
        endcase
    end

    function void send_mem_req;
        input logic hwrite;
        input line_addr_t addr;
        input hprot_t hprot;
        input line_t line;

        llc_mem_req_o.hwrite = hwrite;
        llc_mem_req_o.addr = addr;
        llc_mem_req_o.hsize = `WORD;
        llc_mem_req_o.hprot = hprot;
        llc_mem_req_o.line = line;
        llc_mem_req_valid_int = 1'b1;
    endfunction

    function void send_rsp_out;
        input coh_msg_t coh_msg;
        input line_addr_t addr;
        input line_t line;
        input cache_id_t req_id;
        input cache_id_t dest_id;
        input invack_cnt_t invack_cnt;
        input word_offset_t word_offset;
        input word_mask_t word_mask;

        llc_rsp_out_o.coh_msg = coh_msg;
        llc_rsp_out_o.addr = addr;
        llc_rsp_out_o.line = line;
        llc_rsp_out_o.req_id = req_id;
        llc_rsp_out_o.dest_id = dest_id;
        llc_rsp_out_o.invack_cnt = invack_cnt;
        llc_rsp_out_o.word_offset = word_offset;
        llc_rsp_out_o.word_mask = word_mask;
        llc_rsp_out_valid_int = 1'b1;
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

    function void write_owner_helper;
        input line_t line_orig;
        input cache_id_t req_id;
        input word_mask_t word_mask_i;
        output line_t line_out;

        for (int i = 0; i < `WORDS_PER_LINE; i++) begin
            if (word_mask_i[i]) begin
                line_out[i * `BITS_PER_WORD +: `BITS_PER_WORD] =
                    req_id;
            end else begin
                line_out[i * `BITS_PER_WORD +: `BITS_PER_WORD] =
                    line_orig[i * `BITS_PER_WORD +: `BITS_PER_WORD];
            end
        end
    endfunction

    function void send_fwd_out;
        input mix_msg_t coh_msg;
        input line_addr_t addr;
        input cache_id_t req_id;
        input cache_id_t dest_id;
        input word_mask_t word_mask;
        input line_t line;

        llc_fwd_out_o.coh_msg = coh_msg;
        llc_fwd_out_o.addr = addr;
        llc_fwd_out_o.req_id = req_id;
        llc_fwd_out_o.dest_id = dest_id;
        llc_fwd_out_o.word_mask = word_mask;
        llc_fwd_out_o.line = line;
        llc_fwd_out_valid_int = 1'b1;
    endfunction

    function void fill_mshr_entry;
        input mix_msg_t msg;
        input cache_id_t req_id;
        input llc_tag_t tag;
        input llc_way_t way;
        input unstable_state_t state;
        input hprot_t hprot;
        input invack_cnt_calc_t	invack_cnt;
        input line_t line;
        input word_mask_t word_mask;

        update_mshr_value_msg = msg;
        update_mshr_value_req_id = req_id;
        update_mshr_value_tag = tag;
        update_mshr_value_way = way;
        update_mshr_value_line = line;
        update_mshr_value_state = state;
        update_mshr_value_hprot = hprot;
        update_mshr_value_invack_cnt = invack_cnt;
        update_mshr_value_word_mask = word_mask;
        update_mshr_value_word_mask_reg = word_mask;
        add_mshr_entry = 1'b1;
    endfunction
    
    function void get_cur_len;
        input line_t line_in;
        output line_t line_out;

        line_out = 'h0;
        line_out[0 +: `BITS_PER_WORD] = line_in[`BITS_PER_WORD +: `BITS_PER_WORD];
    endfunction

    function void set_cur_len;
        input line_t line_orig;
        input line_t line_in;
        output line_t line_out;

        line_out = line_orig;
        line_out[`BITS_PER_WORD +: `BITS_PER_WORD] = line_in[0 +: `BITS_PER_WORD];
    endfunction

    function void get_ref_len;
        input line_t line_in;
        output line_t line_out;

        line_out = 'h0;
        line_out[0 +: `BITS_PER_WORD] = line_in[0 +: `BITS_PER_WORD];
    endfunction
endmodule

// --------- BACKUP FOR LATER ------------

            // SEND_FWD_WITH_OWNER_MASK : begin
            //     if (~send_fwd_pending_words) begin
            //         next_state = decode;
            //     end
            // end
            // REQ_ODATA_HANDLER_HIT : begin
            //     // If words are owned elsewhere, wait for response for any
            //     // non-owned words to be sent, and then to send_fwd state.
            //     // If no words are owned elsewhere, just wait for response
            //     // to be sent.
            //     if (llc_req_in.word_mask & word_mask_owned) begin
            //         if (llc_req_in.word_mask & ~word_mask_owned) begin
            //             if (llc_rsp_out_ready_int) begin
            //                 next_state = SEND_FWD_WITH_OWNER_MASK;
            //             end
            //         end else begin
            //             next_state = SEND_FWD_WITH_OWNER_MASK;
            //         end
            //     end else begin
            //         if (llc_req_in.word_mask & ~word_mask_owned) begin
            //             if (llc_rsp_out_ready_int) begin
            //                 next_state = DECODE;
            //             end
            //         end
            //     end
            // end

    // // Special register to store words that are pending to be forwarded.
    // word_mask_t send_fwd_pending_words_next, send_fwd_pending_words;
    // int fwd_owned_word;
    // mix_msg_t send_fwd_coh_msg;
    // always_ff @(posedge clk or negedge rst) begin
    //     if (!rst) begin
    //         send_fwd_pending_words <= 0;
    //     end else begin
    //         send_fwd_pending_words <= send_fwd_pending_words_next;
    //     end
    // end

        // send_fwd_pending_words_next = 'h0;

                        // // For owned words, we will transition to another state;
                        // // send response for remaining words
                        // if (llc_req_in.word_mask & owners_buf[req_in_way]) begin
                        //     send_fwd_pending_words_next = llc_req_in.word_mask & owners_buf[req_in_way];
                        //     send_fwd_coh_msg = `FWD_REQ_Odata;
                        // end
                        // if (llc_req_in.word_mask & ~owners_buf[req_in_way]) begin
                            // send_rsp_out (
                            //     /* coh_msg */ `RSP_Odata,
                            //     /* line_addr */ llc_req_in.addr,
                            //     /* line */ lines_buf[req_in_way],
                            //     /* req_id */ llc_req_in.req_id,
                            //     /* dest_id */ llc_req_in.req_id,
                            //     /* invack_cnt */ 'h0,
                            //     /* word_offset */ 'h0,
                            //     /* word_mask */ llc_req_in.word_mask & ~owners_buf[req_in_way]
                            // );
                        // end

                        // // Next, we check if there are any sharers remaining.
                        // // If yes, we must transition to another state later to send
                        // // them invalidations, and add an MSHR entry for them.
                        // if (update_bufs_data_sharers) begin
                        // end else


            // SEND_FWD_WITH_OWNER_MASK : begin
            //     if (llc_fwd_out_ready_int) begin
            //         // Find any (lowest index) word that needs a forward.
            //         for (int i = `WORDS_PER_LINE; i > 0; i--) begin
            //             if (send_fwd_pending_words[i]) begin
            //                 if (llc_req_in.req_id != owners_cache_id[i] || llc_req_in.coh_msg == `FWD_RVK_O) begin
            //                     fwd_owned_word = i;
            //                 end
            //             end
            //         end

            //         // Remove the word from the pending words for forward.
            //         send_fwd_pending_words_next = send_fwd_pending_words & ~(1 << fwd_owned_word);

            //         // Coalescing: check if there are any other words with the same cache ID,
            //         // remove them from pending words and add them to word_mask of the request.
            //         for (int i = fwd_owned_word + 1; i < `WORDS_PER_LINE; i++) begin
            //             if (send_fwd_pending_words[i] && (owners_cache_id[i] == owners_cache_id[fwd_owned_word])) begin
            //                 send_fwd_pending_words_next = send_fwd_pending_words & ~(1 << i);
            //             end
            //         end

            //         // Send forward for the words that were removed from the pending words.
            //         if (send_fwd_pending_words & ~send_fwd_pending_words_next) begin
            //             send_fwd_out (
            //                 /* coh_msg */ send_fwd_coh_msg,
            //                 /* addr */ llc_req_in.addr
            //                 /* req_id */ llc_req_in.req_id
            //                 /* word_mask */ (send_fwd_pending_words & ~send_fwd_pending_words_next)
            //                 /* line */ 'h0
            //             );
            //         end
            //     end
            // end
