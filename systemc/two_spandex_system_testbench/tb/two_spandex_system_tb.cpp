/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

	Modified by Zeran Zhu, Robert Jin, Vignesh Suresh
	zzhu35@illinois.edu
	
	April 9 2021

*/

#include "two_spandex_system_tb.hpp"

#define L2_0_CID 0
#define L2_1_CID 1

#define HWRITE_READ  0
#define HWRITE_WRITE 1

#define TIME (sc_time_stamp())

static line_t mem_gold[MAIN_MEMORY_SPACE] = {};

void multi_wait(unsigned n) {
    for (unsigned cycle = 0; cycle < n; cycle++)
        wait();
}            

/*
 * Processes
 */

#ifdef STATS_ENABLE
void two_spandex_system_tb::get_stats()
{
    l2_stats_0_tb.reset_get();
    l2_stats_1_tb.reset_get();

    wait();

    while(true) {
        bool tmp;
        l2_stats_0_tb.get(tmp);
        wait();
        l2_stats_1_tb.get(tmp);
        wait();
    }
}
#endif

// Handle communication events between the caches
// Right now, this just forwards data between the
// two caches, adapting the interface as needed,
// but in theory it could also act as additional
// debugging by intercepting these messages.

void two_spandex_system_tb::l2_req_out_if()
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

        // Handle the request if available from cache 0
        // else handle the request if available from cache 1
        if(l2_req_out_0_tb.nb_can_get()) {
            l2_req_out_t l2_req;
            l2_req_out_0_tb.nb_get(l2_req);
            put_req_in(l2_req.coh_msg,
                       l2_req.addr,
                       l2_req.line,
                       L2_0_CID, // cache ID
                       l2_req.hprot,
                       0, // woff
                       0, // wvalid
                       l2_req.word_mask);
        } else if(l2_req_out_1_tb.nb_can_get()) {
            l2_req_out_t l2_req;
            l2_req_out_1_tb.nb_get(l2_req);
            put_req_in(l2_req.coh_msg,
                       l2_req.addr,
                       l2_req.line,
                       L2_1_CID, // cache ID
                       l2_req.hprot,
                       0, // woff
                       0, // wvalid
                       l2_req.word_mask);
        }
    }
}

void two_spandex_system_tb::l2_fwd_out_if()
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

        if(l2_fwd_out_0_tb.nb_can_get()) {
            l2_fwd_out_t l2_fwd;
            l2_fwd_out_0_tb.nb_get(l2_fwd);
            // TODO: do something with this

            cerr << "L2 0 sent a forward message, but you don't have a handler for it!" << endl;
        } else if(l2_fwd_out_1_tb.nb_can_get()) {
            l2_fwd_out_t l2_fwd;
            l2_fwd_out_1_tb.nb_get(l2_fwd);
            // TODO: do something with this

            cerr << "L2 1 sent a forward message, but you don't have a handler for it!" << endl;
        }        
    }
}

void two_spandex_system_tb::l2_rsp_out_if()
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

        // Handle the request if available from cache 0
        // else handle the request if available from cache 1
        if(l2_rsp_out_0_tb.nb_can_get()) {
            l2_rsp_out_t l2_rsp;
            l2_rsp_out_0_tb.nb_get(l2_rsp);
            if (l2_rsp.to_req) {
                if(l2_rsp.req_id == L2_1_CID) {
                    put_l2_rsp_in_1(l2_rsp.coh_msg,
                                l2_rsp.addr,
                                l2_rsp.line,
                                l2_rsp.word_mask,
                                0);
                } else {
                    CACHE_REPORT_VAR(TIME, "L2_Rsp, but to a different target", l2_rsp);
                }
            } else {
                put_llc_rsp_in(l2_rsp.coh_msg,
                            l2_rsp.addr,
                            l2_rsp.line,
                            l2_rsp.req_id,
                            l2_rsp.word_mask);
            }
        } else if(l2_rsp_out_1_tb.nb_can_get()) {
            l2_rsp_out_t l2_rsp;
            l2_rsp_out_1_tb.nb_get(l2_rsp);
            if (l2_rsp.to_req) {
                if(l2_rsp.req_id == L2_0_CID) {
                    put_l2_rsp_in_0(l2_rsp.coh_msg,
                                l2_rsp.addr,
                                l2_rsp.line,
                                l2_rsp.word_mask,
                                0);
                } else {
                    CACHE_REPORT_VAR(TIME, "L2_Rsp, but to a different target", l2_rsp);
                }
            } else {            
                put_llc_rsp_in(l2_rsp.coh_msg,
                            l2_rsp.addr,
                            l2_rsp.line,
                            l2_rsp.req_id,
                            l2_rsp.word_mask);
            }
        }
    }
}

