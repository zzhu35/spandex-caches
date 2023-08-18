`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"
// TODO: Removed evict_way related code.
module l2_bufs (
    input logic clk,
    input logic rst,
    // Command to read into bufs
    input logic rd_set_into_bufs,
    // Values from localmem
    input line_t lmem_rd_data_line[`L2_WAYS],
    input l2_tag_t lmem_rd_data_tag[`L2_WAYS],
    input hprot_t lmem_rd_data_hprot[`L2_WAYS],
    input state_t lmem_rd_data_state[`L2_WAYS][`WORDS_PER_LINE],
    // Bufs that are loaded for use in FSM
    output line_t lines_buf[`L2_WAYS],
    output l2_tag_t tags_buf[`L2_WAYS],
    output hprot_t hprots_buf[`L2_WAYS],
    output state_t states_buf[`L2_WAYS][`WORDS_PER_LINE]
    );
    // Read all data of a set from the registers populated
    // by localmem into bufs registers that is used in the FSM.
    genvar i, j;
    generate
        for (i = 0; i < `L2_WAYS; i++) begin
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    lines_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    lines_buf[i] <= lmem_rd_data_line[i];
                end
            end
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    tags_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    tags_buf[i] <= lmem_rd_data_tag[i];
                end
            end
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    hprots_buf[i] <= 0;
                end else if (rd_set_into_bufs) begin
                    hprots_buf[i] <= lmem_rd_data_hprot[i];
                end
            end
            for (j = 0; j < `WORDS_PER_LINE; j++) begin
                always_ff @(posedge clk or negedge rst) begin
                    if (!rst) begin
                        states_buf[i][j] <= 0;
                    end else if (rd_set_into_bufs) begin
                        states_buf[i][j] <= lmem_rd_data_state[i][j];
                    end
                end
            end
        end
    endgenerate
endmodule
// module l2_bufs(
//     input logic clk,
//     input logic rst,
//     input logic rd_mem_en,
//     input l2_way_t way,
//     input var line_t rd_data_line[`L2_WAYS],
//     input var l2_tag_t rd_data_tag[`L2_WAYS],
//     input var hprot_t rd_data_hprot[`L2_WAYS],
//     input l2_way_t rd_data_evict_way,
//     input var state_t rd_data_state[`L2_WAYS],
//     output l2_way_t evict_way_buf,
//     output line_t lines_buf[`L2_WAYS],
//     output l2_tag_t tags_buf[`L2_WAYS],
//     output hprot_t hprots_buf[`L2_WAYS],
//     output state_t states_buf[`L2_WAYS]
//     );
   
//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             evict_way_buf <= 0;
//         end else if (rd_mem_en) begin
//             evict_way_buf <= rd_data_evict_way;
//         end
//     end
//     genvar i;
//     generate
//         for (i = 0; i < `L2_WAYS; i++) begin
//             always_ff @(posedge clk or negedge rst) begin
//                 if (!rst) begin
//                     lines_buf[i] <= 0;
//                 end else if (rd_mem_en) begin
//                     lines_buf[i] <= rd_data_line[i];
//                 end
//             end
//             always_ff @(posedge clk or negedge rst) begin
//                 if (!rst) begin
//                     tags_buf[i] <= 0;
//                 end else if (rd_mem_en) begin 
//                     tags_buf[i] <= rd_data_tag[i];
//                 end
//             end
//             always_ff @(posedge clk or negedge rst) begin       
//                 if (!rst) begin
//                     hprots_buf[i] <= 0;
//                 end else if (rd_mem_en) begin
//                     hprots_buf[i] <= rd_data_hprot[i];
//                 end
//             end
//             always_ff @(posedge clk or negedge rst) begin
//                 if (!rst) begin
//                     states_buf[i] <= 0;
//                 end else if (rd_mem_en) begin
//                     states_buf[i] <= rd_data_state[i];
//                 end
//             end
//         end
//     endgenerate
// endmodule