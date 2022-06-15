/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

	Modified by Zeran Zhu, Robert Jin, Vignesh Suresh
	zzhu35@illinois.edu
	
	April 9 2021

*/

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
    line_t line, line1, req_line, fwd_line;
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

    error_count = 0;

    ////////////////////////////////////////////////////////////////
    // TEST 1: setting a lock - AMO_SWAP
    ////////////////////////////////////////////////////////////////
    addr.breakdown(base_addr);

    word = 0x1;
    line = 0x1;
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0001 /* word_mask */);

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(0 /* line */);

    wait();

    // current_valid_state = 2;

    ////////////////////////////////////////////////////////////////
    // somebody trying to set - FWD_REQ_Odata
    ////////////////////////////////////////////////////////////////
    put_fwd_in(FWD_REQ_Odata /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
        line /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_Odata /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
        line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);    

    wait();

    ////////////////////////////////////////////////////////////////
    // somebody doing self-invalidating read of lock - FWD_REQ_V
    ////////////////////////////////////////////////////////////////
    put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
        0 /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_NACK /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
        0 /* line */, 0b0001 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // checking lock value - Req_S
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    ////////////////////////////////////////////////////////////////
    // releasing lock - AMO_SWAP
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0001 /* word_mask */);

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    // current_valid_state = 3;

    ////////////////////////////////////////////////////////////////
    // set lock again - AMO_SWAP
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(0 /* line */);

    wait();

    // current_valid_state = 4;

    ////////////////////////////////////////////////////////////////
    // reading lock - WB and ReqS
    // TODO in the previous step, we did Req_Odata, but here, since
    // the line was not fully owned, it became fully shared. This might
    // be okay since shared state must be on line basis, so we
    // need to sacrifice the partially owned state
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);    

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2: writing to location and immediately reading back
    // TODO this is not working as expected. Even for ReqO,
    // if there is a hit in the MSHR, there is a set conflict
    // and the following ReqS is serviced only if the RspO is returned
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82518450;
    addr.breakdown(base_addr);
    word = 0xdeadbeefdead0000;
    base_addr1 = 0x82518458;
    addr1.breakdown(base_addr1);
    word1 = 0xdeadbeefdead1111;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word1;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr1.word /* addr */, word1 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // Reading the same written line with FWD_REQ_V and FWD_REQ_S
    ////////////////////////////////////////////////////////////////
    put_fwd_in(FWD_REQ_V /* coh_msg */, addr1.word /* addr */, 1 /* req_id */,
        0 /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_V /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr1.word /* addr */,
        line /* line */, 0b0001 /* word_mask */);

    wait();

    put_fwd_in(FWD_REQ_S /* coh_msg */, addr1.word /* addr */, 2 /* req_id */,
        0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 2 /* req_id */, 0 /* to_req */, addr1.word /* addr */,
        line /* line */, 0b0011 /* word_mask */);

    wait();

    get_rsp_out(RSP_S /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr1.word /* addr */,
        line /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr1.word /* addr */, DATA /* hprot */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 3: Read new line with different request types
    // TODO even if the requested data is not full line, in case of
    // reqV, we are requesting the full line with full word_mask.
    // This must have been partial word_mask. In the FSM, we are
    // checking which words in the line are not valid and sending
    // request for all of them.
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82528450;
    addr.breakdown(base_addr);
    word = 0xdeadbeefdead2222;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word + 0x1111;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // read again with ReqV
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // read again with ReqS
    // TODO this is responding without sending the request to LLC
    // the FSM only checks whether all the words in the line are valid,
    // not shared.
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // self-invalidating read with ReqV
    // TODO when self-invalidating, we cannot use current_valid_state
    // variable because for those intermediate valid states, we are
    // not invalidating the L1.
    // If we need to change it, we might need to do away with
    // current_valid_state completely and invalidate all valid lines
    // for every acquire.
    ////////////////////////////////////////////////////////////////
    word = 0xdeadbeefdead4444;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word + 0x1111;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 1 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    // current_valid_state = 5;

    ////////////////////////////////////////////////////////////////
    // self-invalidating read with ReqS
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 1 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    // current_valid_state = 6;

    // get_inval(addr.word /* addr */, DATA /* hprot */);    

    // wait();

    // get_inval(addr.word /* addr */, DATA /* hprot */);    

    ////////////////////////////////////////////////////////////////
    // TEST 4: write to this line and try to return with ReqV
    // Note: when we write only one word and send ReqS, we get a WB hit
    // which we dispatch. This write buffer entry has only 1 word, unlike
    // the previous test where we had both words.
    ////////////////////////////////////////////////////////////////
    word = 0xdeadbeefdead6666;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word - 0x1111;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
    //     0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    // get_rd_rsp(line /* line */);

    // wait();

    ////////////////////////////////////////////////////////////////
    // try to return with ReqS
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;

    get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word - 0x1111;

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);    

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // write to the next line and try to return with ReqV
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82528460;
    addr.breakdown(base_addr);
    word = 0xdeadbeefdead8888;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0010 /* word_mask */);

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0010 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // try to return with ReqS
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);    

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 5: testing self-invalidate
    // we will load many lines using ReqV and then end the phase
    // with one self-invalidate
    ////////////////////////////////////////////////////////////////
    for (int i = 0; i < WORDS_PER_LINE * L2_WAYS; i++) {
        base_addr = 0x82520000 + 0x8*i;
        addr.breakdown(base_addr);

        put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, 0 /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        if (i%2 == 0) {
            word = 0xcafedeadcafede00 + 0x1*i;
            line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
            line.range(BITS_PER_WORD - 1, 0) = word;

            get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
                DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

            put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
                0b0011 /* word_mask */, 0 /* invack_cnt */);
        }

        get_rd_rsp(line /* line */);

        wait();
    }

    for (int i = 0; i < SPX_MAX_V; i++) {
        l2_fence_tb.put(0x1);
        wait();
    }

    for (int i = 0; i < WORDS_PER_LINE * L2_WAYS; i++) {
        base_addr = 0x82520000 + 0x8*i;
        addr.breakdown(base_addr);

        // get_inval(addr.word /* addr */, DATA /* hprot */);

        wait();  
    }

    ////////////////////////////////////////////////////////////////
    // we will now send FWD_REQ_V to get nacks for all these lines
    ////////////////////////////////////////////////////////////////
    for (int i = 0; i < WORDS_PER_LINE * L2_WAYS; i++) {
        base_addr = 0x82520000 + 0x8*i;
        addr.breakdown(base_addr);

        put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            0 /* line */, 0b0001 /* word_mask */);

        get_rsp_out(RSP_NACK /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0001 /* word_mask */);

        wait();
    }

    ////////////////////////////////////////////////////////////////
    // TEST 6: fill up the reqs buffer with ReqO's
    // First we fill the WB with N_WB entries
    ////////////////////////////////////////////////////////////////
    for (int i = 0; i < N_WB; i++) {
        base_addr = 0x82520100 + 0x10*i;
        addr.breakdown(base_addr);
        word = 0xdeadcafedeafca00 + 0x1*i;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        wait();
    }

    ////////////////////////////////////////////////////////////////
    // Then we add N_REQS more requests to fill up the reqs buffer
    // and receive N_REQS dispatches from the WB
    // TODO we are seeing the same entry of the WB being evicted
    // because we are checking for WORD_MASK_ALL. Even peek_wb
    // is written to pick the last entry that is free not the first.
    ////////////////////////////////////////////////////////////////
    for (int i = N_WB; i < N_WB+N_REQS; i++) {
        base_addr = 0x82520100 + 0x10*i;
        addr.breakdown(base_addr);
        word = 0xdeadcafedeafca00 + 0x1*i;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        base_addr = 0x82520100 + 0x10*(i-1);
        addr.breakdown(base_addr);
        word = 0xdeadcafedeafca00 + 0x1*(i-1);
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

        wait();
    }

    ////////////////////////////////////////////////////////////////
    // send the response for the entries in the MSHR
    ////////////////////////////////////////////////////////////////
    for (int i = N_WB; i < N_WB+N_REQS; i++) {
        base_addr = 0x82520100 + 0x10*(i-1);
        addr.breakdown(base_addr);
        word = 0xdeadcafedeafca00 + 0x1*(i-1);
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
            0b0001 /* word_mask */, 0 /* invack_cnt */);

        wait();
    }

    ////////////////////////////////////////////////////////////////
    // flush the write buffer and add entries to the MSHR
    // TODO the entries are received in a different order than what
    // is expected
    ////////////////////////////////////////////////////////////////
    l2_fence_tb.put(0x2);

    base_addr = 0x82520100 + 0x10*(N_WB+N_REQS-1);
    addr.breakdown(base_addr);
    word = 0xdeadcafedeafca00 + 0x1*(N_WB+N_REQS-1);
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    for (int i = N_WB-2; i >= 0; i--) {
        base_addr = 0x82520100 + 0x10*i;
        addr.breakdown(base_addr);
        word = 0xdeadcafedeafca00 + 0x1*i;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
            0b0001 /* word_mask */, 0 /* invack_cnt */);

        wait();
    }

    ///////////////////////////////////////////////////////////////
    // TEST 7: Invalidation forwards. We will first bring
    // lines into shared state and then send invalidation requests
    // and then again try to read them
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82530800;
    addr.breakdown(base_addr);
    word = 0xdeadbeefdeadbeef;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    ////////////////////////////////////////////////////////////////
    // we will now send an invalidate
    ////////////////////////////////////////////////////////////////
    put_fwd_in(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);    

    wait();

    get_rsp_out(RSP_INV_ACK_SPDX /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0011 /* word_mask */);

    ////////////////////////////////////////////////////////////////
    // repeat the above experiment for fwd_stall
    // in this case, the REQ_S is assumed to reach the LLC after
    // the original invalidate forward is sent out. In other words,
    // the ownership request from another L2 came first. Therefore,
    // the LLC should be sending the updating line from the owner.
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    put_fwd_in(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_INV_ACK_SPDX /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    ////////////////////////////////////////////////////////////////
    // TEST 8: partial FWD_REQ_O
    // TODO this is invalidating the whole line from L1 cache, even
    // though the ownership transfer was for 1 word only. We might
    // not be able to do anything about that now since the L1 tracks
    // on line granularity
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82531800;
    addr.breakdown(base_addr);
    word = 0xbeefdeadbeefdead;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE/* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    base_addr = 0x82531808;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, WRITE/* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    base_addr = 0x82531800;
    addr.breakdown(base_addr);

    get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    put_fwd_in(FWD_REQ_O /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            0 /* line */, 0b0010 /* word_mask */);

    get_rsp_out(RSP_O /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0010 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    ////////////////////////////////////////////////////////////////
    // TODO now, if there is a ReqV for a single word, we're
    // fetching the remaining words from LLC - not necessary
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0010 /* word_mask */);

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0010 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    ////////////////////////////////////////////////////////////////
    // now, send a revoke ownership request
    ////////////////////////////////////////////////////////////////
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 9: partial FWD_WTfwd
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82532800;
    addr.breakdown(base_addr);
    word = 0xbeefdeadbeefdead;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE/* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    base_addr = 0x82532808;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, WRITE/* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    base_addr = 0x82532800;
    addr.breakdown(base_addr);

    get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    word = 0xcafedeadcafedead;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = 0;

    put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            line /* line */, 0b0010 /* word_mask */);

    get_rsp_out(RSP_O /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0010 /* word_mask */);

    wait();

    ////////////////////////////////////////////////////////////////
    // revoke one word in the line and retry the earlier experiment
    ////////////////////////////////////////////////////////////////
    word = 0xbeefdeadbeefdead;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    ////////////////////////////////////////////////////////////////
    // TEST 10: flush
    ////////////////////////////////////////////////////////////////
    l2_flush_tb.put(0x1);

    for (int i = 0; i < N_WB+N_REQS; i++) {
        base_addr = 0x82520100 + 0x10*i;
        addr.breakdown(base_addr);
        word = 0xdeadcafedeafca00 + 0x1*i;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

        put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
             0b0001 /* word_mask */, 0 /* invack_cnt */);

        wait();
    }

    base_addr = 0x82532800;
    addr.breakdown(base_addr);

    word = 0xcafedeadcafedead;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    word = 0xbeefdeadbeefdead;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 11: Half-word atomics
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82080100;
    addr.breakdown(base_addr);

    word = 0x22222222;
    word1 = 0x1111111111111111;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    line.range(BITS_PER_WORD - 1, 0) = word1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0001 /* word_mask */);

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    // current_valid_state = 2;

    ////////////////////////////////////////////////////////////////
    // send atomic write for next word also
    ////////////////////////////////////////////////////////////////
    base_addr = 0x8208010C;
    addr.breakdown(base_addr);

    word = 0x3333333300000000;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, word /* word */, DATA /* hprot */,
        AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0010 /* word_mask */);

    word1 = 0x1111111111111111;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word1;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0010 /* word_mask */, 0 /* invack_cnt */);

    word1 = 0x1111111122222222;
    line.range(BITS_PER_WORD - 1, 0) = word1;

    get_rd_rsp(line /* line */);

    wait();

    // current_valid_state = 3;

    ////////////////////////////////////////////////////////////////
    // checking lock value - Req_S
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    word1 = 0x3333333311111111;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word1;

    get_rd_rsp(line /* line */);

    ////////////////////////////////////////////////////////////////
    // TEST 12: LR-SC
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82080880;
    addr.breakdown(base_addr);

    word = 0x1111111111111111;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b01 /* word_mask */);

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b01 /* word_mask */, 0 /* invack_cnt */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b10 /* word_mask */);

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b10 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    base_addr = 0x82080888;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    base_addr = 0x82080880;
    addr.breakdown(base_addr);

    word = 0x2222222222222222;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_EXOKAY);

    wait();

    ////////////////////////////////////////////////////////////////
    // repeat the same but with a forward in between
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
        0 /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_V /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0001 /* word_mask */);

    wait();

    word = 0x3333333333333333;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_OKAY);

    wait();

    ////////////////////////////////////////////////////////////////
    // read the modified location
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);    

    // put_fwd_in(FWD_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    //     0 /* line */, 0b0001 /* word_mask */);

    // wait();

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // word = 0x1111111111111111;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    word = 0x1111111111111111;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 13: repeat above test for sub-word granularity LR-SC
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82080980;
    addr.breakdown(base_addr);

    word = 0x3333333333333333;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, WORD_MASK_ALL /* word_mask */);

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        WORD_MASK_ALL /* word_mask */, 0 /* invack_cnt */);

    word = 0x3333333333333333;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_rd_rsp(line /* line */);

    wait();

    word = 0x44444444;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_EXOKAY);

    wait();

    ////////////////////////////////////////////////////////////////
    // repeat the same but with a forward in between
    ////////////////////////////////////////////////////////////////
    word = 0x3333333344444444;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
        0 /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_V /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0001 /* word_mask */);

    wait();

    word = 0x55555555;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_OKAY);

    wait();

    ////////////////////////////////////////////////////////////////
    // read the modified location
    ////////////////////////////////////////////////////////////////
    // word = 0x3333333355555555;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD_32 /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);    

    // put_fwd_in(FWD_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    //     0 /* line */, 0b0001 /* word_mask */);

    // wait();

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // word = 0x3333333333333333;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 14: repeat above test for sub-word granularity LR-SC
    // at 4-byte aligned address
    ////////////////////////////////////////////////////////////////
    base_addr = 0x82080A8C;
    addr.breakdown(base_addr);

    word = 0x6666666666666666;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, WORD_MASK_ALL /* word_mask */);

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        WORD_MASK_ALL /* word_mask */, 0 /* invack_cnt */);

    word = 0x6666666666666666;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_rd_rsp(line /* line */);

    wait();

    word = 0x7777777700000000;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_EXOKAY);

    wait();

    ////////////////////////////////////////////////////////////////
    // repeat the same but with a forward in between
    ////////////////////////////////////////////////////////////////
    word = 0x7777777766666666;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
        0 /* line */, 0b0010 /* word_mask */);

    get_rsp_out(RSP_V /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0010 /* word_mask */);

    wait();

    word = 0x8888888800000000;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_OKAY);

    wait();

    ////////////////////////////////////////////////////////////////
    // read the modified location
    ////////////////////////////////////////////////////////////////
    // word = 0x8888888866666666;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);    

    // put_fwd_in(FWD_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    //     0 /* line */, 0b0010 /* word_mask */);

    // wait();

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // word = 0x6666666666666666;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    word = 0x6666666666666666;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 15: non-atomic sub-word granularities
    ////////////////////////////////////////////////////////////////
    base_addr = 0x820A820C;
    addr.breakdown(base_addr);

    word = 0x2222222200000000;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = 0;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    word = 0x1111111111111111;
    line1.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line1.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0010 /* word_mask */);

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line1 /* line */,
        0b0010 /* word_mask */, 0 /* invack_cnt */);

    wait();

    word.range(63,32) = 0x22222222;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
            0 /* line */, 0b0010 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 1 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0010 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

	CACHE_REPORT_VAR(sc_time_stamp(), "[SPANDEX] Error count", error_count);

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
    l2_bresp_tb.reset_get();
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

