`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_mshr(
    input logic clk,
    input logic rst,
    input logic add_mshr_entry,
    input mix_msg_t fwd_in_coh_msg,
    input logic do_bulk_rsp,
    input addr_t l2_cpu_bulk_len_int,
    input logic ongoing_drain,
    // Update parts of an MSHR entry.
    input logic update_mshr_state,
    input logic update_mshr_line,
    input logic update_mshr_tag,
    input logic update_mshr_word_mask,
    input logic update_mshr_word,
    // Function of the MSHR to perform
    input logic [2:0] mshr_op_code,
    // Values to update an MSHR entry.
    input cpu_msg_t update_mshr_value_cpu_msg,
    input hprot_t update_mshr_value_hprot,
    input hsize_t update_mshr_value_hsize,
    input l2_tag_t update_mshr_value_tag,
    input l2_way_t update_mshr_value_way,
    input line_t update_mshr_value_line,
    input unstable_state_t update_mshr_value_state,
    input word_t update_mshr_value_word,
    input amo_t  update_mshr_value_amo,
    input word_mask_t update_mshr_value_word_mask,
    input word_mask_t update_mshr_value_word_mask_reg,
`ifdef USE_WB
    input logic clear_wb_entry,
    input logic wb_use_dispatch_entry,
    input l2_tag_t wb_dispatch_tag,
    input l2_set_t wb_dispatch_set,
`endif
    input logic add_mshr_fwd_entry,
    input logic coal_mshr_fwd_entry,

    addr_breakdown_t.in addr_br,
    line_breakdown_l2_t.in line_br,
    output logic set_set_conflict_mshr,
    output logic clr_set_conflict_mshr,
    output logic set_fwd_stall,
    output logic clr_fwd_stall,
    output logic set_fwd_stall_entry,
    output logic [`MSHR_BITS-1:0] set_fwd_stall_entry_data,
    // Drain status - any ownership requests pending.
    output logic mshr_write_pending,
`ifdef USE_WB
    output logic mshr_drain_conflict,
`endif
    // Signals indicating whether there was a hit and the index for hit.
    output logic mshr_hit_next,
    output logic mshr_hit,
    output logic [`MSHR_BITS-1:0] mshr_i_next,
    output logic [`MSHR_BITS-1:0] mshr_i,
    output logic mshr_coalesce_hit_next,
    output logic mshr_coalesce_hit,
    output logic [`MSHR_BITS-1:0] mshr_coalesce_i_next,
    output logic [`MSHR_BITS-1:0] mshr_coalesce_i,
    // All MSHR entries
    output mshr_buf_t mshr[`N_MSHR]
    );

    logic fwd_stall_override;
    logic is_within_bulk_limit;

    // Generate logic for all MSHR entries
    genvar i;
    generate
        for (i = 0; i < `N_MSHR; i++) begin
            // Update all parts of MSHR entry when adding
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].cpu_msg <= 0;
                    mshr[i].set <= 0;
                    mshr[i].way <= 0;
                    mshr[i].hsize <= 0;
                    mshr[i].w_off <= 0;
                    mshr[i].b_off <= 0;
                    mshr[i].hprot <= 0;
                    mshr[i].amo <= 0;
                    mshr[i].word_mask_reg <= 0;
