/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

	Modified by Zeran Zhu, Robert Jin, Vignesh Suresh
	zzhu35@illinois.edu
	
	April 9 2021

*/

#include "spandex_system_tb.hpp"

#define L2_CID 0

#define HWRITE_READ  0
#define HWRITE_WRITE 1

#define TIME (sc_time_stamp())

/*
 * Processes
 */

#ifdef STATS_ENABLE
void spandex_system_tb::get_stats()
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

// Handle communication events between the caches
// Right now, this just forwards data between the
// two caches, adapting the interface as needed,
// but in theory it could also act as additional
// debugging by intercepting these messages.

void spandex_system_tb::l2_req_out_if()
{
    while(true) {

        // Wait for communication
        // TODO: would be great to have an event that we could
        // wait on, but that isn't supported by the nb_get_initiators.
        // Maybe look at the get_initiators.
        wait();

        // This interface is going to take somewhere between 1 and 10 cycles
        // to pass any particular message along, in order to lazily simulate
        // the latency of the interface.
        int cycles = rand() % 10;
        for(int i = 0; i < cycles; i++) {
            wait();
        }

        // Handle the request
        if(l2_req_out_tb.nb_can_get()) {
            l2_req_out_t l2_req;
            l2_req_out_tb.nb_get(l2_req);
            put_req_in(l2_req.coh_msg,
                       l2_req.addr,
                       l2_req.line,
                       L2_CID, // cache ID
                       l2_req.hprot,
                       0, // woff
                       0, // wvalid
                       l2_req.word_mask);
        }
    }
}

void spandex_system_tb::l2_fwd_out_if()
{
    while(true) {

        // Wait for communication
        // TODO: would be great to have an event that we could
        // wait on, but that isn't supported by the nb_get_initiators.
        // Maybe look at the get_initiators.
        wait();

        // This interface is going to take somewhere between 1 and 10 cycles
        // to pass any particular message along, in order to lazily simulate
        // the latency of the interface.
        int cycles = rand() % 10;
        for(int i = 0; i < cycles; i++) {
            wait();
        }

        if(l2_fwd_out_tb.nb_can_get()) {
            l2_fwd_out_t l2_fwd;
            l2_fwd_out_tb.nb_get(l2_fwd);
            // TODO: do something with this

            cerr << "L2 sent a forward message, but you don't have a handler for it!" << endl;
        }
    }
}

void spandex_system_tb::l2_rsp_out_if()
{
    while(true) {

        // Wait for communication
        // TODO: would be great to have an event that we could
        // wait on, but that isn't supported by the nb_get_initiators.
        // Maybe look at the get_initiators.
        wait();

        // This interface is going to take somewhere between 1 and 10 cycles
        // to pass any particular message along, in order to lazily simulate
        // the latency of the interface.
        int cycles = rand() % 10;
        for(int i = 0; i < cycles; i++) {
            wait();
        }

        if(l2_rsp_out_tb.nb_can_get()) {
            l2_rsp_out_t l2_rsp;
            l2_rsp_out_tb.nb_get(l2_rsp);
            put_llc_rsp_in(l2_rsp.coh_msg,
                           l2_rsp.addr,
                           l2_rsp.line,
                           l2_rsp.req_id,
                           l2_rsp.word_mask);
        }
    }
}

void spandex_system_tb::llc_rsp_out_if()
{
    while(true) {

        // Wait for communication
        // TODO: would be great to have an event that we could
        // wait on, but that isn't supported by the nb_get_initiators.
        // Maybe look at the get_initiators.
        wait();

        // This interface is going to take somewhere between 1 and 10 cycles
        // to pass any particular message along, in order to lazily simulate
        // the latency of the interface.
        int cycles = rand() % 10;
        for(int i = 0; i < cycles; i++) {
            wait();
        }

        if(llc_rsp_out_tb.nb_can_get()) {
            llc_rsp_out_t<CACHE_ID_WIDTH> llc_rsp;
            llc_rsp_out_tb.nb_get(llc_rsp);
            if(llc_rsp.dest_id == L2_CID) {
                put_l2_rsp_in(llc_rsp.coh_msg,
                              llc_rsp.addr,
                              llc_rsp.line,
                              llc_rsp.word_mask,
                              llc_rsp.invack_cnt);
            } else {
                CACHE_REPORT_VAR(TIME, "LLC_Rsp, but to a different target", llc_rsp);
            }

        }
    }
}

void spandex_system_tb::llc_fwd_out_if()
{
    while(true) {

        // Wait for communication
        // TODO: would be great to have an event that we could
        // wait on, but that isn't supported by the nb_get_initiators.
        // Maybe look at the get_initiators.
        wait();

        // This interface is going to take somewhere between 1 and 10 cycles
        // to pass any particular message along, in order to lazily simulate
        // the latency of the interface.
        int cycles = rand() % 10;
        for(int i = 0; i < cycles; i++) {
            wait();
        }

        if(llc_fwd_out_tb.nb_can_get()) {
            llc_fwd_out_t llc_fwd;
            llc_fwd_out_tb.nb_get(llc_fwd);
            if(llc_fwd.dest_id == L2_CID) {
                put_fwd_in(llc_fwd.coh_msg,
                           llc_fwd.addr,
                           llc_fwd.req_id,
                           llc_fwd.line,
                           llc_fwd.word_mask);
            } else {
                CACHE_REPORT_VAR(TIME, "LLC_Fwd, but to a different target", llc_fwd);
            }

        }
    }
}

