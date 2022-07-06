/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

	Modified by Zeran Zhu, Robert Jin, Vignesh Suresh
	zzhu35@illinois.edu
	
	April 9 2021

*/

#ifndef __l2_spandex_tb_HPP__
#define __l2_spandex_tb_HPP__

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <algorithm>
#include "spandex_utils.hpp"

class l2_spandex_tb : public sc_module
{
public:

    // Clock signal
    sc_in<bool> clk;

    // Reset signal
    sc_in<bool> rst;

    // Other signals
    sc_in<bool> flush_done;
    sc_in<bool> acc_flush_done;

    // Input ports
    put_initiator<l2_cpu_req_t> l2_cpu_req_tb;
    put_initiator<l2_fwd_in_t>	l2_fwd_in_tb;
    put_initiator<l2_rsp_in_t>	l2_rsp_in_tb;
    put_initiator<bool>		    l2_flush_tb;
    put_initiator<sc_uint<2> >  l2_fence_tb;

    // Output ports
    get_initiator<l2_rd_rsp_t>	l2_rd_rsp_tb;
    get_initiator<l2_inval_t>   l2_inval_tb;
    get_initiator<sc_uint<2> >  l2_bresp_tb;
    get_initiator<l2_req_out_t> l2_req_out_tb;
    get_initiator<l2_fwd_out_t> l2_fwd_out_tb;
    get_initiator<l2_rsp_out_t> l2_rsp_out_tb;

#ifdef STATS_ENABLE
    get_initiator<bool>         l2_stats_tb;
#endif 

    // Constructor
    SC_CTOR(l2_spandex_tb)
    {
	    // Process performing the test
	    SC_CTHREAD(l2_test, clk.pos());
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
#ifdef STATS_ENABLE
	    l2_stats_tb.clk_rst(clk, rst);
#endif
    }

    // Processes
    void l2_test();

#ifdef STATS_ENABLE
    void get_stats();
#endif

    // Functions
    inline void reset_l2_test();

    void put_cpu_req(l2_cpu_req_t &cpu_req, cpu_msg_t cpu_msg, hsize_t hsize, 
        addr_t addr, word_t word, hprot_t hprot, amo_t amo, bool aq, bool rl, bool dcs_en, 
        bool use_owner_pred, dcs_t dcs, cache_id_t pred_cid);
    void get_req_out(coh_msg_t coh_msg, addr_t addr, hprot_t hprot, line_t line, word_mask_t word_mask);
    void get_rsp_out(coh_msg_t coh_msg, cache_id_t req_id, bool to_req, addr_t addr, 
        line_t line, word_mask_t word_mask);
    void put_fwd_in(mix_msg_t coh_msg, addr_t addr, cache_id_t req_id, line_t line, word_mask_t word_mask);
    void put_rsp_in(coh_msg_t coh_msg, addr_t addr, line_t line, word_mask_t word_mask, invack_cnt_t invack_cnt);
    void get_rd_rsp(line_t line);
    void get_bresp(sc_uint<2> gold_bresp_val);
    void get_inval(addr_t addr_inval, hprot_t hprot_inval);
    void op(cpu_msg_t cpu_msg, int beh, int rsp_beh, coh_msg_t rsp_msg, invack_cnt_t invack_cnt, 
	    coh_msg_t put_msg, hsize_t hsize, addr_breakdown_t req_addr, word_t req_word, 
	    line_t rsp_line, int fwd_beh, mix_msg_t fwd_msg, state_t fwd_state, cache_id_t fwd_id, 
	    line_t fwd_line, hprot_t hprot);
    void op_flush(coh_msg_t coh_msg, addr_t addr);
    void flush(int n_lines, bool is_flush_all);

    int error_count;

private:

    bool rpt;
};


#endif /* __l2_spandex_tb_HPP__ */


