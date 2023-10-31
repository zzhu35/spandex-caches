`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_lookup (
    input logic clk,
    input logic rst,
    // Lookup command and trigger
    input logic lookup_mode,
    input logic lookup_en,
    // Bufs values used to check cache hit or miss
    input l2_tag_t tags_buf[`L2_WAYS],
    input state_t states_buf[`L2_WAYS][`WORDS_PER_LINE],
    input l2_way_t evict_way_buf,
    line_breakdown_l2_t.in line_br,
    addr_breakdown_t.in addr_br,
    // Current and registered signals for hit/miss/empty
    // Current inputs are used in FSM 1 to decide next state;
    // Registered outputs are used until new registration happens.
    output logic tag_hit,
    output logic tag_hit_next,
    output logic empty_way_found,
    output logic empty_way_found_next,
    output l2_way_t empty_way,
    output l2_way_t empty_way_next,
    output l2_way_t way_hit,
    output l2_way_t way_hit_next,
    output word_mask_t word_mask_shared,
    output word_mask_t word_mask_shared_next,
    output word_mask_t word_mask_owned,
    output word_mask_t word_mask_owned_next,
    output word_mask_t word_mask_owned_evict,
    output word_mask_t word_mask_owned_evict_next,
    output logic word_hit,
    output logic word_hit_next,
    output state_t word_hit_state,
    output state_t word_hit_state_next
    );

    logic line_present;

    always_comb begin
        way_hit_next = 'h0;
        tag_hit_next = 1'b0;
        empty_way_next = 'h0;
        empty_way_found_next = 1'b0;
        word_mask_shared_next = 'h0;
        word_mask_owned_next = 'h0;
        word_mask_owned_evict_next = 'h0;
        line_present = 1'b0;
        word_hit_state_next = 'h0;
        word_hit_next = 1'b0;

        if (lookup_en) begin
            case(lookup_mode)
                // Check if incoming request hits or misses in cache
                `L2_LOOKUP : begin
                    for (int i = `L2_WAYS-1; i >= 0; i--) begin
                        line_present = 1'b0;

                        // Is any word in the line in a valid state?
                        for (int j = 0; j < `WORDS_PER_LINE; j++) begin
                            if (states_buf[i][j] > `SPX_I) begin
                                line_present = 1'b1;
                            end
                        end

                        // Given the line is present, does the tag match?
                        if (tags_buf[i] == addr_br.tag && line_present) begin
                            tag_hit_next = 1'b1;
                            way_hit_next = i;
                        end

                        // If none of the words are valid, then the way is empty.
                        if (!line_present) begin
                            empty_way_found_next = 1'b1;
                            empty_way_next = i;
                        end

                        // TODO: When adding valid state, we should check whether it is 
                        // greater than current_valid_state.
                        // Given that the tag is hit and the line is present, we check
                        // whether word being requested is in valid state as well.
                        // (it is possible that the word we requested for is not in valid state).
                        if (tag_hit_next && states_buf[way_hit_next][addr_br.w_off] > `SPX_I) begin
                            word_hit_next = 1'b1;
                            word_hit_state_next = states_buf[way_hit_next][addr_br.w_off];
                        end
                    end

                    // Check how many words in the line are in owned or shared state
                    if (tag_hit_next) begin
                        for (int j = 0; j < `WORDS_PER_LINE; j++) begin
                            if (states_buf[way_hit_next][j] == `SPX_R) begin
                                word_mask_owned_next[j] = 1'b1;
                                word_mask_shared_next[j] = 1'b1;
                            end else if (states_buf[way_hit_next][j] == `SPX_S) begin
                                word_mask_shared_next[j] = 1'b1;
                            end
                        end
                    end

                    // If neither hit nor empty way available, check number of owned words
                    // in way to be evicted.
                    if (!tag_hit_next && !empty_way_found_next) begin
                        for (int j = 0; j < `WORDS_PER_LINE; j++) begin
                            if (states_buf[evict_way_buf][j] == `SPX_R) begin
                                word_mask_owned_evict_next[j] = 1'b1;
                            end
                        end
                    end
                end
                // Check if incoming forward hits or misses in cache
                `L2_LOOKUP_FWD : begin
                    for (int i = `L2_WAYS-1; i >= 0; i--) begin
                        line_present = 1'b0;

                        // Is any word in the line in a valid state?
                        for (int j = 0; j < `WORDS_PER_LINE; j++) begin
                            if (states_buf[i][j] > `SPX_I) begin
                                line_present = 1'b1;
                            end
                        end

                        // Given the line is present, does the tag match?
                        if (tags_buf[i] == line_br.tag && line_present) begin
                            tag_hit_next = 1'b1;
                            way_hit_next = i;
                        end
                        
                        // Given that the tag is hit and the line is present, we check
                        // whether word being requested is in valid state as well.
                        // (it is possible that the word we requested for is not in valid state.
                        if (tag_hit_next && states_buf[way_hit_next][addr_br.w_off] > `SPX_I) begin
                            word_hit_next = 1'b1;
                            word_hit_state_next = states_buf[way_hit_next][addr_br.w_off];
                        end
                    end

                    // Check how many words in the line are in owned or shared state
                    if (tag_hit_next) begin
                        for (int j = 0; j < `WORDS_PER_LINE; j++) begin
                            if (states_buf[way_hit_next][j] == `SPX_R) begin
                                word_mask_owned_next[j] = 1'b1;
                                word_mask_shared_next[j] = 1'b1;
                            end else if (states_buf[way_hit_next][j] == `SPX_S) begin
                                word_mask_shared_next[j] = 1'b1;
                            end
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
            word_mask_shared <= 0;
            word_mask_owned <= 0;
            word_mask_owned_evict <= 0;
            word_hit <= 0;
            word_hit_state <= 1'b0;
        end else if (lookup_en) begin
            way_hit <= way_hit_next;
            tag_hit <= tag_hit_next;
            empty_way <= empty_way_next;
            empty_way_found <= empty_way_found_next;
            word_mask_shared <= word_mask_shared_next;
            word_mask_owned <= word_mask_owned_next;
            word_mask_owned_evict <= word_mask_owned_evict_next;
            word_hit <= word_hit_next;
            word_hit_state <= word_hit_state_next;
        end
    end

