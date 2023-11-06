`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

`ifdef USE_WB
module l2_wb (
    input logic clk,
    input logic rst,
    input logic add_wb_entry,
    input logic clear_wb_entry,
    input logic [`WB_BITS-1:0] wb_evict_buf,
    input logic ongoing_drain,
    // Update parts of an WB entry.
    input logic update_wb_way,
    input logic update_wb_line,
    input logic update_wb_hprot,
    input logic update_wb_word_mask,
    input logic update_wb_dcs_en,
    input logic update_wb_dcs,
    input logic update_wb_use_owner_pred,
    input logic update_wb_pred_cid,
    // Function of the WB to perform
    input logic wb_op_code,
    // Values to update an WB entry.
    input l2_way_t update_wb_value_way,
    input line_t update_wb_value_line,
    input hprot_t update_wb_value_hprot,
    input word_mask_t update_wb_value_word_mask,
    input logic update_wb_value_dcs_en,
    input dcs_t update_wb_value_dcs,
    input logic update_wb_value_use_owner_pred,
    input cache_id_t update_wb_value_pred_cid,
    addr_breakdown_t.in addr_br,

    // Signals indicating whether there was a hit, an empty entry or valid entry.
    output logic wb_hit_next,
    output logic wb_hit,
    output logic [`WB_BITS-1:0] wb_hit_i_next,
    output logic [`WB_BITS-1:0] wb_hit_i,
    output logic wb_empty_next,
    output logic wb_empty,
    output logic [`WB_BITS-1:0] wb_empty_i_next,
    output logic [`WB_BITS-1:0] wb_empty_i,
    output logic wb_valid_next,
    output logic wb_valid,
    output logic [`WB_BITS-1:0] wb_valid_i_next,
    output logic [`WB_BITS-1:0] wb_valid_i,
    // All WB entries
    output wb_buf_t wb[`N_WB]
    );

    // Generate logic for all WB entries
    genvar i;
    generate
        for (i = 0; i < `N_WB; i++) begin
            // Update all parts of WB entry when adding
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    wb[i].tag <= 0;
                    wb[i].set <= 0;
                    wb[i].way <= 0;
                    wb[i].hprot <= 0;
                    wb[i].line <= 0;
                    wb[i].word_mask <= 0;
                    wb[i].dcs_en <= 0;
                    wb[i].dcs <= 0;
                    wb[i].use_owner_pred <= 0;
                    wb[i].pred_cid <= 0;
                    wb[i].valid <= 0;
                end else if (add_wb_entry) begin
                    if (wb_hit) begin
                        if (wb_hit_i == i) begin
                            wb[i].way <= update_wb_value_way;
                            wb[i].hprot <= update_wb_value_hprot;
                            wb[i].line <= update_wb_value_line;
                            wb[i].word_mask <= update_wb_value_word_mask;
                            wb[i].dcs_en <= update_wb_value_dcs_en;
                            wb[i].dcs <= update_wb_value_dcs;
                            wb[i].use_owner_pred <= update_wb_value_use_owner_pred;
                            wb[i].pred_cid <= update_wb_value_pred_cid;
                        end
                    end else if (wb_empty) begin
                        if (wb_empty_i == i) begin
                            wb[i].tag <= addr_br.tag;
                            wb[i].set <= addr_br.set;
                            wb[i].way <= update_wb_value_way;
                            wb[i].hprot <= update_wb_value_hprot;
                            wb[i].line <= update_wb_value_line;
                            wb[i].word_mask <= update_wb_value_word_mask;
                            wb[i].dcs_en <= update_wb_value_dcs_en;
                            wb[i].dcs <= update_wb_value_dcs;
                            wb[i].use_owner_pred <= update_wb_value_use_owner_pred;
                            wb[i].pred_cid <= update_wb_value_pred_cid;
                            wb[i].valid <= 1'b1;
                        end
                    end
                end else if (clear_wb_entry) begin
                    if (ongoing_drain) begin
                        if (wb_valid_i == i) begin
                            wb[i].valid <= 1'b0;
                        end
                    end else begin
                        if (wb_evict_buf == i) begin
                            wb[i].valid <= 1'b0;
                        end
                    end
                end
            end
        end
    endgenerate

    always_comb begin
        wb_hit_i_next = 'h0;
        wb_hit_next = 1'b0;
        wb_empty_i_next = 'h0;
        wb_empty_next = 1'b0;
        wb_valid_i_next = 'h0;
        wb_valid_next = 1'b0;

        // Different WB-specific actions from L2 FSM
        case(wb_op_code)
            // Check if there is a hit, an empty entry or valid entry.
            `L2_WB_PEEK_REQ : begin
                for (int i = 0; i < `N_WB; i++) begin
                    if (wb[i].valid == 1'b0) begin
                        wb_empty_next = 1'b1;
                        wb_empty_i_next = i;
                    end else begin
                        wb_valid_next = 1'b1;
                        wb_valid_i_next = i;
                    end

                    if (wb[i].tag == addr_br.tag && wb[i].set == addr_br.set && wb[i].valid == 1'b1) begin
                        wb_hit_next = 1'b1;
                        wb_hit_i_next = i;
                    end

                    // If we are not doing a drain, we want to dispatch WB entries based
                    // on a policy - here we use a round robin policy to set wb_evict_buf,
                    // which determines what entry is dispatched. This will only be used
                    // when the WB is full, therefore we can assume that the entry is valid.
                end
            end
            default : begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            wb_hit_i <= 0;
            wb_hit <= 0;
            wb_empty_i <= 0;
            wb_empty <= 0;
            wb_valid_i <= 0;
            wb_valid <= 0;
        end else if (wb_op_code != `L2_WB_IDLE) begin
            wb_hit_i <= wb_hit_i_next;
            wb_hit <= wb_hit_next;
            wb_empty_i <= wb_empty_i_next;
            wb_empty <= wb_empty_next;
            wb_valid_i <= wb_valid_i_next;
            wb_valid <= wb_valid_next;
        end
    end

endmodule
`endif