void spandex_system_tb::l2_inval_if()
{
    while(true) {

        // Wait for communication
        // TODO: would be great to have an event that we could
        // wait on, but that isn't supported by the nb_get_initiators.
        // Maybe look at the get_initiators.
        wait();

        // This interface is going to take somewhere between 1 and 10 cycles
        // to pass any particular message along, in order to lazily simulate
        // the latency of the interface.
        int cycles = rand() % 10;
        for(int i = 0; i < cycles; i++) {
            wait();
        }

        if(l2_inval_tb.nb_can_get()) {
            l2_inval_t inval;
            l2_inval_tb.nb_get(inval);

            cerr << "L2 sent an inval message, but you don't have a handler for it!" << endl;

        }
    }
}

void spandex_system_tb::llc_dma_rsp_out_if()
{
    while(true) {

        // Wait for communication
        // TODO: would be great to have an event that we could
        // wait on, but that isn't supported by the nb_get_initiators.
        // Maybe look at the get_initiators.
        wait();

        // This interface is going to take somewhere between 1 and 10 cycles
        // to pass any particular message along, in order to lazily simulate
        // the latency of the interface.
        int cycles = rand() % 10;
        for(int i = 0; i < cycles; i++) {
            wait();
        }
        
        if(llc_dma_rsp_out_tb.nb_can_get()) {
            llc_rsp_out_t<LLC_COH_DEV_ID_WIDTH> rsp;
            llc_dma_rsp_out_tb.nb_get(rsp);

            cerr << "LLC sent a dma rsp message, but you don't have a handler for it!" << endl;
        }
    }
}

// Emulate memory by responding to llc requests
void spandex_system_tb::mem_if()
{
    while(true) {

        wait();

        llc_mem_req_t llc_req;
        while(!llc_mem_req_tb.nb_can_get()) wait();
        llc_mem_req_tb.nb_get(llc_req);

        // Memory is going to take between 1 and 50 cycles to service
        // any incoming request, in order to lazily simulate the latency
        // of accessing main mem in the system
        int cycles = rand() % 50;
        for(int i = 0; i < cycles; i++) {
            wait();
        }

        if(llc_req.hwrite == HWRITE_READ) {
            put_mem_rsp(main_mem[llc_req.addr]);
        } else {
            main_mem[llc_req.addr] = llc_req.line;
        }
    }
}

void spandex_system_tb::spandex_system_test()
{
    /*
     * Reset
     */

    reset_spandex_system_test();

    CACHE_REPORT_INFO("[SPANDEX] Reset done!"); 

    system_test();

	CACHE_REPORT_VAR(sc_time_stamp(), "[SPANDEX] Error count", error_count);

    // End simulation
    sc_stop();
}

#define DEBUG0
#ifdef DEBUG0
#define PDBG(s) CACHE_REPORT_INFO(s)
#else
#define PDBG(s)
#endif

#define BITS_FOR_SIZE(sz) ( sz == WORD_64 ? 64 \
                          : sz == WORD_32 ? 32 \
                          : sz == HALFWORD ? 16 \
                          : 8)

#define ALIGN_ADDRESS(addr, sz) ( ((sz) == WORD_64) ? ((addr) - ((addr) % 8)) \
                                : ((sz) == WORD_32) ? ((addr) - ((addr) % 4)) \
                                : ((sz) == HALFWORD) ? ((addr) - ((addr) % 2)) \
                                : ((unsigned long long) addr))

void multi_wait(unsigned n) {
    for (unsigned cycle = 0; cycle < n; cycle++)
        wait();
}                                

