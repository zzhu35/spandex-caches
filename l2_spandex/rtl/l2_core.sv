`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_core(
    input logic clk,
    input logic rst,
    input logic l2_cpu_req_valid,
    input logic l2_fwd_in_valid,
    input logic l2_rsp_in_valid,
    input logic l2_req_out_ready,
    input logic l2_rsp_out_ready,
    input logic l2_fwd_out_ready,
    input logic l2_rd_rsp_ready,
    input logic l2_flush_valid,
    input logic l2_flush_i,
    input logic l2_fence_valid,
    input fence_t l2_fence_i,
    input logic l2_inval_ready,
    input logic l2_bresp_ready,

    l2_cpu_req_t.in l2_cpu_req_i,
    l2_fwd_in_t.in l2_fwd_in_i,
    l2_rsp_in_t.in l2_rsp_in_i,

    output logic l2_cpu_req_ready,
    output logic l2_fwd_in_ready,
    output logic l2_rsp_in_ready,
    output logic l2_req_out_valid,
    output logic l2_rsp_out_valid,
    output logic l2_fwd_out_valid,
    output logic l2_rd_rsp_valid,
    output logic l2_flush_ready,
    output logic l2_fence_ready,
    output logic l2_inval_valid,
    output logic flush_done,
    output logic acc_flush_done,
    output logic l2_bresp_valid,
    output bresp_t l2_bresp,

    l2_req_out_t.out l2_req_out,
    l2_rsp_out_t.out l2_rsp_out,
    l2_fwd_out_t.out l2_fwd_out,
    l2_rd_rsp_t.out l2_rd_rsp,
    l2_inval_t.out l2_inval
    );

    //interfaces
    l2_cpu_req_t l2_cpu_req();
    l2_fwd_in_t l2_fwd_in();
    l2_rsp_in_t l2_rsp_in();
    l2_rsp_out_t l2_rsp_out_o();
    l2_fwd_out_t l2_fwd_out_o();
    l2_req_out_t l2_req_out_o();
    l2_rd_rsp_t l2_rd_rsp_o();
    l2_inval_t l2_inval_o();
    line_breakdown_l2_t line_br(), line_br_next();
    addr_breakdown_t addr_br(), addr_br_next(), addr_br_reqs();

    //wires
    logic l2_cpu_req_ready_int, l2_fwd_in_ready_int, l2_rsp_in_ready_int, l2_flush_ready_int;
    logic l2_rsp_out_ready_int, l2_req_out_ready_int, l2_inval_ready_int, l2_rd_rsp_ready_int;
    logic l2_cpu_req_valid_int, l2_fwd_in_valid_int, l2_rsp_in_valid_int, l2_flush_valid_int;
    logic l2_rsp_out_valid_int, l2_req_out_valid_int, l2_inval_valid_int, l2_rd_rsp_valid_int;
    logic l2_bresp_valid_int, l2_bresp_ready_int;
    logic l2_fwd_out_valid_int, l2_fwd_out_ready_int, l2_fence_valid_int, l2_fence_ready_int;
    logic decode_en, lookup_en, rd_set_into_bufs;
    logic fwd_stall, fwd_stall_ended, ongoing_flush, set_conflict, evict_stall, ongoing_atomic, idle;
    logic set_cpu_req_conflict, set_fwd_in_stalled;
    logic do_flush, do_rsp, do_fwd, do_ongoing_flush, do_cpu_req;
    logic set_ongoing_flush, clr_ongoing_flush, set_cpu_req_from_conflict, set_fwd_in_from_stalled;
    logic set_ongoing_atomic, clr_ongoing_atomic, set_set_conflict, clr_set_conflict;
    logic incr_flush_way, incr_flush_set, clr_flush_set, clr_flush_way;
    logic do_flush_next, do_rsp_next, do_fwd_next, do_ongoing_flush_next, do_cpu_req_next;
    logic set_set_conflict_fsm, set_set_conflict_mshr, clr_set_conflict_fsm, clr_set_conflict_mshr;
    logic set_fwd_stall, clr_fwd_stall, set_fwd_stall_entry, clr_reqs_cnt, incr_mshr_cnt, clr_fwd_stall_ended;
    logic clr_evict_stall, set_evict_stall, incr_evict_way_buf;
    logic clr_flush_stall_ended, set_flush_stall_ended, flush_stall_ended, is_flush_all;
    logic lookup_mode, tag_hit, empty_way_found, tag_hit_next, empty_way_found_next;
    logic add_mshr_entry, add_mshr_entry_flush, mshr_hit, mshr_hit_next, update_mshr_state, update_mshr_line;
    logic update_mshr_tag, lmem_wr_en_clear_mshr, update_mshr_state_atomic, put_reqs_atomic;
    logic lmem_wr_rst, lmem_wr_en_state, lmem_wr_en_line, lmem_wr_en_evict_way, lmem_rd_en;
    logic ongoing_atomic_set_conflict_instr, set_ongoing_atomic_set_conflict_instr, clr_ongoing_atomic_set_conflict_instr;
    logic [2:0] mshr_op_code;
    logic [`L2_SET_BITS:0] flush_set;
    logic [`L2_WAY_BITS:0] flush_way;
    logic [`MSHR_BITS-1:0] mshr_i, set_fwd_stall_entry_data, fwd_stall_entry, mshr_i_next, reqs_atomic_i;
    logic [`MSHR_BITS_P1-1:0] mshr_cnt;
    logic update_mshr_word_mask;

    addr_t cpu_req_addr;
    mix_msg_t fwd_in_coh_msg;
    bresp_t l2_bresp_o;
    l2_set_t lmem_set_in;
    l2_way_t empty_way, empty_way_next, way_hit, way_hit_next, lmem_way_in;
    l2_way_t lmem_wr_data_evict_way, lmem_rd_data_evict_way, evict_way_buf;
    line_addr_t rsp_in_addr, fwd_in_addr, fwd_in_tmp_addr;
    mshr_buf_t mshr[`N_MSHR];
    word_mask_t word_mask_shared, word_mask_owned, word_mask_shared_next, word_mask_owned_next;
    word_mask_t word_mask_owned_evict, word_mask_owned_evict_next, word_mask_valid, word_mask_valid_next;
    logic word_hit, word_hit_next;
    state_t word_hit_state, word_hit_state_next;

    byte_offset_t write_word_b_off_in;
    hsize_t write_word_hsize_in;
    line_t write_word_line_in, write_word_line_out;
    word_t write_word_word_in;
    word_offset_t write_word_w_off_in;

    byte_offset_t write_word_amo_b_off_in;
    hsize_t write_word_amo_hsize_in;
    line_t write_word_amo_line_in, write_word_amo_line_out;
    word_t write_word_amo_word_in;
    word_offset_t write_word_amo_w_off_in;
    amo_t write_word_amo_amo_in;

    line_t lines_buf[`L2_WAYS];
    l2_tag_t tags_buf[`L2_WAYS];
    hprot_t hprots_buf[`L2_WAYS];
    state_t states_buf[`L2_WAYS][`WORDS_PER_LINE];

    state_t lmem_wr_data_state[`WORDS_PER_LINE], lmem_rd_data_state[`L2_WAYS][`WORDS_PER_LINE];
    line_t lmem_wr_data_line, lmem_rd_data_line[`L2_WAYS];
    hprot_t lmem_wr_data_hprot, lmem_rd_data_hprot[`L2_WAYS];
    l2_tag_t lmem_wr_data_tag, lmem_rd_data_tag[`L2_WAYS];

    cpu_msg_t update_mshr_value_cpu_msg;
    l2_tag_t update_mshr_value_tag;
    hsize_t update_mshr_value_hsize;
    unstable_state_t update_mshr_value_state;
    l2_way_t update_mshr_value_way;
    hprot_t update_mshr_value_hprot;
    word_t update_mshr_value_word;
    line_t update_mshr_value_line;
    amo_t update_mshr_value_amo;
    word_mask_t update_mshr_value_word_mask;
    word_mask_t update_mshr_value_word_mask_reg;

    fence_t l2_fence;
    logic ongoing_fence, mshr_write_pending, clr_ongoing_fence, set_ongoing_fence;
    logic ongoing_drain, clr_ongoing_drain, set_ongoing_drain;
    logic do_fence, do_fence_next, do_ongoing_fence, do_ongoing_fence_next;

`ifdef USE_WB
    logic do_ongoing_drain, do_ongoing_drain_next;
    logic wb_hit_next, wb_hit, wb_empty_next, wb_empty, wb_valid_next, wb_valid;
    logic [`WB_BITS-1:0] wb_hit_i_next, wb_hit_i, wb_empty_i_next, wb_empty_i, wb_valid_i_next, wb_valid_i;
    logic [`WB_BITS-1:0] wb_evict_buf;
    logic mshr_drain_conflict, add_wb_entry, clear_wb_entry;
    logic update_wb_way, update_wb_line, update_wb_hprot, update_wb_word_mask;
    logic update_wb_dcs_en, update_wb_dcs, update_wb_use_owner_pred, update_wb_pred_cid;
    logic wb_op_code;
    l2_way_t update_wb_value_way;
    line_t update_wb_value_line;
    hprot_t update_wb_value_hprot;
    word_mask_t update_wb_value_word_mask;
    logic update_wb_value_dcs_en;
    dcs_t update_wb_value_dcs;
    logic update_wb_value_use_owner_pred;
    cache_id_t update_wb_value_pred_cid;
    l2_tag_t wb_dispatch_tag;
    l2_set_t wb_dispatch_set;
    logic [`WB_BITS_P1-1:0] wb_cnt;
    wb_buf_t wb[`N_WB];
`endif

    assign clr_flush_stall_ended = 1'b0;
    assign set_flush_stall_ended = 1'b0;
    assign flush_stall_ended = 1'b0;
    assign ongoing_atomic_set_conflict_instr = 1'b0;
    assign set_ongoing_atomic_set_conflict_instr = 1'b0;
    assign clr_ongoing_atomic_set_conflict_instr = 1'b0;

    assign set_set_conflict = set_set_conflict_fsm | set_set_conflict_mshr;
    assign clr_set_conflict = clr_set_conflict_fsm | clr_set_conflict_mshr;
    assign fwd_in_coh_msg = l2_fwd_in.coh_msg;
    assign lmem_rd_en = 1'b1;

    //instances
    l2_bufs bufs_u(.*);
    l2_fsm fsm_u(.*);
    l2_interfaces interfaces_u(.*);
    l2_input_decoder decode_u (.*);
`ifdef XILINX_FPGA
    l2_localmem localmem_u (.*);
`endif
`ifdef GF12
    l2_localmem_gf12 localmem_u(.*);
`endif
    l2_lookup lookup_u(.*);
    l2_regs regs_u (.*);
    l2_mshr mshr_u (.*);
    l2_write_word write_word_u(.*);
    l2_write_word_amo write_word_amo_u(.*);
`ifdef USE_WB
    l2_wb wb_u (.*);
`endif

endmodule