void two_spandex_system_tb::llc_rsp_out_if()
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

        // Route the LLC response as indicated in dest id
        if(llc_rsp_out_tb.nb_can_get()) {
            llc_rsp_out_t<CACHE_ID_WIDTH> llc_rsp;
            llc_rsp_out_tb.nb_get(llc_rsp);
            if(llc_rsp.dest_id == L2_0_CID) {
                put_l2_rsp_in_0(llc_rsp.coh_msg,
                              llc_rsp.addr,
                              llc_rsp.line,
                              llc_rsp.word_mask,
                              llc_rsp.invack_cnt);
            } else if(llc_rsp.dest_id == L2_1_CID) {
                put_l2_rsp_in_1(llc_rsp.coh_msg,
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

void two_spandex_system_tb::llc_fwd_out_if()
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

        // Route the LLC response as indicated in dest id
        if(llc_fwd_out_tb.nb_can_get()) {
            llc_fwd_out_t llc_fwd;
            llc_fwd_out_tb.nb_get(llc_fwd);
            if(llc_fwd.dest_id == L2_0_CID) {
                put_fwd_in_0(llc_fwd.coh_msg,
                           llc_fwd.addr,
                           llc_fwd.req_id,
                           llc_fwd.line,
                           llc_fwd.word_mask);
            } else if(llc_fwd.dest_id == L2_1_CID) {
                put_fwd_in_1(llc_fwd.coh_msg,
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

void two_spandex_system_tb::l2_inval_if()
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

        if(l2_inval_0_tb.nb_can_get()) {
            l2_inval_t inval;
            l2_inval_0_tb.nb_get(inval);

            cerr << "L2 0 sent an inval message, but you don't have a handler for it!" << endl;

        } else if(l2_inval_1_tb.nb_can_get()) {
            l2_inval_t inval;
            l2_inval_1_tb.nb_get(inval);

            cerr << "L2 1 sent an inval message, but you don't have a handler for it!" << endl;

        }
    }
}

void two_spandex_system_tb::llc_dma_rsp_out_if()
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
void two_spandex_system_tb::mem_if()
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

void two_spandex_system_tb::two_spandex_system_test_0()
{
    /*
     * Reset
     */

    reset_two_spandex_system_test_0();

    CACHE_REPORT_INFO("[SPANDEX] Reset done!"); 

    system_test_0();

	CACHE_REPORT_VAR(sc_time_stamp(), "[SPANDEX] Error count", error_count);

    // End simulation
    sc_stop();
}

void two_spandex_system_tb::two_spandex_system_test_1()
{
    /*
     * Reset
     */

    reset_two_spandex_system_test_1();

    CACHE_REPORT_INFO("[SPANDEX] Reset done!"); 

    multi_wait(100);

    system_test_1();

	CACHE_REPORT_VAR(sc_time_stamp(), "[SPANDEX] Error count", error_count);
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

void two_spandex_system_tb::system_test_0()
{
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
        put_cpu_req_0(cpu_req[REQ_I], WRITE, WORD, addr.word, 0x01, DATA, 0, aq, rl, false, false, 0, 0);

        wait();

        put_cpu_req_0(cpu_req[REQ_I], READ, WORD, addr.word, 0x01, DATA, 0, aq, rl, false, false, 0, 0);

        wait();

        get_rd_rsp_0(0x01);

        wait();

        return;
    }

    if (1) {
        #define LARGE_RANDOM ((unsigned long long)((rand() << 12) + rand()))
        #define EXTRA_LARGE_RANDOM ((LARGE_RANDOM << 24) + LARGE_RANDOM)

        line_t line = rand(), line2 = rand();

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
                    put_cpu_req_0(cpu_req[REQ_I], READ, hsize, base_addr, line, read_hprot, 0, aq, rl, false, false, 0, 0);

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
                        put_cpu_req_0(cpu_req[REQ_I], WRITE, hsize2, base_addr2, line2, DATA, 0, aq, rl, wt_fwd_en, false, wt_fwd_en, 0);

                        wait();

                        // We'll accept either the original line or the one that we just wrote as an answer if the addresses happen
                        // to coincide.
                        PDBG("About to get response");
                        if(addr.line_addr == addr2.line_addr) {
                            mem_gold_mutex.lock();
                            get_rd_rsp_or_0(mem_gold[addr.line_addr], line2);
                            mem_gold_mutex.unlock();
                        } else {
                            mem_gold_mutex.lock();
                            get_rd_rsp_0(mem_gold[addr.line_addr]);
                            mem_gold_mutex.unlock();
                        }

                        // Update the golden value
                        // TODO: we probably need to get a better system for indexing into our golden memory.
                        int bit_offset = addr2.w_off * BITS_PER_WORD + addr2.b_off * 8;
                        int bytes_offset = addr2.b_off * 8;
                        mem_gold_mutex.lock();
                        mem_gold[addr2.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize2) - 1, bit_offset) = line2.range(bytes_offset + BITS_FOR_SIZE(hsize2) - 1, bytes_offset);
                        mem_gold_mutex.unlock();

                        // outstanding_writes++;

                    } else {
                        PDBG("About to get response");
                        // TODO: we probably need to get a better system for indexing into our golden memory.
                        mem_gold_mutex.lock();
                        get_rd_rsp_0(mem_gold[addr.line_addr]);
                        mem_gold_mutex.unlock();
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
                    put_cpu_req_0(cpu_req[REQ_I], READ_ATOMIC, hsize, base_addr, line, DATA, 0, aq, rl, false, false, 0, 0);

                    wait();

                    mem_gold_mutex.lock();
                    get_rd_rsp_0(mem_gold[addr.line_addr]);
                    mem_gold_mutex.unlock();

                    amo_i = (amo_i + 1) % (sizeof(addr_amo) / sizeof(addr_amo[0]));
                    addr_amo[amo_i] = base_addr;
                    atomicity = true;

                    break;
                }

                case WRITE: {
                    PDBG("About to WRITE")
                    put_cpu_req_0(cpu_req[REQ_I], WRITE, hsize, base_addr, line, DATA, 0, aq, rl, wt_fwd_en, false, wt_fwd_en, 0);

                    // TODO: we probably need to get a better system for indexing into our golden memory.
                    int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    int bytes_offset = addr.b_off * 8;
                    mem_gold_mutex.lock();
                    mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);
                    mem_gold_mutex.unlock();

                    atomicity = false;

                    // outstanding_writes++;

                    break;
                }

                case WRITE_ATOMIC: {

                    sc_uint<2> bresp;

                    // Make sure all of the outstanding writes are serviced first
                    while(outstanding_writes != 0) {
                        while(!l2_bresp_0_tb.nb_can_get()) wait();
                        l2_bresp_0_tb.nb_get(bresp);
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
                            put_cpu_req_0(cpu_req[REQ_I], WRITE_ATOMIC, hsize, base_addr, line, DATA, 0, aq, rl, false, false, 0, 0);

                            // Get the result of the operation
                            while(!l2_bresp_0_tb.nb_can_get()) wait();
                            l2_bresp_0_tb.nb_get(bresp);

                            if(bresp == BRESP_EXOKAY) {
                                int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                                int bytes_offset = addr.b_off * 8;
                                PDBG("About to update golden memory. bit_offset = " << bit_offset << ".");
                                mem_gold_mutex.lock();
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);
                                mem_gold_mutex.unlock();
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
                            put_cpu_req_0(cpu_req[REQ_I], WRITE_ATOMIC, hsize, base_addr, line, DATA, 0, aq, rl, false, false, 0, 0);

                            // Get the result of the operation
                            while(!l2_bresp_0_tb.nb_can_get()) wait();
                            l2_bresp_0_tb.nb_get(bresp);

                            if(bresp == BRESP_EXOKAY) {
                                // We happened to randomly choose an address that would work, so let's update the state.
                                int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                                int bytes_offset = addr.b_off * 8;
                                PDBG("About to update golden memory. bit_offset = " << bit_offset << ".");
                                mem_gold_mutex.lock();
                                mem_gold[addr_amo_breakdown.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);
                                mem_gold_mutex.unlock();
                            }

                            break;
                        }

                        default:
                            break;
                        }

                    } else {
                        // If we don't have an outstanding reservation set, then we'll just try
                        // to access a random memory location and expect it to fail
                        put_cpu_req_0(cpu_req[REQ_I], WRITE_ATOMIC, WORD, addr.word, line, DATA, 0, aq, rl, false, false, 0, 0);

                        // Get the result of the operation
                        while(!l2_bresp_0_tb.nb_can_get()) wait();
                        l2_bresp_0_tb.nb_get(bresp);

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
                    put_cpu_req_0(cpu_req[REQ_I], WRITE_ATOMIC, hsize, base_addr, line, DATA, amo_op, aq, rl, false, false, 0, 0);

                    wait();

                    int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    int bytes_offset = addr.b_off * 8;

                    word_mask_t mask = 1 << addr.w_off;

                    // Read the result back: this should always be the old value of that memory location
                    mem_gold_mutex.lock();
                    get_rd_rsp_0(mem_gold[addr.line_addr], mask);
                    mem_gold_mutex.unlock();
                    // get_rd_rsp(mem_gold[addr.line_addr]);

                    long long orig, line_val;

                    if(hsize == WORD_64) {
                        mem_gold_mutex.lock();
                        orig = mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset).to_int64();
                        mem_gold_mutex.unlock();
                        line_val = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset).to_int64();
                    } else {
                        mem_gold_mutex.lock();
                        orig = mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset).to_int();
                        mem_gold_mutex.unlock();
                        line_val = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset).to_int();
                    }

                    // Update the golden memory
                    PDBG("About to update golden memory. bit_offset = " << bit_offset << ".");
                    switch(amo_op) {
                    
                        case AMO_SWAP:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_ADD:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val + orig;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_AND:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = ~line_val & orig;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_OR:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val | orig;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_XOR:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val ^ orig;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_MAX:
                            mem_gold_mutex.lock();
                            if(orig < line_val)
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_MAXU:
                            mem_gold_mutex.lock();
                            if(((unsigned long long) orig) < ((unsigned long long) line_val))
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_MIN:
                            mem_gold_mutex.lock();
                            if(orig > line_val)
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_MINU:
                            mem_gold_mutex.lock();
                            if(((unsigned long long) orig) > ((unsigned long long) line_val))
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
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

void two_spandex_system_tb::system_test_1()
{
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
        put_cpu_req_1(cpu_req[REQ_I], WRITE, WORD, addr.word, 0x01, DATA, 0, aq, rl, false, false, 0, 0);

        wait();

        put_cpu_req_1(cpu_req[REQ_I], READ, WORD, addr.word, 0x01, DATA, 0, aq, rl, false, false, 0, 0);

        wait();

        get_rd_rsp_1(0x01);

        wait();

        return;
    }

    if (1) {
        #define LARGE_RANDOM ((unsigned long long)((rand() << 12) + rand()))
        #define EXTRA_LARGE_RANDOM ((LARGE_RANDOM << 24) + LARGE_RANDOM)

        line_t line = rand(), line2 = rand();

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
                    put_cpu_req_1(cpu_req[REQ_I], READ, hsize, base_addr, line, read_hprot, 0, aq, rl, false, false, 0, 0);

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
                        put_cpu_req_1(cpu_req[REQ_I], WRITE, hsize2, base_addr2, line2, DATA, 0, aq, rl, wt_fwd_en, false, wt_fwd_en, 0);

                        wait();

                        // We'll accept either the original line or the one that we just wrote as an answer if the addresses happen
                        // to coincide.
                        PDBG("About to get response");
                        if(addr.line_addr == addr2.line_addr) {
                            mem_gold_mutex.lock();
                            get_rd_rsp_or_1(mem_gold[addr.line_addr], line2);
                            mem_gold_mutex.unlock();
                        } else {
                            mem_gold_mutex.lock();
                            get_rd_rsp_1(mem_gold[addr.line_addr]);
                            mem_gold_mutex.unlock();
                        }

                        // Update the golden value
                        // TODO: we probably need to get a better system for indexing into our golden memory.
                        int bit_offset = addr2.w_off * BITS_PER_WORD + addr2.b_off * 8;
                        int bytes_offset = addr2.b_off * 8;
                        mem_gold_mutex.lock();
                        mem_gold[addr2.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize2) - 1, bit_offset) = line2.range(bytes_offset + BITS_FOR_SIZE(hsize2) - 1, bytes_offset);
                        mem_gold_mutex.unlock();

                        // outstanding_writes++;

                    } else {
                        PDBG("About to get response");
                        // TODO: we probably need to get a better system for indexing into our golden memory.
                        mem_gold_mutex.lock();
                        get_rd_rsp_1(mem_gold[addr.line_addr]);
                        mem_gold_mutex.unlock();
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
                    put_cpu_req_1(cpu_req[REQ_I], READ_ATOMIC, hsize, base_addr, line, DATA, 0, aq, rl, false, false, 0, 0);

                    wait();

                    mem_gold_mutex.lock();
                    get_rd_rsp_1(mem_gold[addr.line_addr]);
                    mem_gold_mutex.unlock();

                    amo_i = (amo_i + 1) % (sizeof(addr_amo) / sizeof(addr_amo[0]));
                    addr_amo[amo_i] = base_addr;
                    atomicity = true;

                    break;
                }

                case WRITE: {
                    PDBG("About to WRITE")
                    put_cpu_req_1(cpu_req[REQ_I], WRITE, hsize, base_addr, line, DATA, 0, aq, rl, wt_fwd_en, false, wt_fwd_en, 0);

                    // TODO: we probably need to get a better system for indexing into our golden memory.
                    int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    int bytes_offset = addr.b_off * 8;
                    mem_gold_mutex.lock();
                    mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);
                    mem_gold_mutex.unlock();

                    atomicity = false;

                    // outstanding_writes++;

                    break;
                }

                case WRITE_ATOMIC: {

                    sc_uint<2> bresp;

                    // Make sure all of the outstanding writes are serviced first
                    while(outstanding_writes != 0) {
                        while(!l2_bresp_1_tb.nb_can_get()) wait();
                        l2_bresp_1_tb.nb_get(bresp);
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
                            put_cpu_req_1(cpu_req[REQ_I], WRITE_ATOMIC, hsize, base_addr, line, DATA, 0, aq, rl, false, false, 0, 0);

                            // Get the result of the operation
                            while(!l2_bresp_1_tb.nb_can_get()) wait();
                            l2_bresp_1_tb.nb_get(bresp);

                            if(bresp == BRESP_EXOKAY) {
                                int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                                int bytes_offset = addr.b_off * 8;
                                PDBG("About to update golden memory. bit_offset = " << bit_offset << ".");
                                mem_gold_mutex.lock();
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);
                                mem_gold_mutex.unlock();
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
                            put_cpu_req_1(cpu_req[REQ_I], WRITE_ATOMIC, hsize, base_addr, line, DATA, 0, aq, rl, false, false, 0, 0);

                            // Get the result of the operation
                            while(!l2_bresp_1_tb.nb_can_get()) wait();
                            l2_bresp_1_tb.nb_get(bresp);

                            if(bresp == BRESP_EXOKAY) {
                                // We happened to randomly choose an address that would work, so let's update the state.
                                int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                                int bytes_offset = addr.b_off * 8;
                                PDBG("About to update golden memory. bit_offset = " << bit_offset << ".");
                                mem_gold_mutex.lock();
                                mem_gold[addr_amo_breakdown.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset);
                                mem_gold_mutex.unlock();
                            }

                            break;
                        }

                        default:
                            break;
                        }

                    } else {
                        // If we don't have an outstanding reservation set, then we'll just try
                        // to access a random memory location and expect it to fail
                        put_cpu_req_1(cpu_req[REQ_I], WRITE_ATOMIC, WORD, addr.word, line, DATA, 0, aq, rl, false, false, 0, 0);

                        // Get the result of the operation
                        while(!l2_bresp_1_tb.nb_can_get()) wait();
                        l2_bresp_1_tb.nb_get(bresp);

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
                    put_cpu_req_1(cpu_req[REQ_I], WRITE_ATOMIC, hsize, base_addr, line, DATA, amo_op, aq, rl, false, false, 0, 0);

                    wait();

                    int bit_offset = addr.w_off * BITS_PER_WORD + addr.b_off * 8;
                    int bytes_offset = addr.b_off * 8;

                    word_mask_t mask = 1 << addr.w_off;

                    // Read the result back: this should always be the old value of that memory location
                    mem_gold_mutex.lock();
                    get_rd_rsp_1(mem_gold[addr.line_addr], mask);
                    mem_gold_mutex.unlock();
                    // get_rd_rsp(mem_gold[addr.line_addr]);

                    long long orig, line_val;

                    if(hsize == WORD_64) {
                        mem_gold_mutex.lock();
                        orig = mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset).to_int64();
                        mem_gold_mutex.unlock();
                        line_val = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset).to_int64();
                    } else {
                        mem_gold_mutex.lock();
                        orig = mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset).to_int();
                        mem_gold_mutex.unlock();
                        line_val = line.range(bytes_offset + BITS_FOR_SIZE(hsize) - 1, bytes_offset).to_int();
                    }

                    // Update the golden memory
                    PDBG("About to update golden memory. bit_offset = " << bit_offset << ".");
                    switch(amo_op) {
                    
                        case AMO_SWAP:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_ADD:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val + orig;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_AND:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = ~line_val & orig;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_OR:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val | orig;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_XOR:
                            mem_gold_mutex.lock();
                            mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val ^ orig;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_MAX:
                            mem_gold_mutex.lock();
                            if(orig < line_val)
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_MAXU:
                            mem_gold_mutex.lock();
                            if(((unsigned long long) orig) < ((unsigned long long) line_val))
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_MIN:
                            mem_gold_mutex.lock();
                            if(orig > line_val)
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
                            break;

                        case AMO_MINU:
                            mem_gold_mutex.lock();
                            if(((unsigned long long) orig) > ((unsigned long long) line_val))
                                mem_gold[addr.line_addr].range(bit_offset + BITS_FOR_SIZE(hsize) - 1, bit_offset) = line_val;
                            mem_gold_mutex.unlock();
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

inline void two_spandex_system_tb::reset_two_spandex_system_test_0()
{
    l2_cpu_req_0_tb.reset_put();
    l2_fwd_in_0_tb.reset_put();
    l2_rsp_in_0_tb.reset_put();
    l2_flush_0_tb.reset_put();
    l2_fence_0_tb.reset_put();
    l2_rd_rsp_0_tb.reset_get();
    l2_inval_0_tb.reset_get();
    l2_bresp_0_tb.reset_get();
    l2_req_out_0_tb.reset_get();
    l2_fwd_out_0_tb.reset_get();
    l2_rsp_out_0_tb.reset_get();

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

inline void two_spandex_system_tb::reset_two_spandex_system_test_1()
{
    l2_cpu_req_1_tb.reset_put();
    l2_fwd_in_1_tb.reset_put();
    l2_rsp_in_1_tb.reset_put();
    l2_flush_1_tb.reset_put();
    l2_fence_1_tb.reset_put();
    l2_rd_rsp_1_tb.reset_get();
    l2_inval_1_tb.reset_get();
    l2_bresp_1_tb.reset_get();
    l2_req_out_1_tb.reset_get();
    l2_fwd_out_1_tb.reset_get();
    l2_rsp_out_1_tb.reset_get();

    wait();
}

void two_spandex_system_tb::put_cpu_req_0(l2_cpu_req_t &cpu_req, cpu_msg_t cpu_msg, hsize_t hsize, 
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

    l2_cpu_req_0_tb.put(cpu_req);

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "CPU_REQ 0", cpu_req);
}

void two_spandex_system_tb::put_cpu_req_1(l2_cpu_req_t &cpu_req, cpu_msg_t cpu_msg, hsize_t hsize, 
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

    l2_cpu_req_1_tb.put(cpu_req);

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "CPU_REQ 1", cpu_req);
}

