`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_core (
    input logic clk,
    input logic rst,
    input logic llc_req_in_valid,
    input logic llc_dma_req_in_valid,
    input logic llc_rsp_in_valid,
    input logic llc_mem_rsp_valid,
    input logic llc_rst_tb_i,
    input logic llc_rst_tb_valid,
    input logic llc_rsp_out_ready,
    input logic llc_dma_rsp_out_ready,
    input logic llc_fwd_out_ready,
    input logic llc_mem_req_ready,
    input logic llc_rst_tb_done_ready,

    llc_req_in_t.in llc_req_in_i,
    llc_dma_req_in_t.in llc_dma_req_in_i,
    llc_rsp_in_t.in llc_rsp_in_i,
    llc_mem_rsp_t.in llc_mem_rsp_i,

    output logic llc_dma_req_in_ready,
    output logic llc_req_in_ready,
    output logic llc_rsp_in_ready,
    output logic llc_mem_rsp_ready,
    output logic llc_rst_tb_ready,
    output logic llc_rsp_out_valid,
    output logic llc_dma_rsp_out_valid,
    output logic llc_fwd_out_valid,
    output logic llc_mem_req_valid,
    output logic llc_rst_tb_done_valid,
    output logic llc_rst_tb_done,

    llc_dma_rsp_out_t.out llc_dma_rsp_out,
    llc_rsp_out_t.out  llc_rsp_out,
    llc_fwd_out_t.out llc_fwd_out,
    llc_mem_req_t.out llc_mem_req
    );

    llc_req_in_t llc_req_in();
    llc_dma_req_in_t llc_dma_req_in();
    llc_rsp_in_t llc_rsp_in();
    llc_mem_rsp_t llc_mem_rsp();
    logic llc_rst_tb;

    //wires
    logic flush_stall, clr_flush_stall, set_flush_stall;
    logic llc_rsp_out_ready_int, llc_dma_rsp_out_ready_int, llc_fwd_out_ready_int, llc_mem_req_ready_int, llc_rst_tb_done_ready_int;

    //wires
    logic clr_rst_flush_stalled_set, incr_rst_flush_stalled_set;
    logic update_evict_way, set_update_evict_way, incr_evict_way_buf;
    logic is_rst_to_get, is_req_to_get, is_req_to_resume, is_dma_req_to_get, is_rsp_to_get;
    logic llc_req_in_ready_int, llc_dma_req_in_ready_int, llc_rsp_in_ready_int, llc_rst_tb_ready_int, llc_mem_rsp_ready_int;
    logic llc_req_in_valid_int, llc_dma_req_in_valid_int, llc_rsp_in_valid_int, llc_rst_tb_valid_int, llc_mem_rsp_valid_int;
    logic llc_rsp_out_valid_int, llc_dma_rsp_out_valid_int, llc_fwd_out_valid_int, llc_mem_req_valid_int, llc_rst_tb_done_valid_int;
    logic update_bufs_way, update_bufs_lines, update_bufs_tags, update_bufs_sharers, update_bufs_owners, update_bufs_hprot, update_bufs_dirty_bits, update_bufs_states;
    logic rd_en, wr_en, wr_en_evict_way, evict, evict_next;
    logic set_set_conflict_fsm, set_set_conflict_mshr, clr_set_conflict_fsm, clr_set_conflict_mshr;
    logic clr_evict_stall, set_evict_stall;
    logic set_conflict, evict_stall;
    logic decode_en, lookup_en;
    logic do_get_req, do_get_req_next, do_get_rsp, do_get_rsp_next;
    line_addr_t req_in_addr, rsp_in_addr, dma_req_in_addr, req_in_stalled_addr, req_in_recall_addr;
    logic update_req_in_stalled, update_req_in_from_stalled, set_req_in_stalled;
    logic req_in_stalled_valid, clr_req_in_stalled_valid, set_req_in_stalled_valid;
    logic set_req_from_conflict, set_req_conflict;

    logic lmem_wr_en_state, lmem_wr_en_line, lmem_wr_en_evict_way, lmem_wr_en_sharers, lmem_wr_en_owner, lmem_wr_en_dirty_bit, lmem_wr_en_all_mem;
    llc_set_t lmem_set_in;
    llc_way_t lmem_way_in;
    state_t lmem_wr_data_state;
    line_t lmem_wr_data_line;
    hprot_t lmem_wr_data_hprot;
    llc_tag_t lmem_wr_data_tag;
    llc_way_t lmem_wr_data_evict_way;
    sharers_t lmem_wr_data_sharers;
    owner_t lmem_wr_data_owner;
    logic lmem_wr_data_dirty_bit;

    logic lmem_rd_data_dirty_bit[`LLC_WAYS];
    hprot_t lmem_rd_data_hprot[`LLC_WAYS];
    line_t lmem_rd_data_line[`LLC_WAYS];
    llc_state_t lmem_rd_data_state[`LLC_WAYS];
    llc_tag_t lmem_rd_data_tag[`LLC_WAYS];
    llc_way_t lmem_rd_data_evict_way;
    sharers_t lmem_rd_data_sharers[`LLC_WAYS];
    owner_t lmem_rd_data_owner[`LLC_WAYS];

    logic [(`LLC_NUM_PORTS-1):0] lmem_wr_rst_flush;

    logic dirty_bits_buf[`LLC_WAYS];
    hprot_t hprots_buf[`LLC_WAYS];
    line_t lines_buf[`LLC_WAYS];
    llc_state_t states_buf[`LLC_WAYS];
    llc_tag_t tags_buf[`LLC_WAYS];
    llc_way_t evict_way_buf;
    sharers_t sharers_buf[`LLC_WAYS];
    owner_t owners_buf[`LLC_WAYS];

    logic update_bufs_data_dirty_bits;
    hprot_t update_bufs_data_hprot;
    line_t update_bufs_data_lines;
    llc_state_t update_bufs_data_states;
    llc_tag_t update_bufs_data_tags;
    sharers_t update_bufs_data_sharers;
    owner_t update_bufs_data_owners;

    logic add_mshr_entry, mshr_hit_next, mshr_hit;
    logic update_mshr_tag, update_mshr_way, update_mshr_state, update_mshr_invack_cnt, update_mshr_line, update_mshr_word_mask;
    logic [2:0] mshr_op_code;
    logic incr_mshr_cnt;
    mix_msg_t update_mshr_value_msg;
    cache_id_t update_mshr_value_req_id;
    llc_tag_t update_mshr_value_tag;
    llc_way_t update_mshr_value_way;
    unstable_state_t update_mshr_value_state;
    hprot_t update_mshr_value_hprot;
    invack_cnt_calc_t update_mshr_value_invack_cnt;
    line_t update_mshr_value_line;
    word_mask_t update_mshr_value_word_mask;
    word_mask_t update_mshr_value_word_mask_reg;
    logic [`MSHR_BITS-1:0] mshr_i_next, mshr_i;
    mshr_llc_buf_t mshr[`N_MSHR];
    logic [`MSHR_BITS_P1-1:0] mshr_cnt;

    logic rd_set_into_bufs;
    llc_way_t mem_rsp_way;

    logic lookup_mode;
    logic tag_hit;
    logic tag_hit_next;
    logic empty_way_found;
    logic empty_way_found_next;
    llc_way_t empty_way;
    llc_way_t empty_way_next;
    llc_way_t way_hit;
    llc_way_t way_hit_next;
    word_mask_t word_mask_owned;
    word_mask_t word_mask_owned_next;
    word_mask_t word_mask_owned_evict;
    word_mask_t word_mask_owned_evict_next;
    cache_id_t owners_cache_id[`WORDS_PER_LINE];
    cache_id_t owners_evict_cache_id[`WORDS_PER_LINE];

    assign llc_rst_tb_ready_int = 1'b1;
    assign llc_dma_req_in_ready_int = 1'b1;
    assign lmem_rd_en = 1'b1;
    assign set_set_conflict = set_set_conflict_fsm | set_set_conflict_mshr;
    assign clr_set_conflict = clr_set_conflict_fsm | clr_set_conflict_mshr;
    assign update_req_in_stalled = 1'b0;
    assign update_req_in_from_stalled = 1'b0;
    assign set_req_in_stalled = 1'b0;
    assign llc_rst_tb_done = 1'b0;
    assign lmem_wr_rst_flush = 'h0;

    //interfaces
    line_breakdown_llc_t line_br();
    line_breakdown_llc_t line_br_next();
    llc_dma_req_in_t llc_dma_req_in_next();
    llc_rsp_out_t llc_rsp_out_o();
    llc_dma_rsp_out_t llc_dma_rsp_out_o();
    llc_fwd_out_t llc_fwd_out_o();
    llc_mem_req_t llc_mem_req_o();
    llc_mem_rsp_t llc_mem_rsp_next();

    //instances
    llc_regs regs_u(.*);
    llc_input_decoder input_decoder_u(.*);
    llc_interfaces interfaces_u (.*);
    llc_localmem localmem_u(.*);
    llc_bufs bufs_u(.*);
    llc_lookup lookup_u(.*);
    llc_fsm fsm_u(.*);
    llc_mshr mshr_u(.*);

endmodule

// module llc_core (
//     input logic clk,
//     input logic rst,
//     input logic llc_req_in_valid,
//     input logic llc_dma_req_in_valid,
//     input logic llc_rsp_in_valid,
//     input logic llc_mem_rsp_valid,
//     input logic llc_rst_tb_i,
//     input logic llc_rst_tb_valid,
//     input logic llc_rsp_out_ready,
//     input logic llc_dma_rsp_out_ready,
//     input logic llc_fwd_out_ready,
//     input logic llc_mem_req_ready,
//     input logic llc_rst_tb_done_ready,

//     llc_req_in_t.in llc_req_in_i,
//     llc_dma_req_in_t.in llc_dma_req_in_i,
//     llc_rsp_in_t.in llc_rsp_in_i,
//     llc_mem_rsp_t.in llc_mem_rsp_i,

//     output logic llc_dma_req_in_ready,
//     output logic llc_req_in_ready,
//     output logic llc_rsp_in_ready,
//     output logic llc_mem_rsp_ready,
//     output logic llc_rst_tb_ready,
//     output logic llc_rsp_out_valid,
//     output logic llc_dma_rsp_out_valid,
//     output logic llc_fwd_out_valid,
//     output logic llc_mem_req_valid,
//     output logic llc_rst_tb_done_valid,
//     output logic llc_rst_tb_done,

//     llc_dma_rsp_out_t.out llc_dma_rsp_out,
//     llc_rsp_out_t.out  llc_rsp_out,
//     llc_fwd_out_t.out llc_fwd_out,
//     llc_mem_req_t.out llc_mem_req
//     );

//     llc_req_in_t llc_req_in();
//     llc_dma_req_in_t llc_dma_req_in();
//     llc_rsp_in_t llc_rsp_in();
//     llc_mem_rsp_t llc_mem_rsp();
//     logic llc_rst_tb;

//     //STATE MACHINE

//     localparam DECODE = 3'b000;
//     localparam READ_SET = 3'b001;
//     localparam READ_MEM = 3'b010;
//     localparam LOOKUP = 3'b011;
//     localparam PROCESS = 3'b100;
//     localparam UPDATE = 3'b101;

//     logic[2:0] state, next_state;
//     always_ff @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             state <= DECODE;
//         end else begin
//             state <= next_state;
//         end
//     end

//     //wires
//     logic process_done, idle, idle_next;
//     logic rst_stall, clr_rst_stall;
//     logic flush_stall, clr_flush_stall, set_flush_stall;
//     logic do_get_dma_req, is_flush_to_resume, is_rst_to_resume, is_rst_to_get_next, is_rsp_to_get_next, look;
//     logic llc_rsp_out_ready_int, llc_dma_rsp_out_ready_int, llc_fwd_out_ready_int, llc_mem_req_ready_int, llc_rst_tb_done_ready_int;

//     always_comb begin
//         next_state = state;
//         case(state)
//             DECODE :
//                 if (!idle_next) begin
//                     next_state = READ_SET;
//                 end
//             READ_SET :
//                 next_state = READ_MEM;
//             READ_MEM :
//                 next_state = LOOKUP;
//             LOOKUP :
//                 next_state = PROCESS;
//             PROCESS :
//                 if (process_done) begin
//                     next_state = UPDATE;
//                 end
//             UPDATE :
//                 if ((is_flush_to_resume || is_rst_to_resume) && !flush_stall && !rst_stall) begin
//                     if (llc_rst_tb_done_ready_int) begin
//                         next_state = DECODE;
//                     end
//                 end else begin
//                     next_state = DECODE;
//                 end
//             default :
//                 next_state = DECODE;
//        endcase
//     end

//     logic decode_en, rd_set_en, rd_mem_en, update_en, process_en, lookup_en;
//     assign decode_en = (state == DECODE);
//     assign rd_set_en = (state == READ_SET);
//     assign rd_mem_en = (state == READ_MEM);
//     assign lookup_en = (state == LOOKUP);
//     assign process_en = (state == PROCESS) | (state == LOOKUP);
//     assign update_en = (state == UPDATE);

//     //wires
//     logic req_stall, clr_req_stall_decoder, clr_req_stall_process, set_req_stall;
//     logic req_in_stalled_valid, clr_req_in_stalled_valid, set_req_in_stalled_valid;
//     logic clr_rst_flush_stalled_set, incr_rst_flush_stalled_set;
//     logic update_dma_addr_from_req, incr_dma_addr;
//     logic recall_pending, clr_recall_pending, set_recall_pending;
//     logic req_pending, set_req_pending, clr_req_pending;
//     logic dma_read_pending, clr_dma_read_pending, set_dma_read_pending;
//     logic dma_write_pending, clr_dma_write_pending, set_dma_write_pending;
//     logic recall_valid, clr_recall_valid, set_recall_valid, set_recall_evict_addr;
//     logic is_dma_read_to_resume, clr_is_dma_read_to_resume;
//     logic set_is_dma_read_to_resume_decoder, set_is_dma_read_to_resume_process;
//     logic is_dma_write_to_resume, clr_is_dma_write_to_resume;
//     logic set_is_dma_write_to_resume_decoder, set_is_dma_write_to_resume_process;
//     logic update_evict_way, set_update_evict_way, incr_evict_way_buf;
//     logic is_rst_to_get, is_req_to_get, is_req_to_resume, is_dma_req_to_get, is_rsp_to_get, do_get_req;
//     logic llc_req_in_ready_int, llc_dma_req_in_ready_int, llc_rsp_in_ready_int, llc_rst_tb_ready_int, llc_mem_rsp_ready_int;
//     logic llc_req_in_valid_int, llc_dma_req_in_valid_int, llc_rsp_in_valid_int, llc_rst_tb_valid_int, llc_mem_rsp_valid_int;
//     logic llc_rst_tb_done_o, rst_in, rst_state;
//     logic llc_rsp_out_valid_int, llc_dma_rsp_out_valid_int, llc_fwd_out_valid_int, llc_mem_req_valid_int, llc_rst_tb_done_valid_int;
//     logic wr_en_lines_buf, wr_en_tags_buf, wr_en_sharers_buf, wr_en_owners_buf, wr_en_hprots_buf, wr_en_dirty_bits_buf, wr_en_states_buf;
//     logic update_req_in_stalled, update_req_in_from_stalled, set_req_in_stalled;
//     logic rd_en, wr_en, wr_en_evict_way, evict, evict_next;
//     logic [(`LLC_NUM_PORTS-1):0] wr_rst_flush;

