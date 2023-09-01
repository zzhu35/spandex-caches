`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_fsm (
    input logic clk,
    input logic rst,
    // From input decoder
    input logic do_get_rsp,
    input logic do_get_rsp_next,
    input logic do_get_req,
    input logic do_get_req_next,
    // From interfaces
    input logic llc_mem_req_ready_int,
    input logic llc_fwd_out_ready_int,
    input logic llc_rsp_out_ready_int,
    input logic llc_mem_rsp_valid_int,
    // From MSHR
    input logic mshr_hit,
    input logic mshr_hit_next,
    input logic [`MSHR_BITS-1:0] mshr_i,
    input logic [`MSHR_BITS-1:0] mshr_i_next,
    input mshr_llc_buf_t mshr[`N_MSHR],
    input logic set_set_conflict_mshr,
    input logic clr_set_conflict_mshr,
    // From lookup
    input logic tag_hit,
    input logic tag_hit_next,
    input logic empty_way_found,
    input logic empty_way_found_next,
    input llc_way_t way_hit,
    input llc_way_t way_hit_next,
    input llc_way_t empty_way,
    input llc_way_t empty_way_next,
    input word_mask_t word_mask_owned,
    input word_mask_t word_mask_owned_next,
    // Bufs populated from the current set in RAMs.
    input var logic dirty_bits_buf[`LLC_WAYS],
    input var line_t lines_buf[`LLC_WAYS],
    input var llc_tag_t tags_buf[`LLC_WAYS],
    input var sharers_t sharers_buf[`LLC_WAYS],
    input var owner_t owners_buf[`LLC_WAYS],
    input var hprot_t hprots_buf[`LLC_WAYS],
    input var llc_state_t states_buf[`LLC_WAYS],
    input llc_way_t evict_way_buf,
    // State registers from regs/others
    input logic evict_stall,
    input logic set_conflict,

    // Interface buses
    llc_req_in_t.in llc_req_in,
    llc_dma_req_in_t.in llc_dma_req_in,
    llc_rsp_in_t.in llc_rsp_in,
    llc_mem_rsp_t.in llc_mem_rsp,
    llc_mem_rsp_t.in llc_mem_rsp_next,
    line_breakdown_llc_t.in line_br,
    line_breakdown_llc_t.in line_br_next,

    // To input_decoder - get new input
    output logic decode_en,
    // To lookup - check for hit/miss/conflict in new set.
    output logic lookup_en,
    output logic lookup_mode,
    // To external interfaces - new data available.
    output logic llc_mem_req_valid_int,
    output logic llc_fwd_out_valid_int,
    output logic llc_rsp_out_valid_int,
    output logic llc_mem_rsp_ready_int,
    output logic llc_dma_rsp_out_valid_int,
    // To bufs to read RAMs into bufs.
    output logic rd_set_into_bufs,
    // Way to store memory response once received.
    output llc_way_t mem_rsp_way,
    // Increment evict way after current eviction and update memory.
    output logic set_update_evict_way,
    output logic incr_evict_way_buf,
    // To MSHR
    output logic add_mshr_entry,
    output logic update_mshr_tag,
    output logic update_mshr_way,
    output logic update_mshr_state,
    output logic update_mshr_invack_cnt,
    output logic update_mshr_line,
    output logic update_mshr_word_mask,
    output logic [2:0] mshr_op_code,
    output logic incr_mshr_cnt,
    output mix_msg_t update_mshr_value_msg,
    output cache_id_t update_mshr_value_req_id,
    output llc_tag_t update_mshr_value_tag,
    output llc_way_t update_mshr_value_way,
    output unstable_state_t update_mshr_value_state,
    output hprot_t update_mshr_value_hprot,
    output invack_cnt_calc_t update_mshr_value_invack_cnt,
    output line_t update_mshr_value_line,
    output word_mask_t update_mshr_value_word_mask,
    output word_mask_t update_mshr_value_word_mask_reg,
    // To localmem - update triggers
    output llc_set_t lmem_set_in,
    output llc_way_t lmem_way_in,
    output logic lmem_wr_en_state,
    output logic lmem_wr_en_line,
    output logic lmem_wr_en_evict_way,
    output logic lmem_wr_en_sharers,
    output logic lmem_wr_en_owner,
    output logic lmem_wr_en_dirty_bit,
    output logic lmem_wr_en_all_mem,
    // To localmem - update values
    output state_t lmem_wr_data_state,
    output line_t lmem_wr_data_line,
    output hprot_t lmem_wr_data_hprot,
    output llc_tag_t lmem_wr_data_tag,
    output llc_way_t lmem_wr_data_evict_way,
    output sharers_t lmem_wr_data_sharers,
    output owner_t lmem_wr_data_owner,
    output logic lmem_wr_data_dirty_bit,
    // Outputs to regs to register states
    output logic clr_evict_stall,
    output logic set_evict_stall,
    output logic set_set_conflict_fsm,
    output logic clr_set_conflict_fsm,
    output logic set_req_conflict,

    llc_mem_req_t.out llc_mem_req_o,
    llc_fwd_out_t.out llc_fwd_out_o,
    llc_rsp_out_t.out llc_rsp_out_o,
    llc_dma_rsp_out_t.out llc_dma_rsp_out_o
    );

    //STATE ENCODING
    localparam RESET = 6'b000000;
    localparam DECODE = 6'b000001;

    localparam RSP_MSHR_LOOKUP = 6'b000010;
    localparam RSP_INV_HANDLER = 6'b000011;
    localparam RSP_RVK_O_HANDLER = 6'b000100;

    localparam REQ_MSHR_LOOKUP = 6'b010000;
    localparam REQ_SET_CONFLICT = 6'b010001;
    localparam REQ_TAG_LOOKUP = 6'b010010;
    localparam REQ_ODATA_HANDLER_HIT = 6'b010011;
    localparam REQ_ODATA_HANDLER_MISS = 6'b010100;
    localparam REQ_ODATA_HANDLER_MISS_RSP = 6'b010101;
    localparam REQ_S_HANDLER_HIT = 6'b010110;
    localparam REQ_S_HANDLER_MISS = 6'b010111;
    localparam REQ_S_HANDLER_MISS_RSP = 6'b011000;
    localparam REQ_WB_HANDLER_HIT = 6'b011001;
    localparam REQ_EVICT = 6'b011010;

    localparam SEND_FWD_WITH_OWNER_MASK = 6'b100000;

    logic [5:0] state, next_state;
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
    llc_way_t req_in_way;
    assign req_in_way = tag_hit ? way_hit : (empty_way_found ? empty_way : 'h0);

    // Way to store memory response once received.
    llc_way_t mem_rsp_way_next;
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            mem_rsp_way <= 'h0;
        end else begin
            mem_rsp_way <= mem_rsp_way_next;
        end
    end

    always_comb begin
        // TODO: Add a state to account for reset, when you
        // hear back from Joseph why LLC has reset specifically.
        // It needs to be coupled with the flush logic.
        next_state = state;
        case (state)
            RESET : begin
                if (rst_set == `LLC_SETS - 1) begin
                    next_state = DECODE;
                end
            end
            DECODE : begin
                if (do_get_rsp_next) begin
                    next_state = RSP_MSHR_LOOKUP;
                end else if (do_get_req_next) begin
                    next_state = REQ_MSHR_LOOKUP;
                end
            end
            RSP_MSHR_LOOKUP : begin
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
                case(mshr[mshr_i].state)
                    `LLC_SWB : begin
                        if (~update_mshr_value_invack_cnt) begin
                            if (llc_mem_req_ready_int) begin
                                next_state = DECODE;
                            end
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
            RSP_RVK_O_HANDLER : begin
                case(mshr[mshr_i].state)
                    `LLC_OWB : begin
                        if (llc_mem_req_ready_int) begin
                            next_state = DECODE;
                        end
                    end
                    default : begin
                        next_state = DECODE;
                    end
                endcase
            end
            REQ_MSHR_LOOKUP : begin
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
                        default : begin
                            next_state = DECODE;
                        end
                    endcase
                end else begin
                    next_state = REQ_EVICT;
                end
            end
            REQ_ODATA_HANDLER_HIT : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_ODATA_HANDLER_MISS : begin
                if (llc_mem_req_ready_int) begin
                    next_state = REQ_ODATA_HANDLER_MISS_RSP;
                end
            end
            REQ_ODATA_HANDLER_MISS_RSP : begin
                if (llc_mem_rsp_valid_int) begin
                    if (llc_rsp_out_ready_int) begin
                        next_state = DECODE;
                    end
                end
            end
            REQ_S_HANDLER_HIT : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_S_HANDLER_MISS : begin
                if (llc_mem_req_ready_int) begin
                    next_state = REQ_S_HANDLER_MISS_RSP;
                end
            end
            REQ_S_HANDLER_MISS_RSP : begin
                if (llc_mem_rsp_valid_int) begin
                    if (llc_rsp_out_ready_int) begin
                        next_state = DECODE;
                    end
                end
            end
            REQ_WB_HANDLER_HIT : begin
                if (llc_rsp_out_ready_int) begin
                    next_state = DECODE;
                end
            end
            REQ_EVICT : begin
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
                        if (llc_fwd_out_ready_int) begin
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
        incr_evict_way_buf = 1'b0;
        add_mshr_entry = 1'b0;
        update_mshr_tag = 1'b0;
        update_mshr_way = 1'b0;
        update_mshr_state = 1'b0;
        update_mshr_invack_cnt = 1'b0;
        update_mshr_line = 1'b0;
        update_mshr_word_mask = 1'b0;
        mshr_op_code = 'h0;
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
        set_update_evict_way = 1'b0;
        mem_rsp_way_next = 'h0;

        case (state)
            RESET : begin
                lmem_wr_en_state = 1'b1;
                lmem_wr_data_state = 'h0;
                lmem_set_in = rst_set;
            end
            DECODE : begin
                if (do_get_rsp_next) begin
                    lmem_set_in = line_br_next.set;
                end else if (do_get_req_next) begin
                    lmem_set_in = line_br_next.set;
                end
            end
            RSP_MSHR_LOOKUP : begin
                mshr_op_code = `LLC_MSHR_LOOKUP;
            end
            RSP_INV_HANDLER : begin
                // Reduce number of invalidations to wait for by one.
                update_mshr_value_invack_cnt = mshr[mshr_i].invack_cnt - 1;
                update_mshr_invack_cnt = 1'b1;

                // Remove the sender from the sharer list.
                lmem_way_in = mshr[mshr_i].way;
                lmem_wr_data_sharers = sharers_buf[mshr[mshr_i].way] & ~(1 << llc_rsp_in.req_id);
                lmem_wr_en_sharers = 1'b1;

                if (~update_mshr_value_invack_cnt) begin
                    case (mshr[mshr_i].state)
                        `LLC_SWB : begin
                            // Write back data to memory.
                            send_mem_req (
                                /* coh_msg */ `LLC_WRITE,
                                /* line_addr */ llc_rsp_in.addr,
                                /* hprot */ mshr[mshr_i].hprot,
                                /* line */ mshr[mshr_i].line
                            );

                            // Update the states RAM
                            lmem_set_in = line_br.set;
                            lmem_way_in = mshr[mshr_i].way;
                            lmem_wr_data_state = `LLC_I;
                            lmem_wr_en_state = 1'b1;

                            // Clear the MSHR entry
                            update_mshr_state = 1'b1;
                            update_mshr_value_state = `LLC_I;
                            incr_mshr_cnt = 1'b1;

                            // LLC_SI is triggered on eviction
                            // therefore, we update eviction registers
                            // and update the stalled request.
                            incr_evict_way_buf = 1'b1;
                            set_update_evict_way = 1'b1;
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

                            // LLC_SI is triggered on eviction
                            // therefore, we update eviction registers
                            // and update the stalled request.
                            incr_evict_way_buf = 1'b1;
                            set_update_evict_way = 1'b1;
                            clr_evict_stall = 1'b1;
                        end
                    endcase
                end
            end
            RSP_RVK_O_HANDLER : begin
                // Directly update the RAMs because only one response is expected -
                // lines and owner.
                lmem_set_in = line_br.set;
                lmem_way_in = mshr[mshr_i].way;
                // Update the words in the response in the line, based on word_mask.
                write_line_helper (
                    /* line_orig */ lines_buf[mshr[mshr_i].way],
                    /* line_in */ llc_rsp_in.line,
                    /* word_mask_i */ llc_rsp_in.word_mask,
                    /* line_out */ lmem_wr_data_line
                );
                // Clear the words that were in the owners field.
                lmem_wr_data_owner = owners_buf[mshr[mshr_i].way] & ~llc_rsp_in.word_mask;
                lmem_wr_en_line = 1'b1;
                lmem_wr_en_owner = 1'b1;

                // We do not change the sharers list because L2 invalidates on revoke rather than go to shared.
                // State table shows to move to valid state, which is okay even on eviction from LLC. However,
                // this necessitates a self-invalidation. Therefore, we choose to invalidate instead for now.
                case (mshr[mshr_i].state)
                    `LLC_OWB : begin
                        // Write back data to memory.
                        send_mem_req (
                            /* coh_msg */ `LLC_WRITE,
                            /* line_addr */ llc_rsp_in.addr,
                            /* hprot */ mshr[mshr_i].hprot,
                            /* line */ lmem_wr_data_line
                        );

                        // Update the states RAM
                        lmem_set_in = line_br.set;
                        lmem_way_in = mshr[mshr_i].way;
                        lmem_wr_data_state = `LLC_I;
                        lmem_wr_en_state = 1'b1;

                        // Clear the MSHR entry
                        update_mshr_state = 1'b1;
                        update_mshr_value_state = `LLC_I;
                        incr_mshr_cnt = 1'b1;

                        // LLC_OWB is triggered on eviction
                        // therefore, we update eviction registers
                        // and update the stalled request.
                        incr_evict_way_buf = 1'b1;
                        set_update_evict_way = 1'b1;
                        clr_evict_stall = 1'b1;
                    end
                endcase
            end
            REQ_MSHR_LOOKUP : begin
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

                        // Update owner and lines RAM
                        lmem_set_in = line_br.set;
                        lmem_way_in = req_in_way;
                        write_owner_helper (
                            /* line_orig */ lines_buf[req_in_way],
                            /* req_id */ llc_req_in.req_id,
                            /* word_mask_i */ llc_req_in.word_mask,
                            /* line_out */ lmem_wr_data_line
                        );
                        lmem_wr_data_owner = llc_req_in.word_mask;
                        lmem_wr_en_line = 1'b1;
                        lmem_wr_en_owner = 1'b1;
                    end
                    `LLC_S : begin
                        // First, we remove the requestor from the sharers list (if present)
                        lmem_way_in = req_in_way;
                        lmem_wr_data_sharers = sharers_buf[req_in_way] & ~(1 << llc_req_in.req_id);
                        lmem_wr_en_sharers = 1'b1;

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

                        // Update owner, states and lines RAM
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
                    end
                endcase
            end
            REQ_ODATA_HANDLER_MISS : begin
                // On miss, get data from memory.
                send_mem_req (
                    /* coh_msg */ `LLC_READ,
                    /* line_addr */ llc_req_in.addr,
                    /* hprot */ llc_req_in.hprot,
                    /* line */ 'h0
                );

                // Indicate ready for data from memory, and update
                // way to be allocated.
                llc_mem_rsp_ready_int = 1'b1;
                mem_rsp_way_next = req_in_way;
            end
            REQ_ODATA_HANDLER_MISS_RSP : begin
                if (llc_mem_rsp_valid_int) begin
                    // Once data is received from memory, send response to requestor.
                    send_rsp_out (
                        /* coh_msg */ `RSP_Odata,
                        /* line_addr */ llc_req_in.addr,
                        /* line */ llc_mem_rsp_next.line,
                        /* req_id */ llc_req_in.req_id,
                        /* dest_id */ llc_req_in.req_id,
                        /* invack_cnt */ 'h0,
                        /* word_offset */ 'h0,
                        /* word_mask */ llc_req_in.word_mask
                    );

                    // Update all RAMs - owners_buf and lines_buf with word owned and owner, respectively.
                    lmem_set_in = line_br.set;
                    lmem_way_in = req_in_way;
                    write_owner_helper (
                        /* line_orig */ llc_mem_rsp_next.line,
                        /* req_id */ llc_req_in.req_id,
                        /* word_mask_i */ llc_req_in.word_mask,
                        /* line_out */ lmem_wr_data_line
                    );
                    lmem_wr_data_owner = llc_req_in.word_mask;
                    lmem_wr_data_hprot = llc_req_in.hprot;
                    lmem_wr_data_tag = line_br.tag;
                    lmem_wr_data_state = `LLC_V;
                    lmem_wr_data_dirty_bit = 1'b0;
                    lmem_wr_en_all_mem = 1'b1;
                end
            end
            REQ_S_HANDLER_HIT : begin
                case (states_buf[req_in_way])
                    `LLC_V : begin
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

                        // Update sharer, states RAM
                        lmem_set_in = line_br.set;
                        lmem_way_in = req_in_way;
                        lmem_wr_data_sharers = 1 << llc_req_in.req_id;
                        lmem_wr_data_state = `LLC_S;
                        lmem_wr_en_sharers = 1'b1;
                        lmem_wr_en_state = 1'b1;
                    end
                    `LLC_S : begin
                        // Update sharer RAM - add requestor
                        lmem_set_in = line_br.set;
                        lmem_way_in = req_in_way;
                        lmem_wr_data_sharers = sharers_buf[req_in_way] | (1 << llc_req_in.req_id);
                        lmem_wr_en_sharers = 1'b1;

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
                endcase
            end
            REQ_S_HANDLER_MISS : begin
                // On miss, get data from memory.
                send_mem_req (
                    /* coh_msg */ `LLC_READ,
                    /* line_addr */ llc_req_in.addr,
                    /* hprot */ llc_req_in.hprot,
                    /* line */ 'h0
                );

                // Indicate ready for data from memory, and update
                // way to be allocated.
                llc_mem_rsp_ready_int = 1'b1;
                mem_rsp_way_next = req_in_way;
            end
            REQ_S_HANDLER_MISS_RSP : begin
                if (llc_mem_rsp_valid_int) begin
                    // Once data is received from memory, send response to requestor.
                    send_rsp_out (
                        /* coh_msg */ `RSP_S,
                        /* line_addr */ llc_req_in.addr,
                        /* line */ llc_mem_rsp_next.line,
                        /* req_id */ llc_req_in.req_id,
                        /* dest_id */ llc_req_in.req_id,
                        /* invack_cnt */ 'h0,
                        /* word_offset */ 'h0,
                        /* word_mask */ llc_req_in.word_mask
                    );

                    // Update all RAMs.
                    lmem_set_in = line_br.set;
                    lmem_way_in = req_in_way;
                    lmem_wr_data_line = llc_mem_rsp_next.line;
                    lmem_wr_data_sharers = 1 << llc_req_in.req_id;
                    lmem_wr_data_hprot = llc_req_in.hprot;
                    lmem_wr_data_tag = line_br.tag;
                    lmem_wr_data_state = `LLC_S;
                    lmem_wr_data_dirty_bit = 1'b0;
                    lmem_wr_en_all_mem = 1'b1;
                end
            end
            REQ_WB_HANDLER_HIT : begin
                // Send response for the write-back
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

                // Update data in bufs, remove owner and mark line as dirty.
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
            REQ_EVICT : begin
                case (states_buf[evict_way_buf])
                    `LLC_V : begin
                        if (!owners_buf[evict_way_buf]) begin
                            if (dirty_bits_buf[evict_way_buf]) begin
                                send_mem_req (
                                    /* coh_msg */ `LLC_WRITE,
                                    /* line_addr */ (tags_buf[evict_way_buf] << `LLC_SET_BITS) | line_br.set,
                                    /* hprot */ hprots_buf[evict_way_buf],
                                    /* line */ lines_buf[evict_way_buf]
                                );
                            end

                            // Update the states RAM
                            lmem_set_in = line_br.set;
                            lmem_way_in = req_in_way;
                            lmem_wr_data_state = `LLC_I;
                            lmem_wr_en_state = 1'b1;
                        end else begin
                            // TODO: Assuming only single owner for the line!
                            if (llc_fwd_out_ready_int) begin
                                send_fwd_out (
                                    /* coh_msg */ `FWD_RVK_O,
                                    /* addr */ (tags_buf[evict_way_buf] << `LLC_SET_BITS) | line_br.set,
                                    /* req_id */ llc_req_in.req_id,
                                    /* word_mask */ owners_buf[evict_way_buf],
                                    /* line */ lines_buf[evict_way_buf]
                                );

                                fill_mshr_entry (
                                    /* msg */ `FWD_RVK_O,
                                    /* req_id */ llc_req_in.req_id,
                                    /* tag */ tags_buf[evict_way_buf],
                                    /* way */ evict_way_buf,
                                    /* state */ `LLC_OWB,
                                    /* hprot */ hprots_buf[evict_way_buf],
                                    /* invack_cnt */ 'h1,
                                    /* line */ lines_buf[evict_way_buf],
                                    /* word_mask */ owners_buf[evict_way_buf]
                                );
                            end

                            set_evict_stall = 1'b1;
                        end
                    end
                    `LLC_S : begin
                        // TODO: Assuming only single sharer for the line!
                        if (llc_fwd_out_ready_int) begin
                            send_fwd_out (
                                /* coh_msg */ `FWD_INV,
                                /* addr */ (tags_buf[evict_way_buf] << `LLC_SET_BITS) | line_br.set,
                                /* req_id */ llc_req_in.req_id,
                                /* word_mask */ `WORD_MASK_ALL,
                                /* line */ 'h0
                            );

                            if (dirty_bits_buf[evict_way_buf]) begin
                                fill_mshr_entry (
                                    /* msg */ `FWD_INV,
                                    /* req_id */ llc_req_in.req_id,
                                    /* tag */ tags_buf[evict_way_buf],
                                    /* way */ evict_way_buf,
                                    /* state */ `LLC_SWB,
                                    /* hprot */ hprots_buf[evict_way_buf],
                                    /* invack_cnt */ 'h1,
                                    /* line */ 'h0,
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
                                    /* invack_cnt */ 'h1,
                                    /* line */ 'h0,
                                    /* word_mask */ `WORD_MASK_ALL
                                );
                            end
                        end

                        set_evict_stall = 1'b1;
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
        input word_mask_t word_mask;
        input line_t line;

        llc_fwd_out_o.coh_msg = coh_msg;
        llc_fwd_out_o.addr = addr;
        llc_fwd_out_o.req_id = req_id;
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

// module llc_fsm (
//     input logic clk,
//     input logic rst,
//     input logic process_en,
//     input logic rst_in,
//     input logic is_flush_to_resume,
//     input logic is_rst_to_resume,
//     input logic is_rst_to_get,
//     input logic is_rsp_to_get,
//     input logic is_req_to_get,
//     input logic is_dma_req_to_get,
//     input logic is_dma_read_to_resume,
//     input logic is_dma_write_to_resume,
//     input logic is_req_to_resume,
//     input logic recall_pending,
//     input logic recall_valid,
//     input logic req_stall,
//     input logic llc_mem_req_ready_int,
//     input logic llc_fwd_out_ready_int,
//     input logic llc_rsp_out_ready_int,
//     input logic evict,
//     input logic evict_next,
//     input logic llc_mem_rsp_valid_int,
//     input logic llc_dma_rsp_out_ready_int,
//     input var logic dirty_bits_buf[`LLC_WAYS],
//     input var line_t lines_buf[`LLC_WAYS],
//     input var llc_tag_t tags_buf[`LLC_WAYS],
//     input var sharers_t sharers_buf[`LLC_WAYS],
//     input var owner_t owners_buf[`LLC_WAYS],
//     input var hprot_t hprots_buf[`LLC_WAYS],
//     input var llc_state_t states_buf[`LLC_WAYS],
//     input llc_way_t evict_way_buf,
//     input llc_tag_t req_in_stalled_tag,
//     input llc_set_t req_in_stalled_set,
//     input llc_set_t set,
//     input llc_way_t way,
//     input llc_way_t way_next,
//     input line_addr_t addr_evict,
//     input line_addr_t recall_evict_addr,
//     input addr_t dma_addr,

//     llc_req_in_t.in llc_req_in,
//     llc_dma_req_in_t.in llc_dma_req_in,
//     llc_rsp_in_t.in llc_rsp_in,
//     llc_mem_rsp_t.in llc_mem_rsp,
//     line_breakdown_llc_t.in line_br,

//     output logic llc_mem_req_valid_int,
//     output logic llc_fwd_out_valid_int,
//     output logic llc_rsp_out_valid_int,
//     output logic llc_mem_rsp_ready_int,
//     output logic llc_dma_rsp_out_valid_int,
//     output logic rst_state,
//     output logic clr_req_stall_process,
//     output logic clr_rst_flush_stalled_set,
//     output logic set_recall_valid,
//     output logic set_recall_pending,
//     output logic set_flush_stall,
//     output logic wr_en_lines_buf,
//     output logic wr_en_tags_buf,
//     output logic wr_en_sharers_buf,
//     output logic wr_en_owners_buf,
//     output logic wr_en_hprots_buf,
//     output logic wr_en_dirty_bits_buf,
//     output logic wr_en_states_buf,
//     output logic dirty_bits_buf_wr_data,
//     output logic process_done,
//     output logic set_req_stall,
//     output logic set_req_in_stalled_valid,
//     output logic set_req_in_stalled,
//     output logic update_req_in_stalled,
//     output logic incr_evict_way_buf,
//     output logic set_update_evict_way,
//     output logic set_dma_read_pending,
//     output logic set_is_dma_read_to_resume_process,
//     output logic set_dma_write_pending,
//     output logic set_is_dma_write_to_resume_process,
//     output logic clr_recall_pending,
//     output logic clr_recall_valid,
//     output logic clr_dma_read_pending,
//     output logic clr_dma_write_pending,
//     output logic incr_dma_addr,
//     output logic set_req_pending,
//     output logic clr_req_pending,
//     output logic set_recall_evict_addr,
//     output line_t lines_buf_wr_data,
//     output llc_tag_t tags_buf_wr_data,
//     output sharers_t sharers_buf_wr_data,
//     output owner_t owners_buf_wr_data,
//     output hprot_t hprots_buf_wr_data,
//     output llc_state_t states_buf_wr_data,

//     llc_mem_req_t.out llc_mem_req_o,
//     llc_fwd_out_t.out llc_fwd_out_o,
//     llc_rsp_out_t.out llc_rsp_out_o,
//     llc_dma_rsp_out_t.out llc_dma_rsp_out_o
//     );

//     //STATE ENCODING
//     localparam IDLE = 5'b00000;
//     localparam PROCESS_FLUSH_RESUME = 5'b00001;
//     localparam PROCESS_RST = 5'b00010;
//     localparam PROCESS_RSP = 5'b00011;
//     localparam REQ_RECALL_EM = 5'b00100;
//     localparam REQ_RECALL_SSD = 5'b00101;
//     localparam EVICT = 5'b00110;
//     localparam REQ_GET_S_M_IV_MEM_REQ = 5'b00111;
//     localparam REQ_GET_S_M_IV_MEM_RSP = 5'b01000;
//     localparam REQ_GET_S_M_IV_SEND_RSP = 5'b01001;
//     localparam REQ_GETS_S = 5'b01010;
//     localparam REQ_GET_S_M_EM = 5'b01011;
//     localparam REQ_GET_S_M_SD = 5'b01100;
//     localparam REQ_GETM_S_FWD = 5'b01101;
//     localparam REQ_GETM_S_RSP = 5'b01110;
//     localparam REQ_PUTS = 5'b01111;
//     localparam REQ_PUTM = 5'b10000;
//     localparam DMA_REQ_TO_GET = 5'b10001;
//     localparam DMA_RECALL_EM = 5'b10010;
//     localparam DMA_RECALL_SSD = 5'b10011;
//     localparam DMA_EVICT = 5'b10100;
//     localparam DMA_READ_RESUME_MEM_REQ = 5'b10101;
//     localparam DMA_READ_RESUME_MEM_RSP = 5'b10110;
//     localparam DMA_READ_RESUME_DMA_RSP = 5'b10111;
//     localparam DMA_WRITE_RESUME_MEM_REQ = 5'b11000;
//     localparam DMA_WRITE_RESUME_MEM_RSP = 5'b11001;
//     localparam DMA_WRITE_RESUME_WRITE = 5'b11010;

//     logic [4:0] state, next_state;
//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             state <= IDLE;
//         end else begin
//             state <= next_state;
//         end
//     end

//     logic [(`MAX_N_L2_BITS - 1):0] l2_cnt, invack_cnt;
//     logic incr_invack_cnt, skip;
//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             l2_cnt <= 0;
//         end else if (state == IDLE) begin
//             l2_cnt <= 0;
//         end else if ((state == REQ_RECALL_SSD || state == DMA_RECALL_SSD || state == REQ_GETM_S_FWD)
//                     && (llc_fwd_out_ready_int || skip) && l2_cnt < `MAX_N_L2) begin
//             l2_cnt <= l2_cnt + 1;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             invack_cnt <= 0;
//         end else if (state == IDLE) begin
//             invack_cnt <= 0;
//         end else if (incr_invack_cnt) begin
//             invack_cnt <= invack_cnt + 1;
//         end
//     end

//     line_addr_t line_addr;
//     dma_length_t valid_words;
//     word_offset_t dma_read_woffset;
//     word_offset_t dma_write_woffset;
//     invack_cnt_t dma_info;
//     llc_way_t cur_way;
//     logic misaligned_next, misaligned;

//     always_comb begin
//         next_state = state;
//         process_done = 1'b0;
//         if (process_en) begin
//             case (state)
//                 IDLE: begin
//                     if (is_flush_to_resume) begin
//                         next_state = PROCESS_FLUSH_RESUME;
//                     end else if (is_rst_to_get) begin
//                         next_state = PROCESS_RST;
//                     end else if (is_rsp_to_get) begin
//                         next_state = PROCESS_RSP;
//                     end else if (is_req_to_get || is_req_to_resume) begin
//                         if (evict_next && !recall_pending && !recall_valid && states_buf[way_next] != `VALID) begin
//                             case (states_buf[way_next])
//                                 `EXCLUSIVE : next_state = REQ_RECALL_EM;
//                                 `MODIFIED : next_state = REQ_RECALL_EM;
//                                 `SD : next_state = REQ_RECALL_SSD;
//                                 `SHARED : next_state = REQ_RECALL_SSD;
//                                 default : next_state = IDLE;
//                             endcase
//                         end else if (!recall_pending || recall_valid) begin
//                             if (evict_next) begin
//                                 next_state = EVICT;
//                             end else begin
//                                 case(llc_req_in.coh_msg)
//                                     `REQ_GETS : begin
//                                         case(states_buf[way_next])
//                                             `INVALID : next_state = REQ_GET_S_M_IV_MEM_REQ;
//                                             `VALID : next_state = REQ_GET_S_M_IV_SEND_RSP;
//                                             `SHARED : next_state = REQ_GETS_S;
//                                             `EXCLUSIVE : next_state = REQ_GET_S_M_EM;
//                                             `MODIFIED : next_state = REQ_GET_S_M_EM;
//                                             `SD : next_state = REQ_GET_S_M_SD;
//                                             default : next_state = IDLE;
//                                         endcase
//                                     end
//                                     `REQ_GETM : begin
//                                         case(states_buf[way_next])
//                                             `INVALID : next_state = REQ_GET_S_M_IV_MEM_REQ;
//                                             `VALID : next_state = REQ_GET_S_M_IV_SEND_RSP;
//                                             `SHARED : next_state = REQ_GETM_S_FWD;
//                                             `EXCLUSIVE : next_state = REQ_GET_S_M_EM;
//                                             `MODIFIED : next_state = REQ_GET_S_M_EM;
//                                             `SD : next_state = REQ_GET_S_M_SD;
//                                             default : next_state = IDLE;
//                                         endcase
//                                 end
//                                     `REQ_PUTS : next_state = REQ_PUTS;
//                                     `REQ_PUTM : next_state = REQ_PUTM;
//                                     default : next_state = IDLE;
//                                 endcase
//                             end
//                         end
//                     end else if (is_dma_req_to_get || is_dma_read_to_resume || is_dma_write_to_resume) begin
//                         if (is_dma_req_to_get) begin
//                             next_state = DMA_REQ_TO_GET;
//                         end else if (!recall_valid && !recall_pending && states_buf[way_next] != `INVALID
//                                     && states_buf[way_next] != `VALID) begin
//                             case (states_buf[way_next])
//                                 `EXCLUSIVE : next_state = DMA_RECALL_EM;
//                                 `MODIFIED : next_state = DMA_RECALL_EM;
//                                 `SD : next_state = DMA_RECALL_SSD;
//                                 `SHARED : next_state = DMA_RECALL_SSD;
//                                 default : next_state = IDLE;
//                             endcase
//                         end else if (!recall_pending || recall_valid) begin
//                             if (evict_next || recall_valid) begin
//                                 next_state = DMA_EVICT;
//                             end else if (is_dma_read_to_resume) begin
//                                 if (states_buf[way_next] == `INVALID) begin
//                                     next_state = DMA_READ_RESUME_MEM_REQ;
//                                 end else begin
//                                     next_state = DMA_READ_RESUME_DMA_RSP;
//                                 end
//                             end else begin
//                                 if (states_buf[way_next] == `INVALID && misaligned_next) begin
//                                     next_state = DMA_WRITE_RESUME_MEM_REQ;
//                                 end else begin
//                                     next_state = DMA_WRITE_RESUME_WRITE;
//                                 end
//                             end
//                         end
//                     end else begin
//                         process_done = 1'b1;
//                     end
//                 end
//                 PROCESS_FLUSH_RESUME : begin
//                     if (cur_way == `LLC_WAYS - 1 && (llc_mem_req_ready_int || skip)) begin
//                         next_state = IDLE;
//                         process_done = 1'b1;
//                     end
//                 end
//                 PROCESS_RST : begin
//                      next_state = IDLE;
//                      process_done = 1'b1;
//                 end
//                 PROCESS_RSP : begin
//                     next_state = IDLE;
//                     process_done = 1'b1;
//                 end
//                 REQ_RECALL_EM : begin
//                     if (llc_fwd_out_ready_int || states_buf[way] == `SD) begin
//                         if (recall_valid) begin
//                             if (evict) begin
//                                 next_state = EVICT;
//                             end else begin
//                                 case(llc_req_in.coh_msg)
//                                     `REQ_GETS : begin
//                                         case(states_buf[way])
//                                             `INVALID : next_state = REQ_GET_S_M_IV_MEM_REQ;
//                                             `VALID : next_state = REQ_GET_S_M_IV_SEND_RSP;
//                                             `SHARED : next_state = REQ_GETS_S;
//                                             `EXCLUSIVE : next_state = REQ_GET_S_M_EM;
//                                             `MODIFIED : next_state = REQ_GET_S_M_EM;
//                                             `SD : next_state = REQ_GET_S_M_SD;
//                                             default : next_state = IDLE;
//                                         endcase
//                                     end
//                                     `REQ_GETM : begin
//                                         case(states_buf[way])
//                                             `INVALID : next_state = REQ_GET_S_M_IV_MEM_REQ;
//                                             `VALID : next_state = REQ_GET_S_M_IV_SEND_RSP;
//                                             `SHARED : next_state = REQ_GETM_S_FWD;
//                                             `EXCLUSIVE : next_state = REQ_GET_S_M_EM;
//                                             `MODIFIED : next_state = REQ_GET_S_M_EM;
//                                             `SD : next_state = REQ_GET_S_M_SD;
//                                             default : next_state = IDLE;
//                                         endcase
//                                 end
//                                     `REQ_PUTS : next_state = REQ_PUTS;
//                                     `REQ_PUTM : next_state = REQ_PUTM;
//                                     default : next_state = IDLE;
//                                 endcase
//                             end
//                         end else begin
//                             next_state = IDLE;
//                             process_done = 1'b1;
//                         end
//                     end
//                 end
//                 REQ_RECALL_SSD : begin
//                     if (l2_cnt == `MAX_N_L2 - 1 && (llc_fwd_out_ready_int || skip)) begin
//                         if (!recall_pending || recall_valid) begin
//                             if (evict) begin
//                                 next_state = EVICT;
//                             end else begin
//                                 case(llc_req_in.coh_msg)
//                                     `REQ_GETS : begin
//                                         case(states_buf[way])
//                                             `INVALID : next_state = REQ_GET_S_M_IV_MEM_REQ;
//                                             `VALID : next_state = REQ_GET_S_M_IV_SEND_RSP;
//                                             `SHARED : next_state = REQ_GETS_S;
//                                             `EXCLUSIVE : next_state = REQ_GET_S_M_EM;
//                                             `MODIFIED : next_state = REQ_GET_S_M_EM;
//                                             `SD : next_state = REQ_GET_S_M_SD;
//                                             default : next_state = IDLE;
//                                         endcase
//                                     end
//                                     `REQ_GETM : begin
//                                         case(states_buf[way])
//                                             `INVALID : next_state = REQ_GET_S_M_IV_MEM_REQ;
//                                             `VALID : next_state = REQ_GET_S_M_IV_SEND_RSP;
//                                             `SHARED : next_state = REQ_GETM_S_FWD;
//                                             `EXCLUSIVE : next_state = REQ_GET_S_M_EM;
//                                             `MODIFIED : next_state = REQ_GET_S_M_EM;
//                                             `SD : next_state = REQ_GET_S_M_SD;
//                                             default : next_state = IDLE;
//                                         endcase
//                                 end
//                                     `REQ_PUTS : next_state = REQ_PUTS;
//                                     `REQ_PUTM : next_state = REQ_PUTM;
//                                     default : next_state = IDLE;
//                                 endcase
//                             end
//                         end else begin
//                             next_state = IDLE;
//                             process_done = 1'b1;
//                         end
//                     end
//                 end
//                 EVICT : begin
//                     if ((states_buf[way] == `VALID && dirty_bits_buf[way] && llc_mem_req_ready_int)
//                         || (states_buf[way] != `VALID || !dirty_bits_buf[way])) begin
//                         case(llc_req_in.coh_msg)
//                             `REQ_GETS : begin
//                                 case(states_buf_wr_data)
//                                     `INVALID : next_state = REQ_GET_S_M_IV_MEM_REQ;
//                                     `VALID : next_state = REQ_GET_S_M_IV_SEND_RSP;
//                                     `SHARED : next_state = REQ_GETS_S;
//                                     `EXCLUSIVE : next_state = REQ_GET_S_M_EM;
//                                     `MODIFIED : next_state = REQ_GET_S_M_EM;
//                                     `SD : next_state = REQ_GET_S_M_SD;
//                                     default : next_state = IDLE;
//                                 endcase
//                             end
//                            `REQ_GETM : begin
//                                 case(states_buf_wr_data)
//                                     `INVALID : next_state = REQ_GET_S_M_IV_MEM_REQ;
//                                     `VALID : next_state = REQ_GET_S_M_IV_SEND_RSP;
//                                     `SHARED : next_state = REQ_GETM_S_FWD;
//                                     `EXCLUSIVE : next_state = REQ_GET_S_M_EM;
//                                     `MODIFIED : next_state = REQ_GET_S_M_EM;
//                                     `SD : next_state = REQ_GET_S_M_SD;
//                                     default : next_state = IDLE;
//                                 endcase
//                             end
//                            `REQ_PUTS : next_state = REQ_PUTS;
//                            `REQ_PUTM : next_state = REQ_PUTM;
//                            default : next_state = IDLE;
//                         endcase
//                     end
//                 end
//                 REQ_GET_S_M_IV_MEM_REQ : begin
//                     if (llc_mem_req_ready_int) begin
//                         next_state = REQ_GET_S_M_IV_MEM_RSP;
//                     end
//                 end
//                 REQ_GET_S_M_IV_MEM_RSP : begin
//                     if (llc_mem_rsp_valid_int) begin
//                         next_state = REQ_GET_S_M_IV_SEND_RSP;
//                     end
//                 end
//                 REQ_GET_S_M_IV_SEND_RSP : begin
//                     if (llc_rsp_out_ready_int) begin
//                         next_state = IDLE;
//                         process_done = 1'b1;
//                     end
//                 end
//                 REQ_GETS_S:  begin
//                     if (llc_rsp_out_ready_int) begin
//                         next_state = IDLE;
//                         process_done = 1'b1;
//                     end
//                 end
//                 REQ_GET_S_M_EM: begin
//                     if (llc_fwd_out_ready_int) begin
//                         next_state = IDLE;
//                         process_done = 1'b1;
//                     end
//                 end
//                 REQ_GET_S_M_SD : begin
//                     next_state = IDLE;
//                     process_done = 1'b1;
//                 end
//                 REQ_GETM_S_FWD : begin
//                     if (l2_cnt == `MAX_N_L2 - 1 && (llc_fwd_out_ready_int || skip)) begin
//                         next_state = REQ_GETM_S_RSP;
//                     end
//                 end
//                 REQ_GETM_S_RSP : begin
//                     if (llc_rsp_out_ready_int) begin
//                         next_state = IDLE;
//                         process_done = 1'b1;
//                     end
//                 end
//                 REQ_PUTS : begin
//                     if (llc_fwd_out_ready_int) begin
//                         next_state = IDLE;
//                         process_done = 1'b1;
//                     end
//                 end
//                 REQ_PUTM : begin
//                     if (llc_fwd_out_ready_int) begin
//                         next_state = IDLE;
//                         process_done = 1'b1;
//                     end
//                 end
//                 DMA_REQ_TO_GET : begin
//                     if (!recall_valid && !recall_pending && states_buf[way] != `INVALID && states_buf[way] != `VALID) begin
//                         case (states_buf[way])
//                             `EXCLUSIVE : next_state = DMA_RECALL_EM;
//                             `MODIFIED : next_state = DMA_RECALL_EM;
//                             `SD : next_state = DMA_RECALL_SSD;
//                             `SHARED : next_state = DMA_RECALL_SSD;
//                             default : next_state = IDLE;
//                         endcase
//                     end else if (!recall_pending || recall_valid) begin
//                         if (evict || recall_valid) begin
//                             next_state = DMA_EVICT;
//                         end else if (llc_dma_req_in.coh_msg == `REQ_DMA_READ_BURST) begin
//                             if (states_buf[way] == `INVALID) begin
//                                 next_state = DMA_READ_RESUME_MEM_REQ;
//                             end else begin
//                                 next_state = DMA_READ_RESUME_DMA_RSP;
//                             end
//                         end else begin
//                             if (states_buf[way] == `INVALID && misaligned_next) begin
//                                 next_state = DMA_WRITE_RESUME_MEM_REQ;
//                             end else begin
//                                 next_state = DMA_WRITE_RESUME_WRITE;
//                             end
//                         end
//                     end else begin
//                         next_state = IDLE;
//                         process_done = 1'b1;
//                     end
//                 end
//                 DMA_RECALL_EM : begin
//                     if (llc_fwd_out_ready_int || states_buf[way] == `SD) begin
//                         if (recall_valid) begin
//                             if (evict || recall_valid) begin
//                                 next_state = DMA_EVICT;
//                             end else if (is_dma_read_to_resume) begin
//                                 if (states_buf[way] == `INVALID) begin
//                                     next_state = DMA_READ_RESUME_MEM_REQ;
//                                 end else begin
//                                     next_state = DMA_READ_RESUME_DMA_RSP;
//                                 end
//                             end else begin
//                                 if (states_buf[way] == `INVALID && misaligned_next) begin
//                                     next_state = DMA_WRITE_RESUME_MEM_REQ;
//                                 end else begin
//                                     next_state = DMA_WRITE_RESUME_WRITE;
//                                 end
//                             end
//                         end else begin
//                             next_state = IDLE;
//                             process_done = 1'b1;
//                         end
//                     end
//                 end
//                 DMA_RECALL_SSD : begin
//                     if (l2_cnt == `MAX_N_L2 - 1 && (llc_fwd_out_ready_int || skip)) begin
//                         if (states_buf[way] == `SHARED) begin
//                             next_state = DMA_EVICT;
//                         end else if (!recall_pending || recall_valid) begin
//                             if (evict || recall_valid) begin
//                                 next_state = DMA_EVICT;
//                             end else if (is_dma_read_to_resume) begin
//                                 if (states_buf[way] == `INVALID) begin
//                                     next_state = DMA_READ_RESUME_MEM_REQ;
//                                 end else begin
//                                     next_state = DMA_READ_RESUME_DMA_RSP;
//                                 end
//                             end else begin
//                                 if (states_buf[way] == `INVALID && misaligned_next) begin
//                                     next_state = DMA_WRITE_RESUME_MEM_REQ;
//                                 end else begin
//                                     next_state = DMA_WRITE_RESUME_WRITE;
//                                 end
//                             end
//                         end else begin
//                             next_state = IDLE;
//                             process_done = 1'b1;
//                         end
//                     end
//                 end
//                 DMA_EVICT : begin
//                     if ((evict && ((dirty_bits_buf[way] && llc_mem_req_ready_int) || !dirty_bits_buf[way])) || (!evict)) begin
//                         if (is_dma_read_to_resume) begin
//                             if (states_buf_wr_data == `INVALID) begin
//                                 next_state = DMA_READ_RESUME_MEM_REQ;
//                             end else begin
//                                 next_state = DMA_READ_RESUME_DMA_RSP;
//                             end
//                         end else begin
//                             if (states_buf_wr_data == `INVALID && misaligned_next) begin
//                                 next_state = DMA_WRITE_RESUME_MEM_REQ;
//                             end else begin
//                                 next_state = DMA_WRITE_RESUME_WRITE;
//                             end
//                         end
//                     end
//                 end
//                 DMA_READ_RESUME_MEM_REQ : begin
//                     if (llc_mem_req_ready_int) begin
//                         next_state = DMA_READ_RESUME_MEM_RSP;
//                     end
//                 end
//                 DMA_READ_RESUME_MEM_RSP : begin
//                     if (llc_mem_rsp_valid_int) begin
//                         next_state = DMA_READ_RESUME_DMA_RSP;
//                     end
//                 end
//                 DMA_READ_RESUME_DMA_RSP: begin
//                     if (llc_dma_rsp_out_ready_int) begin
//                         next_state = IDLE;
//                         process_done = 1'b1;
//                     end
//                 end
//                 DMA_WRITE_RESUME_MEM_REQ : begin
//                     if (llc_mem_req_ready_int) begin
//                         next_state = DMA_WRITE_RESUME_MEM_RSP;
//                     end
//                 end
//                 DMA_WRITE_RESUME_MEM_RSP : begin
//                     if (llc_mem_rsp_valid_int) begin
//                         next_state = DMA_WRITE_RESUME_WRITE;
//                     end
//                 end
//                 DMA_WRITE_RESUME_WRITE : begin
//                     next_state = IDLE;
//                     process_done = 1'b1;
//                 end
//                 default : next_state = IDLE;
//             endcase
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             cur_way <= 0;
//         end else if (state == IDLE) begin
//             cur_way <= 0;
//         end else if ((state == PROCESS_FLUSH_RESUME) && (llc_mem_req_ready_int || skip)) begin
//             cur_way <= cur_way + 1;
//         end
//     end

//     logic dma_start, dma_done;
//     dma_length_t dma_length, dma_read_length;

//     logic dma_start_next;
//     dma_length_t dma_length_next;

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             dma_start <= 1'b0;
//             dma_length <= 0;
//             dma_read_length <= 0;
//         end else if (state == DMA_REQ_TO_GET) begin
//             dma_start <= 1'b1;
//             dma_length <= 0;
//             dma_read_length <= llc_dma_req_in.line[(`BITS_PER_LINE - 1) : (`BITS_PER_LINE - `ADDR_BITS)];
//         end else if (state == DMA_READ_RESUME_DMA_RSP || state == DMA_WRITE_RESUME_WRITE) begin
//             dma_start <= dma_start_next;
//             dma_length <= dma_length_next;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             misaligned <= 1'b0;
//         end else begin
//             misaligned <= misaligned_next;
//         end
//     end

//     logic [`WORDS_PER_LINE-1:0] words_to_write;
//     logic [`WORD_BITS-1:0] words_to_write_sum;
//     always_comb begin
//         //imterfaces
//         llc_mem_req_o.hwrite = 0;
//         llc_mem_req_o.hsize = 0;
//         llc_mem_req_o.hprot = 0;
//         llc_mem_req_o.addr = 0;
//         llc_mem_req_o.line = 0;
//         llc_mem_req_valid_int = 1'b0;

//         llc_rsp_out_o.coh_msg = 0;
//         llc_rsp_out_o.addr = 0;
//         llc_rsp_out_o.line = 0;
//         llc_rsp_out_o.req_id = 0;
//         llc_rsp_out_o.dest_id = 0;
//         llc_rsp_out_o.invack_cnt = 0;
//         llc_rsp_out_o.word_offset = 0;
//         llc_rsp_out_valid_int = 1'b0;

//         llc_fwd_out_o.coh_msg = 0;
//         llc_fwd_out_o.addr = 0;
//         llc_fwd_out_o.req_id = 0;
//         llc_fwd_out_o.dest_id = 0;
//         llc_fwd_out_valid_int = 1'b0;

//         llc_dma_rsp_out_o.coh_msg = 0;
//         llc_dma_rsp_out_o.addr = 0;
//         llc_dma_rsp_out_o.line = 0;
//         llc_dma_rsp_out_o.req_id = 0;
//         llc_dma_rsp_out_o.dest_id = 0;
//         llc_dma_rsp_out_o.invack_cnt = 0;
//         llc_dma_rsp_out_o.word_offset = 0;
//         llc_dma_rsp_out_valid_int = 1'b0;

//         llc_mem_rsp_ready_int = 1'b0;

//         //write to buffers
//         lines_buf_wr_data = 0;
//         wr_en_lines_buf = 1'b0;
//         dirty_bits_buf_wr_data = 1'b0;
//         wr_en_dirty_bits_buf = 1'b0;
//         states_buf_wr_data = 0;
//         wr_en_states_buf = 1'b0;
//         sharers_buf_wr_data = 0;
//         wr_en_sharers_buf = 1'b0;
//         owners_buf_wr_data = 0;
//         wr_en_owners_buf = 1'b0;
//         wr_en_hprots_buf = 1'b0;
//         hprots_buf_wr_data = 0;
//         wr_en_tags_buf = 1'b0;
//         tags_buf_wr_data = 0;
//         incr_evict_way_buf = 1'b0;
//         set_update_evict_way = 1'b0;

//         //stalls/recalls
//         set_flush_stall = 1'b0;
//         clr_rst_flush_stalled_set = 1'b0;
//         clr_req_stall_process = 1'b0;
//         set_req_stall = 1'b0;
//         set_req_in_stalled_valid = 1'b0;
//         set_req_in_stalled = 1'b0;
//         update_req_in_stalled = 1'b0;
//         set_recall_pending = 1'b0;
//         clr_recall_pending = 1'b0;
//         clr_recall_valid = 1'b0;
//         set_req_pending = 1'b0;
//         clr_req_pending = 1'b0;
//         set_recall_evict_addr = 1'b0;
//         set_recall_valid = 1'b0;

//         //DMA
//         set_dma_read_pending = 1'b0;
//         set_is_dma_read_to_resume_process = 1'b0;
//         set_dma_write_pending = 1'b0;
//         set_is_dma_write_to_resume_process = 1'b0;
//         valid_words = `WORDS_PER_LINE;
//         dma_read_woffset = 0;
//         dma_write_woffset = 0;
//         dma_info = 0;
//         dma_done = 1'b0;
//         dma_length_next = 0;
//         dma_start_next = 1'b0;
//         incr_dma_addr = 1'b0;
//         clr_dma_read_pending = 1'b0;
//         clr_dma_write_pending = 1'b0;
//         words_to_write = 0;
//         words_to_write_sum = 0;
//         misaligned_next = 1'b0;

//         //misc
//         line_addr = 0;
//         skip = 1'b0;
//         incr_invack_cnt = 1'b0;
//         rst_state = 1'b0;

//         case (state)
//             IDLE : begin
//                 dma_write_woffset = llc_dma_req_in.word_offset;
//                 valid_words = llc_dma_req_in.valid_words + 1;
//                 misaligned_next = ((dma_write_woffset != 0) || (valid_words != `WORDS_PER_LINE));
//             end
//             PROCESS_FLUSH_RESUME :  begin
//                 line_addr = (tags_buf[cur_way] << `LLC_SET_BITS) | set;
//                 if (states_buf[cur_way] == `VALID && dirty_bits_buf[cur_way]) begin
//                     llc_mem_req_o.hwrite = `LLC_WRITE;
//                     llc_mem_req_o.addr = line_addr;
//                     llc_mem_req_o.hsize = `WORD;
//                     llc_mem_req_o.hprot = hprots_buf[cur_way];
//                     llc_mem_req_o.line = lines_buf[cur_way];
//                     llc_mem_req_valid_int = 1'b1;
//                 end else begin
//                     skip = 1'b1;
//                 end
//             end
//             PROCESS_RST : begin
//                 //FLUSH
//                 if (rst_in) begin
//                     set_flush_stall = 1'b1;
//                     clr_rst_flush_stalled_set = 1'b1;
//                 end else begin
//                     rst_state = 1'b1;
//                 end
//             end
//             PROCESS_RSP : begin
//                 if (recall_pending && (llc_rsp_in.addr == recall_evict_addr)) begin
//                     if (llc_rsp_in.coh_msg == `RSP_DATA) begin
//                         wr_en_lines_buf = 1'b1;
//                         lines_buf_wr_data = llc_rsp_in.line;
//                         wr_en_dirty_bits_buf = 1'b1;
//                         dirty_bits_buf_wr_data = 1'b1;
//                     end
//                     set_recall_valid = 1'b1;
//                 end else begin
//                     wr_en_lines_buf = 1'b1;
//                     lines_buf_wr_data = llc_rsp_in.line;
//                     wr_en_dirty_bits_buf = 1'b1;
//                     dirty_bits_buf_wr_data = 1'b1;
//                 end

//                 if (req_stall && (line_br.tag == req_in_stalled_tag) && (line_br.set == req_in_stalled_set)) begin
//                     clr_req_stall_process = 1'b1;
//                 end

//                 if (states_buf[way] == `SD && set_recall_valid) begin
//                     wr_en_states_buf = 1'b1;
//                     states_buf_wr_data = `VALID;
//                 end else if (sharers_buf[way] != 0) begin
//                     wr_en_states_buf = 1'b1;
//                     states_buf_wr_data = `SHARED;
//                 end else begin
//                     wr_en_states_buf = 1'b1;
//                     states_buf_wr_data = `VALID;
//                 end
//             end
//             REQ_RECALL_EM : begin
//                 set_req_pending = 1'b1;
//                 set_recall_pending = 1'b1;
//                 set_recall_evict_addr = 1'b1;
//                 llc_fwd_out_o.coh_msg = `FWD_GETM_LLC;
//                 llc_fwd_out_o.addr = addr_evict;
//                 llc_fwd_out_o.req_id = owners_buf[way];
//                 llc_fwd_out_o.dest_id = owners_buf[way];;
//                 llc_fwd_out_valid_int = 1'b1;
//             end
//             REQ_RECALL_SSD : begin
//                 set_recall_evict_addr = 1'b1;
//                 if (states_buf[way] == `SD) begin
//                     set_recall_pending = 1'b1;
//                     set_req_pending = 1'b1;
//                 end
//                 if (sharers_buf[way] & (1 << l2_cnt)) begin
//                     llc_fwd_out_o.coh_msg = `FWD_INV_LLC;
//                     llc_fwd_out_o.addr = addr_evict;
//                     llc_fwd_out_o.req_id = l2_cnt;
//                     llc_fwd_out_o.dest_id = l2_cnt;
//                     llc_fwd_out_valid_int = 1'b1;
//                 end else begin
//                     skip = 1'b1;
//                 end
//             end
//             EVICT : begin
//                 clr_recall_pending = 1'b1;
//                 clr_recall_valid = 1'b1;
//                 clr_req_pending = 1'b1;

//                 if (way == evict_way_buf) begin
//                     set_update_evict_way = 1'b1;
//                     incr_evict_way_buf = 1'b1;
//                 end
//                 if (dirty_bits_buf[way]) begin
//                     llc_mem_req_valid_int = 1'b1;
//                     llc_mem_req_o.hwrite = `LLC_WRITE;
//                     llc_mem_req_o.addr = addr_evict;
//                     llc_mem_req_o.hsize = `WORD;
//                     llc_mem_req_o.hprot = hprots_buf[way];
//                     llc_mem_req_o.line = lines_buf[way];
//                 end
//                 wr_en_states_buf = 1'b1;
//                 states_buf_wr_data = `INVALID;
//                 wr_en_sharers_buf = 1'b1;
//                 sharers_buf_wr_data = 0;
//                 wr_en_owners_buf = 1'b1;
//                 owners_buf_wr_data = 0;
//             end
//             REQ_GET_S_M_IV_MEM_REQ : begin
//                 llc_mem_req_valid_int = 1'b1;
//                 llc_mem_req_o.hwrite = `READ;
//                 llc_mem_req_o.addr = llc_req_in.addr;
//                 llc_mem_req_o.hsize = `WORD;
//                 llc_mem_req_o.hprot = llc_req_in.hprot;
//                 llc_mem_req_o.line = 0;
//             end
//             REQ_GET_S_M_IV_MEM_RSP : begin
//                 wr_en_hprots_buf = 1'b1;
//                 hprots_buf_wr_data = llc_req_in.hprot;
//                 wr_en_tags_buf = 1'b1;
//                 tags_buf_wr_data = line_br.tag;
//                 wr_en_dirty_bits_buf = 1'b1;
//                 dirty_bits_buf_wr_data = 1'b0;
//                 llc_mem_rsp_ready_int = 1'b1;
//             end
//             REQ_GET_S_M_IV_SEND_RSP : begin
//                 if (llc_req_in.coh_msg == `REQ_GETS && llc_req_in.hprot == 1'b0)  begin
//                     llc_rsp_out_o.coh_msg = `RSP_DATA;
//                     wr_en_sharers_buf = 1'b1;
//                     sharers_buf_wr_data = 1 << llc_req_in.req_id;
//                     states_buf_wr_data = `SHARED;
//                 end else begin
//                     if (llc_req_in.coh_msg == `REQ_GETS) begin
//                         llc_rsp_out_o.coh_msg = `RSP_EDATA;
//                         states_buf_wr_data = `EXCLUSIVE;
//                     end else if (llc_req_in.coh_msg == `REQ_GETM) begin
//                         llc_rsp_out_o.coh_msg = `RSP_DATA;
//                         states_buf_wr_data = `MODIFIED;
//                     end
//                     wr_en_owners_buf = 1'b1;
//                     owners_buf_wr_data = llc_req_in.req_id;
//                 end
//                 wr_en_states_buf = 1'b1;
//                 llc_rsp_out_o.addr = llc_req_in.addr;
//                 llc_rsp_out_o.line = lines_buf[way];
//                 llc_rsp_out_o.req_id = llc_req_in.req_id;
//                 llc_rsp_out_o.dest_id = 0;
//                 llc_rsp_out_o.invack_cnt = 0;
//                 llc_rsp_out_o.word_offset = 0;
//                 llc_rsp_out_valid_int = 1'b1;
//             end
//             REQ_GETS_S : begin
//                 wr_en_sharers_buf = 1'b1;
//                 sharers_buf_wr_data = sharers_buf[way] | (1 << llc_req_in.req_id);

//                 llc_rsp_out_o.coh_msg = `RSP_DATA;
//                 llc_rsp_out_o.addr = llc_req_in.addr;
//                 llc_rsp_out_o.line = lines_buf[way];
//                 llc_rsp_out_o.req_id = llc_req_in.req_id;
//                 llc_rsp_out_o.dest_id = 0;
//                 llc_rsp_out_o.invack_cnt = 0;
//                 llc_rsp_out_o.word_offset = 0;
//                 llc_rsp_out_valid_int = 1'b1;
//             end
//             REQ_GET_S_M_EM : begin
//                 if (llc_req_in.coh_msg == `REQ_GETS) begin
//                     states_buf_wr_data = `SD;
//                     llc_fwd_out_o.coh_msg = `FWD_GETS;
//                     wr_en_sharers_buf = 1'b1;
//                     sharers_buf_wr_data = (1 << llc_req_in.req_id) | (1 << owners_buf[way]);
//                     wr_en_states_buf = 1'b1;
//                 end else if (llc_req_in.coh_msg == `REQ_GETM) begin
//                     llc_fwd_out_o.coh_msg = `FWD_GETM;
//                     if (states_buf[way] == `EXCLUSIVE) begin
//                         wr_en_states_buf = 1'b1;
//                         states_buf_wr_data = `MODIFIED;
//                     end
//                     wr_en_owners_buf = 1'b1;
//                     owners_buf_wr_data = llc_req_in.req_id;
//                 end
//                 llc_fwd_out_o.addr = llc_req_in.addr;
//                 llc_fwd_out_o.req_id = llc_req_in.req_id;
//                 llc_fwd_out_o.dest_id = owners_buf[way];
//                 llc_fwd_out_valid_int = 1'b1;
//             end
//             REQ_GET_S_M_SD : begin
//                 set_req_stall = 1'b1;
//                 set_req_in_stalled_valid = 1'b1;
//                 set_req_in_stalled = 1'b1;
//                 update_req_in_stalled = 1'b1;
//             end
//             REQ_GETM_S_FWD : begin
//                 if (((sharers_buf[way] & (1 << l2_cnt)) != 0) && (l2_cnt != llc_req_in.req_id)) begin
//                     if (llc_fwd_out_ready_int) begin
//                         incr_invack_cnt = 1'b1;
//                     end
//                     llc_fwd_out_o.coh_msg = `FWD_INV;
//                     llc_fwd_out_o.addr = llc_req_in.addr;
//                     llc_fwd_out_o.req_id = llc_req_in.req_id;
//                     llc_fwd_out_o.dest_id = l2_cnt;
//                     llc_fwd_out_valid_int = 1'b1;
//                 end else begin
//                     skip = 1'b1;
//                 end
//             end
//             REQ_GETM_S_RSP : begin
//                 llc_rsp_out_o.coh_msg = `RSP_DATA;
//                 llc_rsp_out_o.addr = llc_req_in.addr;
//                 llc_rsp_out_o.line = lines_buf[way];
//                 llc_rsp_out_o.req_id = llc_req_in.req_id;
//                 llc_rsp_out_o.dest_id = 0;
//                 llc_rsp_out_o.invack_cnt = invack_cnt;
//                 llc_rsp_out_o.word_offset = 0;
//                 llc_rsp_out_valid_int = 1'b1;

//                 wr_en_states_buf = 1'b1;
//                 states_buf_wr_data = `MODIFIED;
//                 wr_en_owners_buf = 1'b1;
//                 owners_buf_wr_data = llc_req_in.req_id;
//                 wr_en_sharers_buf = 1'b1;
//                 sharers_buf_wr_data = 0;
//             end
//             REQ_PUTS : begin
//                 llc_rsp_out_o.coh_msg = `RSP_PUTACK;
//                 llc_rsp_out_o.addr = llc_req_in.addr;
//                 llc_rsp_out_o.req_id = llc_req_in.req_id;
//                 llc_rsp_out_o.dest_id = llc_req_in.req_id;
//                 llc_rsp_out_valid_int = 1'b1;
//                 if (states_buf[way] == `SHARED || states_buf[way] == `SD) begin
//                     wr_en_sharers_buf = 1'b1;
//                     sharers_buf_wr_data = sharers_buf[way] & ~(1 << llc_req_in.req_id);
//                     if (states_buf[way] == `SHARED && sharers_buf_wr_data == 0) begin
//                         states_buf_wr_data = `VALID;
//                         wr_en_states_buf = 1'b1;
//                     end
//                 end else if (states_buf[way] == `EXCLUSIVE && owners_buf[way] == llc_req_in.req_id) begin
//                     wr_en_states_buf = 1'b1;
//                     states_buf_wr_data = `VALID;
//                 end
//             end
//             REQ_PUTM : begin
//                 llc_rsp_out_o.coh_msg = `RSP_PUTACK;
//                 llc_rsp_out_o.addr = llc_req_in.addr;
//                 llc_rsp_out_o.req_id = llc_req_in.req_id;
//                 llc_rsp_out_o.dest_id = llc_req_in.req_id;
//                 llc_rsp_out_valid_int = 1'b1;
//                 if (states_buf[way] == `SHARED || states_buf[way] == `SD) begin
//                     sharers_buf_wr_data = sharers_buf[way] & ~(1 << llc_req_in.req_id);
//                     wr_en_sharers_buf = 1'b1;
//                     if (states_buf[way] == `SHARED && sharers_buf_wr_data == 0) begin
//                         states_buf_wr_data = `VALID;
//                         wr_en_states_buf = 1'b1;
//                     end
//                 end else if (states_buf[way] == `EXCLUSIVE || states_buf[way] == `MODIFIED) begin
//                     if (owners_buf[way] == llc_req_in.req_id) begin
//                         wr_en_states_buf = 1'b1;
//                         states_buf_wr_data = `VALID;
//                         wr_en_lines_buf = 1'b1;
//                         lines_buf_wr_data = llc_req_in.line;
//                         wr_en_dirty_bits_buf = 1'b1;
//                         dirty_bits_buf_wr_data = 1'b1;
//                     end
//                 end
//             end
//             DMA_REQ_TO_GET : begin
//                 dma_write_woffset = llc_dma_req_in.word_offset;
//                 valid_words = llc_dma_req_in.valid_words + 1;
//                 misaligned_next = ((dma_write_woffset != 0) || (valid_words != `WORDS_PER_LINE));
//                 if (llc_dma_req_in.coh_msg == `REQ_DMA_READ_BURST) begin
//                     set_dma_read_pending = 1'b1;
//                     set_is_dma_read_to_resume_process = 1'b1;
//                 end else begin
//                     set_dma_write_pending = 1'b1;
//                     set_is_dma_write_to_resume_process = 1'b1;
//                 end
//             end
//             DMA_RECALL_EM : begin
//                 dma_write_woffset = llc_dma_req_in.word_offset;
//                 valid_words = llc_dma_req_in.valid_words + 1;
//                 misaligned_next = ((dma_write_woffset != 0) || (valid_words != `WORDS_PER_LINE));
//                 set_recall_evict_addr = 1'b1;
//                 set_recall_pending = 1'b1;
//                 llc_fwd_out_o.coh_msg = `FWD_GETM_LLC;
//                 llc_fwd_out_o.addr = addr_evict;
//                 llc_fwd_out_o.req_id = owners_buf[way];
//                 llc_fwd_out_o.dest_id = owners_buf[way];;
//                 llc_fwd_out_valid_int = 1'b1;
//             end
//             DMA_RECALL_SSD : begin
//                 dma_write_woffset = llc_dma_req_in.word_offset;
//                 valid_words = llc_dma_req_in.valid_words + 1;
//                 misaligned_next = ((dma_write_woffset != 0) || (valid_words != `WORDS_PER_LINE));
//                 set_recall_evict_addr = 1'b1;
//                 if (states_buf[way] == `SHARED) begin
//                     set_recall_valid = 1'b1;
//                 end
//                 if (states_buf[way] == `SD) begin
//                     set_recall_pending = 1'b1;
//                 end
//                 if (sharers_buf[way] & (1 << l2_cnt)) begin
//                     llc_fwd_out_o.coh_msg = `FWD_INV_LLC;
//                     llc_fwd_out_o.addr = addr_evict;
//                     llc_fwd_out_o.req_id = l2_cnt;
//                     llc_fwd_out_o.dest_id = l2_cnt;
//                     llc_fwd_out_valid_int = 1'b1;
//                 end else begin
//                     skip = 1'b1;
//                 end
//             end
//             DMA_EVICT : begin
//                 clr_recall_pending = 1'b1;
//                 clr_recall_valid = 1'b1;

//                 wr_en_owners_buf = 1'b1;
//                 owners_buf_wr_data = 0;
//                 wr_en_sharers_buf = 1'b1;
//                 sharers_buf_wr_data = 0;
//                 dma_write_woffset = llc_dma_req_in.word_offset;
//                 valid_words = llc_dma_req_in.valid_words + 1;
//                 misaligned_next = ((dma_write_woffset != 0) || (valid_words != `WORDS_PER_LINE));

//                 if (evict) begin
//                     if (way == evict_way_buf) begin
//                         set_update_evict_way = 1'b1;
//                         incr_evict_way_buf = 1'b1;
//                     end
//                     if (dirty_bits_buf[way]) begin
//                         llc_mem_req_o.hwrite = `LLC_WRITE;
//                         llc_mem_req_o.addr = addr_evict;
//                         llc_mem_req_o.hsize = `WORD;
//                         llc_mem_req_o.hprot = hprots_buf[way];
//                         llc_mem_req_o.line = lines_buf[way];
//                         llc_mem_req_valid_int = 1'b1;
//                     end
//                     states_buf_wr_data = `INVALID;
//                     wr_en_states_buf = 1'b1;
//                 end else if (recall_valid) begin
//                     states_buf_wr_data = `VALID;
//                     wr_en_states_buf = 1'b1;
//                 end
//             end
//             DMA_READ_RESUME_MEM_REQ : begin
//                 llc_mem_req_o.hwrite = `READ;
//                 llc_mem_req_o.addr = dma_addr;
//                 llc_mem_req_o.hsize = `WORD;
//                 llc_mem_req_o.hprot = llc_dma_req_in.hprot;
//                 llc_mem_req_o.line = 0;
//                 llc_mem_req_valid_int = 1'b1;
//             end
//             DMA_READ_RESUME_MEM_RSP : begin
//                 llc_mem_rsp_ready_int = 1'b1;
//             end
//             DMA_READ_RESUME_DMA_RSP : begin
//                 if (states_buf[way] == `INVALID) begin
//                     wr_en_hprots_buf = 1'b1;
//                     hprots_buf_wr_data = `DATA;
//                     wr_en_tags_buf = 1'b1;
//                     tags_buf_wr_data = line_br.tag;
//                     wr_en_states_buf = 1'b1;
//                     states_buf_wr_data = `VALID;
//                     wr_en_dirty_bits_buf = 1'b1;
//                     dirty_bits_buf_wr_data = 1'b0;
//                 end

//                 if (dma_start) begin
//                     dma_read_woffset = llc_dma_req_in.word_offset;
//                 end else begin
//                     dma_read_woffset = 0;
//                 end

//                 //only increment once
//                 if (llc_dma_rsp_out_ready_int) begin
//                     dma_length_next = dma_length + (`WORDS_PER_LINE - dma_read_woffset);
//                 end else begin
//                     dma_length_next = dma_length;
//                 end


//                 if (dma_length_next >= dma_read_length) begin
//                     dma_done = 1'b1;
//                 end

//                 if (dma_start & dma_done) begin
//                     valid_words = dma_read_length;
//                 end else if (dma_start) begin
//                     valid_words = dma_length_next;
//                 end else if (dma_length_next > dma_read_length) begin
//                     valid_words = `WORDS_PER_LINE - (dma_length_next - dma_read_length);
//                 end else begin
//                     valid_words = `WORDS_PER_LINE;
//                 end

//                 dma_info[0] = dma_done;
//                 dma_info[`WORD_BITS:1] = valid_words - 1;

//                 llc_dma_rsp_out_o.coh_msg = `RSP_DATA_DMA;
//                 llc_dma_rsp_out_o.addr = dma_addr;
//                 llc_dma_rsp_out_o.line = lines_buf[way];
//                 llc_dma_rsp_out_o.req_id = llc_dma_req_in.req_id;
//                 llc_dma_rsp_out_o.dest_id = 0;
//                 llc_dma_rsp_out_o.invack_cnt = dma_info;
//                 llc_dma_rsp_out_o.word_offset = dma_read_woffset;
//                 llc_dma_rsp_out_valid_int = 1'b1;

//                 if (llc_dma_rsp_out_ready_int) begin
//                     incr_dma_addr = 1'b1;
//                     dma_start_next = 1'b0;
//                     if (dma_done) begin
//                         clr_dma_read_pending = 1'b1;
//                         clr_dma_write_pending = 1'b1;
//                     end
//                 end
//             end
//             DMA_WRITE_RESUME_MEM_REQ : begin
//                 llc_mem_req_o.hwrite = `READ;
//                 llc_mem_req_o.addr = dma_addr;
//                 llc_mem_req_o.hsize = `WORD;
//                 llc_mem_req_o.hprot = llc_dma_req_in.hprot;
//                 llc_mem_req_o.line = 0;
//                 llc_mem_req_valid_int = 1'b1;
//             end
//             DMA_WRITE_RESUME_MEM_RSP : begin
//                 dma_write_woffset = llc_dma_req_in.word_offset;
//                 valid_words = llc_dma_req_in.valid_words + 1;
//                 misaligned_next = ((dma_write_woffset != 0) || (valid_words != `WORDS_PER_LINE));
//                 llc_mem_rsp_ready_int = 1'b1;
//             end
//             DMA_WRITE_RESUME_WRITE : begin
//                 dma_write_woffset = llc_dma_req_in.word_offset;
//                 valid_words = llc_dma_req_in.valid_words + 1;
//                 if (misaligned) begin
//                     lines_buf_wr_data = lines_buf[way];

//                     for (int i = 0; i < `WORDS_PER_LINE; i++) begin
//                         if (i >= dma_write_woffset) begin
//                             words_to_write[i] = 1'b1;
//                         end
//                     end

//                     for (int i = 0; i < `WORDS_PER_LINE; i++) begin
//                         words_to_write_sum = 0;
//                         for (int j = 0; j < i; j++) begin
//                             words_to_write_sum = words_to_write_sum + words_to_write[j];
//                         end
//                         if (words_to_write[i] && (valid_words > words_to_write_sum)) begin
//                             lines_buf_wr_data[(`BITS_PER_WORD*i + `BITS_PER_WORD -1) -: (`BITS_PER_WORD)]
//                                 = llc_dma_req_in.line[(`BITS_PER_WORD*i + `BITS_PER_WORD - 1) -: (`BITS_PER_WORD)];
//                         end
//                     end

//                     wr_en_lines_buf = 1'b1;
//                 end else begin
//                     wr_en_lines_buf = 1'b1;
//                     lines_buf_wr_data = llc_dma_req_in.line;
//                 end

//                 wr_en_dirty_bits_buf = 1'b1;
//                 dirty_bits_buf_wr_data = 1'b1;

//                 if (states_buf[way] == `INVALID) begin
//                     wr_en_states_buf = 1'b1;
//                     states_buf_wr_data = `VALID;
//                     wr_en_hprots_buf = 1'b1;
//                     hprots_buf_wr_data = `DATA;
//                     wr_en_tags_buf = 1'b1;
//                     tags_buf_wr_data = line_br.tag;
//                 end

//                 if (llc_dma_req_in.hprot) begin
//                     dma_done = 1'b1;
//                 end

//                 incr_dma_addr = 1'b1;
//                 dma_start_next = 1'b0;
//                 if (dma_done) begin
//                     clr_dma_read_pending = 1'b1;
//                     clr_dma_write_pending = 1'b1;
//                 end
//             end
//             default : skip = 1'b0;
//         endcase
//     end
// endmodule
