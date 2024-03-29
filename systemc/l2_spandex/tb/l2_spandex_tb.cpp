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
    addr_t base_addr1 = 0x82000000;

    /*
     * Reset
     */

    reset_l2_test();

    CACHE_REPORT_INFO("[SPANDEX] Reset done!");

    error_count = 0;

    ////////////////////////////////////////////////////////////////
    // TEST -1 - Flush
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test -1!");
    addr.breakdown(base_addr1);

    // Write and read to multiple sets and ways - 8 sets and all ways
    for (int j = 0; j < 8; j++) {
        for (int i = 0; i < L2_WAYS; i++) {
            if (i % 2 == 0) {
                put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
                    addr.word /* addr */, 0 /* word */, DATA /* hprot */,
                    0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                    0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
                    DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

                wait();

                word = i+1;
                line.range(BITS_PER_WORD - 1, 0) = word;
                line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

                put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
                    0b0011 /* word_mask */, 0 /* invack_cnt */);        

                get_rd_rsp(line /* line */);

                wait();
            } else {
                word = i+2;

                put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
                    addr.word /* addr */, word /* word */, DATA /* hprot */,
                    0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                    0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
                    DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

                wait();

                word = i+1;
                line.range(BITS_PER_WORD - 1, 0) = word;
                line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

                put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
                    0b0011 /* word_mask */, 0 /* invack_cnt */);                

                wait();
            }

            addr.tag_incr(1);
        }

        addr.set_incr(1);
    }

    l2_flush_tb.put(0x1);
    wait();
    l2_flush_tb.put(0x0);

    addr.breakdown(base_addr1);

    for (int j = 0; j < 8; j++) {
        for (int i = 0; i < L2_WAYS; i++) {
            if (i % 2 == 0) {
                wait();
            } else {
                line.range(BITS_PER_WORD - 1, 0) = i+2;
                line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = i+1;

                get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
                    DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

                wait();

                put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
                    0b0011 /* word_mask */, 0 /* invack_cnt */);

                wait();
            }

            addr.tag_incr(1);
        }

        addr.set_incr(1);
    }    

    ////////////////////////////////////////////////////////////////
    // TEST 0 - Write + Read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0!");
    addr.breakdown(base_addr);

    wait();

    word = 0x1;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x1;
    line.range(BITS_PER_WORD - 1, 0) = 0;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x1;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 0.1 - Write (hit) + Read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0.1!");
    base_addr = 0x82508258;
    addr.breakdown(base_addr);

    word = 0x2;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 0.2 - Write (hit) WORD_32 aligned + Read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0.2!");
    base_addr = 0x82508254;
    addr.breakdown(base_addr);

    word = 0x300000000;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x300000001;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 0.3 - Read + Write (miss) + Read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0.3!");
    base_addr = 0x82508260;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x4444444444444444;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    word = 0x5;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    line.range(BITS_PER_WORD - 1, 0) = 0x0000000000000005;

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 0.4 - Read + Write (miss) WORD_32 aligned + Read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0.4!");
    base_addr = 0x82508270;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x4444444444444444;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    base_addr = 0x82508274;
    word = 0x500000000;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    line.range(BITS_PER_WORD - 1, 0) = 0x0000000544444444;

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 0.5 - Read L2_WAYS+1 times + evict + Read back 1st
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0.5!");
    base_addr = 0x82508280;
    addr.breakdown(base_addr);

    for (int i = 0; i < L2_WAYS+1; i++) {

        put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, 0 /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);
    
        if (i == L2_WAYS) {
            get_inval(0x82508280 /* addr */, DATA /* hprot */);
        }

        get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

        wait();

        line = i+1;

        put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
            0b0011 /* word_mask */, 0 /* invack_cnt */);

        wait();

        get_rd_rsp(line /* line */);

        addr.tag_incr(1);
    }

    base_addr = 0x82508280;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    base_addr = 0x82508280;
    addr.breakdown(base_addr);

    addr.tag_incr(1);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    base_addr = 0x82508280;
    addr.breakdown(base_addr);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0x1;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    base_addr = 0x82508270;
    addr.breakdown(base_addr);

    word = 0x4444444444444444;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = 0x0000000544444444;

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 0.6 - Write L2_WAYS+1 times + evict (write-back)
    // + Read back 1st
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0.6!");
    base_addr = 0x82508380;
    addr.breakdown(base_addr);

    for (int i = 0; i < L2_WAYS; i++) {
        word = i+1;

        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

        wait();

        line = 0;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = i+2;

        put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
            0b0011 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);
    }

    word = L2_WAYS+1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    base_addr = 0x82508380;
    addr.breakdown(base_addr);

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0011 /* word_mask */, 0 /* invack_cnt */);

    addr.tag_incr(L2_WAYS);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    base_addr = 0x82508380;
    addr.breakdown(base_addr);

    addr.tag_incr(1);

    for (int i = 0; i < L2_WAYS; i++) {
        put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, 0 /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        wait();

        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = i+3;
        line.range(BITS_PER_WORD - 1, 0) = i+2;

        get_rd_rsp(line /* line */);

        addr.tag_incr(1);
    }

    ////////////////////////////////////////////////////////////////
    // TEST 0.7 - Back-to-back writes to same line (set conflict),
    // and read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0.7!");
    base_addr = 0x82508480;
    addr.breakdown(base_addr);

    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    base_addr = 0x82508484;
    word = 0x300000000;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    base_addr = 0x82508488;
    addr.breakdown(base_addr);
    word = 0x4;

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    base_addr = 0x8250848C;
    word = 0x500000000;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
        base_addr /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    base_addr = 0x82508480;
    addr.breakdown(base_addr);
    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    base_addr = 0x82508480;
    addr.breakdown(base_addr);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x500000004;
    line.range(BITS_PER_WORD - 1, 0) = 0x300000001;

    wait();

    get_rd_rsp(line /* line */);

    ////////////////////////////////////////////////////////////////
    // TEST 0.8 - Write L2_WAYS+1 times + evict (write-back) + write
    // at same time + Read back 1st
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0.8!");
    base_addr = 0x82508580;
    addr.breakdown(base_addr);

    for (int i = 0; i < L2_WAYS; i++) {
        word = i+1;

        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

        wait();

        line = 0;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = i+2;

        put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
            0b0011 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);
    }

    word = L2_WAYS+1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    base_addr = 0x82508580;
    addr.breakdown(base_addr);

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Write to same line
    addr.tag_incr(L2_WAYS);
    word = 0;
    word.range(2 * BITS_PER_HALFWORD - 1, 1 * BITS_PER_HALFWORD) = L2_WAYS+2;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
        (addr.word + 0x4) /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    word = L2_WAYS+3;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
        (addr.word + 0x8) /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    base_addr = 0x82508580;
    addr.breakdown(base_addr);

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0011 /* word_mask */, 0 /* invack_cnt */);

    addr.tag_incr(L2_WAYS);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    base_addr = 0x82508580;
    addr.breakdown(base_addr);

    addr.tag_incr(1);

    for (int i = 0; i < L2_WAYS; i++) {
        put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, 0 /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        wait();

        if (i == L2_WAYS-1) {
            line.range(4 * BITS_PER_HALFWORD - 1, 3 * BITS_PER_HALFWORD) = 0;
            line.range(3 * BITS_PER_HALFWORD - 1, 2 * BITS_PER_HALFWORD) = L2_WAYS+3;
            line.range(2 * BITS_PER_HALFWORD - 1, 1 * BITS_PER_HALFWORD) = L2_WAYS+2;
            line.range(1 * BITS_PER_HALFWORD - 1, 0 * BITS_PER_HALFWORD) = i+2;
        } else {
            line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = i+3;
            line.range(BITS_PER_WORD - 1, 0) = i+2;
        }

        get_rd_rsp(line /* line */);

        addr.tag_incr(1);
    }

    ////////////////////////////////////////////////////////////////
    // TEST 0.9 - Read, invalidate (no fwd_stall) and read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 0.9!");
    base_addr = 0x82508680;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x1;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    wait();

    // Invalidate
    put_fwd_in(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_INV_ACK_SPDX /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Read back
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x2;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 1.0 - Read, invalidate (with fwd_stall) and read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.0!");
    base_addr = 0x82508780;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // Invalidate
    put_fwd_in(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_INV_ACK_SPDX /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x1;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    wait();

    // Read back
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x2;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 1.1 - Write, revoke (no fwd_stall) and read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.1!");
    base_addr = 0x82508880;
    addr.breakdown(base_addr);

    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    line.range(BITS_PER_WORD - 1, 0) = word;

    // Revoke ownership
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Read back
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x3;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 1.2: setting a counter (AMO_SWAP) and reading back,
    // incrementing the counter (AMO_ADD) and reading back.
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.2!");
    base_addr = 0x82508980;
    addr.breakdown(base_addr);

    word = 0x1;
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    word = 0x2;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    wait();

    get_rd_rsp(line /* line */);

    wait();

    word = 0x1;
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        AMO_ADD /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    wait();

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 1.3: LR, followed by SC and read back. Just SC and get
    // error. LR, revoke, SC and get error.
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.3!");
    base_addr = 0x82508A80;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 1 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x2;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    word = 0x3;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_EXOKAY /* bresp */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_WORD - 1, 0) = word;

    wait();

    get_rd_rsp(line /* line */);

    wait();

    addr.tag_incr(1);

    word = 0x4;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_OKAY /* bresp */);

    word = 0x5;

    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 1 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    // Revoke ownership
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x6;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_OKAY /* bresp */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 1.4 - Write, revoke (with fwd_stall) and read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.4!");
    base_addr = 0x82508B80;
    addr.breakdown(base_addr);

    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    // Revoke ownership
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Read back
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x3;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x3;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 1.5 - Write L2_WAYS+1 times + evict (write-back) + write
    // at same time + Read back 1st
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.5!");
    base_addr = 0x82508C80;
    addr.breakdown(base_addr);

    for (int i = 0; i < L2_WAYS; i++) {
        word = i+1;

        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

        wait();

        line = 0;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = i+2;

        put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
            0b0011 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);
    }

    // Write to same set and cause an eviction.
    word = L2_WAYS+1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    // Evict first line
    base_addr = 0x82508C80;
    addr.breakdown(base_addr);

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Write to different line, not in the same set.
    base_addr = 0x82508D80;
    addr.breakdown(base_addr);

    word = L2_WAYS+2;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    // Send response back for the eviction, after the two above writes.
    base_addr = 0x82508C80;
    addr.breakdown(base_addr);

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0011 /* word_mask */, 0 /* invack_cnt */);

    // Accept the request for the overflow line (not the different set one).
    base_addr = 0x82508C80;
    addr.tag_incr(L2_WAYS);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    // Accept the request different set line.
    base_addr = 0x82508D80;
    addr.breakdown(base_addr);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+3;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    base_addr = 0x82508C80;
    addr.breakdown(base_addr);

    addr.tag_incr(1);

    for (int i = 0; i < L2_WAYS; i++) {
        put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, 0 /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        wait();

        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = i+3;
        line.range(BITS_PER_WORD - 1, 0) = i+2;

        get_rd_rsp(line /* line */);

        addr.tag_incr(1);
    }

    base_addr = 0x82508D80;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+3;
    line.range(BITS_PER_WORD - 1, 0) = L2_WAYS+2;

    get_rd_rsp(line /* line */);

    ////////////////////////////////////////////////////////////////
    // TEST 1.6 - Write, Fence, Write, Forward, Response, Read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.6!");
    base_addr = 0x82508E80;
    addr.breakdown(base_addr);

    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    l2_fence_tb.put(0x2);

    wait();

    // Add a new CPU request to different set
    base_addr = 0x82508F80;
    addr.breakdown(base_addr);

    word = 0x3;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    // Add a forward to a line on a different set
    base_addr = 0x82508D80;
    addr.breakdown(base_addr);

    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = L2_WAYS+2;

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+3;
    line.range(BITS_PER_WORD - 1, 0) = L2_WAYS+2;

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Send response for original request.
    base_addr = 0x82508E80;
    addr.breakdown(base_addr);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    // Receive request and send response for outstanding request.
    base_addr = 0x82508F80;
    addr.breakdown(base_addr);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    // Read back original request and outstanding request.
    base_addr = 0x82508E80;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    get_rd_rsp(line /* line */);
    
    base_addr = 0x82508F80;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x3;

    get_rd_rsp(line /* line */);        

    ////////////////////////////////////////////////////////////////
    // TEST 1.7 - Back-to-back fences
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.7!");
    base_addr = 0x82509080;
    addr.breakdown(base_addr);

    word = 0x1;

    // First write
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    addr.tag_incr(1);

    wait();

    // Second write
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    // Back to back fences
    l2_fence_tb.put(0x1);

    wait(); 

    l2_fence_tb.put(0x3);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    // Read back both writes.
    base_addr = 0x82509080;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    get_rd_rsp(line /* line */);
    
    addr.tag_incr(1);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    get_rd_rsp(line /* line */);      
    
    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 1.8 - Write, AMO release, Write, Fwd, Read back
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.8!");
    base_addr = 0x82509180;
    addr.breakdown(base_addr);

    word = 0x1;

    // First write
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    // Send an AMO with rl semantic
    base_addr = 0x82509280;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // Workaround - this is a line we unknowingly evict from a previous test.
    get_inval(0x8250a280 /* addr */, DATA /* hprot */);

    wait();

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    // Second write to another set
    base_addr = 0x82509480;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    // Put forward in for another line in another set
    base_addr = 0x82509080;
    addr.breakdown(base_addr);

    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Send response to original write.
    base_addr = 0x82509180;
    addr.breakdown(base_addr);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    // Send response to AMO.
    base_addr = 0x82509280;
    addr.breakdown(base_addr);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    // Get request for pending write
    base_addr = 0x82509480;
    addr.breakdown(base_addr);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    // Read back AMO line
    base_addr = 0x82509280;
    addr.breakdown(base_addr);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    wait();

    get_rd_rsp(line /* line */);      
    
    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 1.9 - Write, FWD_REQ_S, Write, FWD_REQ_S (fwd_stall)
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 1.9!");
    base_addr = 0x83500100;
    addr.breakdown(base_addr);

    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();    

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    put_fwd_in(FWD_REQ_S /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    get_rsp_out(RSP_S /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */); 

    wait();

    get_rsp_out(RSP_RVK_O /* coh_msg */, 1 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */); 

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x3;

    // Write to same line again.
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();    

    put_fwd_in(FWD_REQ_S /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x3;

    get_rsp_out(RSP_S /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */); 

    wait();

    get_rsp_out(RSP_RVK_O /* coh_msg */, 2 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */); 

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2.0 - Write, FWD_REQ_Odata, Write, FWD_REQ_Odata (fwd_stall)
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.0!");
    base_addr = 0x83500200;
    addr.breakdown(base_addr);

    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();    

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    put_fwd_in(FWD_REQ_Odata /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    get_rsp_out(RSP_Odata /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */); 

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x3;

    // Write to same line again.
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();    

    put_fwd_in(FWD_REQ_Odata /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x3;

    get_rsp_out(RSP_Odata /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */); 

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2.1 - Read + LR (miss) + FWD_INV + RSP + SC; (EXOKAY)
    //              LR (hit) + Instr Read + SC; (EXOKAY)
    //              LR (hit) + Data Read + SC; (OKAY)
    //              LR (hit) + FWD_INV to different address + SC; (EXOKAY)
    //              LR (hit) + FWD_RVK + SC (OKAY)
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.1!");
    base_addr = 0x83500300;
    addr.breakdown(base_addr);

    ////////////////////////////////////////////////////////////////
    // 1 - Read + LR (miss) + FWD_INV + RSP + SC; (EXOKAY)
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x1;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    get_rd_rsp(line /* line */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 1 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Invalidate
    put_fwd_in(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_INV_ACK_SPDX /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    word = 0x2;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_EXOKAY /* bresp */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_WORD - 1, 0) = word;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // 2 - LR (hit) + Instr Read + SC; (EXOKAY)
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 1 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    addr.tag_incr(1);
    
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, INSTR /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        INSTR /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x4;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    base_addr = 0x83500300;
    addr.breakdown(base_addr);

    word = 0x3;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_EXOKAY /* bresp */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x1;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // 3 - LR (hit) + Data Read + SC; (OKAY)
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 1 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    addr.tag_incr(2);
    
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x4;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    base_addr = 0x83500300;
    addr.breakdown(base_addr);

    word = 0x5;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_EXOKAY /* bresp */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x1;
    line.range(BITS_PER_WORD - 1, 0) = 0x5;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // 4 - LR (hit) + FWD_INV to different address + SC; (EXOKAY)
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 1 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    addr.tag_incr(2);
    
    // Invalidate
    put_fwd_in(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_INV_ACK_SPDX /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    base_addr = 0x83500300;
    addr.breakdown(base_addr);

    word = 0x5;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_EXOKAY /* bresp */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x1;
    line.range(BITS_PER_WORD - 1, 0) = 0x5;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // 5 - LR (hit) + FWD_RVK + SC (OKAY)
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 1 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    // Revoke
    put_fwd_in(FWD_REQ_S /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_S /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);

    wait();

    get_rsp_out(RSP_RVK_O /* coh_msg */, 1 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);
        
    wait();

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x6;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_bresp(BRESP_OKAY /* bresp */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x5;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2.2 - {WRITE x L2_WAYS} + FWD_STALL + REQWB + FWD_REQODATA
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.2!");
    base_addr = 0x83500400;
    addr.breakdown(base_addr);
    
    for (int i = 0; i < L2_WAYS; i++) {
        word = i+1;

        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

        wait();

        line = 0;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = i+2;

        put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
            0b0011 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);
    }

    wait();

    // Write to same set and cause an eviction.
    word = L2_WAYS+1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = 0x1;

    // Evict first line
    base_addr = 0x83500400;
    addr.breakdown(base_addr);

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();            

    // Get request for the pending new write
    addr.tag_incr(L2_WAYS);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    // Write unrelated line
    base_addr = 0x83500420;
    addr.breakdown(base_addr);

    word = L2_WAYS+4;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();
   
    // Add a forward from other core at the same time - FWD_STALL
    put_fwd_in(FWD_REQ_Odata /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    wait();

    // Write to same set again and cause an eviction.
    word = L2_WAYS+2;
    base_addr = 0x83500400;
    addr.breakdown(base_addr);
    addr.tag_incr(L2_WAYS);
    addr.tag_incr(1);

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // Evict second line
    base_addr = 0x83500400;
    addr.breakdown(base_addr);
    addr.tag_incr(1);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x3;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x1;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    // Add a forward from other core at the same time - should be stalled
    base_addr = 0x83500400;
    addr.breakdown(base_addr);
    addr.tag_incr(1);

    put_fwd_in(FWD_REQ_Odata /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    for (int i = 0; i < 32; i++) {
        wait();
    }

    wait();

    // Put response for the pending write to unrelated line
    base_addr = 0x83500420;
    addr.breakdown(base_addr);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+3;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    // Put response for write-back
    base_addr = 0x83500400;
    addr.breakdown(base_addr);
    addr.tag_incr(1);

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    // Get response for pending forward to unrelated line
    base_addr = 0x83500420;
    addr.breakdown(base_addr);

    word = L2_WAYS+4;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_rsp_out(RSP_Odata /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */); 

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Get response for pending forward
    base_addr = 0x83500400;
    addr.breakdown(base_addr);
    addr.tag_incr(1);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x3;
    line.range(BITS_PER_WORD - 1, 0) = 0x2;

    get_rsp_out(RSP_Odata /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */); 

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Get request for the pending new write
    addr.tag_incr(L2_WAYS);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+3;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

#ifndef USE_WB
    ////////////////////////////////////////////////////////////////
    // TEST 2.3 - ReqWTFwd (hit and miss - SPX_I, SPX_S,
    // wrong word SPX_R) and no empty_way_found
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.3!");
    base_addr = 0x83500500;
    addr.breakdown(base_addr);

    ////////////////////////////////////////////////////////////////
    // HIT
    ////////////////////////////////////////////////////////////////
    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    word = 0x3;

    // ReqWTFwd to word 0
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    wait();

    word = 0x4;

    // ReqWTFwd to word 1
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x4;
    line.range(BITS_PER_WORD - 1, 0) = 0x3;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // MISS - SPX_I
    ////////////////////////////////////////////////////////////////
    // Revoke line
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x5;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    wait();

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = 0x5;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x6;

    // ReqWTFwd to word 1 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x6;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0010 /* word_mask */, 0 /* invack_cnt */);

    wait();

    ////////////////////////////////////////////////////////////////
    // MISS - SPX_S
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x8;
    line.range(BITS_PER_WORD - 1, 0) = 0x7;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    word = 0x9;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    wait();

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = 0x9;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0xA;

    // ReqWTFwd to word 1 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0xA;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0010 /* word_mask */, 0 /* invack_cnt */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0xC;
    line.range(BITS_PER_WORD - 1, 0) = 0xB;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // MISS - SPX_R (wrong word)
    ////////////////////////////////////////////////////////////////
    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    line.range(BITS_PER_WORD - 1, 0) = word;

    // Revoke one word in the line
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0010 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0010 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x3;

    // ReqWTFwd to word 1 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0010 /* word_mask */, 0 /* invack_cnt */);

    wait();

    base_addr = 0x83500510;
    addr.breakdown(base_addr);

    word = 0x4;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x5;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    line.range(BITS_PER_WORD - 1, 0) = word;

    // Revoke one word in the line
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x6;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2.4 - REQ_WTFwd + NACK + retry.    
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.4!");
    base_addr = 0x83500600;
    addr.breakdown(base_addr);    

    word = 0x1;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_NACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2.4.1 - FWD_WTFwd + NACK + retry.    
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.4.1!");
    base_addr = 0x83500600;
    addr.breakdown(base_addr);    

    word = 0x2;

    // FwdWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        1 /* use_owner_pred */, 1 /* dcs */, 1 /* pred_cid */);

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_fwd_out(FWD_WTfwd /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_rsp_in(RSP_NACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();
#else
    ////////////////////////////////////////////////////////////////
    // TEST 2.3 - ReqWTFwd (hit and miss - SPX_I, SPX_S,
    // wrong word SPX_R) and no empty_way_found
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.3!");
    base_addr = 0x83500500;
    addr.breakdown(base_addr);

    ////////////////////////////////////////////////////////////////
    // HIT
    ////////////////////////////////////////////////////////////////
    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    word = 0x3;

    // ReqWTFwd to word 0
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    wait();

    word = 0x4;

    // ReqWTFwd to word 1
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x4;
    line.range(BITS_PER_WORD - 1, 0) = 0x3;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // MISS - SPX_I
    ////////////////////////////////////////////////////////////////
    // Revoke line
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x5;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x6;

    // ReqWTFwd to word 1 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = 0x5;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x6;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    ////////////////////////////////////////////////////////////////
    // MISS - SPX_S
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x8;
    line.range(BITS_PER_WORD - 1, 0) = 0x7;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    word = 0x9;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0xA;

    // ReqWTFwd to word 1 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = 0x9;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0xA;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0xC;
    line.range(BITS_PER_WORD - 1, 0) = 0xB;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();    

    ////////////////////////////////////////////////////////////////
    // MISS - SPX_R (wrong word)
    ////////////////////////////////////////////////////////////////
    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    line.range(BITS_PER_WORD - 1, 0) = word;

    // Revoke one word in the line
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0010 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0010 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x3;

    // ReqWTFwd to word 1 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0010 /* word_mask */, 0 /* invack_cnt */);

    wait();

    base_addr = 0x83500510;
    addr.breakdown(base_addr);

    word = 0x4;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x5;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    line.range(BITS_PER_WORD - 1, 0) = word;

    // Revoke one word in the line
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x6;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2.4 - REQ_WTFwd + NACK + retry.    
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.4!");
    base_addr = 0x83500600;
    addr.breakdown(base_addr);    

    word = 0x1;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_NACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2.4.1 - FWD_WTFwd + NACK + retry.    
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.4.1!");
    base_addr = 0x83500600;
    addr.breakdown(base_addr);    

    word = 0x2;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        1 /* use_owner_pred */, 1 /* dcs */, 1 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_fwd_out(FWD_WTfwd /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_NACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();
#endif

    ////////////////////////////////////////////////////////////////
    // TEST 2.5 - REQ_Odata for read, followed by FWD_WTFwd
    // Revoke and attempt FWD_WTFwd again - NACK.
    // REQ_Odata for read again, with FWD_WTFwd (fwd_stall)
    // Revoke and attempt FWD_WTFwd again (no fwd_stall) - NACK.    
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.5!");
    base_addr = 0x83500700;
    addr.breakdown(base_addr);

    ////////////////////////////////////////////////////////////////
    // REQ_Odata for read, followed by FWD_WTFwd
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqOdata /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x1;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    word = 0x3;

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    // FWDWTFwd to word 0
    put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
            line /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_O /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x4;

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    // FWDWTFwd to word 1
    put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            line /* line */, 0b0010 /* word_mask */);

    get_rsp_out(RSP_O /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0010 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x4;
    line.range(BITS_PER_WORD - 1, 0) = 0x3;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // Revoke and attempt FWD_WTFwd again - NACK.
    ////////////////////////////////////////////////////////////////
    put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
            0 /* line */, 0b0011 /* word_mask */);

    get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
            line /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x5;

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    // FWDWTFwd to word 0
    put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
            line /* line */, 0b0001 /* word_mask */);

    get_rsp_out(RSP_NACK /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0001 /* word_mask */);

    wait();

    word = 0x6;

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    // FWDWTFwd to word 1
    put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            line /* line */, 0b0010 /* word_mask */);

    get_rsp_out(RSP_NACK /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0010 /* word_mask */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x4;
    line.range(BITS_PER_WORD - 1, 0) = 0x3;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // REQ_Odata for read again, with FWD_WTFwd (fwd_stall)
    ////////////////////////////////////////////////////////////////
    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqOdata /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x5;

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    // FWDWTFwd to word 0 - FWD_STALL
    put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
            line /* line */, 0b0001 /* word_mask */);
        
    wait();

    word = 0x6;

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    // FWDWTFwd to word 1 - FWD_STALL (fwd_in_tmp buffered)
    put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            line /* line */, 0b0010 /* word_mask */);

    wait();

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    get_rsp_out(RSP_O /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0001 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    get_rsp_out(RSP_O /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0010 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x6;
    line.range(BITS_PER_WORD - 1, 0) = 0x5;

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // Wrte-back and attempt FWD_WTFwd again (fwd_stall) - NACK.
    ////////////////////////////////////////////////////////////////
    // Write L2_WAYS to the same set to trigger an eviction.
    for (int i = 0; i < L2_WAYS-1; i++) {
        addr.tag_incr(1);

        word = i+1;

        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
            0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

        get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

        wait();

        line = 0;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = i+2;

        put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
            0b0011 /* word_mask */, 0 /* invack_cnt */);
    }

    addr.tag_incr(1);

    word = L2_WAYS+1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // The previous request will evict the original line we were working on.
    base_addr = 0x83500700;
    addr.breakdown(base_addr);

    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x6;
    line.range(BITS_PER_WORD - 1, 0) = 0x5;

    get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();

    word = 0x7;

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    // FWDWTFwd to word 0
    put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
            line /* line */, 0b0001 /* word_mask */);
    
    get_rsp_out(RSP_NACK /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0001 /* word_mask */);

    wait();

    word = 0x8;

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    // FWDWTFwd to word 1
    put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
            line /* line */, 0b0010 /* word_mask */);

    get_rsp_out(RSP_NACK /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
            0 /* line */, 0b0010 /* word_mask */);

    wait();

    put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
         0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    // Now L2 will service the pending CPU request
    base_addr = 0x83500700;
    addr.breakdown(base_addr);

    addr.tag_incr(L2_WAYS);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    line = 0;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = L2_WAYS+2;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();

    ////////////////////////////////////////////////////////////////
    // TEST 2.6 - Fill WB with half lines (same set) and drain (fence).    
    // Fill WB with half lines (diff set) and drain (fence).    
    // Fill WB with full lines (same set) and drain (AMO).    
    // Fill WB with half lines (same set) and dispatch (new line).    
    ////////////////////////////////////////////////////////////////
#ifdef USE_WB
    CACHE_REPORT_INFO("[SPANDEX] Test 2.6!");

    ////////////////////////////////////////////////////////////////
    // 1 - Fill WB with half lines (same set) and drain (fence).    
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        // ReqWTFwd to word 0 - should miss
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        get_inval(addr.word /* addr */, DATA /* hprot */);

        addr.tag_incr(1);

        wait();
    }
    
    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        line = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

        wait();

        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
            0b0001 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);

        wait();
    }

    ////////////////////////////////////////////////////////////////
    // 2 - Fill WB with half lines (same set) and drain (fence).    
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+2;

        // ReqWTFwd to word 0 - should miss
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        get_inval(addr.word /* addr */, DATA /* hprot */);

        addr.set_incr(1);

        wait();
    }
    
    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+2;

        line = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

        wait();

        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
            0b0001 /* word_mask */, 0 /* invack_cnt */);

        addr.set_incr(1);

        wait();
    }

    ////////////////////////////////////////////////////////////////
    // 1 redux - Fill WB with half lines (same set) and drain (fence).    
    // Send responses together and offset +8.
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        // ReqWTFwd to word 1 - should miss
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        get_inval(addr.word /* addr */, DATA /* hprot */);

        addr.tag_incr(1);

        wait();
    }
    
    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        line = 0;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

        get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

        addr.tag_incr(1);

        wait();
    }

    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
            0b0010 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);

        wait();
    }

    ////////////////////////////////////////////////////////////////
    // 2 redux - Fill WB with half lines (same set) and drain (fence).    
    // Send responses together and offset +8.
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+2;

        // ReqWTFwd to word 1 - should miss
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        get_inval(addr.word /* addr */, DATA /* hprot */);

        addr.set_incr(1);

        wait();
    }
    
    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+2;

        line = 0;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

        get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

        addr.set_incr(1);

        wait();
    }

    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
            0b0010 /* word_mask */, 0 /* invack_cnt */);

        addr.set_incr(1);

        wait();
    }    

    ////////////////////////////////////////////////////////////////
    // 3 - Fill WB with full lines (same set) and drain (AMO).    
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        // ReqWTFwd to word 0 - should miss
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        get_inval(addr.word /* addr */, DATA /* hprot */);

        addr.tag_incr(1);

        wait();
    }

    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+2;

        // ReqWTFwd to word 1 - should miss
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        get_inval(addr.word /* addr */, DATA /* hprot */);

        addr.tag_incr(1);

        wait();
    }
    
    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        line = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word+1;

        get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

        wait();

        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
            0b0011 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);

        wait();
    }

    ////////////////////////////////////////////////////////////////
    // 4 - Fill WB with half lines (same set) and dispatch (new line).    
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        // ReqWTFwd to word 0 - should miss
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        get_inval(addr.word /* addr */, DATA /* hprot */);

        addr.tag_incr(1);

        wait();
    }

    word = N_WB+1;

    // New ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    // Dispatch first WB entry
    base_addr = 0x83500800;
    addr.breakdown(base_addr);

    word = 0x1;

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);        

    // Service new request
    addr.tag_incr(N_WB);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();    
    
    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    // Drain new request first.
    word = N_WB+1;

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);        

    // Drain remaining WB entries.
    base_addr = 0x83500800;
    addr.breakdown(base_addr);
    addr.tag_incr(1);

    for (int i = 1; i < N_WB; i++) {
        word = i+1;

        line = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

        wait();

        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
            0b0001 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);

        wait();
    }

    ////////////////////////////////////////////////////////////////
    // TEST 2.7 - Set conflict before dispatch
    // 1 - WB is full but unable to dispatch because of set conflict.
    // 2 - Unable dispatch next entry for drain because of set conflict.
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.7!");

    ////////////////////////////////////////////////////////////////
    // 1 - WB is full but unable to dispatch because of set conflict.
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500900;
    addr.breakdown(base_addr);    

    // Fill the WB
    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        // ReqWTFwd to word 0 - should miss
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        get_inval(addr.word /* addr */, DATA /* hprot */);

        addr.tag_incr(1);

        wait();
    }

    // Perform an unrelated regular store within the same set.
    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    // New ReqWTFwd to same set - should miss
    addr.tag_incr(1);
    word = N_WB+1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);
    
    for (int i = 0; i < 10; i++) {
        wait();
    }

    // Now send the response for the write
    base_addr = 0x83500900;
    addr.breakdown(base_addr);    
    addr.tag_incr(N_WB);

    word = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = word;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);                

    wait();

    // Dispatch WB entry at wb_evict_buf
    base_addr = 0x83500900;
    addr.breakdown(base_addr);
    addr.tag_incr(N_WB-1);

    word = N_WB-1+1;

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);        

    // Service new request
    base_addr = 0x83500900;
    addr.breakdown(base_addr);
    addr.tag_incr(N_WB+1);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();    
    
    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    // Drain old requests first (new request must be added at the end).
    base_addr = 0x83500900;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB-1; i++) {
        word = i+1;

        line = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

        wait();

        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
            0b0001 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);

        wait();
    }

    // Now drain new request
    base_addr = 0x83500900;
    addr.breakdown(base_addr);
    addr.tag_incr(N_WB+1);

    word = N_WB+1;

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);        

    wait();

    ////////////////////////////////////////////////////////////////
    // 2 - Unable dispatch next entry for drain because of set conflict.
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500A00;
    addr.breakdown(base_addr);    

    // Fill the WB
    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        // ReqWTFwd to word 0 - should miss
        put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, word /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
            0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

        get_inval(addr.word /* addr */, DATA /* hprot */);

        addr.tag_incr(1);

        wait();
    }

    // Perform an unrelated AMO within the same set.
    word = 0x1;

    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    base_addr = 0x83500A00;
    addr.breakdown(base_addr);

    for (int i = 0; i < N_WB; i++) {
        word = i+1;

        line = 0;
        line.range(BITS_PER_WORD - 1, 0) = word;

        get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

        wait();

        put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
            0b0001 /* word_mask */, 0 /* invack_cnt */);

        addr.tag_incr(1);

        wait();
    }

    for (int i = 0; i < 10; i++) {
        wait();
    }

    // Now send the response for the AMO
    word = 0x2;
    line.range(BITS_PER_WORD - 1, 0) = word;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);                

    get_rd_rsp(line /* line */);

    wait();
