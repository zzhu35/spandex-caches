/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

	Modified by Zeran Zhu, Robert Jin, Vignesh Suresh
	zzhu35@illinois.edu
	
	April 9 2021

*/
 
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "llc_spandex_tb.hpp"

#define L2_SETS LLC_SETS

/*
 * Processes
 */

#ifdef STATS_ENABLE
void llc_spandex_tb::get_stats()
{
    llc_stats_tb.reset_get();

    wait();

    while(true) {
	
	bool tmp;

	llc_stats_tb.get(tmp);

	wait();
    }
}
#endif

void llc_spandex_tb::llc_test()
{
    /*
     * Random seed
     */
    
    // initialize
    srand(time(NULL));

    /*
     * Local variables
     */

    // constants
    const word_t empty_word = 0;
    const line_t empty_line = 0;
    const hprot_t empty_hprot = INSTR;

    // preparation variables
    addr_breakdown_llc_t addr_base, addr, addr_evict, null;
    null.breakdown(0);
    word_t word, word_tmp;
    line_t line, orig_line;

    unsigned int n_l2 = 1;
    unsigned int l2_ways = 1;

    const unsigned int MIN_L2 = 4;
    const unsigned int MIN_WAYS = 4;

    addr_t base_addr = 0x82508250;
    addr_t base_addr1 = 0x82518250;

    /*
     * Reset
     */

    reset_llc_test();

    CACHE_REPORT_INFO("[SPANDEX] Reset done!"); 

    error_count = 0;

    ////////////////////////////////////////////////////////////////
    // TEST 1: Simple ReqO and ReqS swaps
    ////////////////////////////////////////////////////////////////
    addr.breakdown(base_addr);
    word = 0xdeadbeefdead0000;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    ////////////////////////////////////////////////////////////////
    // first it needs to fetch the line from memory
    // TODO why is hsize always WORD? Also, why are woff
    // and wvalid not used?
    ////////////////////////////////////////////////////////////////
    put_req_in(REQ_O /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b01 /* word_mask */);

    get_mem_req(0 /* hwrite */, WORD /* hsize */, DATA /* hprot */, addr.word /* addr */, 0 /* line */);

    word = 0x1111111111111111;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_mem_rsp(line /* line */);

    get_rsp_out(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		0 /* req_id */, 0 /* dest_id */, 0 /* woff */, 0b01 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // new ownership request
    // TODO why is there req_id same as dest_id for get_rsp_out?
    // Note: there is no response from the invalidating L2 to the
    // LLC, the LLC just sends the RSP_O for the remaining words
    // without waiting for the invalidating L2
    ////////////////////////////////////////////////////////////////
    word = 0xdeadbeefdead1111;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_req_in(REQ_O /* coh_msg */, addr.word /* addr */, line /* line */, 1 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b11 /* word_mask */);

    get_fwd_out(FWD_REQ_O /* coh_msg */, addr.word /* addr */, 1 /* req_id */, 0 /* dest_id */, 0b01 /* word_mask*/);

    get_rsp_out(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		1 /* req_id */, 1 /* dest_id */, 0 /* woff */, 0b10 /* word_mask */);

    ////////////////////////////////////////////////////////////////
    // new sharing request
    ////////////////////////////////////////////////////////////////
    put_req_in(REQ_S /* coh_msg */, addr.word /* addr */, 0 /* line */, 2 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b11 /* word_mask */);

    get_fwd_out(FWD_REQ_S /* coh_msg */, addr.word /* addr */, 2 /* req_id */, 1 /* dest_id */, 0b11 /* word_mask*/);

    put_rsp_in(RSP_RVK_O /* rsp_msg */, addr.word /* addr */, line /* line */, 1 /* req_id */, 0b11 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // another new sharing request
    ////////////////////////////////////////////////////////////////
    put_req_in(REQ_S /* coh_msg */, addr.word /* addr */, 0 /* line */, 3 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b11 /* word_mask */);

    get_rsp_out(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		3 /* req_id */, 3 /* dest_id */, 0 /* woff */, 0b11 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // new ownership request
    ////////////////////////////////////////////////////////////////
    orig_line = line;
    word = 0xdeadbeefdead2222;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_req_in(REQ_O /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b10 /* word_mask */);

    get_fwd_out(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */, 1 /* dest_id */, 0b10 /* word_mask*/);

    wait();

    get_fwd_out(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */, 2 /* dest_id */, 0b10 /* word_mask*/);

    wait();

    get_fwd_out(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */, 3 /* dest_id */, 0b10 /* word_mask*/);

    put_rsp_in(RSP_INV_ACK_SPDX /* rsp_msg */, addr.word /* addr */, orig_line /* line */, 1 /* req_id */, 0b11 /* word_mask */);

    wait();

    put_rsp_in(RSP_INV_ACK_SPDX /* rsp_msg */, addr.word /* addr */, orig_line /* line */, 2 /* req_id */, 0b11 /* word_mask */);

    wait();

    put_rsp_in(RSP_INV_ACK_SPDX /* rsp_msg */, addr.word /* addr */, orig_line /* line */, 3 /* req_id */, 0b11 /* word_mask */);

    get_rsp_out(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		0 /* req_id */, 0 /* dest_id */, 0 /* woff */, 0b10 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // new sharing request
    ////////////////////////////////////////////////////////////////
    line.range(BITS_PER_WORD - 1, 0) = orig_line.range(BITS_PER_WORD - 1, 0);

    put_req_in(REQ_S /* coh_msg */, addr.word /* addr */, 0 /* line */, 1 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b11 /* word_mask */);

    get_fwd_out(FWD_REQ_S /* coh_msg */, addr.word /* addr */, 1 /* req_id */, 0 /* dest_id */, 0b10 /* word_mask*/);

    put_rsp_in(RSP_S /* rsp_msg */, addr.word /* addr */, line /* line */, 0 /* req_id */, 0b10 /* word_mask */);

    line = orig_line;

    get_rsp_out(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		1 /* req_id */, 1 /* dest_id */, 0 /* woff */, 0b01 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2: ReqOdata to mimic atomic lock and release
    // First we have race between two L2's
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82518000;
    addr.breakdown(base_addr);
    word = 0x1;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = 0;

    put_req_in(REQ_Odata /* coh_msg */, addr.word /* addr */, 0 /* line */, 0 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b10 /* word_mask */);

    get_mem_req(0 /* hwrite */, WORD /* hsize */, DATA /* hprot */, addr.word /* addr */, 0 /* line */);

    put_req_in(REQ_Odata /* coh_msg */, addr.word /* addr */, 0 /* line */, 1 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b10 /* word_mask */);
    
    wait();

    put_mem_rsp(0 /* line */);

    get_rsp_out(RSP_Odata /* coh_msg */, addr.word /* addr */, 0 /* line */, 0 /* invack_cnt */,
		0 /* req_id */, 0 /* dest_id */, 0 /* woff */, 0b10 /* word_mask */);

    wait();

    get_fwd_out(FWD_REQ_Odata /* coh_msg */, addr.word /* addr */, 1 /* req_id */, 0 /* dest_id */, 0b10 /* word_mask*/);

    wait();

    ////////////////////////////////////////////////////////////////
    // Although that the first cache has secured the lock, the second
    // cache will now have the line in owned state, so we will
    // first read it back from first cache
    ////////////////////////////////////////////////////////////////
    put_req_in(REQ_S /* coh_msg */, addr.word /* addr */, 0 /* line */, 0 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b11 /* word_mask */);

    get_fwd_out(FWD_REQ_S /* coh_msg */, addr.word /* addr */, 0 /* req_id */, 1 /* dest_id */, 0b10 /* word_mask*/);

    put_rsp_in(RSP_RVK_O /* rsp_msg */, addr.word /* addr */, line /* line */, 1 /* req_id */, 0b10 /* word_mask */);

    wait();

    get_rsp_out(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		0 /* req_id */, 0 /* dest_id */, 0 /* woff */, 0b01 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // releasing the lock
    ////////////////////////////////////////////////////////////////
    put_req_in(REQ_Odata /* coh_msg */, addr.word /* addr */, 0 /* line */, 0 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b10 /* word_mask */);

    get_fwd_out(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */, 1 /* dest_id */, 0b10 /* word_mask*/);

    put_rsp_in(RSP_INV_ACK_SPDX /* rsp_msg */, addr.word /* addr */, line /* line */, 1 /* req_id */, 0b11 /* word_mask */);

    get_rsp_out(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		0 /* req_id */, 0 /* dest_id */, 0 /* woff */, 0b10 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 3: ReqV
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82518100;
    addr.breakdown(base_addr);
    word = 0xdeadbeefdead3333;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_req_in(REQ_V /* coh_msg */, addr.word /* addr */, 0 /* line */, 0 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b01 /* word_mask */);

    get_mem_req(0 /* hwrite */, WORD /* hsize */, DATA /* hprot */, addr.word /* addr */, 0 /* line */);

    put_mem_rsp(line /* line */);

    get_rsp_out(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		0 /* req_id */, 0 /* dest_id */, 0 /* woff */, 0b01 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // now send a ReqS from other cache - there should be no
    // coherence action
    ////////////////////////////////////////////////////////////////
    put_req_in(REQ_S /* coh_msg */, addr.word /* addr */, 0 /* line */, 1 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b11 /* word_mask */);

    get_rsp_out(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		1 /* req_id */, 1 /* dest_id */, 0 /* woff */, 0b11 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // now send a ReqV from the first cache again - 
    // There should be no coherence action
    ////////////////////////////////////////////////////////////////
    put_req_in(REQ_V /* coh_msg */, addr.word /* addr */, 0 /* line */, 0 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b01 /* word_mask */);

    get_rsp_out(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		0 /* req_id */, 0 /* dest_id */, 0 /* woff */, 0b01 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // now send a ReqO from the second cache again - 
    // again no invalidation
    ////////////////////////////////////////////////////////////////
    put_req_in(REQ_O /* coh_msg */, addr.word /* addr */, 0 /* line */, 1 /* req_id */,
		DATA /* hprot */, 0 /* woff */, 0 /* wvalid */, 0b11 /* word_mask */);

    get_rsp_out(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */, 0 /* invack_cnt */,
		1 /* req_id */, 1 /* dest_id */, 0 /* woff */, 0b11 /* word_mask */);

    wait();

	CACHE_REPORT_VAR(sc_time_stamp(), "[SPANDEX] Error count", error_count);

    // End simulation
    sc_stop();
}

/*
 * Functions
 */

inline void llc_spandex_tb::reset_llc_test()
{
    llc_req_in_tb.reset_put();
    llc_dma_req_in_tb.reset_put();
    llc_rsp_in_tb.reset_put();
    llc_mem_rsp_tb.reset_put();
    llc_rst_tb_tb.reset_put();
    llc_rsp_out_tb.reset_get();
    llc_dma_rsp_out_tb.reset_get();
    llc_fwd_out_tb.reset_get();
    llc_mem_req_tb.reset_get();
    llc_rst_tb_done_tb.reset_get();

    wait();
}

void llc_spandex_tb::get_rsp_out(coh_msg_t coh_msg, addr_t addr, line_t line, invack_cnt_t invack_cnt,
		     cache_id_t req_id, cache_id_t dest_id, word_offset_t woff, word_mask_t word_mask)
{
    llc_rsp_out_t<CACHE_ID_WIDTH> rsp_out;

    llc_rsp_out_tb.get(rsp_out);

    if (rsp_out.coh_msg != coh_msg       ||
	rsp_out.addr   != addr.range(TAG_RANGE_HI, SET_RANGE_LO) ||
	(rsp_out.coh_msg != RSP_O && rsp_out.line   != line)         ||
	rsp_out.invack_cnt != invack_cnt ||
	rsp_out.req_id != req_id         ||
	rsp_out.dest_id != dest_id ||
	rsp_out.word_offset != woff ||
	rsp_out.word_mask != word_mask
	) {
	
	CACHE_REPORT_ERROR("coh_msg get rsp out", rsp_out.coh_msg);
	CACHE_REPORT_ERROR("coh_msg get rsp out gold", coh_msg);
	CACHE_REPORT_ERROR("addr get rsp out", rsp_out.addr);
	CACHE_REPORT_ERROR("addr get rsp out gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("line get rsp out", rsp_out.line);
	CACHE_REPORT_ERROR("line get rsp out gold", line);
	CACHE_REPORT_ERROR("invack_cnt get rsp out", rsp_out.invack_cnt);
	CACHE_REPORT_ERROR("invack_cnt get rsp out gold", invack_cnt);
	CACHE_REPORT_ERROR("req_id get rsp out", rsp_out.req_id);
	CACHE_REPORT_ERROR("req_id get rsp out gold", req_id);
	CACHE_REPORT_ERROR("dest_id get rsp out", rsp_out.dest_id);
	CACHE_REPORT_ERROR("dest_id get rsp out gold", dest_id);
	CACHE_REPORT_ERROR("woff get rsp out", rsp_out.word_offset);
	CACHE_REPORT_ERROR("woff get rsp out gold", woff);
	CACHE_REPORT_ERROR("word_mask get rsp out", rsp_out.word_mask);
	CACHE_REPORT_ERROR("word_mask get rsp out gold", word_mask);

    error_count++;
    }
    if (RPT_TB)
	CACHE_REPORT_VAR(sc_time_stamp(), "RSP_OUT", rsp_out);
}

void llc_spandex_tb::get_dma_rsp_out(coh_msg_t coh_msg, addr_t addr, line_t line, invack_cnt_t invack_cnt,
			 llc_coh_dev_id_t req_id, cache_id_t dest_id, word_offset_t woff)
{
    llc_rsp_out_t<LLC_COH_DEV_ID_WIDTH> rsp_out;

    llc_dma_rsp_out_tb.get(rsp_out);

    if (rsp_out.coh_msg != coh_msg       ||
	rsp_out.addr   != addr.range(TAG_RANGE_HI, SET_RANGE_LO) ||
	rsp_out.line   != line           ||
	rsp_out.invack_cnt != invack_cnt ||
	rsp_out.req_id != req_id         ||
	rsp_out.dest_id != dest_id ||
	rsp_out.word_offset != woff
	) {
	
	CACHE_REPORT_ERROR("coh_msg get rsp out", rsp_out.coh_msg);
	CACHE_REPORT_ERROR("coh_msg get rsp out gold", coh_msg);
	CACHE_REPORT_ERROR("addr get rsp out", rsp_out.addr);
	CACHE_REPORT_ERROR("addr get rsp out gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("line get rsp out", rsp_out.line);
	CACHE_REPORT_ERROR("line get rsp out gold", line);
	CACHE_REPORT_ERROR("invack_cnt get rsp out", rsp_out.invack_cnt);
	CACHE_REPORT_ERROR("invack_cnt get rsp out gold", invack_cnt);
	CACHE_REPORT_ERROR("req_id get rsp out", rsp_out.req_id);
	CACHE_REPORT_ERROR("req_id get rsp out gold", req_id);
	CACHE_REPORT_ERROR("dest_id get rsp out", rsp_out.dest_id);
	CACHE_REPORT_ERROR("dest_id get rsp out gold", dest_id);
	CACHE_REPORT_ERROR("woff get rsp out", rsp_out.dest_id);
	CACHE_REPORT_ERROR("woff get rsp out gold", dest_id);

    error_count++;
    }
    if (RPT_TB)
	CACHE_REPORT_VAR(sc_time_stamp(), "RSP_OUT", rsp_out);
}

void llc_spandex_tb::get_fwd_out(mix_msg_t coh_msg, addr_t addr, cache_id_t req_id, cache_id_t dest_id, word_mask_t word_mask)
{
    llc_fwd_out_t fwd_out;

    llc_fwd_out_tb.get(fwd_out);

    if (fwd_out.coh_msg != coh_msg       ||
	fwd_out.addr   != addr.range(TAG_RANGE_HI, SET_RANGE_LO) ||
	fwd_out.req_id != req_id         ||
	fwd_out.dest_id != dest_id ||
	fwd_out.word_mask != word_mask
	) {
	
	CACHE_REPORT_ERROR("coh_msg get fwd out", fwd_out.coh_msg);
	CACHE_REPORT_ERROR("coh_msg get fwd out gold", coh_msg);
	CACHE_REPORT_ERROR("addr get fwd out", fwd_out.addr);
	CACHE_REPORT_ERROR("addr get fwd out gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("req_id get fwd out", fwd_out.req_id);
	CACHE_REPORT_ERROR("req_id get fwd out gold", req_id);
	CACHE_REPORT_ERROR("dest_id get fwd out", fwd_out.dest_id);
	CACHE_REPORT_ERROR("dest_id get fwd out gold", dest_id);
	CACHE_REPORT_ERROR("word_mask get fwd out", fwd_out.word_mask);
	CACHE_REPORT_ERROR("word_mask get fwd out gold", word_mask);

    error_count++;
    }
    if (RPT_TB)
	CACHE_REPORT_VAR(sc_time_stamp(), "FWD_OUT", fwd_out);
}

void llc_spandex_tb::get_mem_req(bool hwrite, hsize_t hsize, hprot_t hprot, addr_t addr, line_t line)
{
    llc_mem_req_t mem_req;

    mem_req = llc_mem_req_tb.get();

    if (mem_req.hwrite != hwrite ||
	mem_req.hsize  != hsize ||
	mem_req.hprot  != hprot ||
	mem_req.addr   != addr.range(TAG_RANGE_HI, SET_RANGE_LO)   ||
	mem_req.line   != line) {
	
	CACHE_REPORT_ERROR("get mem req", mem_req.hwrite);
	CACHE_REPORT_ERROR("get mem req gold", hwrite);
	CACHE_REPORT_ERROR("get mem req", mem_req.hsize);
	CACHE_REPORT_ERROR("get mem req gold", hsize);
	CACHE_REPORT_ERROR("get mem req", mem_req.hprot);
	CACHE_REPORT_ERROR("get mem req gold", hprot);
	CACHE_REPORT_ERROR("get mem req", mem_req.addr);
	CACHE_REPORT_ERROR("get mem req gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("get mem req", mem_req.line);
	CACHE_REPORT_ERROR("get mem req gold", line);

    error_count++;
    }
    if (RPT_TB)
	CACHE_REPORT_VAR(sc_time_stamp(), "MEM_REQ", mem_req);
}

void llc_spandex_tb::put_mem_rsp(line_t line)
{
    llc_mem_rsp_t mem_rsp;
    mem_rsp.line = line;

    // rand_wait();

    llc_mem_rsp_tb.put(mem_rsp);

    if (RPT_TB)
	CACHE_REPORT_VAR(sc_time_stamp(), "MEM_RSP", mem_rsp);
}

void llc_spandex_tb::put_req_in(mix_msg_t coh_msg, addr_t addr, line_t line, cache_id_t req_id,
			hprot_t hprot, word_offset_t woff, word_offset_t wvalid, word_mask_t word_mask)
{
    llc_req_in_t<CACHE_ID_WIDTH> req_in;
    req_in.coh_msg = coh_msg;
    req_in.hprot = hprot;
    req_in.addr = addr.range(TAG_RANGE_HI, SET_RANGE_LO);
    req_in.line = line;
    req_in.req_id = req_id;
    req_in.word_offset = woff;
    req_in.valid_words = wvalid;
    req_in.word_mask = word_mask;

    // rand_wait();

    llc_req_in_tb.put(req_in);

    if (RPT_TB)
	CACHE_REPORT_VAR(sc_time_stamp(), "REQ_IN", req_in);
}

void llc_spandex_tb::put_dma_req_in(mix_msg_t coh_msg, addr_t addr, line_t line, llc_coh_dev_id_t req_id,
                            hprot_t hprot, word_offset_t woff, word_offset_t wvalid)
{
    llc_req_in_t<LLC_COH_DEV_ID_WIDTH> req_in;
    req_in.coh_msg = coh_msg;
    req_in.hprot = hprot;
    req_in.addr = addr.range(TAG_RANGE_HI, SET_RANGE_LO);
    req_in.line = line;
    req_in.req_id = req_id;
    req_in.word_offset = woff;
    req_in.valid_words = wvalid;

    // rand_wait();

    llc_dma_req_in_tb.put(req_in);

    if (RPT_TB)
	CACHE_REPORT_VAR(sc_time_stamp(), "REQ_IN", req_in);
}

void llc_spandex_tb::put_rsp_in(coh_msg_t rsp_msg, addr_t addr, line_t line, cache_id_t req_id, word_mask_t word_mask)
{
    llc_rsp_in_t rsp_in;
    rsp_in.coh_msg = rsp_msg;
    rsp_in.addr = addr.range(TAG_RANGE_HI, SET_RANGE_LO);
    rsp_in.line = line;
    rsp_in.req_id = req_id;
    rsp_in.word_mask = word_mask;

    // rand_wait();

    llc_rsp_in_tb.put(rsp_in);

    if (RPT_TB)
	CACHE_REPORT_VAR(sc_time_stamp(), "RSP_IN", rsp_in);
}
