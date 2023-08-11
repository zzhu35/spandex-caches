`include "cache_consts.svh"
`include "cache_types.svh"

// Input request to L2
interface l2_cpu_req_if;
    cpu_msg_t cpu_msg;
    hsize_t hsize;
    logic[1:0] hprot;
    addr_t addr;
    word_t word;
    amo_t amo;
    logic valid;
    logic ready;
endinterface

// Read response from L2
interface l2_rd_rsp_if;
    logic valid;
    line_t line;
    logic ready;
endinterface

// Forward from other L2/LLC
interface  l2_fwd_in_if;
    mix_msg_t coh_msg;
    line_addr_t addr;
    cache_id_t req_id;
    logic valid;
    logic ready;
endinterface

// Response from other L2/LLC to L2
interface l2_rsp_in_if;
    coh_msg_t	coh_msg;	// data, e-data, inv-ack, put-ack
    line_addr_t	addr;
    line_t line;
    invack_cnt_t invack_cnt;
    logic valid;
    logic ready;
endinterface

// Response from L2 to other L2/LLC
interface l2_rsp_out_if;
    coh_msg_t coh_msg;	// gets, getm, puts, putm
    cache_id_t req_id;
    logic[1:0] to_req;
    line_addr_t	addr;
    line_t line;
    logic valid;
    logic ready;
endinterface

// Request from L2 to LLC
interface l2_req_out_if;
    coh_msg_t coh_msg;	// gets, getm, puts, putm
    hprot_t	hprot;
    line_addr_t	addr;
    line_t line;
    logic valid;
    logic ready;
endinterface

// Invalidation request from L2 to L1
interface l2_inval_if;
    l2_inval_addr_t addr;
    logic[1:0] hprot;
    logic valid;
    logic ready;
endinterface

// Write response from L2 to L1
interface l2_bresp_if;
    bresp_t data;
    logic valid;
    logic ready;
endinterface

// Flush request to L2
interface l2_flush_if;
    bresp_t data;
    logic valid;
    logic ready;
endinterface

// Stats data from L2
interface l2_stats_if;
    bresp_t data;
    logic valid;
    logic ready;
endinterface