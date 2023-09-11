/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

	Modified by Zeran Zhu, Robert Jin, Vignesh Suresh
	zzhu35@illinois.edu
	
	April 9 2021

*/

#ifndef __TWO_SPANDEX_SYSTEM_TB_HPP__
#define __TWO_SPANDEX_SYSTEM_TB_HPP__

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <algorithm>
#include "spandex_utils.hpp"

#define MAIN_MEMORY_SPACE 0x80000

class two_spandex_system_tb : public sc_module
{
public:

    // Clock signal
    sc_in<bool> clk;

    // Reset signal
    sc_in<bool> rst;

    // Other signals
    sc_in<bool> flush_done_0;
    sc_in<bool> acc_flush_done_0;
    sc_in<bool> flush_done_1;
    sc_in<bool> acc_flush_done_1;

    // L2 0 Input ports
    put_initiator<l2_cpu_req_t> l2_cpu_req_0_tb;
    put_initiator<l2_fwd_in_t>	l2_fwd_in_0_tb;
    put_initiator<l2_rsp_in_t>	l2_rsp_in_0_tb;
    put_initiator<bool>		    l2_flush_0_tb;
    put_initiator<sc_uint<2> >  l2_fence_0_tb;

    // L2 0 Output ports
    nb_get_initiator<l2_rd_rsp_t>	l2_rd_rsp_0_tb;
    nb_get_initiator<l2_inval_t>    l2_inval_0_tb;
    nb_get_initiator<sc_uint<2> >   l2_bresp_0_tb;
    nb_get_initiator<l2_req_out_t>  l2_req_out_0_tb;
    nb_get_initiator<l2_fwd_out_t>  l2_fwd_out_0_tb;
    nb_get_initiator<l2_rsp_out_t>  l2_rsp_out_0_tb;

#ifdef STATS_ENABLE
    get_initiator<bool>         l2_stats_0_tb;
#endif 

    // L2 1 Input ports
    put_initiator<l2_cpu_req_t> l2_cpu_req_1_tb;
    put_initiator<l2_fwd_in_t>	l2_fwd_in_1_tb;
    put_initiator<l2_rsp_in_t>	l2_rsp_in_1_tb;
    put_initiator<bool>		    l2_flush_1_tb;
    put_initiator<sc_uint<2> >  l2_fence_1_tb;

    // L2 1 Output ports
    nb_get_initiator<l2_rd_rsp_t>	l2_rd_rsp_1_tb;
    nb_get_initiator<l2_inval_t>    l2_inval_1_tb;
    nb_get_initiator<sc_uint<2> >   l2_bresp_1_tb;
    nb_get_initiator<l2_req_out_t>  l2_req_out_1_tb;
    nb_get_initiator<l2_fwd_out_t>  l2_fwd_out_1_tb;
    nb_get_initiator<l2_rsp_out_t>  l2_rsp_out_1_tb;

#ifdef STATS_ENABLE
    get_initiator<bool>         l2_stats_1_tb;
#endif 

    // LLC Input ports
    put_initiator<llc_req_in_t<CACHE_ID_WIDTH> >         llc_req_in_tb;
    put_initiator<llc_req_in_t<LLC_COH_DEV_ID_WIDTH> >   llc_dma_req_in_tb;
    put_initiator<llc_rsp_in_t>     llc_rsp_in_tb;
    put_initiator<llc_mem_rsp_t>    llc_mem_rsp_tb; 
    put_initiator<bool>             llc_rst_tb_tb; 

    // LLC Output ports
    nb_get_initiator<llc_rsp_out_t<CACHE_ID_WIDTH> >            llc_rsp_out_tb;
    nb_get_initiator<llc_rsp_out_t<LLC_COH_DEV_ID_WIDTH> >      llc_dma_rsp_out_tb;
    nb_get_initiator<llc_fwd_out_t>    llc_fwd_out_tb;
    nb_get_initiator<llc_mem_req_t>    llc_mem_req_tb;
    nb_get_initiator<bool>             llc_rst_tb_done_tb;

#ifdef STATS_ENABLE
    get_initiator<bool>             llc_stats_tb;
#endif

    sc_mutex mem_gold_mutex;

