`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_spandex_rtl_top(
    `FPGA_DBG input logic clk,
    `FPGA_DBG input logic rst,
    `FPGA_DBG input logic l2_cpu_req_valid,
    `FPGA_DBG input cpu_msg_t l2_cpu_req_data_cpu_msg,
    `FPGA_DBG input hsize_t l2_cpu_req_data_hsize,
    `FPGA_DBG input logic[1:0] l2_cpu_req_data_hprot,
    `FPGA_DBG input addr_t l2_cpu_req_data_addr,
    `FPGA_DBG input word_t l2_cpu_req_data_word,
    `FPGA_DBG input amo_t l2_cpu_req_data_amo,
    `FPGA_DBG input logic l2_cpu_req_data_aq,
    `FPGA_DBG input logic l2_cpu_req_data_rl,
    `FPGA_DBG input logic l2_cpu_req_data_dcs_en,
    `FPGA_DBG input logic l2_cpu_req_data_use_owner_pred,
    `FPGA_DBG input dcs_t l2_cpu_req_data_dcs,
    `FPGA_DBG input cache_id_t l2_cpu_req_data_pred_cid,
    `FPGA_DBG input logic l2_fwd_in_valid,
    `FPGA_DBG input mix_msg_t l2_fwd_in_data_coh_msg,
    `FPGA_DBG input line_addr_t l2_fwd_in_data_addr,
    `FPGA_DBG input cache_id_t l2_fwd_in_data_req_id,
    `FPGA_DBG input line_t l2_fwd_in_data_line,
    `FPGA_DBG input word_mask_t l2_fwd_in_data_word_mask,
    `FPGA_DBG input logic l2_rsp_in_valid,
    `FPGA_DBG input coh_msg_t l2_rsp_in_data_coh_msg,
    `FPGA_DBG input line_addr_t l2_rsp_in_data_addr,
    `FPGA_DBG input line_t l2_rsp_in_data_line,
    `FPGA_DBG input word_mask_t l2_rsp_in_data_word_mask,
    `FPGA_DBG input invack_cnt_t l2_rsp_in_data_invack_cnt,
    `FPGA_DBG input logic l2_req_out_ready,
    `FPGA_DBG input logic l2_rsp_out_ready,
    `FPGA_DBG input logic l2_fwd_out_ready,
    `FPGA_DBG input logic l2_rd_rsp_ready,
    `FPGA_DBG input logic l2_flush_valid,
    `FPGA_DBG input logic l2_flush_data,
    `FPGA_DBG input logic l2_fence_valid,
    `FPGA_DBG input fence_t l2_fence_data,
    `FPGA_DBG input logic l2_inval_ready,
    `FPGA_DBG input logic l2_stats_ready,
    `FPGA_DBG input logic l2_bresp_ready,

    `FPGA_DBG output logic l2_cpu_req_ready,
    `FPGA_DBG output logic l2_fwd_in_ready,
    `FPGA_DBG output logic l2_rsp_in_ready,
    `FPGA_DBG output logic l2_req_out_valid,
    `FPGA_DBG output coh_msg_t l2_req_out_data_coh_msg,
    `FPGA_DBG output logic[1:0] l2_req_out_data_hprot,
    `FPGA_DBG output line_addr_t l2_req_out_data_addr,
    `FPGA_DBG output line_t l2_req_out_data_line,
    `FPGA_DBG output word_mask_t l2_req_out_data_word_mask,
    `FPGA_DBG output logic l2_rsp_out_valid,
    `FPGA_DBG output coh_msg_t l2_rsp_out_data_coh_msg,
    `FPGA_DBG output cache_id_t l2_rsp_out_data_req_id,
    `FPGA_DBG output logic[1:0] l2_rsp_out_data_to_req,
    `FPGA_DBG output line_addr_t l2_rsp_out_data_addr,
    `FPGA_DBG output line_t l2_rsp_out_data_line,
    `FPGA_DBG output word_mask_t l2_rsp_out_data_word_mask,
    `FPGA_DBG output logic l2_fwd_out_valid,
    `FPGA_DBG output coh_msg_t l2_fwd_out_data_coh_msg,
    `FPGA_DBG output cache_id_t l2_fwd_out_data_req_id,
    `FPGA_DBG output logic[1:0] l2_fwd_out_data_to_req,
    `FPGA_DBG output line_addr_t l2_fwd_out_data_addr,
    `FPGA_DBG output line_t l2_fwd_out_data_line,
    `FPGA_DBG output word_mask_t l2_fwd_out_data_word_mask,
    `FPGA_DBG output logic l2_rd_rsp_valid,
    `FPGA_DBG output line_t l2_rd_rsp_data_line,
    `FPGA_DBG output logic l2_flush_ready,
    `FPGA_DBG output logic l2_fence_ready,
    `FPGA_DBG output logic l2_inval_valid,
    `FPGA_DBG output l2_inval_addr_t l2_inval_data_addr,
    `FPGA_DBG output logic[1:0] l2_inval_data_hprot,
    `FPGA_DBG output logic l2_stats_valid,
    `FPGA_DBG output logic l2_stats_data,
    `FPGA_DBG output logic flush_done,
    `FPGA_DBG output logic acc_flush_done,
    `FPGA_DBG output logic l2_bresp_valid,
    `FPGA_DBG output bresp_t l2_bresp_data
    );

    l2_cpu_req_t l2_cpu_req_i();
    assign l2_cpu_req_i.cpu_msg = l2_cpu_req_data_cpu_msg;
    assign l2_cpu_req_i.hsize = l2_cpu_req_data_hsize;
    assign l2_cpu_req_i.hprot = l2_cpu_req_data_hprot[0];
    assign l2_cpu_req_i.addr = l2_cpu_req_data_addr;
    assign l2_cpu_req_i.word = l2_cpu_req_data_word;
    assign l2_cpu_req_i.amo = l2_cpu_req_data_amo;
    assign l2_cpu_req_i.aq = l2_cpu_req_data_aq;
    assign l2_cpu_req_i.rl = l2_cpu_req_data_rl;
    assign l2_cpu_req_i.dcs_en = l2_cpu_req_data_dcs_en;
    assign l2_cpu_req_i.use_owner_pred = l2_cpu_req_data_use_owner_pred;
    assign l2_cpu_req_i.dcs = l2_cpu_req_data_dcs;
    assign l2_cpu_req_i.pred_cid = l2_cpu_req_data_pred_cid;

    l2_fwd_in_t l2_fwd_in_i();
    assign l2_fwd_in_i.coh_msg = l2_fwd_in_data_coh_msg;
    assign l2_fwd_in_i.addr = l2_fwd_in_data_addr;
    assign l2_fwd_in_i.req_id = l2_fwd_in_data_req_id;
    assign l2_fwd_in_i.line = l2_fwd_in_data_line;
    assign l2_fwd_in_i.word_mask = l2_fwd_in_data_word_mask;

    l2_rsp_in_t l2_rsp_in_i();
    assign l2_rsp_in_i.coh_msg = l2_rsp_in_data_coh_msg;
    assign l2_rsp_in_i.addr = l2_rsp_in_data_addr;
    assign l2_rsp_in_i.line = l2_rsp_in_data_line;
    assign l2_rsp_in_i.word_mask = l2_rsp_in_data_word_mask;
    assign l2_rsp_in_i.invack_cnt = l2_rsp_in_data_invack_cnt;

    l2_req_out_t l2_req_out();
    assign l2_req_out_data_coh_msg = l2_req_out.coh_msg;
    assign l2_req_out_data_hprot = {1'b0,  l2_req_out.hprot};
    assign l2_req_out_data_addr = l2_req_out.addr;
    assign l2_req_out_data_line = l2_req_out.line;
    assign l2_req_out_data_word_mask = l2_req_out.word_mask;

    l2_rsp_out_t l2_rsp_out();
    assign l2_rsp_out_data_coh_msg = l2_rsp_out.coh_msg;
    assign l2_rsp_out_data_req_id = l2_rsp_out.req_id;
    assign l2_rsp_out_data_to_req = l2_rsp_out.to_req;
    assign l2_rsp_out_data_addr = l2_rsp_out.addr;
    assign l2_rsp_out_data_line = l2_rsp_out.line;
    assign l2_rsp_out_data_word_mask = l2_rsp_out.word_mask;

    l2_fwd_out_t l2_fwd_out();
    assign l2_fwd_out_data_coh_msg = l2_fwd_out.coh_msg;
    assign l2_fwd_out_data_req_id = l2_fwd_out.req_id;
    assign l2_fwd_out_data_to_req = l2_fwd_out.to_req;
    assign l2_fwd_out_data_addr = l2_fwd_out.addr;
    assign l2_fwd_out_data_line = l2_fwd_out.line;
    assign l2_fwd_out_data_word_mask = l2_fwd_out.word_mask;

    l2_rd_rsp_t l2_rd_rsp();
    assign l2_rd_rsp_data_line = l2_rd_rsp.line;

    logic l2_flush_i;
    assign l2_flush_i = l2_flush_data;

    fence_t l2_fence_i;
    assign l2_fence_i = l2_fence_data;

    l2_inval_t l2_inval();
    assign l2_inval_data_addr = l2_inval.addr;
    assign l2_inval_data_hprot = {1'b0, l2_inval.hprot};

    bresp_t l2_bresp;
    assign l2_bresp_data = l2_bresp;

    assign l2_stats_data = 1'b0;
    assign l2_stats_valid = 1'b0;

    l2_core l2_u(.*);
endmodule

