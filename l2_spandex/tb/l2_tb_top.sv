`timescale 1ps / 1ps
`include "cache_consts.svh"
`include "cache_types.svh"

module l2_tb_top;

logic clk;
logic rst;
logic l2_cpu_req_valid;
cpu_msg_t l2_cpu_req_data_cpu_msg;
hsize_t l2_cpu_req_data_hsize;
logic[1:0] l2_cpu_req_data_hprot;
addr_t l2_cpu_req_data_addr;
word_t l2_cpu_req_data_word;
amo_t l2_cpu_req_data_amo;
logic l2_fwd_in_valid;
mix_msg_t l2_fwd_in_data_coh_msg;
line_addr_t l2_fwd_in_data_addr;
cache_id_t l2_fwd_in_data_req_id;
logic l2_rsp_in_valid;
coh_msg_t l2_rsp_in_data_coh_msg;
line_addr_t l2_rsp_in_data_addr;
line_t l2_rsp_in_data_line;
invack_cnt_t l2_rsp_in_data_invack_cnt;
logic l2_req_out_ready;
logic l2_rsp_out_ready;
logic l2_rd_rsp_ready;
logic l2_flush_valid;
logic l2_flush_data;
logic l2_inval_ready;
logic l2_stats_ready;
logic l2_bresp_ready;

logic l2_cpu_req_ready;
logic l2_fwd_in_ready;
logic l2_rsp_in_ready;
logic l2_req_out_valid;
coh_msg_t l2_req_out_data_coh_msg;
logic[1:0] l2_req_out_data_hprot;
line_addr_t l2_req_out_data_addr;
line_t l2_req_out_data_line;
logic l2_rsp_out_valid;
coh_msg_t l2_rsp_out_data_coh_msg;
cache_id_t l2_rsp_out_data_req_id;
logic[1:0] l2_rsp_out_data_to_req;
line_addr_t l2_rsp_out_data_addr;
line_t l2_rsp_out_data_line;
logic l2_rd_rsp_valid;
line_t l2_rd_rsp_data_line;
logic l2_flush_ready;
logic l2_inval_valid;
l2_inval_addr_t l2_inval_data_addr;
logic[1:0] l2_inval_data_hprot;
logic l2_stats_valid;
logic l2_stats_data;
logic flush_done;
logic l2_bresp_valid;
bresp_t l2_bresp_data;

// l2_cpu_req_t l2_cpu_req_i();
// assign l2_cpu_req_i.cpu_msg = l2_cpu_req_data_cpu_msg;
// assign l2_cpu_req_i.hsize = l2_cpu_req_data_hsize;
// assign l2_cpu_req_i.hprot = l2_cpu_req_data_hprot[0];
// assign l2_cpu_req_i.addr = l2_cpu_req_data_addr;
// assign l2_cpu_req_i.word = l2_cpu_req_data_word;
// assign l2_cpu_req_i.amo = l2_cpu_req_data_amo;

// l2_fwd_in_t l2_fwd_in_i();
// assign l2_fwd_in_i.coh_msg = l2_fwd_in_data_coh_msg;
// assign l2_fwd_in_i.addr = l2_fwd_in_data_addr;
// assign l2_fwd_in_i.req_id = l2_fwd_in_data_req_id;

// l2_rsp_in_t l2_rsp_in_i();
// assign l2_rsp_in_i.coh_msg = l2_rsp_in_data_coh_msg;
// assign l2_rsp_in_i.addr = l2_rsp_in_data_addr;
// assign l2_rsp_in_i.line = l2_rsp_in_data_line;
// assign l2_rsp_in_i.invack_cnt = l2_rsp_in_data_invack_cnt;

// l2_req_out_t l2_req_out();
// assign l2_req_out_data_coh_msg = l2_req_out.coh_msg;
// assign l2_req_out_data_hprot = {1'b0,  l2_req_out.hprot};
// assign l2_req_out_data_addr = l2_req_out.addr;
// assign l2_req_out_data_line = l2_req_out.line;

// l2_rsp_out_t l2_rsp_out();
// assign l2_rsp_out_data_coh_msg = l2_rsp_out.coh_msg;
// assign l2_rsp_out_data_req_id = l2_rsp_out.req_id;
// assign l2_rsp_out_data_to_req = l2_rsp_out.to_req;
// assign l2_rsp_out_data_addr = l2_rsp_out.addr;
// assign l2_rsp_out_data_line = l2_rsp_out.line;

// l2_rd_rsp_t l2_rd_rsp();
// assign l2_rd_rsp_data_line = l2_rd_rsp.line;

// logic l2_flush_i;
// assign l2_flush_i = l2_flush_data;

// l2_inval_t l2_inval();
// assign l2_inval_data_addr = l2_inval.addr;
// assign l2_inval_data_hprot = {1'b0, l2_inval.hprot};

// bresp_t l2_bresp;
// assign l2_bresp_data = l2_bresp;

// `ifdef STATS_ENABLE
// logic l2_stats;
// assign l2_stats_data = l2_stats;
// `endif

l2_rtl_top l2_top_u(.*);

endmodule

