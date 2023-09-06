`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_spandex_rtl_top (
      `FPGA_DBG input logic clk,
      `FPGA_DBG input logic rst,
      `FPGA_DBG input mix_msg_t llc_req_in_data_coh_msg,
      `FPGA_DBG input logic[1:0] llc_req_in_data_hprot,
      `FPGA_DBG input line_addr_t llc_req_in_data_addr,
      `FPGA_DBG input line_t llc_req_in_data_line,
      `FPGA_DBG input cache_id_t llc_req_in_data_req_id,
      `FPGA_DBG input word_offset_t llc_req_in_data_word_offset,
      `FPGA_DBG input word_offset_t llc_req_in_data_valid_words,
      `FPGA_DBG input word_mask_t llc_req_in_data_word_mask,
      `FPGA_DBG input logic llc_req_in_valid,
      `FPGA_DBG input mix_msg_t llc_dma_req_in_data_coh_msg,
      `FPGA_DBG input logic[1:0] llc_dma_req_in_data_hprot,
      `FPGA_DBG input line_addr_t llc_dma_req_in_data_addr,
      `FPGA_DBG input line_t llc_dma_req_in_data_line,
      `FPGA_DBG input llc_coh_dev_id_t llc_dma_req_in_data_req_id,
      `FPGA_DBG input word_offset_t llc_dma_req_in_data_word_offset,
      `FPGA_DBG input word_offset_t llc_dma_req_in_data_valid_words,
      `FPGA_DBG input word_mask_t llc_dma_req_in_data_word_mask,
      `FPGA_DBG input logic llc_dma_req_in_valid,
      `FPGA_DBG input coh_msg_t llc_rsp_in_data_coh_msg,
      `FPGA_DBG input line_addr_t llc_rsp_in_data_addr,
      `FPGA_DBG input line_t llc_rsp_in_data_line,
      `FPGA_DBG input cache_id_t llc_rsp_in_data_req_id,
      `FPGA_DBG input word_mask_t llc_rsp_in_data_word_mask,
      `FPGA_DBG input logic llc_rsp_in_valid,
      `FPGA_DBG input line_t llc_mem_rsp_data_line,
      `FPGA_DBG input logic llc_mem_rsp_valid,
      `FPGA_DBG input logic llc_rst_tb_valid,
      `FPGA_DBG input logic llc_rst_tb_data,
      `FPGA_DBG input logic llc_rsp_out_ready,
      `FPGA_DBG input logic llc_dma_rsp_out_ready,
      `FPGA_DBG input logic llc_fwd_out_ready,
      `FPGA_DBG input logic llc_mem_req_ready,
      `FPGA_DBG input logic llc_rst_tb_done_ready,

      `FPGA_DBG output logic llc_req_in_ready,
      `FPGA_DBG output logic llc_dma_req_in_ready,
      `FPGA_DBG output logic llc_rsp_in_ready,
      `FPGA_DBG output logic llc_mem_rsp_ready,
      `FPGA_DBG output logic llc_rst_tb_ready,
      `FPGA_DBG output logic llc_rsp_out_valid,
      `FPGA_DBG output coh_msg_t llc_rsp_out_data_coh_msg,
      `FPGA_DBG output line_addr_t llc_rsp_out_data_addr,
      `FPGA_DBG output line_t llc_rsp_out_data_line,
      `FPGA_DBG output invack_cnt_t llc_rsp_out_data_invack_cnt,
      `FPGA_DBG output cache_id_t llc_rsp_out_data_req_id,
      `FPGA_DBG output cache_id_t llc_rsp_out_data_dest_id,
      `FPGA_DBG output word_offset_t llc_rsp_out_data_word_offset,
      `FPGA_DBG output word_mask_t llc_rsp_out_data_word_mask,
      `FPGA_DBG output logic llc_dma_rsp_out_valid,
      `FPGA_DBG output coh_msg_t llc_dma_rsp_out_data_coh_msg,
      `FPGA_DBG output line_addr_t  llc_dma_rsp_out_data_addr,
      `FPGA_DBG output line_t llc_dma_rsp_out_data_line,
      `FPGA_DBG output invack_cnt_t llc_dma_rsp_out_data_invack_cnt,
      `FPGA_DBG output llc_coh_dev_id_t llc_dma_rsp_out_data_req_id,
      `FPGA_DBG output cache_id_t llc_dma_rsp_out_data_dest_id,
      `FPGA_DBG output word_offset_t llc_dma_rsp_out_data_word_offset,
      `FPGA_DBG output word_mask_t llc_dma_rsp_out_data_word_mask,
      `FPGA_DBG output logic llc_fwd_out_valid,
      `FPGA_DBG output mix_msg_t llc_fwd_out_data_coh_msg,
      `FPGA_DBG output line_addr_t llc_fwd_out_data_addr,
      `FPGA_DBG output cache_id_t llc_fwd_out_data_req_id,
      `FPGA_DBG output cache_id_t llc_fwd_out_data_dest_id,
      `FPGA_DBG output line_t llc_fwd_out_data_line,
      `FPGA_DBG output word_mask_t llc_fwd_out_data_word_mask,
      `FPGA_DBG output logic llc_mem_req_valid,
      `FPGA_DBG output logic llc_mem_req_data_hwrite,
      `FPGA_DBG output hsize_t llc_mem_req_data_hsize,
      `FPGA_DBG output logic[1:0] llc_mem_req_data_hprot,
      `FPGA_DBG output line_addr_t llc_mem_req_data_addr,
      `FPGA_DBG output line_t llc_mem_req_data_line,
      `FPGA_DBG output logic llc_rst_tb_done_valid,
      `FPGA_DBG output logic llc_rst_tb_done_data,
      `FPGA_DBG input logic llc_stats_ready,
      `FPGA_DBG output logic llc_stats_valid,
      `FPGA_DBG output logic llc_stats_data
      );

      //llc req in
      llc_req_in_t llc_req_in_i();
      assign llc_req_in_i.coh_msg = llc_req_in_data_coh_msg;
      assign llc_req_in_i.hprot = llc_req_in_data_hprot[0];
      assign llc_req_in_i.addr = llc_req_in_data_addr;
      assign llc_req_in_i.line = llc_req_in_data_line;
      assign llc_req_in_i.req_id = llc_req_in_data_req_id;
      assign llc_req_in_i.word_offset = llc_req_in_data_word_offset;
      assign llc_req_in_i.valid_words = llc_req_in_data_valid_words;
      assign llc_req_in_i.word_mask = llc_req_in_data_word_mask;

      //llc dma req in
      llc_dma_req_in_t llc_dma_req_in_i();
      assign llc_dma_req_in_i.coh_msg     = llc_dma_req_in_data_coh_msg;
      assign llc_dma_req_in_i.hprot       = llc_dma_req_in_data_hprot[0];
      assign llc_dma_req_in_i.addr        = llc_dma_req_in_data_addr;
      assign llc_dma_req_in_i.line        = llc_dma_req_in_data_line;
      assign llc_dma_req_in_i.req_id      = llc_dma_req_in_data_req_id;
      assign llc_dma_req_in_i.word_offset = llc_dma_req_in_data_word_offset;
      assign llc_dma_req_in_i.valid_words = llc_dma_req_in_data_valid_words;

      //llc rsp in
      llc_rsp_in_t llc_rsp_in_i();
      assign llc_rsp_in_i.coh_msg = llc_rsp_in_data_coh_msg;
      assign llc_rsp_in_i.addr = llc_rsp_in_data_addr;
      assign llc_rsp_in_i.line = llc_rsp_in_data_line;
      assign llc_rsp_in_i.req_id = llc_rsp_in_data_req_id;
      assign llc_rsp_in_i.word_mask = llc_rsp_in_data_word_mask;

      //llc mem rsp
      llc_mem_rsp_t llc_mem_rsp_i();
      assign llc_mem_rsp_i.line = llc_mem_rsp_data_line;

      //llc rst tb
      logic llc_rst_tb_i;
      assign llc_rst_tb_i = llc_rst_tb_data;

      //llc rsp out
      llc_rsp_out_t llc_rsp_out();
      assign llc_rsp_out_data_coh_msg = llc_rsp_out.coh_msg;
      assign llc_rsp_out_data_addr = llc_rsp_out.addr;
      assign llc_rsp_out_data_line = llc_rsp_out.line;
      assign llc_rsp_out_data_invack_cnt = llc_rsp_out.invack_cnt;
      assign llc_rsp_out_data_req_id = llc_rsp_out.req_id;
      assign llc_rsp_out_data_dest_id = llc_rsp_out.dest_id;
      assign llc_rsp_out_data_word_offset = llc_rsp_out.word_offset;
      assign llc_rsp_out_data_word_mask = llc_rsp_out.word_mask;

      //llc dma rsp out
      llc_dma_rsp_out_t llc_dma_rsp_out();
      assign llc_dma_rsp_out_data_coh_msg = llc_dma_rsp_out.coh_msg;
      assign llc_dma_rsp_out_data_addr = llc_dma_rsp_out.addr;
      assign llc_dma_rsp_out_data_line = llc_dma_rsp_out.line;
      assign llc_dma_rsp_out_data_invack_cnt = llc_dma_rsp_out.invack_cnt;
      assign llc_dma_rsp_out_data_req_id = llc_dma_rsp_out.req_id;
      assign llc_dma_rsp_out_data_dest_id = llc_dma_rsp_out.dest_id;
      assign llc_dma_rsp_out_data_word_offset = llc_dma_rsp_out.word_offset;

      //llc fwd out
      llc_fwd_out_t llc_fwd_out();
      assign llc_fwd_out_data_coh_msg = llc_fwd_out.coh_msg;
      assign llc_fwd_out_data_addr = llc_fwd_out.addr;
      assign llc_fwd_out_data_req_id = llc_fwd_out.req_id;
      assign llc_fwd_out_data_dest_id = llc_fwd_out.dest_id;
      assign llc_fwd_out_data_line = llc_fwd_out.line;
      assign llc_fwd_out_data_word_mask = llc_fwd_out.word_mask;

      //llc mem req
      llc_mem_req_t llc_mem_req();
      assign llc_mem_req_data_hwrite = llc_mem_req.hwrite;
      assign llc_mem_req_data_hsize = llc_mem_req.hsize;
      assign llc_mem_req_data_hprot = {1'b0, llc_mem_req.hprot};
      assign llc_mem_req_data_addr = llc_mem_req.addr;
      assign llc_mem_req_data_line = llc_mem_req.line;

      //llc rst tb done
      logic llc_rst_tb_done;
      assign llc_rst_tb_done_data = llc_rst_tb_done;
      assign llc_rst_tb_ready = 1'b1;
      assign llc_rst_tb_done_valid = 1'b0;

      //llc  stats
      logic llc_stats;
      assign llc_stats_data = 1'b0;
      assign llc_stats_valid = 1'b0;

      assign llc_dma_rsp_out_data_word_mask = 'h0;

      llc_core llc_core_u(.*);

endmodule