#endif    

    ////////////////////////////////////////////////////////////////
    // TEST 2.8 - Read miss with REQ_V.
    // Read hit with REQ_V on owned state.
    // Read hit with REQ_V on shared state.
    // Read hit with REQ_V on valid state.
    // {Read miss with REQ_V} x L2_WAYS + 1.
    // Read miss with REQ_V + WTFwd + Read.
    ////////////////////////////////////////////////////////////////
    CACHE_REPORT_INFO("[SPANDEX] Test 2.8!");

    ////////////////////////////////////////////////////////////////
    // 1 - Read miss with REQ_V.    
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500B00;
    addr.breakdown(base_addr);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x1;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // 2 - Read hit with REQ_V on owned state.
    ////////////////////////////////////////////////////////////////
    addr.tag_incr(1);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqOdata /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x2;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // 3 - Read hit with REQ_V on shared state.
    ////////////////////////////////////////////////////////////////
    addr.tag_incr(1);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x3;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // 4 - Read hit with REQ_V on valid state.
    ////////////////////////////////////////////////////////////////
    addr.tag_incr(1);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x4;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // 5 - {Read miss with REQ_V} x L2_WAYS + 1.
    ////////////////////////////////////////////////////////////////
    base_addr = 0x83500C00;
    addr.breakdown(base_addr);

    for (int i = 0; i < L2_WAYS; i++) {
        put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
            addr.word /* addr */, 0 /* word */, DATA /* hprot */,
            0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
            0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

        get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
            DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

        wait();

        word = i+2;
        line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
        line.range(BITS_PER_WORD - 1, 0) = word;

        put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
            0b0011 /* word_mask */, 0 /* invack_cnt */);

        get_rd_rsp(line /* line */);

        wait();

        addr.tag_incr(1);

        wait();
    }

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    base_addr = 0x83500C00;
    addr.breakdown(base_addr);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    addr.tag_incr(L2_WAYS);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = L2_WAYS;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    get_rd_rsp(line /* line */);

    wait();

    ////////////////////////////////////////////////////////////////
    // 6 - Read miss with REQ_V + WTFwd + Read.
    ////////////////////////////////////////////////////////////////
