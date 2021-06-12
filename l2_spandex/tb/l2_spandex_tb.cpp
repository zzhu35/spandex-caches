// Copyright (c) 2011-2019 Columbia University, System Level Design Group
// SPDX-License-Identifier: Apache-2.0

#include "l2_spandex_tb.hpp"

/*
 * Processes
 */

#ifdef STATS_ENABLE
void l2_spandex_tb::get_stats()
{
    l2_stats_tb.reset_get();

    wait();

    while(true) {
	
	bool tmp;

	l2_stats_tb.get(tmp);

	wait();
    }
}
#endif


void l2_spandex_tb::l2_test()
{
    const bool flush_partial = false;
    const bool flush_all = true;

    /*
     * Random seed
     */
    
    // initialize
    srand(time(NULL));

    /*
     * Local variables
     */

    // preparation variables
    addr_breakdown_t addr, addr1, addr2, addr3, addr4, addr5, addr_evict;
    word_t word, word1, word2, word3, word4;
    line_t line, req_line, fwd_line;
    l2_cpu_req_t cpu_req, cpu_req1, cpu_req2, cpu_req3, cpu_req4;
    l2_req_out_t req_out;
    cache_id_t id;
    invack_cnt_t invack;

    addr_t base_addr = 0x82508250;
    addr_t base_addr1 = 0x82518250;

    /*
     * Reset
     */

    reset_l2_test();

    CACHE_REPORT_INFO("[SPANDEX] Reset done!"); 

    ////////////////////////////////////////////////////////////////
    // Fill up the write buffer with N_WB entries
    ////////////////////////////////////////////////////////////////
    addr.breakdown(base_addr);
    word = 0xdeadbeefdead0000;

    for(int i = 0; i < N_WB; i++)
    {
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
                    addr.word /* addr */, word /* word */, DATA /* hprot */,
                    0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                    0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        wait();

        addr.tag_incr(1);
        word += 0x1111;
    }

    CACHE_REPORT_INFO("[SPANDEX] Filling write buffer done!"); 

    ////////////////////////////////////////////////////////////////
    // Generate a ReqV for a different address
    ////////////////////////////////////////////////////////////////
    addr.breakdown(base_addr1);
    word = 0xdeadbeefdead0000;

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
                addr.word /* addr */, 0 /* word */, DATA /* hprot */,
                0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0b0001 /* word_mask */);

    line = 0xdeadbeefdead0000;
    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    CACHE_REPORT_INFO("[SPANDEX] First ReqV done"); 

    ////////////////////////////////////////////////////////////////
    // Insert a fence to self-invalidate the ReqV and flush WB ReqO's
    ////////////////////////////////////////////////////////////////
    rand_wait();

    l2_fence_tb.put(false);

    rand_wait();

    l2_fence_tb.put(true);

    rand_wait();

    CACHE_REPORT_INFO("[SPANDEX] Fence done"); 

    ////////////////////////////////////////////////////////////////
    // Apprehend the ReqO transfers from WB
    ////////////////////////////////////////////////////////////////
    addr.breakdown(base_addr);
    word = 0xdeadbeefdead0000;

    for(int i = 0; i < N_WB; i++)
    {
        get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, (0b0001 << i)/* word_mask */);

        wait();

        addr.tag_incr(1);
    }

    CACHE_REPORT_INFO("[SPANDEX] ReqO servicing done"); 

    ////////////////////////////////////////////////////////////////
    // Generate a ReqV to the same earlier ReqV address
    ////////////////////////////////////////////////////////////////
    addr.breakdown(base_addr1);

    put_cpu_req(cpu_req /* &cpu_req */, READ/* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, 0 /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0b0001 /* word_mask */);

    line = 0xdeadbeefdead0000;
    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    CACHE_REPORT_INFO("[SPANDEX] Second ReqV done"); 

    // End simulation
    sc_stop();

    ////////////////////////////////////////////////////////////////
    // One more write will cause a write buffer dispatch
    // of the oldest WB entries
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
                addr.word /* addr */, word /* word */, DATA /* hprot */,
                0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    addr1.breakdown(base_addr);
    get_req_out(REQ_O /* coh_msg */, addr1.word /* addr */,
        DATA /* hprot */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr1.word /* addr */,
        0 /* line */, 0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    ////////////////////////////////////////////////////////////////
    // Repeat for another entry
    ////////////////////////////////////////////////////////////////
    addr.tag_incr(1);
    addr1.tag_incr(1);
    word += 0x1111;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
                addr.word /* addr */, word /* word */, DATA /* hprot */,
                0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    get_req_out(REQ_O /* coh_msg */, addr1.word /* addr */,
        DATA /* hprot */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr1.word /* addr */,
        0 /* line */, 0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    // End simulation
    sc_stop();
}

/*
 * Functions
 */

inline void l2_spandex_tb::reset_l2_test()
{
    l2_cpu_req_tb.reset_put();
    l2_fwd_in_tb.reset_put();
    l2_rsp_in_tb.reset_put();
    l2_flush_tb.reset_put();
    l2_fence_tb.reset_put();
    l2_rd_rsp_tb.reset_get();
    l2_inval_tb.reset_get();
    l2_req_out_tb.reset_get();
    l2_fwd_out_tb.reset_get();
    l2_rsp_out_tb.reset_get();

    rpt = RPT_TB;

    wait();
}

void l2_spandex_tb::put_cpu_req(l2_cpu_req_t &cpu_req, cpu_msg_t cpu_msg, hsize_t hsize, 
    addr_t addr, word_t word, hprot_t hprot, amo_t amo, bool aq, bool rl, bool dcs_en, 
    bool use_owner_pred, dcs_t dcs, cache_id_t pred_cid)
{
    cpu_req.cpu_msg = cpu_msg;
    cpu_req.hsize = hsize;
    cpu_req.hprot = hprot;
    cpu_req.addr = addr;
    cpu_req.word = word;
	cpu_req.amo = amo;
	cpu_req.aq = aq;
	cpu_req.rl = rl;
	cpu_req.dcs_en = dcs_en;
	cpu_req.use_owner_pred = use_owner_pred;
	cpu_req.dcs = dcs;
	cpu_req.pred_cid = pred_cid;

    l2_cpu_req_tb.put(cpu_req);

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "CPU_REQ", cpu_req);
}

