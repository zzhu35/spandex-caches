`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_regs (
    input logic clk,
    input logic rst,
    // TODO: signals related to set_conflict, fwd_stall,
    // flush and ongoing_atomic removed temporarily.
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
    // Entry in MSHR that corresponds to fwd_stall
    input logic set_fwd_stall_entry,
    input logic [`MSHR_BITS-1:0] set_fwd_stall_entry_data,
    // Registers
    output logic evict_stall,
    output logic set_conflict,
    output logic fwd_stall,
    output logic fwd_stall_ended,
    output logic [`MSHR_BITS-1:0] fwd_stall_entry,
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

    // TODO: add global register for set_conflict, fwd_stall,
    // flush and ongoing_atomic.

endmodule

// module l2_regs (
//     input logic clk,
//     input logic rst,
//     input logic set_ongoing_flush,
//     input logic clr_ongoing_flush,
//     input logic incr_flush_set,
//     input logic clr_flush_set,
//     input logic incr_flush_way,
//     input logic clr_flush_way,
//     input logic set_set_conflict,
//     input logic clr_set_conflict,
//     input logic set_fwd_stall,
//     input logic clr_fwd_stall,
//     input logic set_fwd_stall_i,
//     input logic fill_reqs,
//     input logic incr_reqs_cnt,
//     input logic fill_reqs_flush,
//     input logic clr_fwd_stall_ended,
//     input logic wr_en_put_reqs,
//     input logic put_reqs_atomic,
//     input logic clr_ongoing_atomic,
//     input logic set_ongoing_atomic,
//     input logic clr_evict_stall,
//     input logic set_evict_stall,
//     input logic lr_to_xmw,
//     input logic [`REQS_BITS-1:0] reqs_atomic_i,
//     input logic [`REQS_BITS-1:0] reqs_i,
//     input logic [`REQS_BITS-1:0] fwd_stall_i_wr_data,

//     output logic ongoing_flush,
//     output logic set_conflict,
//     output logic fwd_stall,
//     output logic fwd_stall_ended,
//     output logic ongoing_atomic,
//     output logic evict_stall,
//     output logic [`L2_SET_BITS:0] flush_set,
//     output logic [`L2_WAY_BITS:0] flush_way,
//     output logic [`REQS_BITS-1:0] fwd_stall_i,
//     output logic [`REQS_BITS_P1-1:0] reqs_cnt
//     );

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             ongoing_flush <= 1'b0;
//         end else if (clr_ongoing_flush) begin
//             ongoing_flush <= 1'b0;
//         end else if (set_ongoing_flush) begin
//             ongoing_flush <= 1'b1;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             flush_set <= 0;
//         end else if (clr_flush_set) begin
//             flush_set <= 0;
//         end else if (incr_flush_set) begin
//             flush_set <= flush_set + 1;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             flush_way <= 0;
//         end else if (clr_flush_way) begin
//             flush_way <= 0;
//         end else if (incr_flush_way) begin
//             flush_way <= flush_way + 1;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             set_conflict <= 1'b0;
//         end else if (clr_set_conflict) begin
//             set_conflict <= 1'b0;
//         end else if (set_set_conflict) begin
//             set_conflict <= 1'b1;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             fwd_stall <= 1'b0;
//         end else if (clr_fwd_stall) begin
//             fwd_stall <= 1'b0;
//         end else if (set_fwd_stall) begin
//             fwd_stall <= 1'b1;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             fwd_stall_i <= 0;
//         end else if (set_fwd_stall_i) begin
//             fwd_stall_i <= fwd_stall_i_wr_data;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             reqs_cnt <= `N_REQS;
//         end else if (fill_reqs || fill_reqs_flush) begin
//             reqs_cnt <= reqs_cnt - 1;
//         end else if (incr_reqs_cnt) begin
//             reqs_cnt <= reqs_cnt + 1;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             fwd_stall_ended <= 1'b0;
//         end else if (clr_fwd_stall_ended) begin
//             fwd_stall_ended <= 1'b0;
//         end else if ((wr_en_put_reqs && fwd_stall && (fwd_stall_i == reqs_i
//                     || (put_reqs_atomic  && fwd_stall_i == reqs_atomic_i)))) begin
//             fwd_stall_ended <= 1'b1;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             ongoing_atomic <= 1'b0;
//         end else if (clr_ongoing_atomic) begin
//             ongoing_atomic <= 1'b0;
//         end else if (set_ongoing_atomic) begin
//             ongoing_atomic <= 1'b1;
//         end
//     end

//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             evict_stall <= 1'b0;
//         end else if (clr_evict_stall) begin
//             evict_stall <= 1'b0;
//         end else if (set_evict_stall) begin
//             evict_stall <= 1'b1;
//         end
//     end

// endmodule