#ifndef USE_WB
#else
    addr.set_incr(1);

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x2;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();

    word = 0x3;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();
    
    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    wait();

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0001 /* word_mask */);

    wait();

    word = 0x3;
    line.range(BITS_PER_WORD - 1, 0) = word;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0x2;

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0001 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();    

    word = 0x4;

    // ReqWTFwd to word 0 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();
   
    // ReqWTFwd to word 1 - should miss
    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
        addr.word + 8 /* addr */, word /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, DCS_ReqWTfwd /* dcs_en */,
        0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    get_inval(addr.word /* addr */, DATA /* hprot */);

    wait();
     
    // Fence to flush WB
    l2_fence_tb.put(0x2);

    wait();

    line = 0;
    line.range(BITS_PER_WORD - 1, 0) = word;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    get_req_out(REQ_WTfwd /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    wait();

    put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    wait();    

    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
        addr.word /* addr */, 0 /* word */, DATA /* hprot */,
        0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
        0 /* use_owner_pred */, DCS_ReqV /* dcs */, 0 /* pred_cid */);

    get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
        DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    wait();

    word = 0x5;
    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    line.range(BITS_PER_WORD - 1, 0) = word;

    put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
        0b0011 /* word_mask */, 0 /* invack_cnt */);

    get_rd_rsp(line /* line */);

    wait();        
