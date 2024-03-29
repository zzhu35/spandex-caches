// Copyright (c) 2011-2022 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

#include "spandex_system_wrap.h"

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

void llc_wrapper_conv::thread_llc_req_in_data_conv(){
    llc_req_in_t<CACHE_ID_WIDTH> tmp = llc_req_in.data.read();
    llc_req_in_data_conv_coh_msg = tmp.coh_msg;
    llc_req_in_data_conv_hprot = tmp.hprot;
    llc_req_in_data_conv_addr = tmp.addr;
    llc_req_in_data_conv_line = tmp.line;
    llc_req_in_data_conv_req_id = tmp.req_id;
    llc_req_in_data_conv_word_offset = tmp.word_offset;
    llc_req_in_data_conv_valid_words = tmp.valid_words;
    llc_req_in_data_conv_word_mask = tmp.word_mask;
}

void llc_wrapper_conv::thread_llc_dma_req_in_data_conv(){
    llc_req_in_t<LLC_COH_DEV_ID_WIDTH> tmp = llc_dma_req_in.data.read();
    llc_dma_req_in_data_conv_coh_msg = tmp.coh_msg;
    llc_dma_req_in_data_conv_hprot = tmp.hprot;
    llc_dma_req_in_data_conv_addr = tmp.addr;
    llc_dma_req_in_data_conv_line = tmp.line;
    llc_dma_req_in_data_conv_req_id = tmp.req_id;
    llc_dma_req_in_data_conv_word_offset = tmp.word_offset;
    llc_dma_req_in_data_conv_valid_words = tmp.valid_words;
    llc_dma_req_in_data_conv_word_mask = tmp.word_mask;
}

void llc_wrapper_conv::thread_llc_rsp_in_data_conv(){
    llc_rsp_in_t tmp = llc_rsp_in.data.read();
    llc_rsp_in_data_conv_coh_msg = tmp.coh_msg;
    llc_rsp_in_data_conv_addr = tmp.addr;
    llc_rsp_in_data_conv_line = tmp.line;
    llc_rsp_in_data_conv_req_id = tmp.req_id;
    llc_rsp_in_data_conv_word_mask = tmp.word_mask;
}

void llc_wrapper_conv::thread_llc_mem_rsp_data_conv(){
    llc_mem_rsp_t tmp = llc_mem_rsp.data.read();
    llc_mem_rsp_data_conv_line = tmp.line;
}

void llc_wrapper_conv::thread_llc_rst_tb_data_conv(){
    llc_rst_tb_data_conv = llc_rst_tb.data.read();
}

void llc_wrapper_conv::thread_llc_rsp_out_data_conv(){
    llc_rsp_out_t<CACHE_ID_WIDTH> tmp;
    tmp.coh_msg = llc_rsp_out_data_conv_coh_msg.read();
    tmp.addr = llc_rsp_out_data_conv_addr.read();
    tmp.line = llc_rsp_out_data_conv_line.read();
    tmp.invack_cnt = llc_rsp_out_data_conv_invack_cnt.read();
    tmp.req_id = llc_rsp_out_data_conv_req_id.read();
    tmp.dest_id = llc_rsp_out_data_conv_dest_id.read();
    tmp.word_offset = llc_rsp_out_data_conv_word_offset.read();
    tmp.word_mask = llc_rsp_out_data_conv_word_mask.read();
    llc_rsp_out.data.write(tmp);
}

void llc_wrapper_conv::thread_llc_dma_rsp_out_data_conv(){
    llc_rsp_out_t<LLC_COH_DEV_ID_WIDTH> tmp;
    tmp.coh_msg = llc_dma_rsp_out_data_conv_coh_msg.read();
    tmp.addr = llc_dma_rsp_out_data_conv_addr.read();
    tmp.line = llc_dma_rsp_out_data_conv_line.read();
    tmp.invack_cnt = llc_dma_rsp_out_data_conv_invack_cnt.read();
    tmp.req_id = llc_dma_rsp_out_data_conv_req_id.read();
    tmp.dest_id = llc_dma_rsp_out_data_conv_dest_id.read();
    tmp.word_offset = llc_dma_rsp_out_data_conv_word_offset.read();
    tmp.word_mask = llc_dma_rsp_out_data_conv_word_mask.read();
    llc_dma_rsp_out.data.write(tmp);
}

void llc_wrapper_conv::thread_llc_fwd_out_data_conv(){
    llc_fwd_out_t tmp; 
    tmp.coh_msg = llc_fwd_out_data_conv_coh_msg.read();
    tmp.addr = llc_fwd_out_data_conv_addr.read();
    tmp.req_id = llc_fwd_out_data_conv_req_id.read();
    tmp.dest_id = llc_fwd_out_data_conv_dest_id.read();
    tmp.line = llc_fwd_out_data_conv_line.read();
    tmp.word_mask = llc_fwd_out_data_conv_word_mask.read();
    llc_fwd_out.data.write(tmp);
}

void llc_wrapper_conv::thread_llc_mem_req_data_conv(){
    llc_mem_req_t tmp;
    tmp.hwrite = llc_mem_req_data_conv_hwrite.read();
    tmp.hsize = llc_mem_req_data_conv_hsize.read();
    tmp.hprot = llc_mem_req_data_conv_hprot.read();
    tmp.addr = llc_mem_req_data_conv_addr.read();
    tmp.line = llc_mem_req_data_conv_line.read();
    llc_mem_req.data.write(tmp);
}

void llc_wrapper_conv::thread_llc_rst_tb_done_data_conv(){
    bool tmp = llc_rst_tb_done_data_conv.read();
    llc_rst_tb_done.data.write(tmp);
}

#ifdef STATS_ENABLE
void llc_wrapper_conv::thread_llc_stats_data_conv(){
    bool tmp = llc_stats_data_conv.read();
    llc_stats.data.write(tmp);
}
#endif

NCSC_MODULE_EXPORT(llc_wrapper_conv) 
