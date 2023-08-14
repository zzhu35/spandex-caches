// Copyright (c) 2011-2022 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

// l2_wrapper.sv
// Author: Joseph Zuckerman
// top level wrapper for l2 cache

module l2_rtl_top(
    input logic clk,
    input logic rst,
    input logic l2_cpu_req_valid,
    input cpu_msg_t l2_cpu_req_data_cpu_msg,
    input hsize_t l2_cpu_req_data_hsize,
    input logic[1:0] l2_cpu_req_data_hprot,
    input addr_t l2_cpu_req_data_addr,
    input word_t l2_cpu_req_data_word,
    input amo_t l2_cpu_req_data_amo,
    input logic l2_cpu_req_data_aq,
    input logic l2_cpu_req_data_rl,
    input logic l2_cpu_req_data_dcs_en,
    input logic l2_cpu_req_data_use_owner_pred,
    input dcs_t l2_cpu_req_data_dcs,
    input cache_id_t l2_cpu_req_data_pred_cid,
    input logic l2_fwd_in_valid,
    input mix_msg_t l2_fwd_in_data_coh_msg,
    input line_addr_t l2_fwd_in_data_addr,
    input cache_id_t l2_fwd_in_data_req_id,
    input line_t l2_fwd_in_data_line,
    input word_mask_t l2_fwd_in_data_word_mask,
    input logic l2_rsp_in_valid,
    input coh_msg_t l2_rsp_in_data_coh_msg,
    input line_addr_t l2_rsp_in_data_addr,
    input line_t l2_rsp_in_data_line,
    input word_mask_t l2_rsp_in_data_word_mask,
    input invack_cnt_t l2_rsp_in_data_invack_cnt,
    input logic l2_req_out_ready,
    input logic l2_rsp_out_ready,
    input logic l2_fwd_out_ready,
    input logic l2_rd_rsp_ready,
    input logic l2_flush_valid,
    input logic l2_flush_data,
    input logic l2_fence_valid,
    input logic[1:0] l2_fence_data,
    input logic l2_inval_ready,
    input logic l2_stats_ready,
    input logic l2_bresp_ready,

    output logic l2_cpu_req_ready,
    output logic l2_fwd_in_ready,
    output logic l2_rsp_in_ready,
    output logic l2_req_out_valid,
    output coh_msg_t l2_req_out_data_coh_msg,
    output logic[1:0] l2_req_out_data_hprot,
    output line_addr_t l2_req_out_data_addr,
    output line_t l2_req_out_data_line,
    output word_mask_t l2_req_out_data_word_mask,
    output logic l2_rsp_out_valid,
    output coh_msg_t l2_rsp_out_data_coh_msg,
    output cache_id_t l2_rsp_out_data_req_id,
    output logic[1:0] l2_rsp_out_data_to_req,
    output line_addr_t l2_rsp_out_data_addr,
    output line_t l2_rsp_out_data_line,
    output word_mask_t l2_rsp_out_data_word_mask,
    output logic l2_fwd_out_valid,
    output coh_msg_t l2_fwd_out_data_coh_msg,
    output cache_id_t l2_fwd_out_data_req_id,
    output logic[1:0] l2_fwd_out_data_to_req,
    output line_addr_t l2_fwd_out_data_addr,
    output line_t l2_fwd_out_data_line,
    output word_mask_t l2_fwd_out_data_word_mask,
    output logic l2_rd_rsp_valid,
    output line_t l2_rd_rsp_data_line,
    output logic l2_flush_ready,
    output logic l2_fence_ready,
    output logic l2_inval_valid,
    output l2_inval_addr_t l2_inval_data_addr,
    output logic[1:0] l2_inval_data_hprot,
    output logic l2_stats_valid,
    output logic l2_stats_data,
    output logic flush_done,
    output logic acc_flush_done,
    output logic l2_bresp_valid,
    output bresp_t l2_bresp_data
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

    logic[1:0] l2_fence_i;
    assign l2_fence_i = l2_fence_data;

    l2_inval_t l2_inval();
    assign l2_inval_data_addr = l2_inval.addr;
    assign l2_inval_data_hprot = {1'b0, l2_inval.hprot};

    bresp_t l2_bresp;
    assign l2_bresp_data = l2_bresp;

`ifdef STATS_ENABLE
    logic l2_stats;
    assign l2_stats_data = l2_stats;
`endif

    l2_core l2_u(.*);
endmodule

