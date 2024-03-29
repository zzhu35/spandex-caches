`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_regs (
    input logic clk,
    input logic rst,
    input logic add_mshr_entry,
    input logic incr_mshr_cnt,
    input logic [`MSHR_BITS-1:0] mshr_i,
    // Triggers to assign to registers
    input logic clr_evict_stall,
    input logic set_evict_stall,
    input logic set_set_conflict,
    input logic clr_set_conflict,
    input logic set_fwd_stall,
    input logic clr_fwd_stall,
    input logic clr_fwd_stall_ended,
    input logic clr_ongoing_fence,
    input logic set_ongoing_fence,
    input logic clr_ongoing_drain,
    input logic set_ongoing_drain,
    input logic clr_ongoing_atomic,
    input logic set_ongoing_atomic,
    input logic set_ongoing_flush,
    input logic clr_ongoing_flush,
    input logic set_ongoing_read_bulk_req,
    input logic set_ongoing_write_bulk_req,
    input logic clr_ongoing_bulk_req,
    input logic incr_bulk_done_1,
    input logic incr_bulk_done_2,
    input logic decr_bulk_done_1,
    input logic decr_bulk_done_2,
    input logic clr_bulk_done,
    input logic incr_flush_set,
    input logic clr_flush_set,
    input logic incr_flush_way,
    input logic clr_flush_way,
    input logic lmem_wr_en_clear_mshr,
    // Entry in MSHR that corresponds to fwd_stall
    input logic set_fwd_stall_entry,
    input logic [`MSHR_BITS-1:0] set_fwd_stall_entry_data,
`ifdef USE_WB
    input logic add_wb_entry,
    input logic wb_hit,
    input logic clear_wb_entry,
`endif

    // Registers
    output logic evict_stall,
    output logic set_conflict,
    output logic fwd_stall,
    output logic fwd_stall_ended,
    output logic ongoing_fence,
    output logic ongoing_drain,
    output logic ongoing_atomic,
    output logic ongoing_flush,
    output logic ongoing_read_bulk_req,
    output logic ongoing_write_bulk_req,
    output addr_t bulk_done,
    output logic [`L2_SET_BITS:0] flush_set,
    output logic [`L2_WAY_BITS:0] flush_way,
    output logic [`MSHR_BITS-1:0] fwd_stall_entry,
`ifdef USE_WB
    output logic [`WB_BITS_P1-1:0] wb_cnt,
    output logic [`WB_BITS-1:0] wb_evict_buf,
`endif
    output logic [`MSHR_BITS_P1-1:0] mshr_cnt
    );

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            mshr_cnt <= `N_MSHR;
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
            fwd_stall <= 1'b0;
        end else if (clr_fwd_stall) begin
            fwd_stall <= 1'b0;
        end else if (set_fwd_stall) begin
            fwd_stall <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            fwd_stall_entry <= 0;
        end else if (set_fwd_stall_entry) begin
            fwd_stall_entry <= set_fwd_stall_entry_data;
        end
    end

    // fwd_stall is only if lifted when the original pending response
    // received, whose MSHR entry cause the fwd to stall.
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            fwd_stall_ended <= 1'b0;
        end else if (clr_fwd_stall_ended) begin
            fwd_stall_ended <= 1'b0;
        end else if (incr_mshr_cnt && fwd_stall && (fwd_stall_entry == mshr_i)) begin
            fwd_stall_ended <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            ongoing_fence <= 1'b0;
        end else if (clr_ongoing_fence) begin
            ongoing_fence <= 1'b0;
        end else if (set_ongoing_fence) begin
            ongoing_fence <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            ongoing_drain <= 1'b0;
        end else if (clr_ongoing_drain) begin
            ongoing_drain <= 1'b0;
        end else if (set_ongoing_drain) begin
            ongoing_drain <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            ongoing_atomic <= 1'b0;
        end else if (clr_ongoing_atomic) begin
            ongoing_atomic <= 1'b0;
        end else if (set_ongoing_atomic) begin
            ongoing_atomic <= 1'b1;
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

`ifdef USE_WB
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            wb_cnt <= `N_WB;
        end else if (add_wb_entry && !wb_hit) begin
            wb_cnt <= wb_cnt - 1;
        end else if (clear_wb_entry) begin
            wb_cnt <= wb_cnt + 1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            wb_evict_buf <= `N_WB-1;
        end else if (clear_wb_entry && !ongoing_drain) begin
            wb_evict_buf <= wb_evict_buf + 1;
        end
    end
`endif

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            ongoing_read_bulk_req <= 1'b0;
            ongoing_write_bulk_req <= 1'b0;
        end else if (clr_ongoing_bulk_req) begin
            ongoing_read_bulk_req <= 1'b0;
            ongoing_write_bulk_req <= 1'b0;
        end else if (set_ongoing_read_bulk_req) begin
            ongoing_read_bulk_req <= 1'b1;
        end else if (set_ongoing_write_bulk_req) begin
            ongoing_write_bulk_req <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            bulk_done <= 0;
        end else if (clr_bulk_done) begin
            bulk_done <= 0;
        end else if (incr_bulk_done_1) begin
            bulk_done <= bulk_done + 1;
        end else if (incr_bulk_done_2) begin
            bulk_done <= bulk_done + 2;
        end else if (decr_bulk_done_1) begin
            bulk_done <= bulk_done - 1;
        end else if (decr_bulk_done_2) begin
            bulk_done <= bulk_done - 2;
        end
    end

endmodule