    // Constructor
    SC_CTOR(two_spandex_system_tb) : main_mem({})
    {
        /*
        * Random seed
        */
        
        // initialize
        srand(0);

	    // Processes performing the test
	    SC_CTHREAD(two_spandex_system_test_0, clk.pos());
	    reset_signal_is(rst, false);
	    SC_CTHREAD(two_spandex_system_test_1, clk.pos());
	    reset_signal_is(rst, false);

        // Processes handling the inter-$ comms
        SC_CTHREAD(l2_req_out_if, clk.pos());
        reset_signal_is(rst, false);
        SC_CTHREAD(l2_fwd_out_if, clk.pos());
        reset_signal_is(rst, false);
        SC_CTHREAD(l2_rsp_out_if, clk.pos());
        reset_signal_is(rst, false);
        SC_CTHREAD(llc_rsp_out_if, clk.pos());
        reset_signal_is(rst, false);
        SC_CTHREAD(llc_fwd_out_if, clk.pos());
        reset_signal_is(rst, false);
        SC_CTHREAD(l2_inval_if, clk.pos());
        reset_signal_is(rst, false);
        SC_CTHREAD(llc_dma_rsp_out_if, clk.pos());
        reset_signal_is(rst, false);

        // Emulate main memory
        SC_CTHREAD(mem_if, clk.pos());
        reset_signal_is(rst, false);

#ifdef STATS_ENABLE
	    SC_CTHREAD(get_stats, clk.pos());
	    reset_signal_is(rst, false);
#endif
	    // Assign clock and reset to put_get ports
	    l2_cpu_req_0_tb.clk_rst(clk, rst);
	    l2_fwd_in_0_tb.clk_rst(clk, rst);
	    l2_rsp_in_0_tb.clk_rst(clk, rst);
	    l2_flush_0_tb.clk_rst(clk, rst);
	    l2_fence_0_tb.clk_rst(clk, rst);
	    l2_rd_rsp_0_tb.clk_rst(clk, rst);
	    l2_inval_0_tb.clk_rst(clk, rst);
	    l2_bresp_0_tb.clk_rst(clk, rst);
	    l2_req_out_0_tb.clk_rst(clk, rst);
	    l2_fwd_out_0_tb.clk_rst(clk, rst);
	    l2_rsp_out_0_tb.clk_rst(clk, rst);

	    l2_cpu_req_1_tb.clk_rst(clk, rst);
	    l2_fwd_in_1_tb.clk_rst(clk, rst);
	    l2_rsp_in_1_tb.clk_rst(clk, rst);
	    l2_flush_1_tb.clk_rst(clk, rst);
	    l2_fence_1_tb.clk_rst(clk, rst);
	    l2_rd_rsp_1_tb.clk_rst(clk, rst);
	    l2_inval_1_tb.clk_rst(clk, rst);
	    l2_bresp_1_tb.clk_rst(clk, rst);
	    l2_req_out_1_tb.clk_rst(clk, rst);
	    l2_fwd_out_1_tb.clk_rst(clk, rst);
	    l2_rsp_out_1_tb.clk_rst(clk, rst);

        llc_req_in_tb.clk_rst (clk, rst);
	    llc_dma_req_in_tb.clk_rst (clk, rst);
	    llc_rsp_in_tb.clk_rst (clk, rst);
	    llc_mem_rsp_tb.clk_rst(clk, rst);
	    llc_rst_tb_tb.clk_rst(clk, rst);
	    llc_dma_rsp_out_tb.clk_rst(clk, rst);
	    llc_rsp_out_tb.clk_rst(clk, rst);
	    llc_fwd_out_tb.clk_rst(clk, rst);
	    llc_mem_req_tb.clk_rst(clk, rst);
	    llc_rst_tb_done_tb.clk_rst(clk, rst);

#ifdef STATS_ENABLE
	    l2_stats_0_tb.clk_rst(clk, rst);
	    l2_stats_1_tb.clk_rst(clk, rst);
        llc_stats_tb.clk_rst(clk, rst);
#endif
    }

    // Processes
    void two_spandex_system_test_0();
    void two_spandex_system_test_1();

    // Inter-$ communication process
    void l2_req_out_if();
    void l2_fwd_out_if();
    void l2_rsp_out_if();
    void llc_rsp_out_if();
    void llc_fwd_out_if();
    void l2_inval_if();
    void llc_dma_rsp_out_if();

    // Memory interface process
    void mem_if();

#ifdef STATS_ENABLE
    void get_stats();
#endif

    // Functions
    inline void reset_two_spandex_system_test_0();
    inline void reset_two_spandex_system_test_1();

    void system_test_0();
    void system_test_1();

    void put_cpu_req_0(l2_cpu_req_t &cpu_req, cpu_msg_t cpu_msg, hsize_t hsize, 
        addr_t addr, word_t word, hprot_t hprot, amo_t amo, bool aq, bool rl, bool dcs_en, 
        bool use_owner_pred, dcs_t dcs, cache_id_t pred_cid);
    void put_cpu_req_1(l2_cpu_req_t &cpu_req, cpu_msg_t cpu_msg, hsize_t hsize, 
        addr_t addr, word_t word, hprot_t hprot, amo_t amo, bool aq, bool rl, bool dcs_en, 
        bool use_owner_pred, dcs_t dcs, cache_id_t pred_cid);
    void get_req_out_0(coh_msg_t coh_msg, addr_t addr, hprot_t hprot, line_t line, word_mask_t word_mask);
    void get_req_out_1(coh_msg_t coh_msg, addr_t addr, hprot_t hprot, line_t line, word_mask_t word_mask);
    void put_fwd_in_0(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask);
    void put_fwd_in_1(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask);
    void put_l2_rsp_in_0(coh_msg_t coh_msg, line_addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt);
    void put_l2_rsp_in_1(coh_msg_t coh_msg, line_addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt);
    void get_rd_rsp_0(line_t line);
    void get_rd_rsp_1(line_t line);
    void get_rd_rsp_0(line_t line, word_mask_t mask);
    void get_rd_rsp_1(line_t line, word_mask_t mask);
    void get_rd_rsp_or_0(line_t line, line_t line2);
    void get_rd_rsp_or_1(line_t line, line_t line2);

    void put_mem_rsp(line_t line);
    void put_req_in(mix_msg_t coh_msg, line_addr_t addr, line_t line, cache_id_t cache_id, hprot_t hprot, 
            word_offset_t woff, word_offset_t wvalid, word_mask_t word_mask);
    void put_llc_rsp_in(coh_msg_t rsp_msg, line_addr_t addr, line_t line, cache_id_t req_id, word_mask_t word_mask);


    int error_count;

private:

    line_t main_mem[MAIN_MEMORY_SPACE];

    bool rpt;
};


#endif /* __TWO_SPANDEX_SYSTEM_TB_HPP__ */


