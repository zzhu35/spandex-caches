`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_regs (
    input logic clk,
    input logic rst,
    // Triggers to assign to registers
    input logic decode_en,
    input logic lookup_en,
    input logic add_mshr_entry,
    input logic incr_mshr_cnt,
    input logic clr_evict_stall,
    input logic set_evict_stall,
    input logic clr_set_conflict,
    input logic set_set_conflict,
    input logic clr_req_in_stalled_valid,
    input logic set_req_in_stalled_valid,
    input logic set_ongoing_flush,
    input logic clr_ongoing_flush,
    input logic incr_flush_set,
    input logic clr_flush_set,
    input logic incr_flush_way,
    input logic clr_flush_way,

    // Registers
    output logic ongoing_flush,
    output logic [`LLC_SET_BITS:0] flush_set,
    output logic [`LLC_WAY_BITS:0] flush_way,
    output logic evict_stall,
    output logic set_conflict,
    output logic req_in_stalled_valid,
    output logic [`MSHR_BITS_P1-1:0] mshr_cnt
    );

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            mshr_cnt <= `N_MSHR;
        // TODO: removed fill_reqs_flush check
        end else if (add_mshr_entry) begin
            mshr_cnt <= mshr_cnt - 1;
        end else if (incr_mshr_cnt) begin
            mshr_cnt <= mshr_cnt + 1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            evict_stall <= 1'b0;
        end else if (clr_evict_stall) begin
            evict_stall <= 1'b0;
        end else if (set_evict_stall) begin
            evict_stall <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            set_conflict <= 1'b0;
        end else if (clr_set_conflict) begin
            set_conflict <= 1'b0;
        end else if (set_set_conflict) begin
            set_conflict <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            req_in_stalled_valid <= 1'b0;
        end else if (clr_req_in_stalled_valid) begin
            req_in_stalled_valid <= 1'b0;
        end else if (set_req_in_stalled_valid) begin
            req_in_stalled_valid <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            ongoing_flush <= 1'b0;
        end else if (clr_ongoing_flush) begin
            ongoing_flush <= 1'b0;
        end else if (set_ongoing_flush) begin
            ongoing_flush <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            flush_set <= 0;
        end else if (clr_flush_set) begin
            flush_set <= 0;
        end else if (incr_flush_set) begin
            flush_set <= flush_set + 1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            flush_way <= 0;
        end else if (clr_flush_way) begin
            flush_way <= 0;
        end else if (incr_flush_way) begin
            flush_way <= flush_way + 1;
        end
    end


endmodule