void l2_spandex_tb::get_req_out(coh_msg_t coh_msg, addr_t addr, hprot_t hprot, word_mask_t word_mask)
{
    l2_req_out_t req_out;

    req_out = l2_req_out_tb.get();

    if (req_out.coh_msg != coh_msg ||
	req_out.hprot   != hprot ||
	req_out.addr != addr.range(TAG_RANGE_HI, SET_RANGE_LO) ||
    req_out.word_mask != word_mask) {

	CACHE_REPORT_ERROR("get req out", req_out.addr);
	CACHE_REPORT_ERROR("get req out gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("get req out", req_out.coh_msg);
	CACHE_REPORT_ERROR("get req out gold", coh_msg);
	CACHE_REPORT_ERROR("get req out", req_out.hprot);
	CACHE_REPORT_ERROR("get req out gold", hprot);
	CACHE_REPORT_ERROR("get req out", req_out.word_mask);
	CACHE_REPORT_ERROR("get req out gold", word_mask);
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "REQ_OUT", req_out);
}

void l2_spandex_tb::get_rsp_out(coh_msg_t coh_msg, cache_id_t req_id, bool to_req, addr_t addr, 
			line_t line)
{
    l2_rsp_out_t rsp_out;

    rsp_out = l2_rsp_out_tb.get();

    if (rsp_out.coh_msg != coh_msg ||
	(rsp_out.req_id != req_id && to_req) ||
	rsp_out.addr != addr.range(TAG_RANGE_HI, SET_RANGE_LO) ||
	(rsp_out.line != line && rsp_out.coh_msg == RSP_DATA)) {

	CACHE_REPORT_ERROR("get rsp out", rsp_out.addr);
	CACHE_REPORT_ERROR("get rsp out gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("get rsp out", rsp_out.coh_msg);
	CACHE_REPORT_ERROR("get rsp out gold", coh_msg);
	CACHE_REPORT_ERROR("get rsp out", rsp_out.req_id);
	CACHE_REPORT_ERROR("get rsp out gold", req_id);
	CACHE_REPORT_ERROR("get rsp out", rsp_out.to_req);
	CACHE_REPORT_ERROR("get rsp out gold", to_req);
	CACHE_REPORT_ERROR("get rsp out", rsp_out.line);
	CACHE_REPORT_ERROR("get rsp out gold", line);
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RSP_OUT", rsp_out);
}

void l2_spandex_tb::put_fwd_in(mix_msg_t coh_msg, addr_t addr, cache_id_t req_id)
{
    l2_fwd_in_t fwd_in;
    
    fwd_in.coh_msg = coh_msg;
    fwd_in.addr = addr.range(TAG_RANGE_HI, SET_RANGE_LO);
    fwd_in.req_id = req_id;

    l2_fwd_in_tb.put(fwd_in);

    if (rpt) CACHE_REPORT_VAR(sc_time_stamp(), "FWD_IN", fwd_in);
}

void l2_spandex_tb::put_rsp_in(coh_msg_t coh_msg, addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt)
{
    l2_rsp_in_t rsp_in;
    
    rsp_in.coh_msg = coh_msg;
    rsp_in.addr = addr.range(TAG_RANGE_HI, SET_RANGE_LO);
    rsp_in.invack_cnt = invack_cnt;
    rsp_in.line = line;
    rsp_in.word_mask = word_mask;

    l2_rsp_in_tb.put(rsp_in);

    if (rpt) CACHE_REPORT_VAR(sc_time_stamp(), "RSP_IN", rsp_in);
}

void l2_spandex_tb::get_rd_rsp(line_t line)
{
    l2_rd_rsp_t rd_rsp;

    l2_rd_rsp_tb.get(rd_rsp);

    if (rd_rsp.line != line) {
	CACHE_REPORT_ERROR("get rd rsp", rd_rsp.line);
	CACHE_REPORT_ERROR("get rd rsp gold", line);
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP", rd_rsp);
}

void l2_spandex_tb::get_inval(addr_t addr)
{
    l2_inval_t inval;
    
    l2_inval_tb.get(inval);

    if (inval != addr.range(TAG_RANGE_HI, SET_RANGE_LO)) {
	CACHE_REPORT_ERROR("get inval", inval);
	CACHE_REPORT_ERROR("get inval gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "INVAL", inval);
}

void l2_spandex_tb::flush(int n_lines, bool is_flush_all)
{
    // issue flush
    l2_flush_tb.put(is_flush_all);

    for (int i = 0; i < n_lines; ++i) {
	l2_req_out_t req_out = l2_req_out_tb.get();
	addr_t tmp_addr = req_out.addr << OFFSET_BITS;
	put_fwd_in(FWD_PUTACK, tmp_addr, 0);
	wait();
    }

    wait();

    if (rpt)
	CACHE_REPORT_INFO("Flush done.");
}