void two_spandex_system_tb::put_fwd_in_0(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask)
{
    l2_fwd_in_t fwd_in;
    
    fwd_in.coh_msg = coh_msg;
    fwd_in.addr = addr;
    fwd_in.req_id = req_id;
    fwd_in.line = line;
    fwd_in.word_mask = word_mask;

    l2_fwd_in_0_tb.put(fwd_in);

    if (rpt) CACHE_REPORT_VAR(sc_time_stamp(), "FWD_IN 0", fwd_in);
}

void two_spandex_system_tb::put_fwd_in_1(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask)
{
    l2_fwd_in_t fwd_in;
    
    fwd_in.coh_msg = coh_msg;
    fwd_in.addr = addr;
    fwd_in.req_id = req_id;
    fwd_in.line = line;
    fwd_in.word_mask = word_mask;

    l2_fwd_in_1_tb.put(fwd_in);

    if (rpt) CACHE_REPORT_VAR(sc_time_stamp(), "FWD_IN 1", fwd_in);
}

void two_spandex_system_tb::put_l2_rsp_in_0(coh_msg_t coh_msg, line_addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt)
{
    l2_rsp_in_t rsp_in;
    
    rsp_in.coh_msg = coh_msg;
    rsp_in.addr = addr;
    rsp_in.invack_cnt = invack_cnt;
    rsp_in.line = line;
    rsp_in.word_mask = word_mask;

    l2_rsp_in_0_tb.put(rsp_in);

    if (rpt) CACHE_REPORT_VAR(sc_time_stamp(), "RSP_IN 0", rsp_in);
}