`ifdef USE_WB
                end else if (add_mshr_entry && clear_wb_entry) begin
                    // TODO: we assume that for entries added from the WB, we do not need 
                    // the w_off and b_off because the line is already updated using them.
                    if (mshr_i == i) begin
                        mshr[i].cpu_msg <= update_mshr_value_cpu_msg;
                        mshr[i].set <= wb_dispatch_set;
                        mshr[i].way <= update_mshr_value_way;
                        mshr[i].hsize <= update_mshr_value_hsize;
                        mshr[i].w_off <= addr_br.w_off;
                        mshr[i].b_off <= addr_br.b_off;
                        mshr[i].hprot <= update_mshr_value_hprot;
                        mshr[i].word <= update_mshr_value_word;
                        mshr[i].amo <= update_mshr_value_amo;
                        mshr[i].word_mask_reg <= update_mshr_value_word_mask_reg;
                    end
                end else if (add_mshr_entry && wb_use_dispatch_entry) begin
                    // TODO: we assume that for entries added from the WB, we do not need 
                    // the w_off and b_off because the line is already updated using them.
                    if (mshr_i_next == i) begin
                        mshr[i].cpu_msg <= update_mshr_value_cpu_msg;
                        mshr[i].set <= wb_dispatch_set;
                        mshr[i].way <= update_mshr_value_way;
                        mshr[i].hsize <= update_mshr_value_hsize;
                        mshr[i].w_off <= addr_br.w_off;
                        mshr[i].b_off <= addr_br.b_off;
                        mshr[i].hprot <= update_mshr_value_hprot;
                        mshr[i].word <= update_mshr_value_word;
                        mshr[i].amo <= update_mshr_value_amo;
                        mshr[i].word_mask_reg <= update_mshr_value_word_mask_reg;
                    end                    
`endif               
                end else if (add_mshr_entry) begin
                    if (mshr_i == i) begin
                        mshr[i].cpu_msg <= update_mshr_value_cpu_msg;
                        mshr[i].set <= add_mshr_fwd_entry ? line_br.set : addr_br.set;
                        mshr[i].way <= update_mshr_value_way;
                        mshr[i].hsize <= update_mshr_value_hsize;
                        mshr[i].w_off <= addr_br.w_off;
                        mshr[i].b_off <= addr_br.b_off;
                        mshr[i].hprot <= update_mshr_value_hprot;
                        mshr[i].amo <= update_mshr_value_amo;
                        mshr[i].word_mask_reg <= update_mshr_value_word_mask_reg;
                    end     
                end
            end

            // Update only state of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].state <= 0;
                end else if (update_mshr_state || add_mshr_entry) begin
`ifdef USE_WB
                    if (wb_use_dispatch_entry) begin
                        if (mshr_i_next == i) begin
                            mshr[i].state <= update_mshr_value_state;
                        end
                    end else if (coal_mshr_fwd_entry) begin
                        if (mshr_coalesce_i == i) begin
                            mshr[i].state <= update_mshr_value_state;
                        end                        
                    end else begin
`endif                        
                        if (mshr_i == i) begin
                            mshr[i].state <= update_mshr_value_state;
                        end
`ifdef USE_WB
                    end
`endif                        
                end
            end

            // Update only line of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].line <= 0;
                end else if (update_mshr_line || add_mshr_entry) begin
`ifdef USE_WB
                    if (wb_use_dispatch_entry) begin
                        if (mshr_i_next == i) begin
                            mshr[i].line <= update_mshr_value_line;
                        end
                    end else if (coal_mshr_fwd_entry) begin
                        if (mshr_coalesce_i == i) begin
                            mshr[i].line <= update_mshr_value_line;
                        end                        
                    end else begin
`endif                        
                        if (mshr_i == i) begin
                            mshr[i].line <= update_mshr_value_line;
                        end
`ifdef USE_WB
                    end
`endif                        
                end
            end

            // Update only tag of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].tag <= 0;
                end else if (update_mshr_tag || add_mshr_entry) begin
`ifdef USE_WB
                    if (wb_use_dispatch_entry) begin
                        if (mshr_i_next == i) begin
                            mshr[i].tag <= update_mshr_value_tag;
                        end
                    end else begin
`endif                        
                        if (mshr_i == i) begin
                            mshr[i].tag <= update_mshr_value_tag;
                        end
`ifdef USE_WB
                    end
`endif                        
                end
            end

            // Update only word_mask of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].word_mask <= 0;
                end else if (update_mshr_word_mask || add_mshr_entry) begin
`ifdef USE_WB
                    if (wb_use_dispatch_entry) begin
                        if (mshr_i_next == i) begin
                            mshr[i].word_mask <= update_mshr_value_word_mask;
                        end
                    end else begin
`endif                        
                        if (mshr_i == i) begin
                            mshr[i].word_mask <= update_mshr_value_word_mask;
                        end
`ifdef USE_WB
                    end
`endif                        
                end
            end

            // Update only word of MSHR entry mshr_i
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    mshr[i].word <= 0;
                end else if (update_mshr_word || add_mshr_entry) begin
`ifdef USE_WB
                    if (mshr_coalesce_hit_next && wb_use_dispatch_entry) begin
                        if (mshr_coalesce_i_next == i) begin
                            mshr[i].word <= update_mshr_value_word;
                        end
                    end else if (mshr_coalesce_hit && clear_wb_entry) begin
                        if (mshr_coalesce_i == i) begin
                            mshr[i].word <= update_mshr_value_word;
                        end                        
                    end else begin
`endif                        
                        if (mshr_i == i) begin
                            mshr[i].word <= update_mshr_value_word;
                        end
