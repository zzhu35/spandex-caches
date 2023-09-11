// Copyright (c) 2011-2022 Columbia University, System Level Design Group
// SPDX-License-Identifier: Apache-2.0

#ifndef __SYSTEM_HPP__
#define __SYSTEM_HPP__

#include "two_spandex_system_wrap.h"
#include "two_spandex_system_tb.hpp"

class system_t : public sc_module
{

public:

    // Clock signal
    sc_in<bool> clk;

    // Reset signal
    sc_in<bool> rst;

    // Signals
    // L2 cache 0
    sc_signal<bool> flush_done_0;
    sc_signal<bool> acc_flush_done_0;

    // L2 cache 1
    sc_signal<bool> flush_done_1;
    sc_signal<bool> acc_flush_done_1;

    // Channels
    // To L2 cache 0
    put_get_channel<l2_cpu_req_t>	l2_cpu_req_0_chnl;
    put_get_channel<l2_fwd_in_t>	l2_fwd_in_0_chnl;
    put_get_channel<l2_rsp_in_t>	l2_rsp_in_0_chnl;
    put_get_channel<bool>		    l2_flush_0_chnl;
    put_get_channel<sc_uint<2> >    l2_fence_0_chnl;

    // From L2 cache 0
    put_get_channel<l2_rd_rsp_t>	l2_rd_rsp_0_chnl;
    put_get_channel<l2_inval_t>     l2_inval_0_chnl;
    put_get_channel<sc_uint<2> >    l2_bresp_0_chnl;
    put_get_channel<l2_req_out_t>	l2_req_out_0_chnl;
    put_get_channel<l2_fwd_out_t>	l2_fwd_out_0_chnl;
    put_get_channel<l2_rsp_out_t>	l2_rsp_out_0_chnl;

#ifdef STATS_ENABLE
    put_get_channel<bool>           l2_stats_0_chnl;
#endif

    // To L2 cache 1
    put_get_channel<l2_cpu_req_t>	l2_cpu_req_1_chnl;
    put_get_channel<l2_fwd_in_t>	l2_fwd_in_1_chnl;
    put_get_channel<l2_rsp_in_t>	l2_rsp_in_1_chnl;
    put_get_channel<bool>		    l2_flush_1_chnl;
    put_get_channel<sc_uint<2> >    l2_fence_1_chnl;

    // From L2 cache 1
    put_get_channel<l2_rd_rsp_t>	l2_rd_rsp_1_chnl;
    put_get_channel<l2_inval_t>     l2_inval_1_chnl;
    put_get_channel<sc_uint<2> >    l2_bresp_1_chnl;
    put_get_channel<l2_req_out_t>	l2_req_out_1_chnl;
    put_get_channel<l2_fwd_out_t>	l2_fwd_out_1_chnl;
    put_get_channel<l2_rsp_out_t>	l2_rsp_out_1_chnl;

#ifdef STATS_ENABLE
    put_get_channel<bool>           l2_stats_1_chnl;
#endif

    // To LLC cache
    put_get_channel<llc_req_in_t<CACHE_ID_WIDTH> >  llc_req_in_chnl;
    put_get_channel<llc_req_in_t<LLC_COH_DEV_ID_WIDTH> >  llc_dma_req_in_chnl;
    put_get_channel<llc_rsp_in_t>  llc_rsp_in_chnl;
    put_get_channel<llc_mem_rsp_t> llc_mem_rsp_chnl;
    put_get_channel<bool>          llc_rst_tb_chnl;

    // From LLC cache
    put_get_channel<llc_rsp_out_t<CACHE_ID_WIDTH> > llc_rsp_out_chnl;
    put_get_channel<llc_rsp_out_t<LLC_COH_DEV_ID_WIDTH> > llc_dma_rsp_out_chnl;
    put_get_channel<llc_fwd_out_t> llc_fwd_out_chnl;
    put_get_channel<llc_mem_req_t> llc_mem_req_chnl;
    put_get_channel<bool>          llc_rst_tb_done_chnl;

#ifdef STATS_ENABLE
    put_get_channel<bool> llc_stats_chnl;
#endif

    // Modules
    // L2 cache instance 0
    l2_wrapper_conv	*l2_dut_0;
    // L2 cache instance 1
    l2_wrapper_conv	*l2_dut_1;
    // LLC cache instance
    llc_wrapper_conv *llc_dut;
    // LLC testbench module
    two_spandex_system_tb *tb;

