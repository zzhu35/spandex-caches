// Copyright (c) 2011-2022 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

#include "l2_spandex_wrap.h"

void l2_wrapper_conv::thread_l2_cpu_req_data_conv(){
    l2_cpu_req_t tmp = l2_cpu_req.data.read();
    l2_cpu_req_data_conv_cpu_msg = tmp.cpu_msg;
    l2_cpu_req_data_conv_hprot = tmp.hprot;
    l2_cpu_req_data_conv_addr = tmp.addr;
    l2_cpu_req_data_conv_hsize = tmp.hsize;
    l2_cpu_req_data_conv_word = tmp.word;
    l2_cpu_req_data_conv_amo = tmp.amo;
    l2_cpu_req_data_conv_aq = tmp.aq;
    l2_cpu_req_data_conv_rl = tmp.rl;
    l2_cpu_req_data_conv_dcs_en = tmp.dcs_en;
    l2_cpu_req_data_conv_use_owner_pred = tmp.use_owner_pred;
    l2_cpu_req_data_conv_dcs = tmp.dcs;
    l2_cpu_req_data_conv_pred_cid = tmp.pred_cid;
}

void l2_wrapper_conv::thread_l2_fwd_in_data_conv(){
    l2_fwd_in_t tmp = l2_fwd_in.data.read();
    l2_fwd_in_data_conv_coh_msg = tmp.coh_msg;
    l2_fwd_in_data_conv_addr = tmp.addr;
    l2_fwd_in_data_conv_req_id = tmp.req_id;
    l2_fwd_in_data_conv_line = tmp.line;
    l2_fwd_in_data_conv_word_mask = tmp.word_mask;
}

void l2_wrapper_conv::thread_l2_rsp_in_data_conv(){
    l2_rsp_in_t tmp = l2_rsp_in.data.read();
    l2_rsp_in_data_conv_coh_msg = tmp.coh_msg;
    l2_rsp_in_data_conv_addr = tmp.addr;
    l2_rsp_in_data_conv_line = tmp.line;
    l2_rsp_in_data_conv_word_mask = tmp.word_mask;
    l2_rsp_in_data_conv_invack_cnt = tmp.invack_cnt;
}

void l2_wrapper_conv::thread_l2_flush_data_conv(){
    l2_flush_data_conv = l2_flush.data.read();
}

void l2_wrapper_conv::thread_l2_fence_data_conv(){
    l2_fence_data_conv = l2_fence.data.read();
}

void l2_wrapper_conv::thread_l2_req_out_data_conv(){
    l2_req_out_t tmp;
    tmp.coh_msg = l2_req_out_data_conv_coh_msg.read();
    tmp.addr = l2_req_out_data_conv_addr.read();
    tmp.line = l2_req_out_data_conv_line.read();
    tmp.hprot = l2_req_out_data_conv_hprot.read();
    tmp.word_mask = l2_req_out_data_conv_word_mask.read();
    l2_req_out.data.write(tmp);
}

void l2_wrapper_conv::thread_l2_rsp_out_data_conv(){
    l2_rsp_out_t tmp;
    tmp.coh_msg = l2_rsp_out_data_conv_coh_msg.read();
    tmp.addr = l2_rsp_out_data_conv_addr.read();
    tmp.line = l2_rsp_out_data_conv_line.read();
    tmp.req_id = l2_rsp_out_data_conv_req_id.read();
    tmp.to_req = l2_rsp_out_data_conv_to_req.read();
    tmp.word_mask = l2_rsp_out_data_conv_word_mask.read();
    l2_rsp_out.data.write(tmp);
}

void l2_wrapper_conv::thread_l2_fwd_out_data_conv(){
    l2_fwd_out_t tmp;
    tmp.coh_msg = l2_fwd_out_data_conv_coh_msg.read();
    tmp.addr = l2_fwd_out_data_conv_addr.read();
    tmp.line = l2_fwd_out_data_conv_line.read();
    tmp.req_id = l2_fwd_out_data_conv_req_id.read();
    tmp.to_req = l2_fwd_out_data_conv_to_req.read();
    tmp.word_mask = l2_fwd_out_data_conv_word_mask.read();
    l2_fwd_out.data.write(tmp);
}

void l2_wrapper_conv::thread_l2_rd_rsp_data_conv(){
    l2_rd_rsp_t tmp;
    tmp.line = l2_rd_rsp_data_conv_line.read();
    l2_rd_rsp.data.write(tmp);
}


void l2_wrapper_conv::thread_l2_inval_data_conv(){
    l2_inval_t tmp;
    tmp.addr = l2_inval_data_conv_addr.read();
    tmp.hprot = l2_inval_data_conv_hprot.read();
    l2_inval.data.write(tmp);
}

void l2_wrapper_conv::thread_l2_bresp_data_conv(){
    bresp_t tmp = l2_bresp_data_conv.read();
    l2_bresp.data.write(tmp);
}

#ifdef STATS_ENABLE
void l2_wrapper_conv::thread_l2_stats_data_conv(){
    bool tmp = l2_stats_data_conv.read();
    l2_stats.data.write(tmp);
}
#endif

NCSC_MODULE_EXPORT(l2_wrapper_conv)