`ifdef USE_WB
                    end
`endif                        
                end
            end
        end
    endgenerate

    always_comb begin
        mshr_i_next = 0;
        mshr_hit_next = 1'b0;
        clr_set_conflict_mshr = 1'b0;
        set_set_conflict_mshr = 1'b0;
        set_fwd_stall_entry = 1'b0;
        set_fwd_stall_entry_data = 'h0;
        set_fwd_stall = 1'b0;
        clr_fwd_stall = 1'b0;
        fwd_stall_override = 1'b0;
        mshr_coalesce_i_next = 'h0;
        mshr_coalesce_hit_next = 1'b0;
        is_within_bulk_limit = 1'b0;
`ifdef USE_WB
        mshr_drain_conflict = 1'b0;
`endif

        // Different MSHR-specific actions from L2 FSM
        case(mshr_op_code)
            // Check if there is a free MSHR entry
            // TODO: this should check if the incoming response is within the range of the
            // bulk transfer, else the wrong entry can be chosen.
            `L2_MSHR_LOOKUP : begin
                for (int i = 0; i < `N_MSHR; i++) begin
                    if (do_bulk_rsp) begin
                        if (mshr[i].word != 'h0 && mshr[i].state == `SPX_IV) begin
                            mshr_hit_next = 1'b1;
                            mshr_i_next = i;
                        end
                    end else if (l2_rsp_in.word_mask == 'h0 && l2_rsp_in.coh_msg == `RSP_O) begin
                        within_bulk_limit_check(mshr[i].tag, mshr[i].set, line_br.tag, line_br.set, l2_cpu_bulk_len_int, is_within_bulk_limit);

                        // If the incoming response is greater/equal to the current bulk done for a pending
                        // write request in an MSHR entry. If yes, we will choose to coalesce the entries.
                        if (is_within_bulk_limit && mshr[i].state != `SPX_I) begin
                            mshr_hit_next = 1'b1;
                            mshr_i_next = i;
                        end
                    end else begin
                        if (mshr[i].tag == line_br.tag && mshr[i].set == line_br.set && mshr[i].state != `SPX_I) begin
                            mshr_hit_next = 1'b1;
                            mshr_i_next = i;
                        end
                    end
                end
            end
            // Check if there is a conflicting entry to incoming request. If yes, stall.
            `L2_MSHR_PEEK_REQ : begin
                clr_set_conflict_mshr = 1'b1;

                for (int i = 0; i < `N_MSHR; i++) begin
                    if (mshr[i].state == `SPX_I) begin
                        mshr_i_next = i;
                    end

                    // If the incoming request matches with an entry in the MSHR,
                    // assert set_conflict (which is sampled in l2_core).
                    if (mshr[i].set == addr_br.set && mshr[i].state != `SPX_I) begin
                        set_set_conflict_mshr = 1'b1;
                        clr_set_conflict_mshr = 1'b0;
                    end
                end
            end
            `L2_MSHR_PEEK_FLUSH : begin
                for (int i = 0; i <`N_MSHR; i++) begin
                    if (mshr[i].state == `SPX_I) begin
                        mshr_i_next = i;
                    end
                end
            end
            // Check if there is a conflicting entry to incoming forward. If yes, stall.
            `L2_MSHR_PEEK_FWD : begin
                clr_fwd_stall = 1'b1;

                // Check if MSHR is full if the forward msg type is bulk. Add a new input signal to get the msg type.
                // Need to also check if there is a matching entry. better to do this in the MSHR module. and clear fwd stall
                // with a signal indicating msg type of forward to regs module.
                if (fwd_in_coh_msg == `FWD_WTfwd_BULK) begin
                    for (int i = 0; i < `N_MSHR; i++) begin
                        // First, we check if this entry is free. In case of no conflict and no pending hit entry,
                        // we will use this entry to start the new bulk transfer.
                        if (mshr[i].state == `SPX_I) begin
                            mshr_hit_next = 1'b1;
                            mshr_i_next = i;
                        end

                        // Next, check if this entry conflicts with the incoming entry. Note that we check for pending
                        // entry to coalesce with - this is relevant only for the HEAD packet.
                        if (mshr[i].tag == line_br.tag && mshr[i].set == line_br.set && mshr[i].state != `SPX_I && mshr[i].state != `SPX_RI) begin
                            set_fwd_stall = 1'b1;
                            clr_fwd_stall = 1'b0;
                        end

                        // Now we will check whether the incoming forward is within the range of any pending bulk forward
                        // in this MSHR entry. 
                        within_bulk_limit_check(mshr[i].tag, mshr[i].set, line_br.tag, line_br.set, mshr[i].word, is_within_bulk_limit);

                        // If there is a hit, we will coalesce the tracking of this forward in the same entry.
                        if (is_within_bulk_limit && mshr[i].state != `SPX_I && mshr[i].cpu_msg == `WRITE) begin
                            mshr_coalesce_hit_next = 1'b1;
                            mshr_coalesce_i_next = i;
                            // Clear fwd stall
                            set_fwd_stall = 1'b0;
                            clr_fwd_stall = 1'b1;
                        end
                    end
                end else begin
                    for (int i = 0; i < `N_MSHR; i++) begin
                        if (mshr[i].tag == line_br.tag && mshr[i].set == line_br.set && mshr[i].state != `SPX_I) begin
                            mshr_hit_next = 1'b1;
                            mshr_i_next = i;

                            // We do not always need to stall - in certain cases, we immediately de-assert fwd_stall
                            case (fwd_in_coh_msg)
                                // For FWD_INV, we always respond (and do not stall the forward). In
                                // case of SPX_IS, we change transient state to SPX_II.
                                // In case of FWD_REQ_S, FWD_REQ_OData, and FWD_RVK_O, need to check SPX_RI.
                                `FWD_INV : begin
                                    fwd_stall_override = 1'b1;
                                end
                                `FWD_RVK_O : begin
                                    if (mshr[i].state == `SPX_RI) begin
                                        fwd_stall_override = 1'b1;
                                    end
                                end
                                `FWD_REQ_S : begin
                                    if (mshr[i].state == `SPX_RI) begin
                                        fwd_stall_override = 1'b1;
                                    end
                                end
                                `FWD_REQ_Odata : begin
                                    if (mshr[i].state == `SPX_RI) begin
                                        fwd_stall_override = 1'b1;
                                    end
                                end
                                `FWD_WTfwd : begin
                                    if (mshr[i].state == `SPX_RI) begin
                                        fwd_stall_override = 1'b1;
                                    end
                                end
                            endcase

                            if (!fwd_stall_override) begin
                                set_fwd_stall = 1'b1;
                                clr_fwd_stall = 1'b0;
                            end
                        end
                    end
                end

                if (set_fwd_stall) begin
                    set_fwd_stall_entry = 1'b1;
                    set_fwd_stall_entry_data = mshr_i_next;
                end
            end
            // Check if there is a conflicting entry to a WB entry being dispatched. If yes, stall.
