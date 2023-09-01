`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_lookup (
    input logic clk,
    input logic rst,
    // Lookup command and trigger
    input logic lookup_mode,
    input logic lookup_en,
    // Bufs values used to check cache hit or miss
    input llc_tag_t tags_buf[`LLC_WAYS],
    input llc_state_t states_buf[`LLC_WAYS],
    input owner_t owners_buf[`LLC_WAYS],
    input line_t lines_buf[`LLC_WAYS],
    input llc_way_t evict_way_buf,

    line_breakdown_llc_t.in line_br,

    // Current and registered signals for hit/miss/empty
    // Current inputs are used in FSM 1 to decide next state;
    // Registered outputs are used until new registration happens.
    output logic tag_hit,
    output logic tag_hit_next,
    output logic empty_way_found,
    output logic empty_way_found_next,
    output llc_way_t empty_way,
    output llc_way_t empty_way_next,
    output llc_way_t way_hit,
    output llc_way_t way_hit_next,
    output word_mask_t word_mask_owned,
    output word_mask_t word_mask_owned_next,
    // Read the line_bufs to get the cache ID of owners, if any.
    output cache_id_t owners_cache_id[`WORDS_PER_LINE]
    );

    always_comb begin
        way_hit_next = 'h0;
        tag_hit_next = 1'b0;
        empty_way_next = 'h0;
        empty_way_found_next = 1'b0;
        word_mask_owned_next = 'h0;

        if (lookup_en) begin
            case(lookup_mode)
                // Check if incoming request hits or misses in cache
                `LLC_LOOKUP : begin
                    for (int i = `LLC_WAYS-1; i >= 0; i--) begin
                        if (tags_buf[i] == line_br.tag && states_buf[i] != `LLC_I) begin
                            tag_hit_next = 1'b1;
                            way_hit_next = i;
                        end

                        if (states_buf[i] == `LLC_I) begin
                            empty_way_found_next = 1'b1;
                            empty_way_next = i;
                        end
                    end

                    // Check how many words in the line are in owned state
                    if (tag_hit_next) begin
                        word_mask_owned_next = owners_buf[way_hit_next];
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
            word_mask_owned <= 0;
        end else if (lookup_en) begin
            way_hit <= way_hit_next;
            tag_hit <= tag_hit_next;
            empty_way <= empty_way_next;
            empty_way_found <= empty_way_found_next;
            word_mask_owned <= word_mask_owned_next;
        end
    end

    genvar i;
    generate
        for (i = 0; i < `WORDS_PER_LINE; i++) begin
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    owners_cache_id[i] <= 0;
                // end else if (tag_hit & word_mask_owned[i]) begin
                //     owners_cache_id[i] <= lines_buf[i * `BITS_PER_WORD +: `CACHE_ID_WIDTH];
                end else begin
                    owners_cache_id[i] <= 0;
                end
            end
        end
    endgenerate

endmodule