void spandex_system_tb::system_test()
{
    if (0) {
        addr_t base_addr = 0x1000;
        addr_breakdown_t addr;
        l2_cpu_req_t cpu_req;
        word_t word;
        line_t line;

        static line_t mem_gold[MAIN_MEMORY_SPACE] = {};

        ////////////////////////////////////////////////////////////////
        // TEST 0.1 - Write a large array, read back and overwrite.
        ////////////////////////////////////////////////////////////////
        const unsigned test_0_1_length = 32 * 1024;
        CACHE_REPORT_INFO("[SPANDEX TB] Test 0.1!"); 
        CACHE_REPORT_INFO("[SPANDEX TB] Writing all elements!"); 

        for (unsigned i = 0; i < test_0_1_length; i++) {
            addr.breakdown(base_addr);
            word = i;
            line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
            line.range(BITS_PER_WORD - 1, 0) = word;

            hsize_t hsize = WORD;

            put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, hsize /* hsize */,
                base_addr /* addr */, word /* word */, DATA /* hprot */,
                0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

            unsigned bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
            unsigned bytes_offset = addr.b_off * 8;
            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);

            base_addr += 0x8;

            multi_wait(10);
        }

        base_addr = 0x1000;
        CACHE_REPORT_INFO("[SPANDEX TB] Read-modify-writing all elements!"); 

        for (unsigned i = 0; i < test_0_1_length; i++) {
            addr.breakdown(base_addr);

            hsize_t hsize = WORD;

            put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, hsize /* hsize */,
                base_addr /* addr */, 0 /* word */, DATA /* hprot */,
                0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

            wait();

            get_rd_rsp(mem_gold[addr.line_addr]);

            multi_wait(10);

            word = i+1;
            line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
            line.range(BITS_PER_WORD - 1, 0) = word;

            put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, hsize /* hsize */,
                base_addr /* addr */, word /* word */, DATA /* hprot */,
                0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

            unsigned bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
            unsigned bytes_offset = addr.b_off * 8;
            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);

            base_addr += 0x8;

            multi_wait(10);
        }

        ////////////////////////////////////////////////////////////////
        // TEST 0.2 - Emulate an FFT and read back
        ////////////////////////////////////////////////////////////////
        const unsigned test_0_2_length = 16 * 1024;
        CACHE_REPORT_INFO("[SPANDEX TB] Test 0.2!"); 
        CACHE_REPORT_INFO("[SPANDEX TB] Performing a 16*1024 FFT!");
        unsigned logn = 14;
    	unsigned transform_length = 1;
    	addr_t data_addr;

        base_addr = 0x1000;

    	for (unsigned bit = 0; bit < logn; bit++) {
    		for (unsigned a = 0; a < transform_length; a++) {
    			for (unsigned b = 0; b < test_0_2_length; b += 2 * transform_length) {
    				unsigned i = b + a;
    				unsigned j = b + a + transform_length;

                    hsize_t hsize = WORD;
                    unsigned bit_offset;
                    unsigned bytes_offset;

                    /////////////////////////////////////////
                    // z_real = data[2 * j];
                    /////////////////////////////////////////
                    data_addr = base_addr + ((2 * j) * 0x8);
                    addr.breakdown(data_addr);

                    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, 0 /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                    wait();

                    get_rd_rsp(mem_gold[addr.line_addr]);

                    /////////////////////////////////////////
                    // z_imag = data[2 * j + 1];
                    /////////////////////////////////////////
                    data_addr = base_addr + ((2 * j + 1) * 0x8);
                    addr.breakdown(data_addr);

                    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, 0 /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                    wait();

                    get_rd_rsp(mem_gold[addr.line_addr]);

                    multi_wait(10);

                    /////////////////////////////////////////
                    // data[2*j] = data[2*i] - t_real;
                    /////////////////////////////////////////
                    data_addr = base_addr + ((2*i) * 0x8);
                    addr.breakdown(data_addr);

                    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, 0 /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                    wait();

                    get_rd_rsp(mem_gold[addr.line_addr]);

                    wait();

                    data_addr = base_addr + ((2*j) * 0x8);
                    addr.breakdown(data_addr);

                    word = bit + a + b + 0x1;
                    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
                    line.range(BITS_PER_WORD - 1, 0) = word;

                    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, word /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);


                    bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    bytes_offset = addr.b_off * 8;
                    mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);

                    multi_wait(10);

                    /////////////////////////////////////////
                    // data[2*j + 1] = data[2*i + 1] - t_imag;
                    /////////////////////////////////////////
                    data_addr = base_addr + ((2*i + 1) * 0x8);
                    addr.breakdown(data_addr);

                    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, 0 /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                    wait();

                    get_rd_rsp(mem_gold[addr.line_addr]);

                    wait();

                    data_addr = base_addr + ((2*j + 1) * 0x8);
                    addr.breakdown(data_addr);

                    word = bit + a + b + 0x2;
                    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
                    line.range(BITS_PER_WORD - 1, 0) = word;

                    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, word /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                    bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    bytes_offset = addr.b_off * 8;
                    mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);

                    multi_wait(10);

                    /////////////////////////////////////////
                    // data[2*i] += t_real;
                    /////////////////////////////////////////
                    data_addr = base_addr + ((2*i) * 0x8);
                    addr.breakdown(data_addr);

                    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, 0 /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                    wait();

                    get_rd_rsp(mem_gold[addr.line_addr]);

                    wait();

                    data_addr = base_addr + ((2*i) * 0x8);
                    addr.breakdown(data_addr);

                    word = bit + a + b + 0x3;
                    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
                    line.range(BITS_PER_WORD - 1, 0) = word;

                    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, word /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                    bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    bytes_offset = addr.b_off * 8;
                    mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);

                    multi_wait(10);

                    /////////////////////////////////////////
                    // data[2*i + 1] += t_imag;
                    /////////////////////////////////////////
                    data_addr = base_addr + ((2*i + 1) * 0x8);
                    addr.breakdown(data_addr);

                    put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, 0 /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                    wait();

                    get_rd_rsp(mem_gold[addr.line_addr]);

                    wait();

                    data_addr = base_addr + ((2*i + 1) * 0x8);
                    addr.breakdown(data_addr);

                    word = bit + a + b + 0x4;
                    line.range(BITS_PER_LINE - 1, BITS_PER_WORD) = 0;
                    line.range(BITS_PER_WORD - 1, 0) = word;

                    put_cpu_req(cpu_req /* &cpu_req */, WRITE /* cpu_msg */, hsize /* hsize */,
                        data_addr /* addr */, word /* word */, DATA /* hprot */,
                        0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                        0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

                    bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    bytes_offset = addr.b_off * 8;
                    mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);

                    multi_wait(10);
    			}
    		}
    		transform_length *= 2;
    	}         

        base_addr = 0x1000;

        for (unsigned i = 0; i < test_0_2_length; i++) {
            addr.breakdown(base_addr);

            hsize_t hsize = WORD;

            put_cpu_req(cpu_req /* &cpu_req */, READ /* cpu_msg */, hsize /* hsize */,
                base_addr /* addr */, 0 /* word */, DATA /* hprot */,
                0 /* amo */, 0 /* aq */, 0 /* rl */, 0 /* dcs_en */,
                0 /* use_owner_pred */, 0 /* dcs */, 0 /* pred_cid */);

            wait();

            get_rd_rsp(mem_gold[addr.line_addr]);

            multi_wait(10);
        }
    }

    static l2_cpu_req_t cpu_req[40]; // Some buffer space
    int req_i = 0;
    #define REQ_I (req_i++ % (sizeof(cpu_req) / sizeof(cpu_req[0])))

    addr_t base_addr = 0x00001010, base_addr2;
    addr_breakdown_t addr, addr2;
    addr_t addr_amo[10];
    int amo_i = 0;
    bool atomicity = false; // If this is false, then we won't even try to
                            // perform the atomic operation, since I assume
                            // the CPU would take care of dis-allowing this.
    bool aq = (rand() % 100 == 0); // Rare aq
    bool rl = (rand() % 100 == 0); // Rare rl

    // A basic test to verify that the system is functioning properly
    if(0) {
        addr.breakdown(base_addr);
        put_cpu_req(cpu_req[REQ_I], WRITE, WORD, addr.word, 0x01, DATA, 0, aq, rl, false, false, 0, 0);

        wait();

        put_cpu_req(cpu_req[REQ_I], READ, WORD, addr.word, 0x01, DATA, 0, aq, rl, false, false, 0, 0);

        wait();

        get_rd_rsp(0x01);

        wait();

        return;
    }

    // A targeted test which attempts to exploit a particular behavior
    // The thought here is that it might be possible to exploit a behavior
    // where the LLC issues a line invalidation to the L2 while that line
    // still has some data to write to that line in the write buffer.
    if(0) {

        // Create the address
        addr.breakdown(base_addr);

        // Issue a read request from the CPU to get the line into the shared state
        put_cpu_req(cpu_req[REQ_I], READ, WORD, addr.word, 0x00, DATA, 0, aq, rl, false, false, 0, 0);

        wait();

        get_rd_rsp(0x00);

        // Issue a write request from the CPU to the L2 on that line that we accessed.
        put_cpu_req(cpu_req[REQ_I], WRITE, WORD, addr.word, 0x01, DATA, 0, aq, rl, false, false, 0, 0);

        for(int i = 0; i < 50; i++)
            wait();

        // Now issue a line invalidation request "from" the LLC to the L2. Note that this means that
        // we are deliberately putting the two caches in inconsistent states, so we can no longer rely on
        // proper behavior here.
        put_fwd_in(FWD_INV_SPDX, addr.line_addr, 0, 0, -1);

        for(int i = 0; i < 50; i++)
            wait();

        // Now that the line is invalidated, we are going to write to another line that shares a set with the
        // original in an attempt to overwrite the data there.
        base_addr2 = 0x01001010;
        addr2.breakdown(base_addr2);
        put_cpu_req(cpu_req[REQ_I], WRITE, WORD, addr2.word, 0x07, DATA, 0, aq, rl, false, false, 0, 0);

        for(int i = 0; i < 50; i++)
            wait();

        // Now, we will attempt to read from the L2 again. Depending on how much we've screwed things up by
        // faking a message from the LLC, this may or may not succeed, even if the L2 is behaving properly.
        // Instead of looking at that, look at the order to messages: does the L2 ever write any data back
        // to the LLC?
        put_cpu_req(cpu_req[REQ_I], READ, WORD, addr.word, 0x00, DATA, 0, aq, rl, false, false, 0, 0);

        wait();

        get_rd_rsp(0x01);

        return;
    }

    if (0) {
        #define LARGE_RANDOM ((unsigned long long)((rand() << 12) + rand()))
        #define EXTRA_LARGE_RANDOM ((LARGE_RANDOM << 24) + LARGE_RANDOM)

        line_t line = rand(), line2 = rand();
        static line_t mem_gold[MAIN_MEMORY_SPACE] = {};

        // A more complex test that attempts to make random access patterns and verify that
        // the memory remains consistent regardless.
        long long i = 0;
        int outstanding_writes = 0;
        while(i < 10000000) {
            // We have several types of accesses, but for now we're just going to
            // stick with reading/writing basic lines.

            // Generate a random read/write operation, and random data to use
            int operation = ((rand() % 2) * 2);
            line += EXTRA_LARGE_RANDOM;
            base_addr = LARGE_RANDOM % (MAIN_MEMORY_SPACE << LINE_RANGE_LO);
            int hsize = rand() % 4;
            base_addr = ALIGN_ADDRESS(base_addr, hsize);

            // For writes: randomly choose to either write-through forward the
            //             write or do a regular store
            bool wt_fwd_en = rand() % 2;
            int wt_hsize = wt_fwd_en ? 3 : hsize;

            // Uncomment to only target a single set of the caches
            // base_addr = base_addr & ~0x1FF0; // L2 set attacking
            // base_addr = base_addr & ~0x3FF0; // LLC set attacking

            if(operation == WRITE) {
                base_addr = ALIGN_ADDRESS(base_addr, wt_hsize);
                hsize = wt_hsize;
            }

            addr.breakdown(base_addr);
            int read_hprot = rand() % 2;

            aq = (rand() % 100 == 0); // Rare aq
            rl = (rand() % 100 == 0); // Rare rl

            switch(operation) {
                case READ: {
                    PDBG("About to READ...");
                    put_cpu_req(cpu_req[REQ_I], READ, hsize, base_addr, line, read_hprot, 0, aq, rl, false, false, 0, 0);

                    wait();

                    // Randomly decide to throw a write request in here
                    if(rand() % 2) {

                        line2 += EXTRA_LARGE_RANDOM;
                        base_addr2 = LARGE_RANDOM % (MAIN_MEMORY_SPACE << LINE_RANGE_LO);
                        int hsize2 = rand() % 4;
                        hsize2 = wt_fwd_en ? 3 : hsize2;
                        base_addr2 = ALIGN_ADDRESS(base_addr2, hsize2);
                        addr2.breakdown(base_addr2);

                        PDBG("About to WRITE (2)");
                        put_cpu_req(cpu_req[REQ_I], WRITE, hsize2, base_addr2, line2, DATA, 0, aq, rl, wt_fwd_en, false, wt_fwd_en, 0);

                        wait();

                        // We'll accept either the original line or the one that we just wrote as an answer if the addresses happen
                        // to coincide.
                        PDBG("About to get response");
                        if(addr.line_addr == addr2.line_addr) {
                            get_rd_rsp_or(mem_gold[addr.line_addr], line2);
                        } else {
                            get_rd_rsp(mem_gold[addr.line_addr]);
                        }

                        // Update the golden value
                        // TODO: we probably need to get a better system for indexing into our golden memory.
                        int bit_offset = addr2.w_off * BITS_PER_WORD + addr2.b_off * 8;
                        int bytes_offset = addr2.b_off * 8;
                        mem_gold[addr2.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize2) - 1, bit_offset) = line2.range(bytes_offset + BITS_FOR_SIZE(hsize2) - 1, bytes_offset);

                        // outstanding_writes++;

                    } else {
                        PDBG("About to get response");
                        // TODO: we probably need to get a better system for indexing into our golden memory.
                        get_rd_rsp(mem_gold[addr.line_addr]);
                    }

                    if(read_hprot == DATA)
                        atomicity = false;

                    break;
                }

                case READ_ATOMIC: {

                    hsize = rand() % 2 + 2; // 32 bit or 64 bit only
                    base_addr = ALIGN_ADDRESS(base_addr, hsize);
                    addr.breakdown(base_addr);

                    // Read from the memory location
                    put_cpu_req(cpu_req[REQ_I], READ_ATOMIC, hsize, base_addr, line, DATA, 0, aq, rl, false, false, 0, 0);

                    wait();

                    get_rd_rsp(mem_gold[addr.line_addr]);

                    amo_i = (amo_i + 1) % (sizeof(addr_amo) / sizeof(addr_amo[0]));
                    addr_amo[amo_i] = base_addr;
                    atomicity = true;

                    break;
                }

                case WRITE: {
                    PDBG("About to WRITE")
                    put_cpu_req(cpu_req[REQ_I], WRITE, hsize, base_addr, line, DATA, 0, aq, rl, wt_fwd_en, false, wt_fwd_en, 0);

                    // TODO: we probably need to get a better system for indexing into our golden memory.
                    int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    int bytes_offset = addr.b_off * 8;
                    mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);

                    atomicity = false;

                    // outstanding_writes++;

                    break;
                }

                case WRITE_ATOMIC: {

                    sc_uint<2> bresp;

                    // Make sure all of the outstanding writes are serviced first
                    while(outstanding_writes != 0) {
                        while(!l2_bresp_tb.nb_can_get()) wait();
                        l2_bresp_tb.nb_get(bresp);
                        outstanding_writes--;
                        wait();
                    }

                    if(atomicity) {

                        // If we have an outstanding request, then we will either try to access that location or a bogus one
                        switch(rand() % 2) {
                        case 0: {
                            hsize = rand() % 2 + 2; // 32 bit or 64 bit only
                            base_addr = ALIGN_ADDRESS(addr_amo[amo_i], hsize);
                            addr.breakdown(base_addr);

                            // Write to the reserved location
                            put_cpu_req(cpu_req[REQ_I], WRITE_ATOMIC, hsize, base_addr, line, DATA, 0, aq, rl, false, false, 0, 0);

                            // Get the result of the operation
                            while(!l2_bresp_tb.nb_can_get()) wait();
                            l2_bresp_tb.nb_get(bresp);

                            if(bresp == BRESP_EXOKAY) {
                                int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                                int bytes_offset = addr.b_off * 8;
                                PDBG("About to update golden memory. bit_offset = " << bit_offset << ".");
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);
                            }

                            break;
                        }

                        case 1: {

                            hsize = rand() % 2 + 2; // 32 bit or 64 bit only
                            base_addr = ALIGN_ADDRESS(base_addr, hsize);
                            addr.breakdown(base_addr);
                            addr_breakdown_t addr_amo_breakdown;
                            addr_amo_breakdown.breakdown(addr_amo[amo_i]);

                            // Try writing to a different location
                            put_cpu_req(cpu_req[REQ_I], WRITE_ATOMIC, hsize, base_addr, line, DATA, 0, aq, rl, false, false, 0, 0);

                            // Get the result of the operation
                            while(!l2_bresp_tb.nb_can_get()) wait();
                            l2_bresp_tb.nb_get(bresp);

                            if(bresp == BRESP_EXOKAY) {
                                // We happened to randomly choose an address that would work, so let's update the state.
                                int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                                int bytes_offset = addr.b_off * 8;
                                PDBG("About to update golden memory. bit_offset = " << bit_offset << ".");
                                mem_gold[addr_amo_breakdown.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);
                            }

                            break;
                        }

                        default:
                            break;
                        }

                    } else {
                        // If we don't have an outstanding reservation set, then we'll just try
                        // to access a random memory location and expect it to fail
                        put_cpu_req(cpu_req[REQ_I], WRITE_ATOMIC, WORD, addr.word, line, DATA, 0, aq, rl, false, false, 0, 0);

                        // Get the result of the operation
                        while(!l2_bresp_tb.nb_can_get()) wait();
                        l2_bresp_tb.nb_get(bresp);

                        if(bresp == BRESP_EXOKAY) {
                            error_count++;
                        }

                        // Note that we are NOT updating the golden memory here.
                    }

                    atomicity = false;

                    break;
                }

                default: {
                    // Do an AMO operation

                    // Select a random amo operation
                    const int amo_ops[] = {AMO_SWAP, AMO_ADD, AMO_AND, AMO_OR, AMO_XOR, AMO_MAX, AMO_MAXU, AMO_MIN, AMO_MINU};
                    int amo_op = amo_ops[rand() % (sizeof(amo_ops) / sizeof(amo_ops[0]))];

                    // Select a random size (only 32-bit and 64-bit supported)
                    hsize = (rand() % 2) + 2;

                    base_addr = ALIGN_ADDRESS(base_addr, hsize);
                    addr.breakdown(base_addr);

                    // Send the request
                    // TODO: I assume that a WRITE_ATOMIC would be an acceptable message to send, but I don't know what we actually
                    //       send in these cases. Might be interesting to also try with a WRITE in case it makes a difference.
                    // put_cpu_req(l2_cpu_req_t &cpu_req, cpu_msg_t cpu_msg, hsize_t hsize, 
                    //              addr_t addr, word_t word, hprot_t hprot, amo_t amo, bool aq, bool rl, bool dcs_en, 
                    //              bool use_owner_pred, dcs_t dcs, cache_id_t pred_cid)
                    put_cpu_req(cpu_req[REQ_I], WRITE_ATOMIC, hsize, base_addr, line, DATA, amo_op, aq, rl, false, false, 0, 0);

                    wait();

                    int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    int bytes_offset = addr.b_off * 8;

                    word_mask_t mask = 1 << addr.w_off;

                    // Read the result back: this should always be the old value of that memory location
                    get_rd_rsp(mem_gold[addr.line_addr], mask);
                    // get_rd_rsp(mem_gold[addr.line_addr]);

                    long long orig, line_val;

                    if(hsize == WORD_64) {
                        orig = mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset).to_int64();
                        line_val = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset).to_int64();
                    } else {
                        orig = mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset).to_int();
                        line_val = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset).to_int();
                    }

                    // Update the golden memory
                    PDBG("About to update golden memory. bit_offset = " << bit_offset << ".");
                    switch(amo_op) {
                    
                        case AMO_SWAP:
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            break;

                        case AMO_ADD:
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val + orig;
                            break;

                        case AMO_AND:
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = ~line_val & orig;
                            break;

                        case AMO_OR:
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val | orig;
                            break;

                        case AMO_XOR:
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val ^ orig;
                            break;

                        case AMO_MAX:
                            if(orig < line_val)
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            break;

                        case AMO_MAXU:
                            if(((unsigned long long) orig) < ((unsigned long long) line_val))
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            break;

                        case AMO_MIN:
                            if(orig > line_val)
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            break;

                        case AMO_MINU:
                            if(((unsigned long long) orig) > ((unsigned long long) line_val))
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            break;

                        default:
                            break;
                    }

                    // TODO: are we able to also send a read in here while waiting for the result of this operation to resolve? I'm not
                    //       sure how this would be transmitted over the AXI interface, but I'm guessing the answer is no. Might be worth
                    //       looking into though.

                    atomicity = false;

                    break;
                }
            }

            if(error_count > 0) {
	            CACHE_REPORT_VAR(sc_time_stamp(), "Error encountered at most recent operation", i);

                break;
            }

            i++;

            #ifdef EN_COVERAGE
            if(i % 10000 == 0) {
                CACHE_REPORT_INFO("Completed iteration " << i << ".");
                CACHE_REPORT_INFO("Coverages so far:");
                for(int i = 0; i < num_coverages; i++) {
                    if(coverages[i].name != NULL)
                        CACHE_REPORT_INFO(coverages[i].name << " (line " << i << ") : " << coverages[i].count);
                }
            }
            #endif

            wait();
        }

        CACHE_REPORT_INFO("Finished system test with 0x" << error_count << " errors after 0x" << i << " iterations.");
    }
}