//     addr_t dma_addr;
//     line_addr_t addr_evict, recall_evict_addr;
//     line_addr_t req_in_addr, rsp_in_addr, dma_req_in_addr, req_in_stalled_addr, req_in_recall_addr;
//     llc_set_t rst_flush_stalled_set;
//     llc_set_t req_in_stalled_set;
//     llc_set_t set, set_next, set_in;
//     llc_tag_t req_in_stalled_tag, tag;
//     llc_way_t way, way_next;

//     logic wr_data_dirty_bit;
//     hprot_t wr_data_hprot;
//     line_t wr_data_line;
//     llc_state_t wr_data_state;
//     llc_tag_t wr_data_tag;
//     llc_way_t wr_data_evict_way;
//     sharers_t wr_data_sharers;
//     owner_t wr_data_owner;

//     logic rd_data_dirty_bit[`LLC_WAYS];
//     hprot_t rd_data_hprot[`LLC_WAYS];
//     line_t rd_data_line[`LLC_WAYS];
//     llc_state_t rd_data_state[`LLC_WAYS];
//     llc_tag_t rd_data_tag[`LLC_WAYS];
//     llc_way_t rd_data_evict_way;
//     sharers_t rd_data_sharers[`LLC_WAYS];
//     owner_t rd_data_owner[`LLC_WAYS];

