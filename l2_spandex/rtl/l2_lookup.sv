// Copyright (c) 2011-2022 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh" 

// l2_lookup.sv

module l2_lookup(
    input logic clk,
    input logic rst, 
    input logic lookup_mode, 
    input logic lookup_en, 
    input l2_way_t evict_way_buf, 
    input var l2_tag_t tags_buf[`L2_WAYS],
    input var state_t states_buf[`L2_WAYS],
    line_breakdown_l2_t.in line_br, 
    addr_breakdown_t.in addr_br, 

    output logic tag_hit, 
    output logic empty_way_found, 
    output logic tag_hit_next, 
    output logic empty_way_found_next, 
    output l2_way_t way_hit,
    output l2_way_t empty_way, 
    output l2_way_t way_hit_next,
    output word_mask_t word_mask_shared,
    output word_mask_t word_mask_owned
    );

    l2_way_t empty_way_next; 

    always_comb begin 
        way_hit_next = 0;
        tag_hit_next = 1'b0; 
        empty_way_next = 0; 
        empty_way_found_next = 1'b0; 
        word_mask_shared = 0;
        word_mask_owned = 0;
        if (lookup_en) begin 
            case(lookup_mode) 
                `L2_LOOKUP : begin 
                    for (int i = `L2_WAYS-1; i >= 0; i--) begin
                        if (tags_buf[i] == addr_br.tag && states_buf[i] != `SPX_I) begin 
                            tag_hit_next = 1'b1; 
                            way_hit_next = i; 
                        end
                        if (states_buf[i] == `SPX_I) begin 
                            empty_way_found_next = 1'b1; 
                            empty_way_next = i; 
                        end
                    end
                    if (tag_hit_next) begin
                        // TODO: Assuming line granularity
                        if (states_buf[way_hit_next] == `SPX_R) begin
                            word_mask_owned = `WORD_MASK_ALL;
                            word_mask_shared = `WORD_MASK_ALL;
                        end else if (states_buf[way_hit_next] == `SPX_S) begin
                            word_mask_shared = `WORD_MASK_ALL;
                        end
                        // for (int i = 0; i < `WORDS_PER_LINE; i++) begin
                        //     if (states_buf[i] == `SPX_R) begin
                        //         word_mask_owned_next[i] = 1'b1;
                        //         word_mask_shared_next[i] = 1'b1;
                        //     end else if (states_buf[i] == `SPX_S) begin
                        //         word_mask_shared_next[i] = 1'b1;
                        //     end
                        // end
                    end
                end
                `L2_LOOKUP_FWD : begin 
                    for (int i = `L2_WAYS-1; i >= 0; i--) begin 
                        if (tags_buf[i] == line_br.tag && states_buf[i]  != `INVALID) begin 
                            tag_hit_next = 1'b1; 
                            way_hit_next = i;
                        end
                    end
                end
            endcase
        end
    end 
    
    always_ff @(posedge clk or negedge rst) begin 
        if (!rst) begin 
            way_hit <= 0;
            tag_hit <= 1'b0; 
            empty_way <= 0; 
            empty_way_found <= 1'b0; 
        end else if (lookup_en) begin 
            way_hit <= way_hit_next;
            tag_hit <= tag_hit_next; 
            empty_way <= empty_way_next; 
            empty_way_found <= empty_way_found_next;  
        end
    end

endmodule