    // Constructor
    SC_CTOR(system_t)
    {
	// Modules
	l2_dut_0 = new l2_wrapper_conv("l2_wrapper_conv_0");
	l2_dut_1 = new l2_wrapper_conv("l2_wrapper_conv_1");
	llc_dut = new llc_wrapper_conv("llc_wrapper_conv");
	tb = new two_spandex_system_tb("two_spandex_system_tb");

	// Binding L2 cache 0
	l2_dut_0->clk(clk);
	l2_dut_0->rst(rst);
	l2_dut_0->flush_done(flush_done_0);
	l2_dut_0->acc_flush_done(acc_flush_done_0);
	l2_dut_0->l2_cpu_req(l2_cpu_req_0_chnl);
	l2_dut_0->l2_fwd_in(l2_fwd_in_0_chnl);
	l2_dut_0->l2_rsp_in(l2_rsp_in_0_chnl);
	l2_dut_0->l2_flush(l2_flush_0_chnl);
	l2_dut_0->l2_fence(l2_fence_0_chnl);
	l2_dut_0->l2_rd_rsp(l2_rd_rsp_0_chnl);
	l2_dut_0->l2_inval(l2_inval_0_chnl);
	l2_dut_0->l2_bresp(l2_bresp_0_chnl);
	l2_dut_0->l2_req_out(l2_req_out_0_chnl);
	l2_dut_0->l2_fwd_out(l2_fwd_out_0_chnl);
	l2_dut_0->l2_rsp_out(l2_rsp_out_0_chnl);	

	// Binding L2 cache 1
	l2_dut_1->clk(clk);
	l2_dut_1->rst(rst);
	l2_dut_1->flush_done(flush_done_1);
	l2_dut_1->acc_flush_done(acc_flush_done_1);
	l2_dut_1->l2_cpu_req(l2_cpu_req_1_chnl);
	l2_dut_1->l2_fwd_in(l2_fwd_in_1_chnl);
	l2_dut_1->l2_rsp_in(l2_rsp_in_1_chnl);
	l2_dut_1->l2_flush(l2_flush_1_chnl);
	l2_dut_1->l2_fence(l2_fence_1_chnl);
	l2_dut_1->l2_rd_rsp(l2_rd_rsp_1_chnl);
	l2_dut_1->l2_inval(l2_inval_1_chnl);
	l2_dut_1->l2_bresp(l2_bresp_1_chnl);
	l2_dut_1->l2_req_out(l2_req_out_1_chnl);
	l2_dut_1->l2_fwd_out(l2_fwd_out_1_chnl);
	l2_dut_1->l2_rsp_out(l2_rsp_out_1_chnl);	

	// Binding LLC cache
	llc_dut->clk(clk);
	llc_dut->rst(rst);
	llc_dut->llc_req_in(llc_req_in_chnl);
	llc_dut->llc_dma_req_in(llc_dma_req_in_chnl);
	llc_dut->llc_rsp_in(llc_rsp_in_chnl);
	llc_dut->llc_mem_rsp(llc_mem_rsp_chnl);
	llc_dut->llc_rst_tb(llc_rst_tb_chnl);
	llc_dut->llc_rsp_out(llc_rsp_out_chnl);
	llc_dut->llc_dma_rsp_out(llc_dma_rsp_out_chnl);
	llc_dut->llc_fwd_out(llc_fwd_out_chnl);
	llc_dut->llc_mem_req(llc_mem_req_chnl);
	llc_dut->llc_rst_tb_done(llc_rst_tb_done_chnl);

#ifdef STATS_ENABLE
	l2_dut_0->l2_stats(l2_stats_0_chnl);
	l2_dut_1->l2_stats(l2_stats_1_chnl);
	llc_dut->llc_stats(llc_stats_chnl);
#endif

	tb->clk(clk);
	tb->rst(rst);

	// Binding L2 0 to testbench
	tb->flush_done_0(flush_done_0);
	tb->acc_flush_done_0(acc_flush_done_0);
	tb->l2_cpu_req_0_tb(l2_cpu_req_0_chnl);
	tb->l2_fwd_in_0_tb(l2_fwd_in_0_chnl);
	tb->l2_rsp_in_0_tb(l2_rsp_in_0_chnl); 
	tb->l2_flush_0_tb(l2_flush_0_chnl); 
	tb->l2_fence_0_tb(l2_fence_0_chnl); 
	tb->l2_rd_rsp_0_tb(l2_rd_rsp_0_chnl);
	tb->l2_inval_0_tb(l2_inval_0_chnl);
	tb->l2_bresp_0_tb(l2_bresp_0_chnl);
	tb->l2_req_out_0_tb(l2_req_out_0_chnl);
	tb->l2_fwd_out_0_tb(l2_fwd_out_0_chnl);
	tb->l2_rsp_out_0_tb(l2_rsp_out_0_chnl);

	// Binding L2 1 to testbench
	tb->flush_done_1(flush_done_1);
	tb->acc_flush_done_1(acc_flush_done_1);
	tb->l2_cpu_req_1_tb(l2_cpu_req_1_chnl);
	tb->l2_fwd_in_1_tb(l2_fwd_in_1_chnl);
	tb->l2_rsp_in_1_tb(l2_rsp_in_1_chnl); 
	tb->l2_flush_1_tb(l2_flush_1_chnl); 
	tb->l2_fence_1_tb(l2_fence_1_chnl); 
	tb->l2_rd_rsp_1_tb(l2_rd_rsp_1_chnl);
	tb->l2_inval_1_tb(l2_inval_1_chnl);
	tb->l2_bresp_1_tb(l2_bresp_1_chnl);
	tb->l2_req_out_1_tb(l2_req_out_1_chnl);
	tb->l2_fwd_out_1_tb(l2_fwd_out_1_chnl);
	tb->l2_rsp_out_1_tb(l2_rsp_out_1_chnl);

	// Binding LLC to testbench
	tb->llc_req_in_tb(llc_req_in_chnl);
	tb->llc_dma_req_in_tb(llc_dma_req_in_chnl);
	tb->llc_rsp_in_tb(llc_rsp_in_chnl);
	tb->llc_mem_rsp_tb(llc_mem_rsp_chnl); 
	tb->llc_rst_tb_tb(llc_rst_tb_chnl);
	tb->llc_rsp_out_tb(llc_rsp_out_chnl);
	tb->llc_dma_rsp_out_tb(llc_dma_rsp_out_chnl);
	tb->llc_fwd_out_tb(llc_fwd_out_chnl);
	tb->llc_mem_req_tb(llc_mem_req_chnl);
	tb->llc_rst_tb_done_tb(llc_rst_tb_done_chnl);

#ifdef STATS_ENABLE
	tb->l2_stats_0_tb(l2_stats_0_chnl);
	tb->l2_stats_1_tb(l2_stats_1_chnl);
	tb->llc_stats_tb(llc_stats_chnl);
#endif
    }
};

#endif // __SYSTEM_HPP__