//     logic dirty_bits_buf[`LLC_WAYS];
//     hprot_t hprots_buf[`LLC_WAYS];
//     line_t lines_buf[`LLC_WAYS];
//     llc_state_t states_buf[`LLC_WAYS];
//     llc_tag_t tags_buf[`LLC_WAYS];
//     llc_way_t evict_way_buf;
//     sharers_t sharers_buf[`LLC_WAYS];
//     owner_t owners_buf[`LLC_WAYS];

//     logic dirty_bits_buf_wr_data;
//     hprot_t hprots_buf_wr_data;
//     line_t lines_buf_wr_data;
//     llc_state_t states_buf_wr_data;
//     llc_tag_t tags_buf_wr_data;
//     sharers_t sharers_buf_wr_data;
//     owner_t owners_buf_wr_data;

//     assign set_in = rd_set_en ? set_next : set;
//     assign llc_rsp_in_ready_int = decode_en & is_rsp_to_get_next;
//     assign llc_rst_tb_ready_int = decode_en & is_rst_to_get_next;
//     assign llc_req_in_ready_int = decode_en & do_get_req;
//     assign llc_dma_req_in_ready_int = decode_en & do_get_dma_req;
//     assign rd_en = !idle;
//     assign tag = line_br.tag;

//     //interfaces
//     line_breakdown_llc_t line_br();
//     llc_dma_req_in_t llc_dma_req_in_next();
//     llc_rsp_out_t llc_rsp_out_o();
//     llc_dma_rsp_out_t llc_dma_rsp_out_o();
//     llc_fwd_out_t llc_fwd_out_o();
//     llc_mem_req_t llc_mem_req_o();
//     llc_mem_rsp_t llc_mem_rsp_next();

//     //instances
//     llc_regs regs_u(.*);
//     llc_input_decoder input_decoder_u(.*);
//     llc_interfaces interfaces_u (.*);
//     llc_localmem localmem_u(.*);
//     llc_update update_u (.*);
//     llc_bufs bufs_u(.*);
//     llc_lookup lookup_u(.*);
//     llc_fsm fsm_u(.*);

// endmodule