void l2_spandex_tb::get_req_out(coh_msg_t coh_msg, addr_t addr, hprot_t hprot, line_t line, word_mask_t word_mask)
{
    l2_req_out_t req_out;

    req_out = l2_req_out_tb.get();

    if (req_out.coh_msg != coh_msg ||
	req_out.hprot   != hprot ||
	req_out.addr != addr.range(TAG_RANGE_HI, SET_RANGE_LO) ||
	req_out.line != line ||
    req_out.word_mask != word_mask) {

	CACHE_REPORT_ERROR("get req out addr", req_out.addr);
	CACHE_REPORT_ERROR("get req out addr gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("get req out coh_msg", req_out.coh_msg);
	CACHE_REPORT_ERROR("get req out coh_msg gold", coh_msg);
	CACHE_REPORT_ERROR("get req out hprot", req_out.hprot);
	CACHE_REPORT_ERROR("get req out hprot gold", hprot);
	CACHE_REPORT_ERROR("get req out line", req_out.line);
	CACHE_REPORT_ERROR("get req out line gold", line);
	CACHE_REPORT_ERROR("get req out word_mask", req_out.word_mask);
	CACHE_REPORT_ERROR("get req out word_mask gold", word_mask);
    error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "REQ_OUT", req_out);
}

void l2_spandex_tb::get_rsp_out(coh_msg_t coh_msg, cache_id_t req_id, bool to_req, addr_t addr,
    line_t line, word_mask_t word_mask)
{
    l2_rsp_out_t rsp_out;

    rsp_out = l2_rsp_out_tb.get();

    if (rsp_out.coh_msg != coh_msg ||
	(rsp_out.req_id != req_id && to_req) ||
	rsp_out.addr != addr.range(TAG_RANGE_HI, SET_RANGE_LO) ||
	(rsp_out.line != line && (rsp_out.coh_msg == RSP_S ||
                              rsp_out.coh_msg == RSP_Odata || 
                              rsp_out.coh_msg == RSP_RVK_O || 
                              rsp_out.coh_msg == RSP_V)) ||
    rsp_out.word_mask != word_mask) {

	CACHE_REPORT_ERROR("get rsp out addr", rsp_out.addr);
	CACHE_REPORT_ERROR("get rsp out addr gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("get rsp out coh_msg", rsp_out.coh_msg);
	CACHE_REPORT_ERROR("get rsp out coh_msg gold", coh_msg);
	CACHE_REPORT_ERROR("get rsp out req_id", rsp_out.req_id);
	CACHE_REPORT_ERROR("get rsp out req_id gold", req_id);
	CACHE_REPORT_ERROR("get rsp out to_req", rsp_out.to_req);
	CACHE_REPORT_ERROR("get rsp out to_req gold", to_req);
	CACHE_REPORT_ERROR("get rsp out line", rsp_out.line);
	CACHE_REPORT_ERROR("get rsp out line gold", line);
	CACHE_REPORT_ERROR("get rsp out word_mask", rsp_out.word_mask);
	CACHE_REPORT_ERROR("get rsp out word_mask gold", word_mask);
    error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RSP_OUT", rsp_out);
}

void l2_spandex_tb::put_fwd_in(mix_msg_t coh_msg, addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask)
{
    l2_fwd_in_t fwd_in;
    
    fwd_in.coh_msg = coh_msg;
    fwd_in.addr = addr.range(TAG_RANGE_HI, SET_RANGE_LO);
    fwd_in.req_id = req_id;
    fwd_in.line = line;
    fwd_in.word_mask = word_mask;

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
    error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP", rd_rsp);
}

void l2_spandex_tb::get_bresp(sc_uint<2> gold_bresp_val)
{
    sc_uint<2> bresp_val;

    l2_bresp_tb.get(bresp_val);

    if (bresp_val != gold_bresp_val) {
	CACHE_REPORT_ERROR("get bresp", bresp_val);
	CACHE_REPORT_ERROR("get bresp gold", gold_bresp_val);
    error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "BRESP", bresp_val);
}

void l2_spandex_tb::get_inval(addr_t addr, hprot_t hprot)
{
    l2_inval_t inval;
    
    l2_inval_tb.get(inval);

    if (inval.addr != addr.range(TAG_RANGE_HI, SET_RANGE_LO) || inval.hprot != hprot) {
	CACHE_REPORT_ERROR("get inval.addr", inval.addr);
	CACHE_REPORT_ERROR("get inval.addr gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("get inval.hprot", inval.hprot);
	CACHE_REPORT_ERROR("get inval.hprot gold", hprot);
    error_count++;
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
	wait();
    }

    wait();

    if (rpt)
	CACHE_REPORT_INFO("Flush done.");
}
