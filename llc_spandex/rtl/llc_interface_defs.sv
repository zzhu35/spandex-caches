`include "spandex_consts.svh"
`include "spandex_types.svh"

interface llc_rsp_out_t;
    coh_msg_t coh_msg;
    line_addr_t addr;
    line_t line;
    invack_cnt_t invack_cnt;
    cache_id_t req_id;
    cache_id_t dest_id;
    word_offset_t word_offset;
    word_mask_t word_mask;

    modport in (input coh_msg, addr, line, invack_cnt, req_id, dest_id, word_offset, word_mask);
    modport out (output coh_msg, addr, line, invack_cnt, req_id, dest_id, word_offset, word_mask);

endinterface

interface llc_dma_rsp_out_t;
   coh_msg_t           coh_msg;
   line_addr_t         addr;
   line_t              line;
   invack_cnt_t        invack_cnt;
   llc_coh_dev_id_t    req_id;
   cache_id_t          dest_id;
   word_offset_t       word_offset;

   modport in (input coh_msg, addr, line, invack_cnt, req_id, dest_id, word_offset);
   modport out (output coh_msg, addr, line, invack_cnt, req_id, dest_id, word_offset);

endinterface

interface llc_fwd_out_t;
    mix_msg_t coh_msg;// fwd_gets, fwd_getm, fwd_inv
    line_addr_t addr;
    cache_id_t req_id;
    cache_id_t dest_id;
    line_t line;
    word_mask_t word_mask;

    modport in (input coh_msg, addr, req_id, dest_id, line, word_mask);
    modport out (output coh_msg, addr, req_id, dest_id, line, word_mask);

endinterface

interface llc_req_in_t;
    mix_msg_t coh_msg;
    hprot_t hprot;
    line_addr_t addr;
    line_t line;
    cache_id_t req_id;
    word_offset_t word_offset;
    word_offset_t valid_words;
    word_mask_t word_mask;

    modport in (input coh_msg, hprot, addr, line, req_id, word_offset, valid_words, word_mask);
    modport out (output coh_msg, hprot, addr, line, req_id, word_offset, valid_words, word_mask);

endinterface

interface llc_dma_req_in_t;
   mix_msg_t        coh_msg;
   hprot_t          hprot;
   line_addr_t      addr;
   line_t           line;
   llc_coh_dev_id_t req_id;
   word_offset_t    word_offset;
   word_offset_t    valid_words;

   modport in (input coh_msg, hprot, addr, line, req_id, word_offset, valid_words);
   modport out (output coh_msg, hprot, addr, line, req_id, word_offset, valid_words);

endinterface

interface llc_rsp_in_t;
    coh_msg_t coh_msg;
    line_addr_t addr;
    line_t line;
    cache_id_t req_id;
    word_mask_t word_mask;

    modport in (input coh_msg, addr, line, req_id, word_mask);
    modport out (output coh_msg, addr, line, req_id, word_mask);

endinterface

/* LLC to Memory */

// requests
interface llc_mem_req_t;
    logic hwrite;
    hsize_t hsize;
    hprot_t hprot;
    line_addr_t addr;
    line_t line;

    modport in (input hwrite, hsize, hprot, addr, line);
    modport out (output hwrite, hsize, hprot, addr, line);

endinterface

// responses

interface llc_mem_rsp_t;
    line_t line;

    modport in (input line);
    modport out (output line);

endinterface

interface line_breakdown_llc_t;
    llc_tag_t tag;
    llc_set_t set;

    modport in (input tag, set);
    modport out (output tag, set);

endinterface