#endif

	CACHE_REPORT_VAR(sc_time_stamp(), "[SPANDEX] Error count", error_count);

    wait();

    // End simulation
    sc_stop();

    // ////////////////////////////////////////////////////////////////
    // // TEST 1: setting a lock - AMO_SWAP
    // ////////////////////////////////////////////////////////////////
    // addr.breakdown(base_addr);

    // word = 0x1;
    // line = 0x1;
    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0001 /* word_mask */);

    // put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //     0b0001 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(0 /* line */);

    // wait();

    // // current_valid_state = 2;

    // ////////////////////////////////////////////////////////////////
    // // somebody trying to set - FWD_REQ_Odata
    // ////////////////////////////////////////////////////////////////
    // put_fwd_in(FWD_REQ_Odata /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
    //     line /* line */, 0b0001 /* word_mask */);

    // get_rsp_out(RSP_Odata /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
    //     line /* line */, 0b0001 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // somebody doing self-invalidating read of lock - FWD_REQ_V
    // ////////////////////////////////////////////////////////////////
    // put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
    //     0 /* line */, 0b0001 /* word_mask */);

    // get_rsp_out(RSP_NACK /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
    //     0 /* line */, 0b0001 /* word_mask */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // checking lock value - Req_S
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // ////////////////////////////////////////////////////////////////
    // // releasing lock - AMO_SWAP
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0001 /* word_mask */);

    // put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0001 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // // current_valid_state = 3;

    // ////////////////////////////////////////////////////////////////
    // // set lock again - AMO_SWAP
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_rd_rsp(0 /* line */);

    // wait();

    // // current_valid_state = 4;

    // ////////////////////////////////////////////////////////////////
    // // reading lock - WB and ReqS
    // // TODO in the previous step, we did Req_Odata, but here, since
    // // the line was not fully owned, it became fully shared. This might
    // // be okay since shared state must be on line basis, so we
    // // need to sacrifice the partially owned state
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

    // put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //      0b0001 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // TEST 2: writing to location and immediately reading back
    // // TODO this is not working as expected. Even for ReqO,
    // // if there is a hit in the MSHR, there is a set conflict
    // // and the following ReqS is serviced only if the RspO is returned
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82518450;
    // addr.breakdown(base_addr);
    // word = 0xdeadbeefdead0000;
    // base_addr1 = 0x82518458;
    // addr1.breakdown(base_addr1);
    // word1 = 0xdeadbeefdead1111;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word1;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // wait();

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //     addr1.word /* addr */, word1 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // wait();

    // get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // Reading the same written line with FWD_REQ_V and FWD_REQ_S
    // ////////////////////////////////////////////////////////////////
    // put_fwd_in(FWD_REQ_V /* coh_msg */, addr1.word /* addr */, 1 /* req_id */,
    //     0 /* line */, 0b0001 /* word_mask */);

    // get_rsp_out(RSP_V /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr1.word /* addr */,
    //     line /* line */, 0b0001 /* word_mask */);

    // wait();

    // put_fwd_in(FWD_REQ_S /* coh_msg */, addr1.word /* addr */, 2 /* req_id */,
    //     0 /* line */, 0b0011 /* word_mask */);

    // get_rsp_out(RSP_RVK_O /* coh_msg */, 2 /* req_id */, 0 /* to_req */, addr1.word /* addr */,
    //     line /* line */, 0b0011 /* word_mask */);

    // wait();

    // get_rsp_out(RSP_S /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr1.word /* addr */,
    //     line /* line */, 0b0011 /* word_mask */);

    // wait();

    // get_inval(addr1.word /* addr */, DATA /* hprot */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // TEST 3: Read new line with different request types
    // // TODO even if the requested data is not full line, in case of
    // // reqV, we are requesting the full line with full word_mask.
    // // This must have been partial word_mask. In the FSM, we are
    // // checking which words in the line are not valid and sending
    // // request for all of them.
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82528450;
    // addr.breakdown(base_addr);
    // word = 0xdeadbeefdead2222;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word + 0x1111;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
    //     0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // read again with ReqV
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
    //     0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // read again with ReqS
    // // TODO this is responding without sending the request to LLC
    // // the FSM only checks whether all the words in the line are valid,
    // // not shared.
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // self-invalidating read with ReqV
    // // TODO when self-invalidating, we cannot use current_valid_state
    // // variable because for those intermediate valid states, we are
    // // not invalidating the L1.
    // // If we need to change it, we might need to do away with
    // // current_valid_state completely and invalidate all valid lines
    // // for every acquire.
    // ////////////////////////////////////////////////////////////////
    // word = 0xdeadbeefdead4444;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word + 0x1111;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 1 /* aq */, 0 /* rl */, 1 /* dcs_en */,
    //     0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // // current_valid_state = 5;

    // ////////////////////////////////////////////////////////////////
    // // self-invalidating read with ReqS
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 1 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // // current_valid_state = 6;

    // // get_inval(addr.word /* addr */, DATA /* hprot */);

    // // wait();

    // // get_inval(addr.word /* addr */, DATA /* hprot */);

    // ////////////////////////////////////////////////////////////////
    // // TEST 4: write to this line and try to return with ReqV
    // // Note: when we write only one word and send ReqS, we get a WB hit
    // // which we dispatch. This write buffer entry has only 1 word, unlike
    // // the previous test where we had both words.
    // ////////////////////////////////////////////////////////////////
    // word = 0xdeadbeefdead6666;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word - 0x1111;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // wait();

    // // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    // //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    // //     0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
    // //     0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    // // get_rd_rsp(line /* line */);

    // // wait();

    // ////////////////////////////////////////////////////////////////
    // // try to return with ReqS
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;

    // get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word - 0x1111;

    // put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0001 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

    // put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //      0b0001 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // wait();

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // write to the next line and try to return with ReqV
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82528460;
    // addr.breakdown(base_addr);
    // word = 0xdeadbeefdead8888;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // wait();

    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
    //     0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0010 /* word_mask */);

    // put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //     0b0010 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // try to return with ReqS
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0001 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

    // put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //      0b0001 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // TEST 5: testing self-invalidate
    // // we will load many lines using ReqV and then end the phase
    // // with one self-invalidate
    // ////////////////////////////////////////////////////////////////
    // for (int i = 0; i < WORDS_PER_LINE * L2_WAYS; i++) {
    //     base_addr = 0x82520000 + 0x8*i;
    //     addr.breakdown(base_addr);

    //     put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //         addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //         0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
    //         0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    //     if (i%2 == 0) {
    //         word = 0xcafedeadcafede00 + 0x1*i;
    //         line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    //         line.range(BITS_PER_WORD - 1, 0) = word;

    //         get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
    //             DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    //         put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
    //             0b0011 /* word_mask */, 0 /* invack_cnt */);
    //     }

    //     get_rd_rsp(line /* line */);

    //     wait();
    // }

    // for (int i = 0; i < SPX_MAX_V; i++) {
    //     l2_fence_tb.put(0x1);
    //     wait();
    // }

    // for (int i = 0; i < WORDS_PER_LINE * L2_WAYS; i++) {
    //     base_addr = 0x82520000 + 0x8*i;
    //     addr.breakdown(base_addr);

    //     // get_inval(addr.word /* addr */, DATA /* hprot */);

    //     wait();
    // }

    // ////////////////////////////////////////////////////////////////
    // // we will now send FWD_REQ_V to get nacks for all these lines
    // ////////////////////////////////////////////////////////////////
    // for (int i = 0; i < WORDS_PER_LINE * L2_WAYS; i++) {
    //     base_addr = 0x82520000 + 0x8*i;
    //     addr.breakdown(base_addr);

    //     put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
    //         0 /* line */, 0b0001 /* word_mask */);

    //     get_rsp_out(RSP_NACK /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
    //         0 /* line */, 0b0001 /* word_mask */);

    //     wait();
    // }

    // ////////////////////////////////////////////////////////////////
    // // TEST 6: fill up the reqs buffer with ReqO's
    // // First we fill the WB with N_WB entries
    // ////////////////////////////////////////////////////////////////
    // for (int i = 0; i < N_WB; i++) {
    //     base_addr = 0x82520100 + 0x10*i;
    //     addr.breakdown(base_addr);
    //     word = 0xdeadcafedeafca00 + 0x1*i;
    //     line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    //     line.range(BITS_PER_WORD - 1, 0) = word;

    //     put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //         addr.word /* addr */, word /* word */, DATA /* hprot */,
    //         0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //         0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    //     wait();
    // }

    // ////////////////////////////////////////////////////////////////
    // // Then we add N_REQS more requests to fill up the reqs buffer
    // // and receive N_REQS dispatches from the WB
    // // TODO we are seeing the same entry of the WB being evicted
    // // because we are checking for WORD_MASK_ALL. Even peek_wb
    // // is written to pick the last entry that is free not the first.
    // ////////////////////////////////////////////////////////////////
    // for (int i = N_WB; i < N_WB+N_REQS; i++) {
    //     base_addr = 0x82520100 + 0x10*i;
    //     addr.breakdown(base_addr);
    //     word = 0xdeadcafedeafca00 + 0x1*i;
    //     line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    //     line.range(BITS_PER_WORD - 1, 0) = word;

    //     put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //         addr.word /* addr */, word /* word */, DATA /* hprot */,
    //         0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //         0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    //     base_addr = 0x82520100 + 0x10*(i-1);
    //     addr.breakdown(base_addr);
    //     word = 0xdeadcafedeafca00 + 0x1*(i-1);
    //     line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    //     line.range(BITS_PER_WORD - 1, 0) = word;

    //     get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
    //         DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    //     wait();
    // }

    // ////////////////////////////////////////////////////////////////
    // // send the response for the entries in the MSHR
    // ////////////////////////////////////////////////////////////////
    // for (int i = N_WB; i < N_WB+N_REQS; i++) {
    //     base_addr = 0x82520100 + 0x10*(i-1);
    //     addr.breakdown(base_addr);
    //     word = 0xdeadcafedeafca00 + 0x1*(i-1);
    //     line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    //     line.range(BITS_PER_WORD - 1, 0) = word;

    //     put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
    //         0b0001 /* word_mask */, 0 /* invack_cnt */);

    //     wait();
    // }

    // ////////////////////////////////////////////////////////////////
    // // flush the write buffer and add entries to the MSHR
    // // TODO the entries are received in a different order than what
    // // is expected
    // ////////////////////////////////////////////////////////////////
    // l2_fence_tb.put(0x2);

    // base_addr = 0x82520100 + 0x10*(N_WB+N_REQS-1);
    // addr.breakdown(base_addr);
    // word = 0xdeadcafedeafca00 + 0x1*(N_WB+N_REQS-1);
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0001 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // for (int i = N_WB-2; i >= 0; i--) {
    //     base_addr = 0x82520100 + 0x10*i;
    //     addr.breakdown(base_addr);
    //     word = 0xdeadcafedeafca00 + 0x1*i;
    //     line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    //     line.range(BITS_PER_WORD - 1, 0) = word;

    //     get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
    //         DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    //     put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, line /* line */,
    //         0b0001 /* word_mask */, 0 /* invack_cnt */);

    //     wait();
    // }

    // ///////////////////////////////////////////////////////////////
    // // TEST 7: Invalidation forwards. We will first bring
    // // lines into shared state and then send invalidation requests
    // // and then again try to read them
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82530800;
    // addr.breakdown(base_addr);
    // word = 0xdeadbeefdeadbeef;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // ////////////////////////////////////////////////////////////////
    // // we will now send an invalidate
    // ////////////////////////////////////////////////////////////////
    // put_fwd_in(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    //         0 /* line */, 0b0011 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

    // wait();

    // get_rsp_out(RSP_INV_ACK_SPDX /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
    //         0 /* line */, 0b0011 /* word_mask */);

    // ////////////////////////////////////////////////////////////////
    // // repeat the above experiment for fwd_stall
    // // in this case, the REQ_S is assumed to reach the LLC after
    // // the original invalidate forward is sent out. In other words,
    // // the ownership request from another L2 came first. Therefore,
    // // the LLC should be sending the updating line from the owner.
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // put_fwd_in(FWD_INV_SPDX /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    //         0 /* line */, 0b0011 /* word_mask */);

    // get_rsp_out(RSP_INV_ACK_SPDX /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
    //         0 /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

    // ////////////////////////////////////////////////////////////////
    // // TEST 8: partial FWD_REQ_O
    // // TODO this is invalidating the whole line from L1 cache, even
    // // though the ownership transfer was for 1 word only. We might
    // // not be able to do anything about that now since the L1 tracks
    // // on line granularity
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82531800;
    // addr.breakdown(base_addr);
    // word = 0xbeefdeadbeefdead;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE/* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // wait();

    // base_addr = 0x82531808;
    // addr.breakdown(base_addr);

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE/* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // base_addr = 0x82531800;
    // addr.breakdown(base_addr);

    // get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // put_fwd_in(FWD_REQ_O /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
    //         0 /* line */, 0b0010 /* word_mask */);

    // get_rsp_out(RSP_O /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
    //         0 /* line */, 0b0010 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

    // ////////////////////////////////////////////////////////////////
    // // TODO now, if there is a ReqV for a single word, we're
    // // fetching the remaining words from LLC - not necessary
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 1 /* dcs_en */,
    //     0 /* use_owner_pred */, 1 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_V /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0010 /* word_mask */);

    // put_rsp_in(RSP_V /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0010 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // ////////////////////////////////////////////////////////////////
    // // now, send a revoke ownership request
    // ////////////////////////////////////////////////////////////////
    // put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    //         0 /* line */, 0b0001 /* word_mask */);

    // get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
    //         line /* line */, 0b0001 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // TEST 9: partial FWD_WTfwd
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82532800;
    // addr.breakdown(base_addr);
    // word = 0xbeefdeadbeefdead;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE/* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // wait();

    // base_addr = 0x82532808;
    // addr.breakdown(base_addr);

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE/* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // base_addr = 0x82532800;
    // addr.breakdown(base_addr);

    // get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0011 /* word_mask */);

    // put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // word = 0xcafedeadcafedead;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line.range(BITS_PER_WORD - 1, 0) = 0;

    // put_fwd_in(FWD_WTfwd /* coh_msg */, addr.word /* addr */, 2 /* req_id */,
    //         line /* line */, 0b0010 /* word_mask */);

    // get_rsp_out(RSP_O /* coh_msg */, 2 /* req_id */, 1 /* to_req */, addr.word /* addr */,
    //         0 /* line */, 0b0010 /* word_mask */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // revoke one word in the line and retry the earlier experiment
    // ////////////////////////////////////////////////////////////////
    // word = 0xbeefdeadbeefdead;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    //         0 /* line */, 0b0001 /* word_mask */);

    // get_rsp_out(RSP_RVK_O /* coh_msg */, 0 /* req_id */, 0 /* to_req */, addr.word /* addr */,
    //         line /* line */, 0b0001 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

    // ////////////////////////////////////////////////////////////////
    // // TEST 10: flush
    // ////////////////////////////////////////////////////////////////
    // l2_flush_tb.put(0x1);

    // for (int i = 0; i < N_WB+N_REQS; i++) {
    //     base_addr = 0x82520100 + 0x10*i;
    //     addr.breakdown(base_addr);
    //     word = 0xdeadcafedeafca00 + 0x1*i;
    //     line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    //     line.range(BITS_PER_WORD - 1, 0) = word;

    //     get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    //         DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    //     put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //          0b0001 /* word_mask */, 0 /* invack_cnt */);

    //     wait();
    // }

    // base_addr = 0x82532800;
    // addr.breakdown(base_addr);

    // word = 0xcafedeadcafedead;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // word = 0xbeefdeadbeefdead;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

    // put_rsp_in(RSP_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //      0b0001 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // TEST 11: Half-word atomics
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82080100;
    // addr.breakdown(base_addr);

    // word = 0x22222222;
    // word1 = 0x1111111111111111;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    // line.range(BITS_PER_WORD - 1, 0) = word1;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0001 /* word_mask */);

    // put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0001 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // // current_valid_state = 2;

    // ////////////////////////////////////////////////////////////////
    // // send atomic write for next word also
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x8208010C;
    // addr.breakdown(base_addr);

    // word = 0x3333333300000000;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
    //     base_addr /* addr */, word /* word */, DATA /* hprot */,
    //     AMO_SWAP /* amo */, 1 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0010 /* word_mask */);

    // word1 = 0x1111111111111111;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word1;

    // put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b0010 /* word_mask */, 0 /* invack_cnt */);

    // word1 = 0x1111111122222222;
    // line.range(BITS_PER_WORD - 1, 0) = word1;

    // get_rd_rsp(line /* line */);

    // wait();

    // // current_valid_state = 3;

    // ////////////////////////////////////////////////////////////////
    // // checking lock value - Req_S
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD_32 /* hsize */,
    //     base_addr /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // word1 = 0x3333333311111111;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word1;

    // get_rd_rsp(line /* line */);

    // ////////////////////////////////////////////////////////////////
    // // TEST 12: LR-SC
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82080880;
    // addr.breakdown(base_addr);

    // word = 0x1111111111111111;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_O /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, line /* line */, 0b01 /* word_mask */);

    // put_rsp_in(RSP_O /* coh_msg */, addr.word /* addr */, 0 /* line */,
    //     0b01 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b10 /* word_mask */);

    // put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
    //     0b10 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // base_addr = 0x82080888;
    // addr.breakdown(base_addr);

    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_rd_rsp(line /* line */);

    // base_addr = 0x82080880;
    // addr.breakdown(base_addr);

    // word = 0x2222222222222222;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_bresp(BRESP_EXOKAY);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // repeat the same but with a forward in between
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_rd_rsp(line /* line */);

    // wait();

    // put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
    //     0 /* line */, 0b0001 /* word_mask */);

    // get_rsp_out(RSP_V /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
    //         line /* line */, 0b0001 /* word_mask */);

    // wait();

    // word = 0x3333333333333333;
    // // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_bresp(BRESP_OKAY);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // read the modified location
    // ////////////////////////////////////////////////////////////////
    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    // //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // // get_inval(addr.word /* addr */, DATA /* hprot */);

    // // put_fwd_in(FWD_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    // //     0 /* line */, 0b0001 /* word_mask */);

    // // wait();

    // // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    // //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // // word = 0x1111111111111111;
    // // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    // // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    // //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // word = 0x1111111111111111;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // TEST 13: repeat above test for sub-word granularity LR-SC
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82080980;
    // addr.breakdown(base_addr);

    // word = 0x3333333333333333;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, WORD_MASK_ALL /* word_mask */);

    // put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
    //     WORD_MASK_ALL /* word_mask */, 0 /* invack_cnt */);

    // word = 0x3333333333333333;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // get_rd_rsp(line /* line */);

    // wait();

    // word = 0x44444444;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_bresp(BRESP_EXOKAY);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // repeat the same but with a forward in between
    // ////////////////////////////////////////////////////////////////
    // word = 0x3333333344444444;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_rd_rsp(line /* line */);

    // wait();

    // put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
    //     0 /* line */, 0b0001 /* word_mask */);

    // get_rsp_out(RSP_V /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
    //         line /* line */, 0b0001 /* word_mask */);

    // wait();

    // word = 0x55555555;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
    //     addr.word /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_bresp(BRESP_OKAY);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // read the modified location
    // ////////////////////////////////////////////////////////////////
    // // word = 0x3333333355555555;
    // // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD_32 /* hsize */,
    //     addr.word /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    // //     DATA /* hprot */, line /* line */, 0b0001 /* word_mask */);

    // // get_inval(addr.word /* addr */, DATA /* hprot */);

    // // put_fwd_in(FWD_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    // //     0 /* line */, 0b0001 /* word_mask */);

    // // wait();

    // // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    // //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // // word = 0x3333333333333333;
    // // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    // // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    // //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // TEST 14: repeat above test for sub-word granularity LR-SC
    // // at 4-byte aligned address
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x82080A8C;
    // addr.breakdown(base_addr);

    // word = 0x6666666666666666;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
    //     base_addr /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, WORD_MASK_ALL /* word_mask */);

    // put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line /* line */,
    //     WORD_MASK_ALL /* word_mask */, 0 /* invack_cnt */);

    // word = 0x6666666666666666;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // get_rd_rsp(line /* line */);

    // wait();

    // word = 0x7777777700000000;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
    //     base_addr /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_bresp(BRESP_EXOKAY);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // repeat the same but with a forward in between
    // ////////////////////////////////////////////////////////////////
    // word = 0x7777777766666666;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
    //     base_addr /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_rd_rsp(line /* line */);

    // wait();

    // put_fwd_in(FWD_REQ_V /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
    //     0 /* line */, 0b0010 /* word_mask */);

    // get_rsp_out(RSP_V /* coh_msg */, 1 /* req_id */, 1 /* to_req */, addr.word /* addr */,
    //         line /* line */, 0b0010 /* word_mask */);

    // wait();

    // word = 0x8888888800000000;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE_ATOMIC /* cpu_msg */, WORD_32 /* hsize */,
    //     base_addr /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 1 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // get_bresp(BRESP_OKAY);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // read the modified location
    // ////////////////////////////////////////////////////////////////
    // // word = 0x8888888866666666;
    // // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    // put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, WORD_32 /* hsize */,
    //     base_addr /* addr */, 0 /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // // get_req_out(REQ_WB /* coh_msg */, addr.word /* addr */,
    // //     DATA /* hprot */, line /* line */, 0b0010 /* word_mask */);

    // // get_inval(addr.word /* addr */, DATA /* hprot */);

    // // put_fwd_in(FWD_WB_ACK /* coh_msg */, addr.word /* addr */, 0 /* req_id */,
    // //     0 /* line */, 0b0010 /* word_mask */);

    // // wait();

    // // get_req_out(REQ_S /* coh_msg */, addr.word /* addr */,
    // //     DATA /* hprot */, 0 /* line */, 0b0011 /* word_mask */);

    // // word = 0x6666666666666666;
    // // line.range(BITS_PER_WORD - 1, 0) = word;

    // // put_rsp_in(RSP_S /* coh_msg */, addr.word /* addr */, line /* line */,
    // //     0b0011 /* word_mask */, 0 /* invack_cnt */);

    // word = 0x6666666666666666;
    // line.range(BITS_PER_WORD - 1, 0) = word;

    // get_rd_rsp(line /* line */);

    // wait();

    // ////////////////////////////////////////////////////////////////
    // // TEST 15: non-atomic sub-word granularities
    // ////////////////////////////////////////////////////////////////
    // base_addr = 0x820A820C;
    // addr.breakdown(base_addr);

    // word = 0x2222222200000000;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line.range(BITS_PER_WORD - 1, 0) = 0;

    // put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, WORD_32 /* hsize */,
    //     base_addr /* addr */, word /* word */, DATA /* hprot */,
    //     0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
    //     0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

    // wait();

    // word = 0x1111111111111111;
    // line1.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;
    // line1.range(BITS_PER_WORD - 1, 0) = word;

    // get_req_out(REQ_Odata /* coh_msg */, addr.word /* addr */,
    //     DATA /* hprot */, 0 /* line */, 0b0010 /* word_mask */);

    // put_rsp_in(RSP_Odata /* coh_msg */, addr.word /* addr */, line1 /* line */,
    //     0b0010 /* word_mask */, 0 /* invack_cnt */);

    // wait();

    // word.range(63,32) = 0x22222222;
    // line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = word;

    // put_fwd_in(FWD_RVK_O /* coh_msg */, addr.word /* addr */, 1 /* req_id */,
    //         0 /* line */, 0b0010 /* word_mask */);

    // get_rsp_out(RSP_RVK_O /* coh_msg */, 1 /* req_id */, 0 /* to_req */, addr.word /* addr */,
    //         line /* line */, 0b0010 /* word_mask */);

    // get_inval(addr.word /* addr */, DATA /* hprot */);

	// CACHE_REPORT_VAR(sc_time_stamp(), "[SPANDEX] Error count", error_count);

    // // End simulation
    // sc_stop();
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