/*
 * Functions
 */

inline void spandex_system_tb::reset_spandex_system_test()
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

    rpt = RPT_TB;

    wait();
}

void spandex_system_tb::put_cpu_req(l2_cpu_req_t &cpu_req, cpu_msg_t cpu_msg, hsize_t hsize, 
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

void spandex_system_tb::get_req_out(coh_msg_t coh_msg, addr_t addr, hprot_t hprot, line_t line, word_mask_t word_mask)
{
    l2_req_out_t req_out;

    while(!l2_req_out_tb.nb_get(req_out)) wait();

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

void spandex_system_tb::get_rsp_out(coh_msg_t coh_msg, cache_id_t req_id, bool to_req, addr_t addr,
    line_t line, word_mask_t word_mask)
{
    l2_rsp_out_t rsp_out;

    while(!l2_rsp_out_tb.nb_get(rsp_out)) wait();

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

void spandex_system_tb::put_fwd_in_(mix_msg_t coh_msg, addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask)
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

void spandex_system_tb::put_fwd_in(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask)
{
    l2_fwd_in_t fwd_in;
    
    fwd_in.coh_msg = coh_msg;
    fwd_in.addr = addr;
    fwd_in.req_id = req_id;
    fwd_in.line = line;
    fwd_in.word_mask = word_mask;

    l2_fwd_in_tb.put(fwd_in);

    if (rpt) CACHE_REPORT_VAR(sc_time_stamp(), "FWD_IN", fwd_in);
}

void spandex_system_tb::put_l2_rsp_in_(coh_msg_t coh_msg, addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt)
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

void spandex_system_tb::put_l2_rsp_in(coh_msg_t coh_msg, line_addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt)
{
    l2_rsp_in_t rsp_in;
    
    rsp_in.coh_msg = coh_msg;
    rsp_in.addr = addr;
    rsp_in.invack_cnt = invack_cnt;
    rsp_in.line = line;
    rsp_in.word_mask = word_mask;

    l2_rsp_in_tb.put(rsp_in);

    if (rpt) CACHE_REPORT_VAR(sc_time_stamp(), "RSP_IN", rsp_in);
}

void spandex_system_tb::get_rd_rsp(line_t line, word_mask_t mask)
{
    l2_rd_rsp_t rd_rsp;

    while(!l2_rd_rsp_tb.nb_get(rd_rsp)) wait();

    line_t rsp = rd_rsp.line;

    bool mismatch = false;
    const unsigned long long mask_word = 0xFFFFFFFFFFFFFFFF >> (64 - BITS_PER_WORD);

    for(int i = 0; i < WORDS_PER_LINE; i++) {
        if(mask & 0x01 == 1) {
            if((line & mask_word) != (rsp & mask_word)) {
                mismatch = true;
            }
        }

        mask >>= 1;
        line >>= BITS_PER_WORD;
        rsp >>= BITS_PER_WORD;
    }

    if (mismatch) {
        CACHE_REPORT_ERROR("get rd rsp     ", rd_rsp.line);
        CACHE_REPORT_ERROR("get rd rsp gold", line);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP", rd_rsp);
}

void spandex_system_tb::get_rd_rsp(line_t line)
{
    l2_rd_rsp_t rd_rsp;

    while(!l2_rd_rsp_tb.nb_get(rd_rsp)) wait();

    if (rd_rsp.line != line) {
        CACHE_REPORT_ERROR("get rd rsp     ", rd_rsp.line);
        CACHE_REPORT_ERROR("get rd rsp gold", line);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP", rd_rsp);
}

void spandex_system_tb::get_rd_rsp_or(line_t line, line_t line2)
{
    l2_rd_rsp_t rd_rsp;

    while(!l2_rd_rsp_tb.nb_get(rd_rsp)) wait();

    if (rd_rsp.line != line && rd_rsp.line != line2) {
        CACHE_REPORT_ERROR("get rd rsp         ", rd_rsp.line);
        CACHE_REPORT_ERROR("get rd rsp gold    ", line);
        CACHE_REPORT_ERROR("alt get rd rsp gold", line2);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP_OR", rd_rsp);
}

void spandex_system_tb::get_bresp(sc_uint<2> gold_bresp_val)
{
    sc_uint<2> bresp_val;

    while(!l2_bresp_tb.nb_get(bresp_val)) wait();

    if (bresp_val != gold_bresp_val) {
        CACHE_REPORT_ERROR("get bresp", bresp_val);
        CACHE_REPORT_ERROR("get bresp gold", gold_bresp_val);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "BRESP", bresp_val);
}

void spandex_system_tb::get_inval(addr_t addr, hprot_t hprot)
{
    l2_inval_t inval;
    
    while(!l2_inval_tb.nb_get(inval)) wait();

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

void spandex_system_tb::flush(int n_lines, bool is_flush_all)
{
    // issue flush
    l2_flush_tb.put(is_flush_all);

    for (int i = 0; i < n_lines; ++i) {
        l2_req_out_t req_out;
        while(!l2_req_out_tb.nb_get(req_out)) wait();
        addr_t tmp_addr = req_out.addr << OFFSET_BITS;
        wait();
    }

    wait();

    if (rpt)
	CACHE_REPORT_INFO("Flush done.");
}

void spandex_system_tb::put_mem_rsp(line_t line)
{
    llc_mem_rsp_t mem_rsp;
    mem_rsp.line = line;

    // rand_wait();

    llc_mem_rsp_tb.put(mem_rsp);

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "MEM_RSP", mem_rsp);
}

void spandex_system_tb::put_req_in_(mix_msg_t coh_msg, addr_t addr, line_t line, cache_id_t req_id,
			hprot_t hprot, word_offset_t woff, word_offset_t wvalid, word_mask_t word_mask)
{
    put_req_in(coh_msg, addr.range(TAG_RANGE_HI, SET_RANGE_LO), line, req_id, hprot, woff, wvalid, word_mask);
}

void spandex_system_tb::put_req_in(mix_msg_t coh_msg, line_addr_t addr, line_t line, cache_id_t req_id, hprot_t hprot, 
            word_offset_t woff, word_offset_t wvalid, word_mask_t word_mask)
{
    llc_req_in_t<CACHE_ID_WIDTH> req_in;
    req_in.coh_msg = coh_msg;
    req_in.hprot = hprot;
    req_in.addr = addr;
    req_in.line = line;
    req_in.req_id = req_id;
    req_in.word_offset = woff;
    req_in.valid_words = wvalid;
    req_in.word_mask = word_mask;

    // rand_wait();

    llc_req_in_tb.put(req_in);

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "REQ_IN", req_in);
}

void spandex_system_tb::put_dma_req_in(mix_msg_t coh_msg, addr_t addr, line_t line, llc_coh_dev_id_t req_id,
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

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "REQ_IN", req_in);
}

void spandex_system_tb::put_llc_rsp_in_(coh_msg_t rsp_msg, addr_t addr, line_t line, cache_id_t req_id, word_mask_t word_mask)
{
    llc_rsp_in_t rsp_in;
    rsp_in.coh_msg = rsp_msg;
    rsp_in.addr = addr.range(TAG_RANGE_HI, SET_RANGE_LO);
    rsp_in.line = line;
    rsp_in.req_id = req_id;
    rsp_in.word_mask = word_mask;

    // rand_wait();

    llc_rsp_in_tb.put(rsp_in);

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RSP_IN", rsp_in);
}

void spandex_system_tb::put_llc_rsp_in(coh_msg_t rsp_msg, line_addr_t addr, line_t line, cache_id_t req_id, word_mask_t word_mask)
{
    llc_rsp_in_t rsp_in;
    rsp_in.coh_msg = rsp_msg;
    rsp_in.addr = addr;
    rsp_in.line = line;
    rsp_in.req_id = req_id;
    rsp_in.word_mask = word_mask;

    // rand_wait();

    llc_rsp_in_tb.put(rsp_in);

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RSP_IN", rsp_in);
}