void two_spandex_system_tb::put_l2_rsp_in_1(coh_msg_t coh_msg, line_addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt)
{
    l2_rsp_in_t rsp_in;
    
    rsp_in.coh_msg = coh_msg;
    rsp_in.addr = addr;
    rsp_in.invack_cnt = invack_cnt;
    rsp_in.line = line;
    rsp_in.word_mask = word_mask;

    l2_rsp_in_1_tb.put(rsp_in);

    if (rpt) CACHE_REPORT_VAR(sc_time_stamp(), "RSP_IN 1", rsp_in);
}

void two_spandex_system_tb::get_rd_rsp_0(line_t line, word_mask_t mask)
{
    l2_rd_rsp_t rd_rsp;

    while(!l2_rd_rsp_0_tb.nb_get(rd_rsp)) wait();

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
        CACHE_REPORT_ERROR("get rd rsp 0     ", rd_rsp.line);
        CACHE_REPORT_ERROR("get rd rsp 0 gold", line);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP 0", rd_rsp);
}

void two_spandex_system_tb::get_rd_rsp_1(line_t line, word_mask_t mask)
{
    l2_rd_rsp_t rd_rsp;

    while(!l2_rd_rsp_1_tb.nb_get(rd_rsp)) wait();

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
        CACHE_REPORT_ERROR("get rd rsp 1     ", rd_rsp.line);
        CACHE_REPORT_ERROR("get rd rsp 1 gold", line);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP 1", rd_rsp);
}

