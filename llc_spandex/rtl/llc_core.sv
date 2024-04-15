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

    logic ongoing_flush, set_ongoing_flush, clr_ongoing_flush;
    logic incr_flush_way, incr_flush_set, clr_flush_set, clr_flush_way;
    logic do_flush, do_flush_next;
    logic [`LLC_SET_BITS:0] flush_set;
    logic [`LLC_WAY_BITS:0] flush_way;
    logic llc_rst_tb_done_o;

    logic clr_ongoing_bulk_req, set_ongoing_bulk_req, incr_bulk_done, clr_bulk_done, set_req_from_bulk, set_req_bulk;
    logic new_bulk_req, ongoing_bulk_req, do_bulk_req, do_bulk_req_next, incr_bulk_nack_counter, clr_bulk_nack_counter;
    addr_t llc_bulk_len_int, bulk_done, bulk_nack_counter;
    logic set_req_bulk_addr;
    line_addr_t set_req_bulk_addr_data;

    assign llc_dma_req_in_ready_int = 1'b1;
    assign lmem_rd_en = 1'b1;
    assign set_set_conflict = set_set_conflict_fsm | set_set_conflict_mshr;
    assign clr_set_conflict = clr_set_conflict_fsm | clr_set_conflict_mshr;
    assign update_req_in_stalled = 1'b0;
    assign update_req_in_from_stalled = 1'b0;
    assign set_req_in_stalled = 1'b0;
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
`ifdef XILINX_FPGA
    llc_localmem localmem_u(.*);
`endif
`ifdef ASIC
    llc_localmem_asic localmem_u(.*);
`endif
    llc_bufs bufs_u(.*);
    llc_lookup lookup_u(.*);
    llc_fsm fsm_u(.*);
    llc_mshr mshr_u(.*);

endmodule