void l2_spandex_tb::get_fwd_out(coh_msg_t coh_msg, cache_id_t req_id, bool to_req, addr_t addr,
    line_t line, word_mask_t word_mask)
{
    l2_fwd_out_t fwd_out;

    fwd_out = l2_fwd_out_tb.get();

    if (fwd_out.coh_msg != coh_msg ||
	(fwd_out.req_id != req_id && to_req) ||
	fwd_out.addr != addr.range(TAG_RANGE_HI, SET_RANGE_LO) ||
	(fwd_out.line != line) ||
    fwd_out.word_mask != word_mask) {

	CACHE_REPORT_ERROR("get fwd out addr", fwd_out.addr);
	CACHE_REPORT_ERROR("get fwd out addr gold", addr.range(TAG_RANGE_HI, SET_RANGE_LO));
	CACHE_REPORT_ERROR("get fwd out coh_msg", fwd_out.coh_msg);
	CACHE_REPORT_ERROR("get fwd out coh_msg gold", coh_msg);
	CACHE_REPORT_ERROR("get fwd out req_id", fwd_out.req_id);
	CACHE_REPORT_ERROR("get fwd out req_id gold", req_id);
	CACHE_REPORT_ERROR("get fwd out to_req", fwd_out.to_req);
	CACHE_REPORT_ERROR("get fwd out to_req gold", to_req);
	CACHE_REPORT_ERROR("get fwd out line", fwd_out.line);
	CACHE_REPORT_ERROR("get fwd out line gold", line);
	CACHE_REPORT_ERROR("get fwd out word_mask", fwd_out.word_mask);
	CACHE_REPORT_ERROR("get fwd out word_mask gold", word_mask);
    error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "FWD_OUT", fwd_out);
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