void two_spandex_system_tb::get_rd_rsp_0(line_t line)
{
    l2_rd_rsp_t rd_rsp;

    while(!l2_rd_rsp_0_tb.nb_get(rd_rsp)) wait();

    if (rd_rsp.line != line) {
        CACHE_REPORT_ERROR("get rd rsp 0     ", rd_rsp.line);
        CACHE_REPORT_ERROR("get rd rsp 0 gold", line);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP 0", rd_rsp);
}

void two_spandex_system_tb::get_rd_rsp_1(line_t line)
{
    l2_rd_rsp_t rd_rsp;

    while(!l2_rd_rsp_1_tb.nb_get(rd_rsp)) wait();

    if (rd_rsp.line != line) {
        CACHE_REPORT_ERROR("get rd rsp 1     ", rd_rsp.line);
        CACHE_REPORT_ERROR("get rd rsp 1 gold", line);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP 1", rd_rsp);
}

void two_spandex_system_tb::get_rd_rsp_or_0(line_t line, line_t line2)
{
    l2_rd_rsp_t rd_rsp;

    while(!l2_rd_rsp_0_tb.nb_get(rd_rsp)) wait();

    if (rd_rsp.line != line && rd_rsp.line != line2) {
        CACHE_REPORT_ERROR("get rd rsp 0         ", rd_rsp.line);
        CACHE_REPORT_ERROR("get rd rsp 0 gold    ", line);
        CACHE_REPORT_ERROR("alt get rd 0 rsp gold", line2);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP_OR 0", rd_rsp);
}

void two_spandex_system_tb::get_rd_rsp_or_1(line_t line, line_t line2)
{
    l2_rd_rsp_t rd_rsp;

    while(!l2_rd_rsp_1_tb.nb_get(rd_rsp)) wait();

    if (rd_rsp.line != line && rd_rsp.line != line2) {
        CACHE_REPORT_ERROR("get rd rsp 1         ", rd_rsp.line);
        CACHE_REPORT_ERROR("get rd rsp 1 gold    ", line);
        CACHE_REPORT_ERROR("alt get rd 1 rsp gold", line2);
        error_count++;
    }

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "RD_RSP_OR 1", rd_rsp);
}

void two_spandex_system_tb::put_mem_rsp(line_t line)
{
    llc_mem_rsp_t mem_rsp;
    mem_rsp.line = line;

    // rand_wait();

    llc_mem_rsp_tb.put(mem_rsp);

    if (rpt)
	CACHE_REPORT_VAR(sc_time_stamp(), "MEM_RSP", mem_rsp);
}

void two_spandex_system_tb::put_req_in(mix_msg_t coh_msg, line_addr_t addr, line_t line, cache_id_t req_id, hprot_t hprot, 
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

void two_spandex_system_tb::put_llc_rsp_in(coh_msg_t rsp_msg, line_addr_t addr, line_t line, cache_id_t req_id, word_mask_t word_mask)
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