`ifdef USE_WB
            `L2_MSHR_PEEK_WB : begin
                for (int i = 0; i < `N_MSHR; i++) begin
                    if (mshr[i].state == `SPX_I) begin
                        mshr_i_next = i;
                    end

                    // If the incoming request matches with an entry in the MSHR,
                    // assert set_conflict (which is sampled in l2_core).
                    if (mshr[i].tag == wb_dispatch_tag && mshr[i].set == wb_dispatch_set && mshr[i].state != `SPX_I) begin
                        set_set_conflict_mshr = 1'b1;
                        clr_set_conflict_mshr = 1'b0;
                    end

                    within_bulk_limit_check(mshr[i].tag, mshr[i].set, wb_dispatch_tag, wb_dispatch_set, l2_cpu_bulk_len_int, is_within_bulk_limit);

                    // If the incoming request is greater/equal to the current bulk done for an ongoing
                    // write request in an MSHR entry. If yes, we will choose to coalesce the entries.
                    if (is_within_bulk_limit && mshr[i].state != `SPX_I && mshr[i].cpu_msg == `WRITE) begin
                        // Return matching entry in MSHR for coalescing.
                        mshr_coalesce_hit_next = 1'b1;
                        mshr_coalesce_i_next = i;
                        // Clear set conflict.
                        set_set_conflict_mshr = 1'b0;
                        clr_set_conflict_mshr = 1'b1;
                    end
                end
            end
            `L2_MSHR_PEEK_DRAIN : begin
                for (int i = 0; i < `N_MSHR; i++) begin
                    if (mshr[i].state == `SPX_I) begin
                        mshr_i_next = i;
                    end

                    // If the incoming request matches with an entry in the MSHR,
                    // assert set_conflict (which is sampled in l2_core).
                    if (mshr[i].tag == wb_dispatch_tag && mshr[i].set == wb_dispatch_set && mshr[i].state != `SPX_I) begin
                        mshr_drain_conflict = 1'b1;
                    end

                    within_bulk_limit_check(mshr[i].tag, mshr[i].set, wb_dispatch_tag, wb_dispatch_set, l2_cpu_bulk_len_int, is_within_bulk_limit);

                    // If the incoming request is greater/equal to the current bulk done for an ongoing
                    // write request in an MSHR entry. If yes, we will choose to coalesce the entries.
                    if (is_within_bulk_limit && mshr[i].state != `SPX_I && mshr[i].cpu_msg == `WRITE) begin
                        // Return matching entry in MSHR for coalescing.
                        mshr_coalesce_hit_next = 1'b1;
                        mshr_coalesce_i_next = i;
                        // Clear drain conflict.
                        mshr_drain_conflict = 1'b0;
                    end
                end
            end            
`endif            
            // Check if there is an earlier bulk entry exists in the MSHR. If yes, stall.
            `L2_MSHR_PEEK_BULK : begin
                clr_set_conflict_mshr = 1'b1;

                for (int i = 0; i < `N_MSHR; i++) begin
                    if (mshr[i].state == `SPX_I) begin
                        mshr_i_next = i;
                    end

                    // If the incoming request matches with an entry in the MSHR,
                    // assert set_conflict (which is sampled in l2_core).
                    if (mshr[i].set == addr_br.set && mshr[i].state != `SPX_I) begin
                        set_set_conflict_mshr = 1'b1;
                        clr_set_conflict_mshr = 1'b0;
                    end

                    // If the incoming request is greater/equal to the current bulk done 
                    if (((mshr[i].set + 1 == addr_br.set) || (mshr[i].tag + 1 == addr_br.tag)) && mshr[i].state != `SPX_I && mshr[i].cpu_msg == `READ) begin
                        set_set_conflict_mshr = 1'b1;
                        clr_set_conflict_mshr = 1'b0;
                    end

                    within_bulk_limit_check(mshr[i].tag, mshr[i].set, addr_br.tag, addr_br.set, l2_cpu_bulk_len_int, is_within_bulk_limit);

                    // If the incoming request is greater/equal to the current bulk done for an ongoing
                    // write request in an MSHR entry. If yes, we will choose to coalesce the entries.
                    if (is_within_bulk_limit && mshr[i].state != `SPX_I && mshr[i].cpu_msg == `WRITE) begin
                        // Clear set conflict.
                        set_set_conflict_mshr = 1'b0;
                        clr_set_conflict_mshr = 1'b1;
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
            mshr_coalesce_i <= 0;
            mshr_coalesce_hit <= 0;
        end else if (mshr_op_code != `L2_MSHR_IDLE) begin
            mshr_i <= mshr_i_next;
            mshr_hit <= mshr_hit_next;
            mshr_coalesce_i <= mshr_coalesce_i_next;
            mshr_coalesce_hit <= mshr_coalesce_hit_next;
        end
    end

    always_comb begin
        mshr_write_pending = 1'b0;

        for (int i = 0; i < `N_MSHR; i++) begin
            if (mshr[i].state == `SPX_XR || mshr[i].state == `SPX_XRV || mshr[i].state == `SPX_AMO) begin
                mshr_write_pending = 1'b1;
            end
        end
    end

`ifdef USE_WB
    function void within_bulk_limit_check;
        input l2_tag_t mshr_tag;
        input l2_set_t mshr_set;
        input l2_tag_t dispatch_tag;
        input l2_set_t dispatch_set;
        input word_t bulk_len;
        output logic is_within;

        line_addr_t mshr_addr, dispatch_addr;
        word_t bulk_len_in_lines;

        mshr_addr = (mshr_tag << `L2_SET_BITS) | mshr_set;
        dispatch_addr = (dispatch_tag << `L2_SET_BITS) | dispatch_set;
        bulk_len_in_lines = bulk_len/`WORDS_PER_LINE;

        is_within = ((dispatch_addr >= mshr_addr) && (dispatch_addr < mshr_addr + bulk_len_in_lines)) ? 1'b1 : 1'b0;
    endfunction
`endif

endmodule
