`timescale 1ps / 1ps
`include "cache_consts.svh"
`include "cache_types.svh"

`include "uvm_macros.svh"
import uvm_pkg::*;

module l2_tb_top();

l2_cpu_req_if l2_cpu_req_intf();
l2_fwd_in_if l2_fwd_in_intf();
l2_rsp_in_if l2_rsp_in_intf();
l2_req_out_if l2_req_out_intf();
l2_rsp_out_if l2_rsp_out_intf();
l2_rd_rsp_if l2_rd_rsp_intf();
l2_inval_if l2_inval_intf();
l2_bresp_if l2_bresp_intf();
l2_flush_if l2_flush_intf();
l2_stats_if l2_stats_intf();
logic flush_done;

// Unused hprot_data bits
logic tie_1;
logic tie_2;

logic clk;
logic rst;

l2_rtl_top l2_top_u(
    .clk(clk),
    .rst(rst),
    // l2_cpu_req
    .l2_cpu_req_valid(l2_cpu_req_intf.valid),
    .l2_cpu_req_data_cpu_msg(l2_cpu_req_intf.cpu_msg),
    .l2_cpu_req_data_hsize(l2_cpu_req_intf.hsize),
    .l2_cpu_req_data_hprot({1'b0, l2_cpu_req_intf.hprot}),
    .l2_cpu_req_data_addr(l2_cpu_req_intf.addr),
    .l2_cpu_req_data_word(l2_cpu_req_intf.word),
    .l2_cpu_req_data_amo(l2_cpu_req_intf.amo),
    .l2_cpu_req_ready(l2_cpu_req_intf.ready),
    // l2_fwd_in
    .l2_fwd_in_valid(l2_fwd_in_intf.valid),
    .l2_fwd_in_data_coh_msg(l2_fwd_in_intf.coh_msg),
    .l2_fwd_in_data_addr(l2_fwd_in_intf.addr),
    .l2_fwd_in_data_req_id(l2_fwd_in_intf.req_id),
    .l2_fwd_in_ready(l2_fwd_in_intf.ready),
    // l2_rsp_in
    .l2_rsp_in_valid(l2_rsp_in_intf.valid),
    .l2_rsp_in_data_coh_msg(l2_rsp_in_intf.coh_msg),
    .l2_rsp_in_data_addr(l2_rsp_in_intf.addr),
    .l2_rsp_in_data_line(l2_rsp_in_intf.line),
    .l2_rsp_in_data_invack_cnt(l2_rsp_in_intf.invack_cnt),
    .l2_rsp_in_ready(l2_rsp_in_intf.ready),
    // l2_req_out
    .l2_req_out_valid(l2_req_out_intf.valid),
    .l2_req_out_data_coh_msg(l2_req_out_intf.coh_msg),
    .l2_req_out_data_hprot({tie_1, l2_req_out_intf.hprot}),
    .l2_req_out_data_addr(l2_req_out_intf.addr),
    .l2_req_out_data_line(l2_req_out_intf.line),
    .l2_req_out_ready(l2_req_out_intf.ready),
    // l2_rsp_out
    .l2_rsp_out_valid(l2_rsp_out_intf.valid),
    .l2_rsp_out_data_coh_msg(l2_rsp_out_intf.coh_msg),
    .l2_rsp_out_data_req_id(l2_rsp_out_intf.req_id),
    .l2_rsp_out_data_to_req(l2_rsp_out_intf.to_req),
    .l2_rsp_out_data_addr(l2_rsp_out_intf.addr),
    .l2_rsp_out_data_line(l2_rsp_out_intf.line),
    .l2_rsp_out_ready(l2_rsp_out_intf.ready),
    // l2_rd_rsp
    .l2_rd_rsp_valid(l2_rd_rsp_intf.valid),
    .l2_rd_rsp_data_line(l2_rd_rsp_intf.line),
    .l2_rd_rsp_ready(l2_rd_rsp_intf.ready),
    // l2_inval
    .l2_inval_valid(l2_inval_intf.valid),
    .l2_inval_data_addr(l2_inval_intf.addr),
    .l2_inval_data_hprot({tie_2, l2_inval_intf.hprot}),
    .l2_inval_ready(l2_inval_intf.ready),
    // l2_bresp
    .l2_bresp_valid(l2_bresp_intf.valid),
    .l2_bresp_data(l2_bresp_intf.data),
    .l2_bresp_ready(l2_bresp_intf.ready),
    // l2_flush
    .l2_flush_valid(l2_flush_intf.valid),
    .l2_flush_data(l2_flush_intf.data),
    .l2_flush_ready(l2_flush_intf.ready),
    // l2_stats
    .l2_stats_valid(l2_stats_intf.valid),
    .l2_stats_data(l2_stats_intf.data),
    .l2_stats_ready(l2_stats_intf.ready),
    .flush_done(flush_done)
);

// Generate clock
always #`CLOCK_PERIOD clk = ~clk;

// Release reset
initial begin
    rst = 1;
    #5 rst = 0;
end

  
  // Adding the interface to config_db
initial begin 
    uvm_config_db#(virtual l2_cpu_req_if)::set(uvm_root::get(),"*","l2_cpu_req_intf",l2_cpu_req_intf);
    $dumpfile("dump.vcd"); $dumpvars;
end
  
initial begin 
    run_test();
end

endmodule