endmodule

// module l2_lookup (
//     input logic clk,
//     input logic rst,
//     input logic lookup_mode,
//     input logic lookup_en,
//     input l2_tag_t tags_buf[`L2_WAYS],
//     input state_t states_buf[`L2_WAYS],
//     line_breakdown_l2_t.in line_br,
//     addr_breakdown_t.in addr_br,

//     output logic tag_hit,
//     output logic empty_way_found,
//     output logic tag_hit_next,
//     output logic empty_way_found_next,
//     output l2_way_t way_hit,
//     output l2_way_t empty_way,
//     output l2_way_t way_hit_next,
//     output word_mask_t word_mask_shared,
//     output word_mask_t word_mask_owned
//     );

//     l2_way_t empty_way_next;

//     always_comb begin
//         way_hit_next = 0;
//         tag_hit_next = 1'b0;
//         empty_way_next = 0;
//         empty_way_found_next = 1'b0;
//         word_mask_shared = 0;
//         word_mask_owned = 0;
//         if (lookup_en) begin
//             case(lookup_mode)
//                 `L2_LOOKUP : begin
//                     for (int i = `L2_WAYS-1; i >= 0; i--) begin
//                         if (tags_buf[i] == addr_br.tag && states_buf[i] != `SPX_I) begin
//                             tag_hit_next = 1'b1;
//                             way_hit_next = i;
//                         end
//                         if (states_buf[i] == `SPX_I) begin
//                             empty_way_found_next = 1'b1;
//                             empty_way_next = i;
//                         end
//                     end
//                     if (tag_hit_next) begin
//                         if (states_buf[way_hit_next] == `SPX_R) begin
//                             word_mask_owned = `WORD_MASK_ALL;
//                             word_mask_shared = `WORD_MASK_ALL;
//                         end else if (states_buf[way_hit_next] == `SPX_S) begin
//                             word_mask_shared = `WORD_MASK_ALL;
//                         end
//                         // for (int i = 0; i < `WORDS_PER_LINE; i++) begin
//                         //     if (states_buf[i] == `SPX_R) begin
//                         //         word_mask_owned_next[i] = 1'b1;
//                         //         word_mask_shared_next[i] = 1'b1;
//                         //     end else if (states_buf[i] == `SPX_S) begin
//                         //         word_mask_shared_next[i] = 1'b1;
//                         //     end
//                         // end
//                     end
//                 end
//                 `L2_LOOKUP_FWD : begin
//                     for (int i = `L2_WAYS-1; i >= 0; i--) begin
//                         if (tags_buf[i] == line_br.tag && states_buf[i]  != `INVALID) begin
//                             tag_hit_next = 1'b1;
//                             way_hit_next = i;
//                         end
//                     end
//                 end
//             endcase
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             way_hit <= 0;
//             tag_hit <= 1'b0;
//             empty_way <= 0;
//             empty_way_found <= 1'b0;
//         end else if (lookup_en) begin
//             way_hit <= way_hit_next;
//             tag_hit <= tag_hit_next;
//             empty_way <= empty_way_next;
//             empty_way_found <= empty_way_found_next;
//         end
//     end

// endmodule
