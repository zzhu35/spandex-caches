// Copyright (c) 2011-2022 Columbia University, System Level Design Group
// SPDX-License-Identifier: Apache-2.0

`include "spandex_consts.svh"
`include "spandex_types.svh"

/* L1 to L2 */

// L1 request
interface l2_cpu_req_t;
    cpu_msg_t cpu_msg;
    hsize_t hsize;
    hprot_t hprot;
    addr_t addr;
    word_t word;
    amo_t amo;
    logic aq;
    logic rl;
    logic dcs_en;
    logic use_owner_pred;
    dcs_t dcs;
    cache_id_t pred_cid;

    modport in (input cpu_msg, hsize, hprot, addr, word, amo, aq, rl, dcs_en, use_owner_pred, dcs, pred_cid);
    modport out (output cpu_msg, hsize, hprot, addr, word, amo, aq, rl, dcs_en, use_owner_pred, dcs, pred_cid);

endinterface

/* L2 to L1 */

// read data response
interface l2_rd_rsp_t;
    line_t line;

    modport in (input line);
    modport out (output line);

endinterface

/* L2/LLC to L2 */
interface  l2_fwd_in_t;
    mix_msg_t coh_msg;
    line_addr_t addr;
    cache_id_t req_id;
    line_t line;
    word_mask_t word_mask;

    modport in (input coh_msg, addr, req_id, line, word_mask);
    modport out (output coh_msg, addr, req_id, line, word_mask);

endinterface

// responses
interface l2_rsp_in_t;
    coh_msg_t coh_msg;
    line_addr_t addr;
    line_t line;
    word_mask_t word_mask;
    invack_cnt_t invack_cnt;

    modport in (input coh_msg, addr, line, word_mask, invack_cnt);
    modport out (output coh_msg, addr, line, word_mask, invack_cnt);

endinterface

/* L2 to L2/LLC */

// responses
interface l2_rsp_out_t;
    coh_msg_t coh_msg;
    cache_id_t req_id;
    logic[1:0] to_req;
    line_addr_t addr;
    line_t line;
    word_mask_t word_mask;

    modport in (input coh_msg, req_id, to_req, addr, line, word_mask);
    modport out (output coh_msg, req_id, to_req, addr, line, word_mask);

endinterface

// requests
interface l2_req_out_t;
    coh_msg_t coh_msg;
    hprot_t hprot;
    line_addr_t addr;
    line_t line;
    word_mask_t word_mask;

    modport in (input coh_msg, hprot, addr, line, word_mask);
    modport out (output coh_msg, hprot, addr, line, word_mask);

endinterface

// forwards
interface  l2_fwd_out_t;
    coh_msg_t coh_msg;
    cache_id_t req_id;
    logic[1:0] to_req;
    line_addr_t addr;
    line_t line;
    word_mask_t word_mask;

    modport in (input coh_msg, req_id, to_req, addr, line, word_mask);
    modport out (output coh_msg, req_id, to_req, addr, line, word_mask);

endinterface

interface line_breakdown_l2_t;
    l2_tag_t tag;
    l2_set_t set;

    modport in (input tag, set);
    modport out (output tag, set);

endinterface

// addr breakdown
interface addr_breakdown_t;
    addr_t              line;
    line_addr_t         line_addr;
    addr_t              word;
    l2_tag_t            tag;
    l2_set_t            set;
    word_offset_t       w_off;
    byte_offset_t       b_off;

    modport in (input line, line_addr, word, tag, set, w_off, b_off);
    modport out (output line, line_addr, word, tag, set, w_off, b_off);

endinterface

interface l2_inval_t;
    l2_inval_addr_t addr;
    hprot_t hprot;

    modport in(input addr, hprot);
    modport out(output addr, hprot);
endinterface
