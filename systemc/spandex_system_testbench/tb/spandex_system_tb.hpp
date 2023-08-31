/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

	Modified by Zeran Zhu, Robert Jin, Vignesh Suresh
	zzhu35@illinois.edu
	
	April 9 2021

*/

#ifndef __SPANDEX_SYSTEM_TB_HPP__
#define __SPANDEX_SYSTEM_TB_HPP__

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <algorithm>
#include "spandex_utils.hpp"

#define MAIN_MEMORY_SPACE 0x80000

class spandex_system_tb : public sc_module
{
public:

    // Clock signal
    sc_in<bool> clk;

    // Reset signal
    sc_in<bool> rst;

    // Other signals
    sc_in<bool> flush_done;
    sc_in<bool> acc_flush_done;

    // L2 Input ports
    put_initiator<l2_cpu_req_t> l2_cpu_req_tb;
    put_initiator<l2_fwd_in_t>	l2_fwd_in_tb;
    put_initiator<l2_rsp_in_t>	l2_rsp_in_tb;
    put_initiator<bool>		    l2_flush_tb;
    put_initiator<sc_uint<2> >  l2_fence_tb;

    // L2 Output ports
    nb_get_initiator<l2_rd_rsp_t>	l2_rd_rsp_tb;
    nb_get_initiator<l2_inval_t>   l2_inval_tb;
    nb_get_initiator<sc_uint<2> >  l2_bresp_tb;
    nb_get_initiator<l2_req_out_t> l2_req_out_tb;
    nb_get_initiator<l2_fwd_out_t> l2_fwd_out_tb;
    nb_get_initiator<l2_rsp_out_t> l2_rsp_out_tb;

#ifdef STATS_ENABLE
    get_initiator<bool>         l2_stats_tb;
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

    // Constructor
    SC_CTOR(spandex_system_tb) : main_mem({})
    {
        /*
        * Random seed
        */
        
        // initialize
        srand(0);

	    // Process performing the test
	    SC_CTHREAD(spandex_system_test, clk.pos());
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
	    l2_cpu_req_tb.clk_rst(clk, rst);
	    l2_fwd_in_tb.clk_rst(clk, rst);
	    l2_rsp_in_tb.clk_rst(clk, rst);
	    l2_flush_tb.clk_rst(clk, rst);
	    l2_fence_tb.clk_rst(clk, rst);
	    l2_rd_rsp_tb.clk_rst(clk, rst);
	    l2_inval_tb.clk_rst(clk, rst);
	    l2_bresp_tb.clk_rst(clk, rst);
	    l2_req_out_tb.clk_rst(clk, rst);
	    l2_fwd_out_tb.clk_rst(clk, rst);
	    l2_rsp_out_tb.clk_rst(clk, rst);

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
	    l2_stats_tb.clk_rst(clk, rst);
        llc_stats_tb.clk_rst(clk, rst);
#endif
    }

    // Processes
    void spandex_system_test();

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
    inline void reset_spandex_system_test();

    void system_test();

    void put_cpu_req(l2_cpu_req_t &cpu_req, cpu_msg_t cpu_msg, hsize_t hsize, 
        addr_t addr, word_t word, hprot_t hprot, amo_t amo, bool aq, bool rl, bool dcs_en, 
        bool use_owner_pred, dcs_t dcs, cache_id_t pred_cid);
    void get_req_out(coh_msg_t coh_msg, addr_t addr, hprot_t hprot, line_t line, word_mask_t word_mask);
    void get_rsp_out(coh_msg_t coh_msg, cache_id_t req_id, bool to_req, addr_t addr, 
        line_t line, word_mask_t word_mask);
    void put_fwd_in_(mix_msg_t coh_msg, addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask);
    void put_fwd_in(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask);
    void put_l2_rsp_in_(coh_msg_t coh_msg, addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt);
    void put_l2_rsp_in(coh_msg_t coh_msg, line_addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt);
    void get_rd_rsp(line_t line);
    void get_rd_rsp(line_t line, word_mask_t mask);
    void get_rd_rsp_or(line_t line, line_t line2);
    void get_bresp(sc_uint<2> gold_bresp_val);
    void get_inval(addr_t addr_inval, hprot_t hprot_inval);
    void op(cpu_msg_t cpu_msg, int beh, int rsp_beh, coh_msg_t rsp_msg, invack_cnt_t invack_cnt, 
	    coh_msg_t put_msg, hsize_t hsize, addr_breakdown_t req_addr, word_t req_word, 
	    line_t rsp_line, int fwd_beh, mix_msg_t fwd_msg, state_t fwd_state, cache_id_t fwd_id, 
	    line_t fwd_line, hprot_t hprot);
    void op_flush(coh_msg_t coh_msg, addr_t addr);
    void flush(int n_lines, bool is_flush_all);

    void put_mem_rsp(line_t line);
    void put_req_in_(mix_msg_t coh_msg, addr_t addr, line_t line, cache_id_t cache_id, hprot_t hprot,
		    word_offset_t woff, word_offset_t wvalid, word_mask_t word_mask);
    void put_req_in(mix_msg_t coh_msg, line_addr_t addr, line_t line, cache_id_t cache_id, hprot_t hprot, 
            word_offset_t woff, word_offset_t wvalid, word_mask_t word_mask);
    void put_dma_req_in(mix_msg_t coh_msg, addr_t addr, line_t line, llc_coh_dev_id_t cache_id, hprot_t hprot,
                        word_offset_t woff, word_offset_t wvalid);
    void put_llc_rsp_in_(coh_msg_t rsp_msg, addr_t addr, line_t line, cache_id_t req_id, word_mask_t word_mask);
    void put_llc_rsp_in(coh_msg_t rsp_msg, line_addr_t addr, line_t line, cache_id_t req_id, word_mask_t word_mask);


    int error_count;

private:

    line_t main_mem[MAIN_MEMORY_SPACE];

    bool rpt;
};


#endif /* __SPANDEX_SYSTEM_TB_HPP__ */


